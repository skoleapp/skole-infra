terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.40.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.2.0"
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

provider "kubernetes" {
  host                   = data.aws_eks_cluster.staging.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.staging.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.staging.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.staging.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.staging.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.staging.token
  }
}

variable "aws_account_id" {
  sensitive = true
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
