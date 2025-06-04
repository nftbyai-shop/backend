
resource "aws_ecs_cluster" "main" {
  name = "staging-cluster"
}

locals {
  application_username = "app_user"
}

resource "aws_ecs_task_definition" "main" {
  family                   = "generate-nft"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "generate-nft"
      image     = "111111111111.dkr.ecr.us-east-1.amazonaws.com/generate-nft:latest"
      essential = true
      cpu       = 256
      memory    = 512

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB_USER", value = local.application_username },
        { name = "DB_HOST", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address },
        { name = "DB_NAME", value = "nftdb" },
        { name = "REGION", value = "us-east-1" },
        { name = "CROSSMINT_API_KEY_SSM_PATH", value = "/staging/nft-producer-service/CROSSMINT_API_KEY" },
        { name = "OPENAI_API_KEY_SSM_PATH", value = "/staging/nft-producer-service/OPENAI_API_KEY" },
        { name = "COLLECTION_ID", value = "2f36274e-3463-49c1-9ee4-a01205674540" },
        { name = "GPT_MODEL_1", value = "gpt-4.1-nano" },
        { name = "IMAGE_GEN_MODEL", value = "dall-e-2" },
        { name = "NFT_RECIPIENT", value = "email:owner@example.com:polygon" },
        { name = "S3_BUCKET", value = data.terraform_remote_state.platform_deployment_state.outputs.s3_bucket_name_for_nfts },
        { name = "LOG_LEVEL", value = "DEBUG" },
        { name = "IMAGE_SIZE", value = "1024x1024" },
        { name = "IMAGE_QUALITY", value = "" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/generate-nft"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "ecs_generate_nft" {
  name              = "/ecs/generate-nft"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRoleAdmin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_admin" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRoleAdmin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_admin" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}



resource "aws_iam_role" "eventbridge_invoke_ecs" {
  name = "eventbridge-invoke-ecs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_scheduler_schedule" "trigger_ecs_task" {
  name = "run-ecs-task-schedule"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "rate(10 minutes)"

  target {
    arn      = aws_ecs_cluster.main.arn
    role_arn = aws_iam_role.eventbridge_invoke_ecs.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.main.arn
      launch_type         = "FARGATE"
      platform_version    = "LATEST"
      network_configuration {
        subnets          = data.terraform_remote_state.platform_deployment_state.outputs.public_subnets
        assign_public_ip = true
        security_groups  = [data.terraform_remote_state.platform_deployment_state.outputs.default_security_group_id]
      }
    }
  }
}


resource "aws_iam_role_policy" "eventbridge_invoke_ecs_policy" {
  name = "eventbridge-invoke-ecs-policy"
  role = aws_iam_role.eventbridge_invoke_ecs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

