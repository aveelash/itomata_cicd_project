module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  # Node Groups
  eks_managed_node_groups = {
    itomata_nodes = {
      # REDUCED: Single node is enough for testing/learning
      min_size     = 1
      max_size     = 2
      desired_size = 1 

      # CHEAPER: t3.micro is the smallest possible, but t3.small is safer for EKS stability
      instance_types = ["t3.small"]
      
      # CRITICAL: Switch to SPOT for ~70-90% savings on compute
      capacity_type  = "SPOT" 

      # OPTIONAL: Shrink the disk size (Default is often 20GB, 10GB is usually enough for testing)
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      labels = {
        Environment = "testing"
        Project     = "itomata"
      }
    }
  }

  tags = {
    Environment = "testing"
    Terraform   = "true"
  }
}