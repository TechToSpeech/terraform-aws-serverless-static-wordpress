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
