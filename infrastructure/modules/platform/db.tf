module "db" {
  source                              = "terraform-aws-modules/rds/aws"
  identifier                          = "nftdb"
  engine                              = "postgres"
  engine_version                      = "17.4"
  instance_class                      = "db.t4g.micro"
  family                              = "postgres17"
  db_name                             = "nftdb"
  username                            = "postgres"
  password                            = random_password.db_password.result
  port                                = "5432"
  iam_database_authentication_enabled = true
  storage_type                        = "gp3"
  allocated_storage                   = 20
  storage_encrypted                   = true
  maintenance_window                  = "Mon:01:00-Mon:02:00"
  backup_window                       = "03:00-03:30"
  network_type                        = "IPV4"
  backup_retention_period             = 7
  availability_zone                   = "us-east-1a"
  create_db_subnet_group              = true
  subnet_ids                          = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  manage_master_user_password         = false
  vpc_security_group_ids              = [aws_security_group.rds_sg.id]
  snapshot_identifier                 = var.snapshot_identifier
}

resource "random_password" "db_password" {
  length           = 22
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
}


resource "aws_ssm_parameter" "db_password" {
  name        = "db_password"
  description = "RDS master password"
  type        = "SecureString"
  value       = random_password.db_password.result
  overwrite   = true
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "RDS SG to be updated later"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "rds-sg"
  }
}
