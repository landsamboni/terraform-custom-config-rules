terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.50.0" #esta es la version de AWS en terraform
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
  required_version = ">1.8.0" #esta es la version de terraform
}


provider "aws" {
  region = var.region
}



#------------------------------------------

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "viajemos-dev-eks-cluster"]
  }
}


data "aws_eks_cluster" "eks_cluster" {
  name = var.cluster_name
}



