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
  family             = "skole-prod-task"
  execution_role_arn = aws_iam_role.ecs_execution.arn
  container_definitions = jsonencode(
    [
      {
        name : "backend_prod",
        image : "${replace(aws_ecr_repository.backend_prod.repository_url, "https://", "")}:${var.prod_backend_latest_tag}",
        cpu : 170,
        memoryReservation : 332,
        portMappings : [
          {
            containerPort : 8000,
            protocol : "tcp"
          }
        ],
        logConfiguration : {
          logDriver : "awslogs",
          options : {
            "awslogs-group" : "backend-prod-logs",
            "awslogs-region" : "eu-central-1"
          }
        },
        essential : true,
        secrets : [
          {
            name : "ALLOWED_HOSTS",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/ALLOWED_HOSTS"
          },
          {
            name : "AWS_ACCESS_KEY_ID",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/ACCESS_KEY_ID"
          },
          {
            name : "AWS_REGION",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/REGION"
          },
          {
            name : "AWS_S3_BUCKET_NAME",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/PROD_S3_BUCKET_NAME"
          },
          {
            name : "AWS_S3_BUCKET_NAME_STATIC",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/PROD_S3_BUCKET_NAME_STATIC"
          },
          {
            name : "AWS_SECRET_ACCESS_KEY",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/SECRET_ACCESS_KEY"
          },
          {
            name : "CLOUDMERSIVE_API_KEY",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/CLOUDMERSIVE_API_KEY"
          },
          {
            name : "CORS_ALLOWED_ORIGIN_REGEXES",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/PROD_CORS_ALLOWED_ORIGIN_REGEXES"
          },
          {
            name : "DATABASE_URL",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/PROD_DATABASE_URL"
          },
          {
            name : "DJANGO_SETTINGS_MODULE",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/DJANGO_SETTINGS_MODULE"
          },
          {
            name : "EMAIL_ADDRESS",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/PROD_EMAIL_ADDRESS"
          },
          {
            name : "EMAIL_CONTACT_FORM_SENDER",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/PROD_EMAIL_CONTACT_FORM_SENDER"
          },
          {
            name : "FCM_SERVER_KEY",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/FCM_SERVER_KEY"
          },
          {
            name : "SECRET_KEY",
            valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/PROD_SECRET_KEY"
          }
        ]
      },
      {
        name : "frontend_prod",
        image : "${replace(aws_ecr_repository.frontend_prod.repository_url, "https://", "")}:${var.prod_frontend_latest_tag}",
        cpu : 341,
        memoryReservation : 663,
        portMappings : [
          {
            containerPort : 3001,
            protocol : "tcp"
          }
        ],
        logConfiguration : {
          logDriver : "awslogs",
          options : {
            "awslogs-group" : "frontend-prod-logs",
            "awslogs-region" : "eu-central-1"
          }
        },
        essential : true
      }
    ]
  )
}

resource "aws_ecs_task_definition" "staging" {
  family             = "skole-staging-task"
  execution_role_arn = aws_iam_role.ecs_execution.arn
  container_definitions = jsonencode([
    {
      name : "backend_staging",
      image : "${replace(aws_ecr_repository.backend_staging.repository_url, "https://", "")}:${var.staging_backend_latest_tag}",
      cpu : 170,
      memoryReservation : 332,
      portMappings : [
        {
          containerPort : 8000,
          protocol : "tcp"
        }
      ],
      logConfiguration : {
        logDriver : "awslogs",
        options : {
          "awslogs-group" : "backend-staging-logs",
          "awslogs-region" : "eu-central-1"
        }
      },
      essential : true,
      secrets : [
        {
          name : "ALLOWED_HOSTS",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/ALLOWED_HOSTS"
        },
        {
          name : "AWS_ACCESS_KEY_ID",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/ACCESS_KEY_ID"
        },
        {
          name : "AWS_REGION",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/REGION"
        },
        {
          name : "AWS_S3_BUCKET_NAME",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/STAGING_S3_BUCKET_NAME"
        },
        {
          name : "AWS_S3_BUCKET_NAME_STATIC",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/STAGING_S3_BUCKET_NAME_STATIC"
        },
        {
          name : "AWS_SECRET_ACCESS_KEY",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/SECRET_ACCESS_KEY"
        },
        {
          name : "CLOUDMERSIVE_API_KEY",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/CLOUDMERSIVE_API_KEY"
        },
        {
          name : "CORS_ALLOWED_ORIGIN_REGEXES",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/STAGING_CORS_ALLOWED_ORIGIN_REGEXES"
        },
        {
          name : "DATABASE_URL",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/STAGING_DATABASE_URL"
        },
        {
          name : "DJANGO_SETTINGS_MODULE",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/DJANGO_SETTINGS_MODULE"
        },
        {
          name : "EMAIL_ADDRESS",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/STAGING_EMAIL_ADDRESS"
        },
        {
          name : "EMAIL_CONTACT_FORM_SENDER",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/STAGING_EMAIL_CONTACT_FORM_SENDER"
        },
        {
          name : "FCM_SERVER_KEY",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/FCM_SERVER_KEY"
        },
        {
          name : "SECRET_KEY",
          valueFrom : "arn:aws:ssm:eu-central-1:630869177434:parameter/STAGING_SECRET_KEY"
        }
      ]
    },
    {
      name : "frontend_staging",
      image : "${replace(aws_ecr_repository.frontend_staging.repository_url, "https://", "")}:${var.staging_frontend_latest_tag}",
      cpu : 341,
      memoryReservation : 663,
      portMappings : [
        {
          containerPort : 3001,
          protocol : "tcp"
        }
      ],
      logConfiguration : {
        logDriver : "awslogs",
        options : {
          "awslogs-group" : "frontend-staging-logs",
          "awslogs-region" : "eu-central-1"
        }
      },
      essential : true
    }
  ])
}
