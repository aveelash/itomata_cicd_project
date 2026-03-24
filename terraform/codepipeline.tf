# Shared Data Source
data "aws_caller_identity" "current" {}

# 1. THE NEW IAM ROLE (Renamed to 'v2' to bypass the Access Denied error)
resource "aws_iam_role" "codebuild_role" {
  name = "itomata-v2-role-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "codebuild.amazonaws.com",
            "codepipeline.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# 2. Create a Connection to GitHub
resource "aws_codestarconnections_connection" "github_conn" {
  name          = "github-itomata-connection"
  provider_type = "GitHub"
}

# 3. S3 Bucket for Pipeline Artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket_prefix = "itomata-pipeline-artifacts-"
  force_destroy = true 
}

# 4. CodeBuild Project
resource "aws_codebuild_project" "itomata_build" {
  name         = "itomata-build-project"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# 5. The actual CI/CD Pipeline
resource "aws_codepipeline" "itomata_pipeline" {
  name          = "itomata-cicd-pipeline"
  role_arn      = aws_iam_role.codebuild_role.arn
  pipeline_type = "V2" 

  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches {
          includes = ["main"]
        }
      }
    }
  }

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type      = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_conn.arn
        FullRepositoryId = "aveelash/itomata_cicd_project"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build_and_Deploy"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.itomata_build.name
      }
    }
  }
}

# 6. IAM Policy - Added ECR and EKS Permissions
resource "aws_iam_role_policy" "codebuild_lifecycle" {
  name = "codebuild-lifecycle-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
          "codebuild:StopBuild"
        ]
        Resource = aws_codebuild_project.itomata_build.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
            "eks:DescribeCluster",
            "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection"
        ]
        Resource = aws_codestarconnections_connection.github_conn.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# 7. NEW: AUTOMATED EKS ACCESS ENTRY
# This removes the need to run the PowerShell commands manually!
resource "aws_eks_access_entry" "codebuild" {
  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.codebuild_role.arn
  user_name         = "codebuild-admin"
  type              = "STANDARD"
  depends_on        = [module.eks]
}

resource "aws_eks_access_policy_association" "codebuild_admin" {
  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.codebuild_role.arn

  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.codebuild]
}