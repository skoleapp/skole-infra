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
