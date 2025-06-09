resource "aws_security_group" "web_alb_sg" {
  name        = "web-alb-sg"
  description = "Allow HTTP/HTTPS from office IP"
  vpc_id      = data.terraform_remote_state.platform_deployment_state.outputs.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["198.51.100.7/32"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["198.51.100.7/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_instance_sg" {
  name   = "ecs-instance-sg"
  vpc_id = data.terraform_remote_state.platform_deployment_state.outputs.vpc_id
  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb" "web_alb" {
  name               = "webserver-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_alb_sg.id]
  subnets            = data.terraform_remote_state.platform_deployment_state.outputs.public_subnets
}

resource "aws_lb_target_group" "web_tg" {
  name        = "webserver-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.platform_deployment_state.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "backend-webserver" {
  name_prefix   = "backend-webserver"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t2.micro"
  key_name      = "MyKeyPair"

  iam_instance_profile {
    name = aws_iam_instance_profile.backend_webserver_instance_profile.name
  }

  network_interfaces {
    security_groups             = [aws_security_group.ecs_instance_sg.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    echo "ECS_CLUSTER=staging-cluster" >> /etc/ecs/ecs.config
  USERDATA
  )
}

resource "aws_autoscaling_group" "ecs" {
  name                  = "ecs-ec2-asg"
  max_size              = 1
  min_size              = 1
  desired_capacity      = 1
  vpc_zone_identifier   = data.terraform_remote_state.platform_deployment_state.outputs.public_subnets
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.backend-webserver.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ecs-ec2-instance"
    propagate_at_launch = true
  }

  health_check_type = "EC2"
}

# -----------------------------------------------------------------------------
# ECS cluster and service – module
# -----------------------------------------------------------------------------
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = "staging-cluster"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/staging-cluster"
      }
    }
  }

  autoscaling_capacity_providers = {
    ec2_capacity = {
      auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

      managed_termination_protection = "ENABLED"
      managed_scaling = {
        status                    = "ENABLED"
        target_capacity           = 100
        minimum_scaling_step_size = 1
        maximum_scaling_step_size = 1
        instance_warmup_period    = 300
      }

      default_capacity_provider_strategy = { weight = 1, base = 0 }
    }
  }

  fargate_capacity_providers = {}

  services = {
    webserver_backend = {
      desired_count = 1
      launch_type   = "EC2"
      cpu           = 256
      memory        = 512

      deployment_minimum_healthy_percent = 100
      deployment_maximum_percent         = 200

      container_definitions = {
        webserver-backend = {
          cpu                       = 256
          memory                    = 512
          essential                 = true
          image                     = "111111111111.dkr.ecr.us-east-1.amazonaws.com/backend"
          port_mappings             = [{ containerPort = 8080, hostPort = 8080, protocol = "tcp" }]
          enable_cloudwatch_logging = true
          log_configuration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/ecs/webserver-backend"
              awslogs-region        = "us-east-1"
              awslogs-stream-prefix = "ecs"
            }
          }

          environment = [
            { name = "AUTH0_DOMAIN", value = "https://dev-4zljthbwh3wy24vx.us.auth0.com" },
            { name = "AUTH0_ISSUER", value = "https://dev-4zljthbwh3wy24vx.us.auth0.com/" },
            { name = "AUTH0_API_AUDIENCE", value = "http://127.0.0.1:8000" },
            { name = "AUTH0_ALGORITHMS", value = "RS256" },
            { name = "CLIENT_URL", value = "http://localhost:5173" },
            { name = "DB_USER", value = "app_user" },
            { name = "DB_HOST", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address },
            { name = "DB_PORT", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_port },
            { name = "DB_NAME", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_name },
            { name = "DEFAULT_NFT_OWNER", value = "email:owner@example.com:polygon" },
            { name = "NFT_IMAGE_STORAGE_URL", value = "https://nfts-38029.s3.us-east-1.amazonaws.com" },
            { name = "REGION", value = "us-east-1" }
          ]
        }
      }

      load_balancer = {
        service = {
          target_group_arn = aws_lb_target_group.web_tg.arn
          container_name   = "webserver-backend"
          container_port   = 8080
        }
      }

      subnet_ids = data.terraform_remote_state.platform_deployment_state.outputs.public_subnets
      security_group_rules = {
        alb_ingress_8080 = {
          type                     = "ingress"
          from_port                = 8080
          to_port                  = 8080
          protocol                 = "tcp"
          source_security_group_id = aws_security_group.web_alb_sg.id
        }
        egress_all = { type = "egress", from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
      }
    }
  }

  tags = { Environment = "staging", Project = "NFT-backend" }

  # Ensure underlying infra exists first
  depends_on = [
    aws_autoscaling_group.ecs,
    aws_launch_template.backend-webserver,
    aws_lb_target_group.web_tg,
    aws_security_group.web_alb_sg
  ]
}

resource "aws_cloudwatch_log_group" "ecs_generate_nft" {
  name              = "/ecs/webserver-backend"
  retention_in_days = 7
}
# -----------------------------------------------------------------------------
# EventBridge schedule – now launches the generate-nft task on EC2
# -----------------------------------------------------------------------------
# (Task definition and IAM roles are unchanged from your earlier config)
resource "aws_scheduler_schedule" "trigger_ecs_task" {
  name = "run-ecs-task-schedule"

  flexible_time_window { mode = "OFF" }
  schedule_expression = "rate(24 hours)"

  target {
    arn      = module.ecs.cluster_arn # output from the ECS module
    role_arn = aws_iam_role.eventbridge_invoke_ecs.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.main.arn
      launch_type         = "EC2"
    }
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "generate-nft"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
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
        { name = "DB_USER", value = "app_user" },
        { name = "DB_HOST", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address },
        { name = "DB_NAME", value = "nftdb" },
        { name = "REGION", value = "us-east-1" },
        { name = "CROSSMINT_API_KEY_SSM_PATH", value = "/staging/nft-producer-service/CROSSMINT_API_KEY" },
        { name = "OPENAI_API_KEY_SSM_PATH", value = "/staging/nft-producer-service/OPENAI_API_KEY" },
        { name = "COLLECTION_ID", value = "2f36274e-3463-49c1-9ee4-a01205674540" },
        { name = "GPT_MODEL_1", value = "gpt-4.1-nano" },
        { name = "IMAGE_GEN_MODEL", value = "dall-e-3" },
        { name = "NFT_RECIPIENT", value = "email:owner@example.com:polygon" },
        { name = "S3_BUCKET", value = data.terraform_remote_state.platform_deployment_state.outputs.s3_bucket_name_for_nfts },
        { name = "LOG_LEVEL", value = "DEBUG" },
        { name = "IMAGE_SIZE", value = "1024x1024" },
        { name = "IMAGE_QUALITY", value = "standard" }
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



resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ecr" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "backend_webserver_instance_profile" {
  name = "backend_webserver_instance_profile"
  role = aws_iam_role.ecs_instance_role.name
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


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# (Optional: attach additional policies for DB, S3, etc as needed)
