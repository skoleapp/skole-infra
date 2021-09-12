terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.36.0"
    }
  }

  backend "s3" {
    // The state bucket has been created manually outside of terraform.
    bucket  = "skole-terraform-state"
    region  = "eu-central-1"
    key     = "terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "prod_postgres_username" {
  sensitive = true
}
variable "prod_postgres_password" {
  sensitive = true
}
variable "prod_public_key" {
  sensitive = true
}
variable "prod_backend_latest_tag" {}
variable "prod_frontend_latest_tag" {}

variable "staging_postgres_username" {
  sensitive = true
}
variable "staging_postgres_password" {
  sensitive = true
}
variable "staging_public_key" {
  sensitive = true
}
variable "staging_backend_latest_tag" {}
variable "staging_frontend_latest_tag" {}
