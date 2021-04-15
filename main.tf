terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.10.0"
    }
  }

  backend "s3" {
    bucket  = "skole-terraform-state"
    region  = "eu-central-1"
    key     = "terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

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
