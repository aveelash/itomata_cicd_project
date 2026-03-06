module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31" # Latest stable version as of 2026

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  # Node Groups (The actual EC2 instances)
  eks_managed_node_groups = {
    itomata_nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"
      
      # Labels help Kubernetes organize your containers
      labels = {
        Environment = "production"
        Project     = "itomata"
      }
    }
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}