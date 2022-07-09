# TODO: Add optional custom KMS key for ECR
#tfsec:ignore:AWS093
resource "aws_ecr_repository" "serverless_wordpress" {
  name = "${var.site_name}-serverless-wordpress"
  # TODO: Investigate enforcing immutability on tags
  #tfsec:ignore:AWS078
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    # TODO: Make ECR scan on push optional in future
    #tfsec:ignore:AWS023
    scan_on_push = false
  }
}

resource "aws_ecr_lifecycle_policy" "expire_untagged" {
  repository = aws_ecr_repository.serverless_wordpress.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire untagged images older than ${var.ecr_untagged_retention_days} days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": ${var.ecr_untagged_retention_days}
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
