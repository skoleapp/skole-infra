# Providers

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.10.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}


# Variables

variable "prod_postgres_username" {}
variable "prod_postgres_password" {}
variable "staging_postgres_username" {}
variable "staging_postgres_password" {}

variable "ecr_policy_keep_10" {
  type    = string
  default = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Only keep the 10 latest images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}


# Data

data "template_file" "container_definitions_prod" {
  template = file("container-definitions-prod.json")

  vars = {
    BACKEND_PROD_ECR  = replace(aws_ecr_repository.backend_prod.repository_url, "https://", "")
    FRONTEND_PROD_ECR = replace(aws_ecr_repository.frontend_prod.repository_url, "https://", "")
  }
}

data "template_file" "container_definitions_staging" {
  template = file("container-definitions-staging.json")

  vars = {
    BACKEND_STAGING_ECR  = replace(aws_ecr_repository.backend_staging.repository_url, "https://", "")
    FRONTEND_STAGING_ECR = replace(aws_ecr_repository.frontend_staging.repository_url, "https://", "")
  }
}

# Terraform state

terraform {
  backend "s3" {
    bucket  = "skole-terraform-state"
    region  = "eu-central-1"
    key     = "terraform.tfstate"
    encrypt = true
  }
}

# IAM

# TODO: ecs_service should most likely use this role.

resource "aws_iam_role" "ecs_service_role" {
  name               = "ecs-service-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_service_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_service_role_attachment" {
  role       = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name               = "ecs-instance-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_policy.json
}

data "aws_iam_policy_document" "ecs_instance_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  path = "/"
  role = aws_iam_role.ecs_instance_role.id
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# VPC

resource "aws_vpc" "prod" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "skole-prod-vpc"
  }
}

resource "aws_vpc" "staging" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "skole-staging-vpc"
  }
}

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "skole-prod-igw"
  }
}

resource "aws_internet_gateway" "staging" {
  vpc_id = aws_vpc.staging.id

  tags = {
    Name = "skole-staging-igw"
  }
}

resource "aws_subnet" "prod_a" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.2.0.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-prod-subnet-a"
  }
}

resource "aws_subnet" "prod_b" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.2.24.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-prod-subnet-b"
  }
}

resource "aws_subnet" "prod_c" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.2.48.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-prod-subnet-c"
  }
}

resource "aws_subnet" "staging_a" {
  vpc_id                  = aws_vpc.staging.id
  cidr_block              = "172.16.0.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-staging-subnet-a"
  }
}

resource "aws_subnet" "staging_b" {
  vpc_id                  = aws_vpc.staging.id
  cidr_block              = "172.16.24.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-staging-subnet-b"
  }
}

resource "aws_subnet" "staging_c" {
  vpc_id                  = aws_vpc.staging.id
  cidr_block              = "172.16.48.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-staging-subnet-c"
  }
}

resource "aws_route_table" "prod" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }

  tags = {
    Name = "skole-prod-rtb"
  }
}

resource "aws_route_table" "staging" {
  vpc_id = aws_vpc.staging.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.staging.id
  }

  tags = {
    Name = "skole-staging-rtb"
  }
}

resource "aws_route_table_association" "prod_a" {
  subnet_id      = aws_subnet.prod_a.id
  route_table_id = aws_route_table.prod.id
}

resource "aws_route_table_association" "prod_b" {
  subnet_id      = aws_subnet.prod_b.id
  route_table_id = aws_route_table.prod.id
}

resource "aws_route_table_association" "prod_c" {
  subnet_id      = aws_subnet.prod_c.id
  route_table_id = aws_route_table.prod.id
}

resource "aws_route_table_association" "staging_a" {
  subnet_id      = aws_subnet.staging_a.id
  route_table_id = aws_route_table.staging.id
}

resource "aws_route_table_association" "staging_b" {
  subnet_id      = aws_subnet.staging_b.id
  route_table_id = aws_route_table.staging.id
}

resource "aws_route_table_association" "staging_c" {
  subnet_id      = aws_subnet.staging_c.id
  route_table_id = aws_route_table.staging.id
}

resource "aws_security_group" "prod" {
  name   = "skole-prod-sg"
  vpc_id = aws_vpc.prod.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.prod_elb.id]
  }

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    # Allows us to manually add whitelisted IPs for example SSHing.
    ignore_changes = [ingress]
  }
}

resource "aws_security_group" "staging" {
  name   = "skole-staging-sg"
  vpc_id = aws_vpc.staging.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.staging_elb.id]
  }

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    # Allows us to manually add whitelisted IPs for example SSHing.
    ignore_changes = [ingress]
  }
}

resource "aws_security_group" "prod_elb" {
  name   = "skole-prod-elb-sg"
  vpc_id = aws_vpc.prod.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "staging_elb" {
  name   = "skole-staging-elb-sg"
  vpc_id = aws_vpc.staging.id

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    # Allows us to manually add whitelisted IPs.
    ignore_changes = [ingress]
  }
}

# ECR

resource "aws_ecr_repository" "backend_prod" {
  name = "backend-prod"
}

resource "aws_ecr_repository" "backend_staging" {
  name = "backend-staging"
}

resource "aws_ecr_repository" "frontend_prod" {
  name = "frontend-prod"
}

resource "aws_ecr_repository" "frontend_staging" {
  name = "frontend-staging"
}

resource "aws_ecr_lifecycle_policy" "backend_prod" {
  repository = aws_ecr_repository.backend_prod.name
  policy     = var.ecr_policy_keep_10
}

resource "aws_ecr_lifecycle_policy" "backend_staging" {
  repository = aws_ecr_repository.backend_staging.name
  policy     = var.ecr_policy_keep_10
}

resource "aws_ecr_lifecycle_policy" "frontend_prod" {
  repository = aws_ecr_repository.frontend_prod.name
  policy     = var.ecr_policy_keep_10
}

resource "aws_ecr_lifecycle_policy" "frontend_staging" {
  repository = aws_ecr_repository.frontend_staging.name
  policy     = var.ecr_policy_keep_10
}


# ECS

resource "aws_ecs_cluster" "prod" {
  name = "skole-prod-cluster"
}

resource "aws_ecs_cluster" "staging" {
  name = "skole-staging-cluster"
}


# EC2

resource "aws_autoscaling_group" "prod" {
  name                 = "skole-prod-asg"
  min_size             = 1
  max_size             = 1
  launch_configuration = aws_launch_configuration.prod.name
  vpc_zone_identifier  = [aws_subnet.prod_a.id, aws_subnet.prod_b.id, aws_subnet.prod_c.id]

  tag {
    key                 = "Name"
    value               = "skole-prod-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "staging" {
  name                 = "skole-staging-asg"
  min_size             = 1
  max_size             = 1
  launch_configuration = aws_launch_configuration.staging.name
  vpc_zone_identifier  = [aws_subnet.staging_a.id, aws_subnet.staging_b.id, aws_subnet.staging_c.id]

  tag {
    key                 = "Name"
    value               = "skole-staging-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_launch_configuration" "prod" {
  name_prefix          = "skole-prod-lc"
  image_id             = "ami-09509e8f8dea8ab83"
  instance_type        = "t2.small"
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=skole-prod-cluster >> /etc/ecs/ecs.config"
  key_name             = "skole"
  security_groups      = [aws_security_group.prod.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "staging" {
  name_prefix          = "skole-staging-lc"
  image_id             = "ami-09509e8f8dea8ab83"
  instance_type        = "t2.micro"
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=skole-staging-cluster >> /etc/ecs/ecs.config"
  key_name             = "skole"
  security_groups      = [aws_security_group.staging.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.id

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb" "prod" {
  name               = "skole-prod-elb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod_elb.id]

  subnet_mapping {
    subnet_id = aws_subnet.prod_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.prod_b.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.prod_c.id
  }
}

resource "aws_lb" "staging" {
  name               = "skole-staging-elb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.staging_elb.id]

  subnet_mapping {
    subnet_id = aws_subnet.staging_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.staging_b.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.staging_c.id
  }
}

resource "aws_lb_listener" "prod_http" {
  load_balancer_arn = aws_lb.prod.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "prod_https" {
  load_balancer_arn = aws_lb.prod.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.skoleapp_com.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_prod.arn
  }

  depends_on = [aws_acm_certificate_validation.skoleapp_com]
}

resource "aws_lb_listener" "staging_https" {
  load_balancer_arn = aws_lb.staging.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.skoleapp_com.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_staging.arn
  }

  depends_on = [aws_acm_certificate_validation.skoleapp_com]
}

resource "aws_lb_listener_certificate" "skole_fi" {
  listener_arn    = aws_lb_listener.prod_https.arn
  certificate_arn = aws_acm_certificate.skole_fi.arn
  depends_on      = [aws_acm_certificate_validation.skole_fi]
}

resource "aws_lb_listener_certificate" "skole_io" {
  listener_arn    = aws_lb_listener.prod_https.arn
  certificate_arn = aws_acm_certificate.skole_io.arn
  depends_on      = [aws_acm_certificate_validation.skole_io]
}

resource "aws_lb_listener_rule" "prod_http_redirect" {
  listener_arn = aws_lb_listener.prod_http.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      host        = "www.skoleapp.com"
    }
  }

  condition {
    host_header {
      values = ["www.skole.fi", "skole.fi", "www.skole.io", "skole.io", "skoleapp.com"]
    }
  }
}


resource "aws_lb_listener_rule" "prod_https_redirect" {
  listener_arn = aws_lb_listener.prod_https.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      host        = "www.skoleapp.com"
    }
  }

  condition {
    host_header {
      values = ["www.skole.fi", "skole.fi", "www.skole.io", "skole.io", "skoleapp.com"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_staging" {
  listener_arn = aws_lb_listener.staging_https.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_staging.arn
  }

  condition {
    host_header {
      values = ["dev-api.*"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_prod" {
  listener_arn = aws_lb_listener.prod_https.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_prod.arn
  }

  condition {
    host_header {
      values = ["api.*"]
    }
  }
}


resource "aws_lb_target_group" "backend_prod" {
  name        = "backend-prod"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.prod.id
  depends_on  = [aws_lb.prod]

  health_check {
    interval = 60
    path     = "/healthz/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "backend_staging" {
  name        = "backend-staging"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.staging.id
  depends_on  = [aws_lb.staging]

  health_check {
    interval = 60
    path     = "/healthz/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "frontend_prod" {
  name        = "frontend-prod"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.prod.id
  depends_on  = [aws_lb.prod]

  health_check {
    interval = 60
    path     = "/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "frontend_staging" {
  name        = "frontend-staging"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.staging.id
  depends_on  = [aws_lb.staging]

  health_check {
    interval = 60
    path     = "/"
    matcher  = "200"
  }
}

resource "aws_ecs_service" "prod" {
  name                               = "skole-prod-service"
  cluster                            = aws_ecs_cluster.prod.id
  task_definition                    = aws_ecs_task_definition.prod.family
  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_prod.arn
    container_name   = "backend_prod"
    container_port   = 8000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_prod.arn
    container_name   = "frontend_prod"
    container_port   = 3001
  }
}

resource "aws_ecs_service" "staging" {
  name                               = "skole-staging-service"
  cluster                            = aws_ecs_cluster.staging.id
  task_definition                    = aws_ecs_task_definition.staging.family
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_staging.arn
    container_name   = "backend_staging"
    container_port   = 8000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend_staging.arn
    container_name   = "frontend_staging"
    container_port   = 3001
  }
}


resource "aws_ecs_task_definition" "prod" {
  family = "skole-prod-task"
  # TODO make this role in this config.
  execution_role_arn    = "arn:aws:iam::630869177434:role/skole-ecs-execution-role"
  container_definitions = data.template_file.container_definitions_prod.rendered
}

resource "aws_ecs_task_definition" "staging" {
  family = "skole-staging-task"
  # TODO use the made role here.
  execution_role_arn    = "arn:aws:iam::630869177434:role/skole-ecs-execution-role"
  container_definitions = data.template_file.container_definitions_staging.rendered
}

resource "aws_eip" "prod" {
  tags = {
    Name = "skole-prod-ip"
  }
}
resource "aws_eip" "staging" {
  tags = {
    Name = "skole-staging-ip"
  }
}


# ACM

resource "aws_acm_certificate" "skoleapp_com" {
  domain_name       = "skoleapp.com"
  validation_method = "DNS"

  subject_alternative_names = ["*.skoleapp.com"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "skole_fi" {
  domain_name       = "skole.fi"
  validation_method = "DNS"

  subject_alternative_names = ["*.skole.fi"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "skole_io" {
  domain_name       = "skole.io"
  validation_method = "DNS"

  subject_alternative_names = ["*.skole.io"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "skoleapp_com" {
  certificate_arn         = aws_acm_certificate.skoleapp_com.arn
  validation_record_fqdns = [aws_route53_record.skoleapp_com_cert.fqdn]
}

resource "aws_acm_certificate_validation" "skole_fi" {
  certificate_arn         = aws_acm_certificate.skole_fi.arn
  validation_record_fqdns = [aws_route53_record.skole_fi_cert.fqdn]
}

resource "aws_acm_certificate_validation" "skole_io" {
  certificate_arn         = aws_acm_certificate.skole_io.arn
  validation_record_fqdns = [aws_route53_record.skole_io_cert.fqdn]
}


# Route 53

resource "aws_route53_zone" "skoleapp_com" {
  name              = "skoleapp.com"
  delegation_set_id = aws_route53_delegation_set.this.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "skole_fi" {
  name              = "skole.fi"
  delegation_set_id = aws_route53_delegation_set.this.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "skole_io" {
  name              = "skole.io"
  delegation_set_id = aws_route53_delegation_set.this.id

  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_route53_delegation_set" "this" {
  reference_name = "skole-dns"
}


resource "aws_route53_record" "skoleapp_com_cert" {
  name    = tolist(aws_acm_certificate.skoleapp_com.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.skoleapp_com.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  records = [tolist(aws_acm_certificate.skoleapp_com.domain_validation_options)[0].resource_record_value]
  ttl     = "60"
}

resource "aws_route53_record" "skole_fi_cert" {
  name    = tolist(aws_acm_certificate.skole_fi.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.skole_fi.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.skole_fi.zone_id
  records = [tolist(aws_acm_certificate.skole_fi.domain_validation_options)[0].resource_record_value]
  ttl     = "60"
}

resource "aws_route53_record" "skole_io_cert" {
  name    = tolist(aws_acm_certificate.skole_io.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.skole_io.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.skole_io.zone_id
  records = [tolist(aws_acm_certificate.skole_io.domain_validation_options)[0].resource_record_value]
  ttl     = "60"
}

resource "aws_route53_record" "www_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "www.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "api.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dev_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "dev.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dev_api_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "dev-api.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_skole_fi" {
  zone_id = aws_route53_zone.skole_fi.zone_id
  name    = "www.skole.fi"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skole_fi" {
  zone_id = aws_route53_zone.skole_fi.zone_id
  name    = "skole.fi"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_skole_io" {
  zone_id = aws_route53_zone.skole_io.zone_id
  name    = "www.skole.io"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skole_io" {
  zone_id = aws_route53_zone.skole_io.zone_id
  name    = "skole.io"
  type    = "A"

  alias {
    name                   = aws_lb.prod.dns_name
    zone_id                = aws_lb.prod.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skoleapp_com_ses" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "_amazonses.skoleapp.com"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.skoleapp_com.verification_token]
}

resource "aws_route53_record" "example_amazonses_dkim_record" {
  count   = 3
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "${element(aws_ses_domain_dkim.skoleapp_com.dkim_tokens, count.index)}._domainkey.skoleapp.com"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.skoleapp_com.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_route53_record" "skoleapp_com_github_verification" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "_github-challenge-skole-inc.www.skoleapp.com."
  type    = "TXT"
  ttl     = 600
  records = ["bf7719f874"]
}

resource "aws_route53_record" "skoleapp_com_gmail_verification" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = ""
  type    = "MX"
  ttl     = 300

  records = [
    "1 ASPMX.L.GOOGLE.COM.",
    "5 ALT1.ASPMX.L.GOOGLE.COM.",
    "5 ALT2.ASPMX.L.GOOGLE.COM.",
    "10 ALT3.ASPMX.L.GOOGLE.COM.",
    "10 ALT4.ASPMX.L.GOOGLE.COM.",
    "15 oaffzqqtrqvihc62qjong2pnj3at6f6q77yr36djmsubhashfe4a.mx-verification.google.com.",
  ]
}

resource "aws_route53_record" "simple_analytics" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "sa"
  type    = "CNAME"
  ttl     = "600"
  records = ["external.simpleanalytics.com."]
}


resource "aws_route53_health_check" "skoleapp_com" {
  fqdn              = "skoleapp.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "www_skoleapp_com" {
  fqdn              = "www.skoleapp.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "skole_fi" {
  fqdn              = "skole.fi"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "www_skole_fi" {
  fqdn              = "www.skole.fi"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}


# RDS

resource "aws_db_instance" "prod" {
  identifier        = "skole-prod-rds"
  name              = "skole_prod_db"
  engine            = "postgres"
  engine_version    = "12.4"
  instance_class    = "db.t2.small"
  allocated_storage = 20
  storage_type      = "gp2"
  username          = var.prod_postgres_username
  password          = var.prod_postgres_password

  db_subnet_group_name   = aws_db_subnet_group.prod.name
  vpc_security_group_ids = [aws_security_group.prod.id]
  publicly_accessible    = false

  final_snapshot_identifier = "skole-prod-final-snapshot"
  backup_window             = "03:00-03:30"
  maintenance_window        = "Mon:03:30-Mon:04:00"
  backup_retention_period   = 14

  deletion_protection = true

  # Note that if we are creating a cross-region read replica this field
  # is ignored and we should instead use `kms_key_id` with a valid ARN.
  storage_encrypted = true
}

resource "aws_db_instance" "staging" {
  identifier        = "skole-staging-rds"
  name              = "skole_staging_db"
  engine            = "postgres"
  engine_version    = "12.4"
  instance_class    = "db.t2.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  username          = var.staging_postgres_username
  password          = var.staging_postgres_password

  db_subnet_group_name   = aws_db_subnet_group.staging.name
  vpc_security_group_ids = [aws_security_group.staging.id]
  publicly_accessible    = false

  final_snapshot_identifier = "skole-staging-final-snapshot"
  backup_window             = "03:00-03:30"
  maintenance_window        = "Mon:03:30-Mon:04:00"
  backup_retention_period   = 14

  deletion_protection = true

  # db.t2.micro doesn't support encryption, but it's fine for staging.
}

resource "aws_db_subnet_group" "prod" {
  name       = "skole-prod-rds-subnet-group"
  subnet_ids = [aws_subnet.prod_a.id, aws_subnet.prod_b.id, aws_subnet.prod_c.id]
}

resource "aws_db_subnet_group" "staging" {
  name       = "skole-staging-rds-subnet-group"
  subnet_ids = [aws_subnet.staging_a.id, aws_subnet.staging_b.id, aws_subnet.staging_c.id]
}


# S3

resource "aws_s3_bucket" "terraform_state" {
  bucket = "skole-terraform-state"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket" "prod_media" {
  bucket = "skole-prod-media"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://www.skoleapp.com"]
  }
}

resource "aws_s3_bucket" "staging_media" {
  bucket = "skole-staging-media"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://dev.skoleapp.com"]
  }
}

resource "aws_s3_bucket" "prod_static" {
  bucket = "skole-prod-static"
  acl    = "private"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AddPerm",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::skole-prod-static/static/*"
    }
  ]
}
EOF

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://api.skoleapp.com"]
  }
}

resource "aws_s3_bucket" "staging_static" {
  bucket = "skole-staging-static"
  acl    = "private"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AddPerm",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::skole-staging-static/static/*"
    }
  ]
}
EOF

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://dev-api.skoleapp.com"]
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "prod_media" {
  bucket                  = aws_s3_bucket.prod_media.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "staging_media" {
  bucket                  = aws_s3_bucket.staging_media.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "prod_static" {
  bucket             = aws_s3_bucket.prod_static.id
  block_public_acls  = true
  ignore_public_acls = true
}

resource "aws_s3_bucket_public_access_block" "staging_static" {
  bucket             = aws_s3_bucket.staging_static.id
  block_public_acls  = true
  ignore_public_acls = true
}


# Cloudwatch

resource "aws_cloudwatch_log_group" "backend_prod" {
  name = "backend-prod-logs"
}

resource "aws_cloudwatch_log_group" "backend_staging" {
  name = "backend-staging-logs"
}

resource "aws_cloudwatch_log_group" "frontend_prod" {
  name = "frontend-prod-logs"
}

resource "aws_cloudwatch_log_group" "frontend_staging" {
  name = "frontend-staging-logs"
}


# SES

resource "aws_ses_domain_identity" "skoleapp_com" {
  domain = "skoleapp.com"
}

resource "aws_ses_domain_dkim" "skoleapp_com" {
  domain = aws_ses_domain_identity.skoleapp_com.domain
}

resource "aws_ses_configuration_set" "this" {
  name = "skole-ses-config"
}

resource "aws_ses_event_destination" "this" {
  name                   = "skole-ses-destination"
  configuration_set_name = aws_ses_configuration_set.this.name
  matching_types         = ["bounce", "complaint", "reject"]
  enabled                = true

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "dimension"
    value_source   = "emailHeader"
  }
}
