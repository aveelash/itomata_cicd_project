resource "aws_ecr_repository" "frontend" {
  # Only create this repo if the region is Mumbai
  count                = var.region == "ap-south-1" ? 1 : 0
  name                 = "itomata-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "backend" {
  count                = var.region == "ap-south-1" ? 1 : 0
  name                 = "itomata-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}