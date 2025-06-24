module "ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  version      = "~> 5.0"
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
      auto_scaling_group_arn         = aws_autoscaling_group.ec2-asg.arn
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
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = null
    }
  }
  services = {
    webserver_backend = {
      requires_compatibilities = ["EC2"]
      create_task_iam_role     = false
      task_iam_role_arn        = aws_iam_role.fastapi_backend_task_role.arn

      network_mode = "host"

      desired_count = 1
      launch_type   = "EC2"
      cpu           = 512
      memory        = 512

      deployment_minimum_healthy_percent = 100
      deployment_maximum_percent         = 200

      container_definitions = {
        webserver-backend = {
          cpu                       = 512
          memory                    = 512
          essential                 = true
          image                     = "111111111111.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
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
            { name = "AUTH0_DOMAIN", value = var.auth0_domain },
            { name = "AUTH0_ISSUER", value = var.auth0_issuer },
            { name = "AUTH0_API_AUDIENCE", value = var.auth0_api_audience },
            { name = "AUTH0_ALGORITHMS", value = var.auth0_algorithms },
            { name = "ALLOW_ORIGINS_URLS", value = jsonencode(var.ALLOW_ORIGINS_URLS) },
            { name = "DB_USER", value = "app_user" },
            { name = "DB_HOST", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_address },
            { name = "DB_PORT", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_port },
            { name = "DB_NAME", value = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_name },
            { name = "CROSSMINT_API_KEY_SSM_PATH", value = "/staging/nft-producer-service/CROSSMINT_API_KEY" },
            { name = "STRIPE_SECRET_KEY_SSM_PATH", value = "/staging/nft-producer-service/STRIPE_SECRET_KEY" },
            { name = "STRIPE_WEBHOOK_SIGNING_SECRET_SSM_PATH", value = "/staging/nft-producer-service/STRIPE_WEBHOOK_SIGNING_SECRET" },
            { name = "NFTBYAI_WALLET_ADDRESS", value = "0xA45BB78a84eA17CA64876D89CeD76ff1E837e759" },
            { name = "SMTP_PASS_SSM_PATH", value = "/staging/nft-producer-service/SMTP_PASS" },
            { name = "SMTP_HOST", value = "smtp.gmail.com" },
            { name = "SMTP_PORT", value = 465 },
            { name = "SMTP_USER", value = "ops@example.com" },
            { name = "SMTP_PASS", value = "REDACTED_SMTP_PASSWORD" },
            { name = "REPORT_TO_EMAIL", value = "alerts+staging3@gmail.com" },
            { name = "SUCCESSFULL_PURCHASE_URL", value = "http://staging.nftbyai.shop/confirmation" },
            { name = "FAILED_PURCHASE_URL", value = "http://staging.nftbyai.shop" },
            { name = "DEFAULT_NFT_OWNER", value = var.default_nft_owner },
            { name = "NFT_IMAGE_STORAGE_URL", value = var.nft_image_storage_url },
            { name = "REGION", value = var.region },
            { name = "FRONTEND_URL", value = var.FRONTEND_URL },
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
          source_security_group_id = aws_security_group.alb_sg.id
        }
        egress_all = { type = "egress", from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
      }

    }
  }

  tags = { Environment = "staging", Project = "NFT-backend" }

  # Ensure underlying infra exists first
  depends_on = [
    aws_autoscaling_group.ec2-asg,
    aws_launch_template.backend-webserver,
    aws_lb_target_group.web_tg,
    aws_security_group.alb_sg
  ]
}


resource "aws_autoscaling_group" "ec2-asg" {
  name                  = "ec2-asg"
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
resource "aws_cloudwatch_log_group" "webserver-backend" {
  name              = "/ecs/webserver-backend"
  retention_in_days = 7
}


resource "aws_iam_role" "fastapi_backend_task_role" {
  name = "ecs-admin-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fastapi_backend_task_role_policy_attachment" {
  role       = aws_iam_role.fastapi_backend_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
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

resource "aws_iam_role_policy_attachment" "webserver_backend_task_role_attach" {
  role       = module.ecs.services["webserver_backend"].tasks_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

