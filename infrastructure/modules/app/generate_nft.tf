
resource "aws_ecs_task_definition" "generate_nft" {
  family                   = "generate-nft"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.generate_nft_execution_role.arn
  task_role_arn            = aws_iam_role.generate_nft_task_role.arn
  container_definitions = jsonencode([
    {
      name      = "generate-nft"
      image     = "${var.account_id}.dkr.ecr.us-east-1.amazonaws.com/generate-nft:latest"
      essential = true
      cpu       = 1024
      memory    = 1024
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DB_USER", value = "app_user" },
        { name = "DB_HOST", value = var.db_instance_address },
        { name = "DB_NAME", value = "nftdb" },
        { name = "REGION", value = "us-east-1" },
        { name = "CROSSMINT_API_KEY_SSM_PATH", value = "/${var.environment_name}/nft-producer-service/CROSSMINT_API_KEY" },
        { name = "OPENAI_API_KEY_SSM_PATH", value = "/${var.environment_name}/nft-producer-service/OPENAI_API_KEY" },
        { name = "STRIPE_SECRET_KEY_SSM_PATH", value = "/${var.environment_name}/nft-producer-service/STRIPE_SECRET_KEY" },
        { name = "COLLECTION_ID", value = var.COLLECTION_ID },
        { name = "GPT_MODEL_1", value = var.GPT_MODEL_1 },
        { name = "IMAGE_GEN_MODEL", value = "gpt-image-1" },
        { name = "NFT_RECIPIENT", value = "email:owner@example.com:polygon" },
        { name = "PRICE_IN_CENTS", value = var.PRICE_IN_CENTS },
        { name = "S3_BUCKET", value = var.nfts_s3_bucket_name },
        { name = "LOG_LEVEL", value = "DEBUG" },
        { name = "IMAGE_SIZE", value = "1024x1536" },
        { name = "IMAGE_QUALITY", value = "high" },
        { name = "ENVIRONMENT", value = var.environment_name }
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

resource "aws_scheduler_schedule" "trigger_generate_nft" {
  name                = "run-generate-nft"
  schedule_expression = "rate(24 hours)"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = module.ecs.cluster_arn
    role_arn = aws_iam_role.eventbridge_invoke_ecs.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.generate_nft.arn

      capacity_provider_strategy {
        capacity_provider = "FARGATE" # built-in provider name
        weight            = 1
      }
      network_configuration {
        subnets          = var.public_subnet_ids
        security_groups  = [aws_security_group.generate_nft_task.id]
        assign_public_ip = true
      }
    }
  }
}


resource "aws_security_group" "generate_nft_task" {
  name        = "generate-nft-task-sg"
  description = "Network rules for awsvpc ENIs of generate-nft tasks"
  vpc_id      = var.vpc_id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "generate_nft_to_rds" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  security_group_id        = var.db_instance_sg
  source_security_group_id = aws_security_group.generate_nft_task.id
  description              = "allow generate-nft tasks to connect to  RDS"
}


resource "aws_cloudwatch_log_group" "generate_nft" {
  name              = "/ecs/generate-nft"
  retention_in_days = 7
}



resource "aws_iam_role" "generate_nft_task_role" {
  name = "generate_nft_task_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "generate_nft_task_role_policy_attachment" {
  role       = aws_iam_role.generate_nft_task_role.name
  policy_arn = aws_iam_policy.generate_nft_task_role_policy.arn
}

resource "aws_iam_policy" "generate_nft_task_role_policy" {
  name = "generate_nft_task_role_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "SSMParameterReadAccess",
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ],
        "Resource" : [
          "arn:aws:ssm:us-east-1:${var.account_id}:parameter/${var.environment_name}/nft-producer-service/CROSSMINT_API_KEY",
          "arn:aws:ssm:us-east-1:${var.account_id}:parameter/${var.environment_name}/nft-producer-service/OPENAI_API_KEY",
          "arn:aws:ssm:us-east-1:${var.account_id}:parameter/${var.environment_name}/nft-producer-service/SMTP_PASS",
          "arn:aws:ssm:us-east-1:${var.account_id}:parameter/${var.environment_name}/nft-producer-service/STRIPE_SECRET_KEY",
          "arn:aws:ssm:us-east-1:${var.account_id}:parameter/${var.environment_name}/nft-producer-service/STRIPE_WEBHOOK_SIGNING_SECRET",
        ]

      },
      {
        "Sid" : "RDSIAMAuthConnect",
        "Effect" : "Allow",
        "Action" : "rds-db:connect",
        "Resource" : "arn:aws:rds-db:${var.region}:${var.account_id}:dbuser:${var.db_instance_resource_id}/app_user"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.nfts_s3_bucket_name}/*"
        ]
      },


    ]
  })
}


resource "aws_iam_role_policy_attachment" "generate_nft_execution_role_policy" {
  role       = aws_iam_role.generate_nft_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "generate_nft_execution_role" {
  name = "generate_nft_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
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

