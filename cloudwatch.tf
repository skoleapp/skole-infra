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
