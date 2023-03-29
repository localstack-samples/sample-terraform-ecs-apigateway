data "aws_region" "current" {
  name = "us-east-1"
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

variable "environment_name" {
  description = "A friendly environment name that will be used for namespacing all cluster resources. Example: staging, qa, or production"
  type = string
  default = "ecsapi-demo"
}

variable "private_dns_namespace_name" {
  description = "The private DNS name that identifies the name that you want to use to locate your resources"
  type = string
  default = "example.com"
}

variable "min_containers_foodstore_foods" {
  description = "Minimum number of ECS tasks per ECS service"
  type = string
  default = 3
}

variable "max_containers_foodstore_foods" {
  description = "Maximum number of ECS tasks per ECS service"
  type = string
  default = 30
}

variable "auto_scaling_target_value_foodstore_foods" {
  description = "Target CPU utilizatio (%) for ECS services auto scaling"
  type = string
  default = 50
}

variable "min_containers_petstore_pets" {
  description = "Minimum number of ECS tasks per ECS service"
  type = string
  default = 3
}

variable "max_containers_petstore_pets" {
  description = "Maximum number of ECS tasks per ECS service"
  type = string
  default = 30
}

variable "auto_scaling_target_value_petstore_pets" {
  description = "Target CPU utilizatio (%) for ECS services auto scaling"
  type = string
  default = 50
}

resource "aws_dynamodb_table" "dynamo_db_table_foodstore_foods" {
  name = "FoodStoreFoods"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "foodId"
  attribute {
      name = "foodId"
      type = "S"
    }
}

resource "aws_dynamodb_table" "dynamo_db_table_petstore_pets" {
  name = "PetStorePets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "petId"
  attribute {
      name = "petId"
      type = "S"
    }
}

resource "aws_vpc" "vpc" {
  enable_dns_support = true
  enable_dns_hostnames = true
  cidr_block = "10.0.0.0/16"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnet_one" {
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_two" {
  availability_zone = element(data.aws_availability_zones.available.names, 1)
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_three" {
  availability_zone = element(data.aws_availability_zones.available.names, 2)
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet_one" {
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.100.0/24"
}

resource "aws_subnet" "private_subnet_two" {
  availability_zone = element(data.aws_availability_zones.available.names, 1)
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.101.0/24"
}

resource "aws_subnet" "private_subnet_three" {
  availability_zone = element(data.aws_availability_zones.available.names, 2)
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.102.0/24"
}

resource "aws_internet_gateway" "internet_gateway" {}

resource "aws_ec2_transit_gateway" "transit_gateway" {}

resource "aws_ec2_transit_gateway_vpc_attachment" "gateway_attachement" {
  subnet_ids = [
    aws_subnet.private_subnet_one.id,
    aws_subnet.private_subnet_two.id,
    aws_subnet.private_subnet_three.id
  ]
  vpc_id = aws_vpc.vpc.id
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "public_route" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

resource "aws_route_table_association" "public_subnet_one_route_table_association" {
  subnet_id = aws_subnet.public_subnet_one.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_two_route_table_association" {
  subnet_id = aws_subnet.public_subnet_two.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_three_route_table_association" {
  subnet_id = aws_subnet.public_subnet_three.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_gateway_one_attachment" {
  vpc = true
}

resource "aws_eip" "nat_gateway_two_attachment" {
  vpc = true
}

resource "aws_eip" "nat_gateway_three_attachment" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway_one" {
  allocation_id = aws_eip.nat_gateway_one_attachment.allocation_id
  subnet_id = aws_subnet.public_subnet_one.id
}

resource "aws_nat_gateway" "nat_gateway_two" {
  allocation_id = aws_eip.nat_gateway_two_attachment.allocation_id
  subnet_id = aws_subnet.public_subnet_two.id
}

resource "aws_nat_gateway" "nat_gateway_three" {
  allocation_id = aws_eip.nat_gateway_three_attachment.allocation_id
  subnet_id = aws_subnet.public_subnet_three.id
}

resource "aws_route_table" "private_route_table_one" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "private_route_one" {
  route_table_id = aws_route_table.private_route_table_one.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway_one.id
}

resource "aws_route_table_association" "private_route_table_one_association" {
  route_table_id = aws_route_table.private_route_table_one.id
  subnet_id = aws_subnet.private_subnet_one.id
}

resource "aws_route_table" "private_route_table_two" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "private_route_two" {
  route_table_id = aws_route_table.private_route_table_two.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway_two.id
}

resource "aws_route_table_association" "private_route_table_two_association" {
  route_table_id = aws_route_table.private_route_table_two.id
  subnet_id = aws_subnet.private_subnet_two.id
}

resource "aws_route_table" "private_route_table_three" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "private_route_three" {
  route_table_id = aws_route_table.private_route_table_three.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway_three.id
}

resource "aws_route_table_association" "private_route_table_three_association" {
  route_table_id = aws_route_table.private_route_table_three.id
  subnet_id = aws_subnet.private_subnet_three.id
}

resource "aws_vpc_endpoint" "dynamo_db_endpoint" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Principal = "*"
        Resource = "*"
      }
    ]
  })
  route_table_ids = [
    aws_route_table.private_route_table_one.id,
    aws_route_table.private_route_table_two.id,
    aws_route_table.private_route_table_three.id
  ]
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
}

resource "aws_security_group" "container_security_group" {
  description = "Access to the Fargate containers"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "container_security_group_self_ingress" {
  // CF Property(GroupId) = aws_security_group.container_security_group.arn
  vpc_id = aws_security_group.container_security_group.id

  ingress {
    protocol = "tcp"
    from_port = 8080
    to_port = 8080
  }
}

resource "aws_iam_role" "auto_scaling_role" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  # managed_policy_arns = [aws_iam_role_policy.servi_role.AmazonEC2ContainerServiceAutoscaleRole]
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
  ]
}

resource "aws_iam_role" "ecs_role" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  })
  path = "/"
}

resource "aws_iam_role_policy" "ecs_role_policy" {
  name = "ecs-service"
  role = aws_iam_role.ecs_role.id
  policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ec2:AttachNetworkInterface",
              "ec2:CreateNetworkInterface",
              "ec2:CreateNetworkInterfacePermission",
              "ec2:DeleteNetworkInterface",
              "ec2:DeleteNetworkInterfacePermission",
              "ec2:Describe*",
              "ec2:DetachNetworkInterface",
              "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
              "elasticloadbalancing:DeregisterTargets",
              "elasticloadbalancing:Describe*",
              "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
              "elasticloadbalancing:RegisterTargets"
            ]
            Resource = "*"
          }
        ]
  })
}

resource "aws_iam_role" "ecs_task_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  })
  path = "/"
}

resource "aws_iam_role_policy" "ecs_task_execution_policy" {
  name = "ecs-task-execution-policy"
  role = aws_iam_role.ecs_task_execution_role.id
  policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Resource = "*"
          }
        ]
  })
}

resource "aws_service_discovery_private_dns_namespace" "private_dns_namespace" {
  vpc = aws_vpc.vpc.arn
  name = var.private_dns_namespace_name
}

resource "aws_service_discovery_service" "service_discovery_service_foodstore_foods" {
  dns_config {
    dns_records {
      type = "SRV"
      ttl = 60
    }
    namespace_id = aws_service_discovery_private_dns_namespace.private_dns_namespace.id
  }
  health_check_custom_config {
    failure_threshold = 1
  }
  name = "foods.foodstore"
}

resource "aws_service_discovery_service" "service_discovery_service_petstore_pets" {
  dns_config {
    dns_records {
      type = "SRV"
      ttl = 60
    }
    namespace_id = aws_service_discovery_private_dns_namespace.private_dns_namespace.id
  }
  health_check_custom_config {
    failure_threshold = 1
  }
  name = "pets.petstore"
}

resource "aws_iam_role" "task_role_foodstore_foods" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "dynamodb-table-access" {
  name = "dynamodb-table-access"
  role = aws_iam_role.task_role_petstore_pets.id
  policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "dynamodb:BatchGet*",
              "dynamodb:DescribeStream",
              "dynamodb:DescribeTable",
              "dynamodb:Get*",
              "dynamodb:Query",
              "dynamodb:Scan",
              "dynamodb:BatchWrite*",
              "dynamodb:CreateTable",
              "dynamodb:Delete*",
              "dynamodb:Update*",
              "dynamodb:PutItem"
            ]
            Resource = "*"
          }
        ]
  })
}

resource "aws_iam_role" "task_role_petstore_pets" {
  assume_role_policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "dynamodb_table_access" {
  name = "dynamodb-table-access"
  role = aws_iam_role.task_role_petstore_pets.id
  policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "dynamodb:BatchGet*",
              "dynamodb:DescribeStream",
              "dynamodb:DescribeTable",
              "dynamodb:Get*",
              "dynamodb:Query",
              "dynamodb:Scan",
              "dynamodb:BatchWrite*",
              "dynamodb:CreateTable",
              "dynamodb:Delete*",
              "dynamodb:Update*",
              "dynamodb:PutItem"
            ]
            Resource = "*"
          }
        ]
  })
}

# resource "aws_iam_role_policy_attachment" "pet_store_attach" {
#   role       = aws_iam_role.task_role_petstore_pets.name
#   policy_arn = aws_iam_role_policy.dynamodb_table_access
# }

# resource "aws_iam_role_policy_attachment" "food_store_attach" {
#   role       = aws_iam_role.task_role_foodstore_foods
#   policy_arn = aws_iam_role_policy.dynamodb_table_access
# }

resource "aws_ecs_task_definition" "task_definition_foodstore_foods" {
  family = "foodstore-foods"
  task_role_arn = aws_iam_role.task_role_foodstore_foods.arn
  requires_compatibilities = ["FARGATE"]

  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "FoodstoreFoods",
      "image": "localstack.container-registry.com/library/foodstore",
      "essential": true,
      "environment": [
        {"name": "DynamoDBTable", "value": "${aws_dynamodb_table.dynamo_db_table_foodstore_foods.name}"}
      ],
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": 8080
        }
      ]
    }
  ]
  TASK_DEFINITION
  network_mode = "awsvpc"
  memory = "512"
  cpu = "256"
}

resource "aws_ecs_task_definition" "task_definition_petstore_pets" {
  family = "petstore-pets"
  task_role_arn = aws_iam_role.task_role_petstore_pets.arn
  requires_compatibilities = ["FARGATE"]
  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "PetstorePets",
      "image": "localstack.container-registry.com/library/petstore",
      "essential": true,
      "environment": [
        {"name": "DynamoDBTable", "value": "${aws_dynamodb_table.dynamo_db_table_petstore_pets.name}"}
      ],
      "portMappings": [
        {
          "protocol": "tcp",
          "containerPort": 8080
        }
      ]
    }
  ]
  TASK_DEFINITION
  network_mode = "awsvpc"
  memory = "512"
  cpu = "256"
}

resource "aws_ecs_service" "service_foodstore_foods" {
  name = "service-foodstore-foods"
  cluster = aws_ecs_cluster.ecs_cluster.arn
  task_definition = aws_ecs_task_definition.task_definition_foodstore_foods.arn
  launch_type = "FARGATE"
  desired_count = 3
  service_registries {
    registry_arn = aws_service_discovery_service.service_discovery_service_foodstore_foods.arn
    port = 8080
  }
  network_configuration {
    assign_public_ip = false
    subnets = [
      aws_subnet.private_subnet_one.id,
      aws_subnet.private_subnet_two.id,
      aws_subnet.private_subnet_three.id
    ]
    security_groups = [
      aws_security_group.container_security_group.id
    ]
  }
}

resource "aws_ecs_service" "service_petstore_pets" {
  name = "service-petstore-pets"
  cluster = aws_ecs_cluster.ecs_cluster.arn
  task_definition = aws_ecs_task_definition.task_definition_petstore_pets.arn
  launch_type = "FARGATE"
  desired_count = 3
  service_registries {
    registry_arn = aws_service_discovery_service.service_discovery_service_petstore_pets.arn
    port = 8080
  }
  network_configuration {
    assign_public_ip = false
    subnets = [
      aws_subnet.private_subnet_one.id,
      aws_subnet.private_subnet_two.id,
      aws_subnet.private_subnet_three.id
    ]
    security_groups = [
      aws_security_group.container_security_group.id
    ]
  }
}

resource "aws_apigatewayv2_vpc_link" "http_api_vpc_link" {
  name = var.environment_name
  security_group_ids = [
    aws_security_group.container_security_group.id
  ]
  subnet_ids = [
    aws_subnet.private_subnet_one.id,
    aws_subnet.private_subnet_two.id,
    aws_subnet.private_subnet_three.id
  ]
}

resource "aws_cognito_user_pool" "user_pool" {
  name = "user-pool"
  username_attributes = [
    "email"
  ]
  auto_verified_attributes = [
    "email"
  ]
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name = "user-pool-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  generate_secret = false
  supported_identity_providers = [
    "COGNITO"
  ]
  prevent_user_existence_errors = "ENABLED"
}

resource "aws_apigatewayv2_api" "http_api" {
  name = var.environment_name
  protocol_type = "HTTP"
  body = jsonencode(
    {
    openapi = "3.0.1"
    info = {
      title = "${var.environment_name}"
    }
    components = {
      securitySchemes = {
        my-authorizer = {
          type = "oauth2"
          flows = {
          }
          x-amazon-apigateway-authorizer = {
            identitySource = "$request.header.Authorization"
            jwtConfiguration = {
              audience = [
                "${aws_cognito_user_pool_client.user_pool_client.client_secret}"
              ]
              # TODO: look into better parity with AWS
              issuer = "http://localhost:4566/${aws_cognito_user_pool.user_pool.id}"
            }
            type = "jwt"
          }
        }
      }
    }
    paths = {
      "/foodstore/foods/{foodId}" = {
        get = {
          responses = {
            default = {
              description = "Default response for GET /foodstore/foods/{foodId}"
            }
          }
          x-amazon-apigateway-integration = {
            payloadFormatVersion = "1.0"
            connectionId = "${aws_apigatewayv2_vpc_link.http_api_vpc_link.id}"
            type = "http_proxy"
            httpMethod = "ANY"
            uri = "${aws_service_discovery_service.service_discovery_service_foodstore_foods.arn}"
            connectionType = "VPC_LINK"
          }
        }
        put = {
          responses = {
            default = {
              description = "Default response for PUT /foodstore/foods/{foodId}"
            }
          }
          security = [
            {
              my-authorizer = [
              ]
            }
          ]
          x-amazon-apigateway-integration = {
            payloadFormatVersion = "1.0"
            connectionId = "${aws_apigatewayv2_vpc_link.http_api_vpc_link.id}"
            type = "http_proxy"
            httpMethod = "ANY"
            uri = "${aws_service_discovery_service.service_discovery_service_foodstore_foods.arn}"
            connectionType = "VPC_LINK"
          }
        }
      }
      "/petstore/pets/{petId}" = {
        get = {
          responses = {
            default = {
              description = "Default response for GET /petstore/pets/{petId}"
            }
          }
          x-amazon-apigateway-integration = {
            payloadFormatVersion = "1.0"
            connectionId = "${aws_apigatewayv2_vpc_link.http_api_vpc_link.id}"
            type = "http_proxy"
            httpMethod = "ANY"
            uri = "${aws_service_discovery_service.service_discovery_service_petstore_pets.arn}"
            connectionType = "VPC_LINK"
          }
        }
        put = {
          responses = {
            default = {
              description = "Default response for PUT /petstore/pets/{petId}"
            }
          }
          security = [
            {
              my-authorizer = [
              ]
            }
          ]
          x-amazon-apigateway-integration = {
            payloadFormatVersion = "1.0"
            connectionId = "${aws_apigatewayv2_vpc_link.http_api_vpc_link.id}"
            type = "http_proxy"
            httpMethod = "ANY"
            uri = "${aws_service_discovery_service.service_discovery_service_petstore_pets.arn}"
            connectionType = "VPC_LINK"
          }
        }
      }
    }
    x-amazon-apigateway-cors = {
      allowOrigins = [
        "https://master.d34am23lsz3nvz.amplifyapp.com"
      ]
      allowHeaders = [
        "*"
      ]
      allowMethods = [
        "PUT",
        "GET"
      ]
    }
    x-amazon-apigateway-importexport-version = "1.0"
  }
  )
}

resource "aws_apigatewayv2_stage" "http_api_stage" {
  name = "$default"
  api_id = aws_apigatewayv2_api.http_api.id
  auto_deploy = true
}

output "api_test_page" {
  description = "The URL of the sample web app client, used to test the sample API"
  value = join("", ["https://master.d34am23lsz3nvz.amplifyapp.com/?stackregion=", data.aws_region.current.name, "&stackhttpapi=", aws_apigatewayv2_api.http_api.id, "&stackuserpool=", aws_cognito_user_pool.user_pool.arn, "&stackuserpoolclient=", aws_cognito_user_pool_client.user_pool_client.client_secret])
  sensitive = true
}

output "api_invoke_url" {
  description = "Invoke URL for the HTTP API"
  value = "https://${aws_apigatewayv2_api.http_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
}

output "api_invoke_url_foodstore_foods" {
  description = "Invoke URL for the HTTP API for the service Foodstore Foods"
  value = "https://${aws_apigatewayv2_api.http_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/foodstore/foods/{foodId}"
}

output "api_invoke_url_petstore_pets" {
  description = "Invoke URL for the HTTP API for the service Petstore Pets"
  value = "https://${aws_apigatewayv2_api.http_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/petstore/pets/{petId}"
}

output "api_id" {
  description = "The ID of the HTTP API"
  value = aws_apigatewayv2_api.http_api.id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value = aws_ecs_cluster.ecs_cluster.arn
}

output "vpc_id" {
  description = "The ID of the VPC that this stack is deployed in"
  value = aws_vpc.vpc.id
}

output "container_security_group" {
  description = "A security group used to allow Fargate containers to receive traffic"
  value = aws_security_group.container_security_group.id
}

output "private_dns_namespace" {
  description = "The ID of the private DNS namespace."
  value = aws_service_discovery_private_dns_namespace.private_dns_namespace.id
}
