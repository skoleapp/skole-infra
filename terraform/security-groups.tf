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

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "Staging instance elastic IP"
    cidr_blocks = ["${aws_eip.staging.public_ip}/32"]
  }

  lifecycle {
    # Allows us to manually add whitelisted IPs.
    ignore_changes = [ingress]
  }
}

resource "aws_security_group" "worker_group_mgmt_one_staging" {
  name_prefix = "worker_group_mgmt_one_staging"
  vpc_id      = aws_vpc.staging.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two_staging" {
  name_prefix = "worker_group_mgmt_two_staging"
  vpc_id      = aws_vpc.staging.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt_staging" {
  name_prefix = "all_worker_management_staging"
  vpc_id      = aws_vpc.staging.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}
