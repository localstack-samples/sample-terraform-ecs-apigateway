#!/bin/bash
# Exercise both container APIs through the HTTP API, the way the web client does:
# - anyone can GET, and an unknown item returns an empty object
# - PUT without a token is rejected by the Cognito JWT authorizer
# - PUT with a Cognito access token stores the item in DynamoDB, and GET returns it
set -euo pipefail

API_NAME=${API_NAME:-ecsapi-demo}
MAX_ATTEMPTS=${MAX_ATTEMPTS:-60}
RUN_ID=ci-$(date +%s)
EMAIL="$RUN_ID@example.com"
PASSWORD='Ci-Passw0rd!'

API_ID=$(lstk aws apigatewayv2 get-apis --query "Items[?Name=='$API_NAME'].ApiId | [0]" --output text)
POOL_ID=$(lstk aws cognito-idp list-user-pools --max-results 10 --query "UserPools[?Name=='user-pool'].Id | [0]" --output text)
CLIENT_ID=$(lstk aws cognito-idp list-user-pool-clients --user-pool-id "$POOL_ID" --query 'UserPoolClients[0].ClientId' --output text)
BASE="http://$API_ID.execute-api.localhost.localstack.cloud:4566"
echo "API: $BASE"

# Wait until both ECS services run at least one task
for service in service-foodstore-foods service-petstore-pets; do
  running=0
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    running=$(lstk aws ecs describe-services --cluster ecs-cluster --services "$service" \
      --query 'services[0].runningCount' --output text)
    [ "$running" != "None" ] && [ "$running" -ge 1 ] && break
    echo "Attempt $attempt/$MAX_ATTEMPTS: $service has no running tasks yet"
    sleep 5
  done
  if [ "$running" = "None" ] || [ "$running" -lt 1 ]; then
    echo "Test failed: $service has no running tasks"
    exit 1
  fi
  echo "PASS: $service is running $running task(s)"
done

# Print "<status> <body>" for a request
call() {
  local response
  response=$(curl -s -m 30 -w '\n%{http_code}' "$@")
  echo "${response##*$'\n'} ${response%$'\n'*}"
}

# Sign up and confirm a user, then log in to get the access token the web client sends
lstk aws cognito-idp sign-up --client-id "$CLIENT_ID" --username "$EMAIL" --password "$PASSWORD" \
  --user-attributes Name=email,Value="$EMAIL" > /dev/null
lstk aws cognito-idp admin-confirm-sign-up --user-pool-id "$POOL_ID" --username "$EMAIL"
TOKEN=$(lstk aws cognito-idp initiate-auth --client-id "$CLIENT_ID" --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="$EMAIL",PASSWORD="$PASSWORD" --query AuthenticationResult.AccessToken --output text)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
  echo "Test failed: could not log in as $EMAIL"
  exit 1
fi
echo "PASS: signed up and logged in as $EMAIL"

# check_store <path prefix> <id field> <table> <payload>
check_store() {
  local prefix=$1 id_field=$2 table=$3 payload=$4 id="$RUN_ID" url result status body stored
  url="$BASE/$prefix/$id"

  # The first requests can fail while the integration warms up, so retry until GET answers
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    result=$(call "$url")
    [ "${result%% *}" = "200" ] && break
    echo "Attempt $attempt/$MAX_ATTEMPTS: GET $prefix returned ${result%% *}"
    sleep 5
  done
  status=${result%% *}; body=${result#* }
  if [ "$status" != "200" ] || [ "$body" != "{}" ]; then
    echo "Test failed: GET $url returned $status '$body', expected 200 '{}'"
    exit 1
  fi
  echo "PASS: anonymous GET $prefix/$id returns an empty object"

  result=$(call -X PUT -H 'Content-Type: application/json' -d "$payload" "$url")
  status=${result%% *}
  if [ "$status" != "401" ]; then
    echo "Test failed: PUT without a token returned $status '${result#* }', expected 401"
    exit 1
  fi
  echo "PASS: PUT $prefix/$id without a token is rejected with 401"

  result=$(call -X PUT -H 'Content-Type: application/json' -H "Authorization: $TOKEN" -d "$payload" "$url")
  status=${result%% *}; body=${result#* }
  if [ "$status" != "200" ] || ! echo "$body" | jq -e --arg id "$id" --arg f "$id_field" '.[$f] == $id' > /dev/null; then
    echo "Test failed: authorized PUT returned $status '$body'"
    exit 1
  fi
  echo "PASS: authorized PUT $prefix/$id stores the item"

  result=$(call "$url")
  body=${result#* }
  if ! echo "$body" | jq -e --argjson p "$payload" '. as $item | $p | to_entries | all(.value == $item[.key])' > /dev/null; then
    echo "Test failed: GET after PUT returned '$body'"
    exit 1
  fi
  stored=$(lstk aws dynamodb get-item --table-name "$table" --key "{\"$id_field\": {\"S\": \"$id\"}}" \
    --query "Item.name.S" --output text)
  if [ "$stored" != "$(echo "$payload" | jq -r .name)" ]; then
    echo "Test failed: $table item $id has name '$stored'"
    exit 1
  fi
  echo "PASS: GET $prefix/$id and the $table table return the stored item"
}

check_store foodstore/foods foodId FoodStoreFoods '{"name": "Gourmet Kibble", "brand": "Pawfect Pet Food Co.", "calories": 350}'
check_store petstore/pets petId PetStorePets '{"name": "Buddy", "breed": "Golden Retriever", "age": 3}'

echo "Test passed: both container APIs serve reads, enforce the authorizer on writes, and persist to DynamoDB"
