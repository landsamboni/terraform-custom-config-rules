variable "region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-east-1"

}

variable "cluster_name" {
  description = "Nombre del clúster EKS"
  type        = string
  default     = "viajemos-dev-eks-cluster"
}
