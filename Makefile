export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION=us-east-1
SHELL := /bin/bash

usage:                ## Show this help
		@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

install:              ## Install dependencies
		@which lstk || npm install -g @localstack/lstk

terraform-setup:      ## Set up Terraform
		cd terraform; \
		lstk tf init; \
		echo "Deploying Terraform configuration 🚀"; \
		lstk tf apply --auto-approve;

cloudformation-setup: ## Set up CloudFormation
		cd cloudformation; \
		STACK="stack1"; \
		CF_FILE="ecsapi-demo-cloudformation.yaml"; \
		echo "Deploying CloudFormation stack 🚀"; \
		lstk aws cloudformation create-stack --stack-name $$STACK --template-body file://$$CF_FILE; \

run:                  ## Run the sample app
		@echo "Building Web assets and uploading to local S3 bucket 🪣"; \
			cd client-application-react; \
			test -e node_modules || yarn; \
			test -e build/index.html || NODE_OPTIONS=--openssl-legacy-provider yarn build; \
			lstk aws s3 mb s3://sample-app; \
			lstk aws s3 sync build s3://sample-app; \
			API_ID=$$(lstk aws apigatewayv2 get-apis | jq -r '.Items[] | select(.Name=="ecsapi-demo") | .ApiId'); \
			POOL_ID=$$(lstk aws cognito-idp list-user-pools --max-results 1 | jq -r '.UserPools[0].Id'); \
			CLIENT_ID=$$(lstk aws cognito-idp list-user-pool-clients --user-pool-id $$POOL_ID | jq -r '.UserPoolClients[0].ClientId'); \
			URL="http://sample-app.s3.localhost.localstack.cloud:4566/index.html?stackregion=us-east-1&stackhttpapi=$$API_ID&stackuserpool=$$POOL_ID&stackuserpoolclient=$$CLIENT_ID"; \
			echo "Check out the sample application 🤩"; \
			echo $$URL

start:                ## Start LocalStack
		@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
		@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) LOCALSTACK_EXTRA_CORS_ALLOWED_ORIGINS=http://sample-app.s3.localhost.localstack.cloud:4566 LOCALSTACK_DISABLE_CUSTOM_CORS_APIGATEWAY=1 lstk start --non-interactive

stop:                 ## Stop the running LocalStack container
		@echo
		lstk stop

ready:                ## Confirm LocalStack is ready (lstk start already waits, so this just reports status)
		@lstk status

logs:                 ## Save the logs in a logs.txt file
		@lstk logs > logs.txt

.PHONY: usage install run start stop ready logs
