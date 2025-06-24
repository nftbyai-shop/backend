resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "arn:aws:acm:us-east-1:111111111111:certificate/01cec85c-1454-47a2-995f-f50db290a47f"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_lb" "web_alb" {
  name               = "webserver-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.terraform_remote_state.platform_deployment_state.outputs.public_subnets
}

resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.platform_deployment_state.outputs.vpc_id
  target_type = "instance"
  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
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

resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow HTTP/HTTPS from Cloudflare"
  vpc_id      = data.terraform_remote_state.platform_deployment_state.outputs.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = data.cloudflare_ip_ranges.cf.ipv4_cidrs
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = data.cloudflare_ip_ranges.cf.ipv4_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
data "cloudflare_ip_ranges" "cf" {}


resource "aws_security_group" "ecs_instance_sg" {
  name   = "ecs-instance-sg"
  vpc_id = data.terraform_remote_state.platform_deployment_state.outputs.vpc_id
  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "from_webserver_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = data.terraform_remote_state.platform_deployment_state.outputs.db_instance_sg
  source_security_group_id = aws_security_group.ecs_instance_sg.id
  description              = "Allow ECS tasks to access RDS"
  depends_on               = [module.ecs]
}



