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
