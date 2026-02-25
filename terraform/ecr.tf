resource "aws_ecr_repository" "frontend" {
  name                 = "itomata-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "backend" {
  name                 = "itomata-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}