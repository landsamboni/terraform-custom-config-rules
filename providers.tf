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





