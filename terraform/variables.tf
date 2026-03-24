variable "region" {
  description = "The AWS region to deploy into"
  type        = string
  # No default value here makes it easier to switch during a disaster
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "itomata-eks-cluster"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}