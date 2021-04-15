terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.36.0"
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
