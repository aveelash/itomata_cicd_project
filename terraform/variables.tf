variable "region" {
  description = "The AWS region to deploy in"
  type        = string
  # No default here, we will provide it during 'apply'
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

# Add this for dynamic Availability Zones
variable "azs" {
  type    = list(string)
}