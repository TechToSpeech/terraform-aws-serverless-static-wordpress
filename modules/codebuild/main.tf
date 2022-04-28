data "aws_region" "current" {}

# TODO: Add optional logging for S3 bucket
# TODO: Add optional versioning for S3 bucket
#tfsec:ignore:AWS002 #tfsec:ignore:AWS017 #tfsec:ignore:AWS077
resource "aws_s3_bucket" "code_source" {
  bucket        = var.codebuild_bucket
  force_destroy = true
}

resource "aws_s3_bucket_acl" "code_source" {
  bucket = aws_s3_bucket.code_source.bucket
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "code_source" {
  bucket = aws_s3_bucket.code_source.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "code_source" {
  bucket                  = aws_s3_bucket.code_source.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "archive_file" "code_build_package" {
  type        = "zip"
  output_path = "${path.module}/codebuild_files/wordpress_docker.zip"
  excludes    = ["wordpress_docker.zip"]
  source_dir  = "${path.module}/codebuild_files/"
  depends_on = [
    local_file.php_ini
  ]
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild_service_role" {
  name               = "${var.site_name}_CodeBuildServiceRole"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "codebuild_role_attachment" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_s3_object" "wordpress_dockerbuild" {
  bucket = aws_s3_bucket.code_source.id
  key    = "wordpress_docker.zip"
  source = "${path.module}/codebuild_files/wordpress_docker.zip"
  etag   = data.archive_file.code_build_package.output_md5
}

resource "aws_security_group" "codebuild_security_group" {
  name        = "${var.site_name}_codebuild_sg"
  description = "security group for codebuild"
  vpc_id      = var.main_vpc_id

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    #tfsec:ignore:AWS009
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#tfsec:ignore:AWS089
resource "aws_cloudwatch_log_group" "wordpress_docker_build" {
  name              = "/aws/codebuild/${var.site_name}-serverless-wordpress-docker-build"
  retention_in_days = 7
}

resource "aws_codebuild_project" "wordpress_docker_build" {
  name          = "${var.site_name}-serverless-wordpress-docker-build"
  description   = "Builds an image of wordpress in docker"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_service_role.arn


  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "S3"
    # Requires ref by name rather than resource: https://github.com/hashicorp/terraform-provider-aws/issues/10195
    location = var.codebuild_bucket
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = var.graviton_codebuild_enabled ? "aws/codebuild/amazonlinux2-aarch64-standard:2.0" : "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    # Use ARM for codebuild if in supporting region
    type                        = var.graviton_codebuild_enabled ? (contains(local.arm_container_regions, data.aws_region.current.name) ? "ARM_CONTAINER" : "LINUX_CONTAINER") : "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.wordpress_ecr_repository
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
    environment_variable {
      name  = "WP2STATIC_VERSION"
      value = var.wp2static_version
    }
    environment_variable {
      name  = "WP2STATIC_S3_ADDON_VERSION"
      value = var.wp2static_s3_addon_version
    }
  }

  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.wordpress_docker_build.name
    }
  }

  source {
    type     = "S3"
    location = "${aws_s3_bucket.code_source.id}/${aws_s3_object.wordpress_dockerbuild.id}"

  }
}

resource "local_file" "php_ini" {
  content  = <<-EOT
      upload_max_filesize=64M
      post_max_size=64M
      max_execution_time=0
      max_input_vars=2000
      memory_limit=${var.container_memory}M
    EOT
  filename = "${path.module}/codebuild_files/php.ini"
}
