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
  fargate_capacity_providers = {}
  services = {
    webserver_backend = {
      create_task_iam_role = false
      tasks_iam_role_arn   = aws_iam_role.fastapi_backend_task_role.arn
      desired_count        = 1
      launch_type          = "EC2"
      cpu                  = 256
      memory               = 512

      deployment_minimum_healthy_percent = 100
      deployment_maximum_percent         = 200

      container_definitions = {
        webserver-backend = {
          cpu                       = 256
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
