resource "aws_db_instance" "prod" {
  identifier        = "skole-prod-rds"
  name              = "skole_prod_db"
  engine            = "postgres"
  engine_version    = "12"
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
  engine_version    = "12"
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
