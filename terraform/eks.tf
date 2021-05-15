locals {
  cluster_name = "staging-eks"
}

module "staging_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "16.1.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.20"
  subnets         = module.staging_eks_vpc.private_subnets

  vpc_id = module.staging_eks_vpc.vpc_id

  node_groups = {
    first = {
      desired_capacity = 1
      max_capacity     = 2
      min_capacity     = 1
      instance_types   = ["t2.small"]
    }
  }

  map_users = [
    {
      userarn  = "arn:aws:iam::${var.aws_account_id}:root"
      username = "root"
      groups   = ["system:masters"]
    },
  ]

  write_kubeconfig   = true
  config_output_path = "./"

  workers_additional_policies = [aws_iam_policy.eks_worker_policy.arn]
}


data "tls_certificate" "staging" {
  url = data.aws_eks_cluster.staging.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "staging" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.staging.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.staging.identity[0].oidc[0].issuer
}

data "aws_eks_cluster" "staging" {
  name = module.staging_eks.cluster_id
}

data "aws_eks_cluster_auth" "staging" {
  name = module.staging_eks.cluster_id
}

resource "kubernetes_ingress" "staging_ingress" {
  metadata {
    name = "staging-ingress"

    annotations = {
      "kubernetes.io/ingress.class"      = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }

  spec {
    backend {
      service_name = "hello-kubernetes"
      service_port = 80
    }

    rule {
      http {
        path {
          backend {
            service_name = "hello-kubernetes"
            service_port = 80
          }
          path = "/"
        }
      }
    }
  }
}

resource "kubernetes_service_account" "eks" {
  metadata {
    name = "skole-eks-service-account"
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name" = "skole-eks-service-account"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::630869177434:role/skole-eks-service-account-role-manual"
    }
  }
}

resource "helm_release" "staging_ingress_controller" {
  name       = "staging-ingress-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.2.1"

  set {
    name  = "serviceAccount.name"
    value = "skole-eks-service-account"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "clusterName"
    value = local.cluster_name
  }
}
