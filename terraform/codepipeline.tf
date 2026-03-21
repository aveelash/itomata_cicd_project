# 1. Create a Connection to GitHub
resource "aws_codestarconnections_connection" "github_conn" {
  name          = "github-itomata-connection"
  provider_type = "GitHub"
}

# 2. S3 Bucket for Pipeline Artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket_prefix = "itomata-pipeline-artifacts-"
  force_destroy = true 
}

# 3. CodeBuild Project
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
    privileged_mode = true # Required to build Docker images

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region # Use the variable, not "ap-south-1"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# 4. The actual CI/CD Pipeline
resource "aws_codepipeline" "itomata_pipeline" {
  name     = "itomata-cicd-pipeline"
  role_arn = aws_iam_role.codebuild_role.arn

  # FIX: Set pipeline type to V2 to support the trigger block
  pipeline_type = "V2" 

  # Trigger block for automatic execution on git push
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
    type     = "S3"
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

# 5. IAM Policy for CodeBuild & Pipeline Lifecycle
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
          "eks:DescribeCluster"
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
      }
    ]
  })
}