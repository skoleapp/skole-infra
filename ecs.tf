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

resource "aws_ecs_cluster" "prod" {
  name = "skole-prod-cluster"
}

resource "aws_ecs_cluster" "staging" {
  name = "skole-staging-cluster"
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
