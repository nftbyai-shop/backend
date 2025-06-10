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

resource "aws_lb" "web_alb" {
  name               = "webserver-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
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
  source_security_group_id = module.ecs.services.webserver_backend.security_group_id
  description              = "Allow ECS tasks to access RDS"
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
