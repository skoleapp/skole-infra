# hashicorp/aws

provider "aws" {
  region  = "eu-central-1"
  version = "~> 3.10.0" # Use the latest patch version.
}

# Variables

variable "postgres_username" {}
variable "postgres_password" {}

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

data "template_file" "container_definitions" {
  template = file("container-definitions.json")

  vars = {
    BACKEND_ECR  = replace(aws_ecr_repository.backend.repository_url, "https://", "")
    FRONTEND_ECR = replace(aws_ecr_repository.frontend.repository_url, "https://", "")
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

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "skole-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "skole-igw"
  }
}

resource "aws_subnet" "a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-subnet-a"
  }
}

resource "aws_subnet" "b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.24.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-subnet-b"
  }
}

resource "aws_subnet" "c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.48.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "skole-subnet-c"
  }
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "skole-rtb"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.a.id
  route_table_id = aws_route_table.this.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.b.id
  route_table_id = aws_route_table.this.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.c.id
  route_table_id = aws_route_table.this.id
}

resource "aws_security_group" "sg" {
  name   = "skole-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
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

resource "aws_security_group" "elb_sg" {
  name   = "skole-elb-sg"
  vpc_id = aws_vpc.this.id

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


# ECR

resource "aws_ecr_repository" "backend" {
  name = "backend"
}

resource "aws_ecr_repository" "backend_staging" {
  name = "backend-staging"
}

resource "aws_ecr_repository" "frontend" {
  name = "frontend"
}

resource "aws_ecr_repository" "frontend_staging" {
  name = "frontend-staging"
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy     = var.ecr_policy_keep_10
}

resource "aws_ecr_lifecycle_policy" "backend_staging" {
  repository = aws_ecr_repository.backend_staging.name
  policy     = var.ecr_policy_keep_10
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy     = var.ecr_policy_keep_10
}

resource "aws_ecr_lifecycle_policy" "frontend_staging" {
  repository = aws_ecr_repository.frontend_staging.name
  policy     = var.ecr_policy_keep_10
}


# ECS

resource "aws_ecs_cluster" "prod" {
  name = "skole-cluster"
}

resource "aws_ecs_cluster" "staging" {
  name = "skole-staging-cluster"
}


# EC2

resource "aws_autoscaling_group" "prod" {
  name                 = "skole-asg"
  min_size             = 1
  max_size             = 1
  launch_configuration = aws_launch_configuration.prod.name
  vpc_zone_identifier  = [aws_subnet.a.id, aws_subnet.b.id, aws_subnet.c.id]

  tag {
    key                 = "Name"
    value               = "skole-instance"
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
  vpc_zone_identifier  = [aws_subnet.a.id, aws_subnet.b.id, aws_subnet.c.id]

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
  name_prefix          = "skole-lc"
  image_id             = "ami-09509e8f8dea8ab83"
  instance_type        = "t2.small"
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=skole-cluster >> /etc/ecs/ecs.config"
  key_name             = "skole"
  security_groups      = [aws_security_group.sg.id]
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
  security_groups      = [aws_security_group.sg.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.id

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb" "this" {
  name               = "skole-elb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]

  subnet_mapping {
    subnet_id = aws_subnet.a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.b.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.c.id
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.skoleapp_com.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  depends_on = [aws_acm_certificate_validation.skoleapp_com]
}

resource "aws_lb_listener_certificate" "skole_fi" {
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate.skole_fi.arn
  depends_on      = [aws_acm_certificate_validation.skole_fi]
}

resource "aws_lb_listener_certificate" "skole_io" {
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate.skole_io.arn
  depends_on      = [aws_acm_certificate_validation.skole_io]
}

resource "aws_lb_listener_rule" "http_redirect" {
  listener_arn = aws_lb_listener.http.arn
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


resource "aws_lb_listener_rule" "https_redirect" {
  listener_arn = aws_lb_listener.https.arn
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
  listener_arn = aws_lb_listener.https.arn
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

resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    host_header {
      values = ["api.*"]
    }
  }
}

resource "aws_lb_listener_rule" "frontend_staging" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 4

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_staging.arn
  }

  condition {
    host_header {
      values = ["dev.*"]
    }
  }
}


resource "aws_lb_target_group" "backend" {
  name        = "backend"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id
  depends_on  = [aws_lb.this]

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
  vpc_id      = aws_vpc.this.id
  depends_on  = [aws_lb.this]

  health_check {
    interval = 60
    path     = "/healthz/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "frontend"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance" # TODO: change to "lambda"
  vpc_id      = aws_vpc.this.id
  depends_on  = [aws_lb.this]

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
  target_type = "instance" # TODO: change to "lambda"
  vpc_id      = aws_vpc.this.id
  depends_on  = [aws_lb.this]

  health_check {
    interval = 60
    path     = "/"
    matcher  = "200"
  }
}

resource "aws_ecs_service" "prod" {
  name                               = "skole-service"
  cluster                            = aws_ecs_cluster.prod.id
  task_definition                    = aws_ecs_task_definition.prod.family
  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3001
  }
}

resource "aws_ecs_service" "staging" {
  name                               = "skole-staging-service"
  cluster                            = aws_ecs_cluster.staging.id
  task_definition                    = aws_ecs_task_definition.staging.family
  desired_count                      = 1
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

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
  family = "skole-task"
  # TODO make this role in this config.
  execution_role_arn    = "arn:aws:iam::630869177434:role/skole-ecs-execution-role"
  container_definitions = data.template_file.container_definitions.rendered
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
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "api.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dev_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "dev.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dev_api_skoleapp_com" {
  zone_id = aws_route53_zone.skoleapp_com.zone_id
  name    = "dev-api.skoleapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_skole_fi" {
  zone_id = aws_route53_zone.skole_fi.zone_id
  name    = "www.skole.fi"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skole_fi" {
  zone_id = aws_route53_zone.skole_fi.zone_id
  name    = "skole.fi"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_skole_io" {
  zone_id = aws_route53_zone.skole_io.zone_id
  name    = "www.skole.io"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "skole_io" {
  zone_id = aws_route53_zone.skole_io.zone_id
  name    = "skole.io"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
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

resource "aws_route53_record" "skoleapp_com_github_verification" {
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "_github-challenge-skole-inc.www.skoleapp.com."
  type    = "TXT"
  ttl     = 600
  records = ["bf7719f874"]
}

resource "aws_route53_record" "example_amazonses_dkim_record" {
  count   = 3
  zone_id = aws_route53_record.skoleapp_com.zone_id
  name    = "${element(aws_ses_domain_dkim.skoleapp_com.dkim_tokens, count.index)}._domainkey.skoleapp.com"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.skoleapp_com.dkim_tokens, count.index)}.dkim.amazonses.com"]
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

resource "aws_db_instance" "this" {
  # Manages the RDS instance and the prod database.
  identifier                = "skole-rds"
  name                      = "skole_db"
  engine                    = "postgres"
  engine_version            = "12.4"
  instance_class            = "db.t2.micro"
  allocated_storage         = 20
  storage_type              = "gp2"
  username                  = var.postgres_username
  password                  = var.postgres_password
  db_subnet_group_name      = aws_db_subnet_group.this.name
  vpc_security_group_ids    = [aws_security_group.sg.id]
  publicly_accessible       = true
  final_snapshot_identifier = "skole-latest-prod-new"

  # Note that if we are creating a cross-region read replica this field
  # is ignored and we should instead use `kms_key_id` with a valid ARN.
  # TODO: enable this when we can afford $30/mo.
  # storage_encrypted = true

  lifecycle {
    prevent_destroy = true
  }
}

# TODO: make new instance for QA which is in it's own VPC
#  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/db_snapshot

resource "aws_db_subnet_group" "this" {
  name       = "skole-rds-subnet-group"
  subnet_ids = [aws_subnet.a.id, aws_subnet.b.id, aws_subnet.c.id]
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

resource "aws_s3_bucket" "media" {
  bucket = "skole-media"
  acl    = "private"

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

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["https://dev.skoleapp.com"]
  }
}

resource "aws_s3_bucket" "static" {
  bucket = "skole-static"
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
      "Resource": "arn:aws:s3:::skole-static/static/*"
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

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
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

resource "aws_s3_bucket_public_access_block" "static" {
  bucket             = aws_s3_bucket.static.id
  block_public_acls  = true
  ignore_public_acls = true
}

resource "aws_s3_bucket_public_access_block" "staging_static" {
  bucket             = aws_s3_bucket.staging_static.id
  block_public_acls  = true
  ignore_public_acls = true
}


# Cloudwatch

resource "aws_cloudwatch_log_group" "backend" {
  name = "backend-logs"
}

resource "aws_cloudwatch_log_group" "backend_staging" {
  name = "backend-staging-logs"
}

resource "aws_cloudwatch_log_group" "frontend" {
  name = "frontend-logs"
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
