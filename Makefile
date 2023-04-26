export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION=us-east-1
SHELL := /bin/bash

usage:                ## Show this help
		@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

install:              ## Install dependencies
		@which localstack || pip install localstack
		@which awslocal || pip install awscli-local
		@which tflocal || pip install terraform-local

terraform-setup:      ## Set up Terraform
		cd terraform; \
		tflocal init; \
		echo "Deploying Terraform configuration 🚀"; \
		tflocal apply --auto-approve;

cloudformation-setup: ## Set up CloudFormation
		cd cloudformation; \
		STACK="stack1"; \
		CF_FILE="ecsapi-demo-cloudformation.yaml"; \
		echo "Deploying CloudFormation stack 🚀"; \
		awslocal cloudformation create-stack --stack-name $$STACK --template-body file://$$CF_FILE; \

run:                  ## Run the sample app
		@echo "Building Web assets and uploading to local S3 bucket 🪣"; \
			cd client-application-react; \
			test -e node_modules || yarn; \
			test -e build/index.html || yarn build; \
			awslocal s3 mb s3://sample-app; \
			awslocal s3 sync build s3://sample-app; \
			API_ID=$$(awslocal apigatewayv2 get-apis | jq -r '.Items[] | select(.Name=="ecsapi-demo") | .ApiId'); \
			POOL_ID=$$(awslocal cognito-idp list-user-pools --max-results 1 | jq -r '.UserPools[0].Id'); \
			CLIENT_ID=$$(awslocal cognito-idp list-user-pool-clients --user-pool-id $$POOL_ID | jq -r '.UserPoolClients[0].ClientId'); \
			URL="http://sample-app.s3.localhost.localstack.cloud:4566/index.html?stackregion=us-east-1&stackhttpapi=$$API_ID&stackuserpool=$$POOL_ID&stackuserpoolclient=$$CLIENT_ID"; \
			echo "Check out the sample application 🤩"; \
			echo $$URL

start:                ## Start LocalStack in detached mode
		EXTRA_CORS_ALLOWED_ORIGINS=http://sample-app.s3.localhost.localstack.cloud:4566 DISABLE_CUSTOM_CORS_APIGATEWAY=1 localstack start -d

stop:                 ## Stop the running LocalStack container
		@echo
		localstack stop

ready:                ## Make sure the LocalStack container is up
		@echo Waiting on the LocalStack container...
		@localstack wait -t 30 && echo LocalStack is ready to use! || (echo Gave up waiting on LocalStack, exiting. && exit 1)

logs:                 ## Save the logs in a logs.txt file
		@localstack logs > logs.txt

.PHONY: usage install run start stop ready logs
