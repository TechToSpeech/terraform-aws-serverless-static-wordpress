output "cloudfront_ssl_arn" {
  value       = aws_acm_certificate.wordpress_site.arn
  description = "The ARN of the ACM certificate used by CloudFront."
}

output "wordpress_ecr_repository" {
  value       = aws_ecr_repository.serverless_wordpress.name
  description = "The name of the ECR repository where wordpress image is stored."
}

output "codebuild_project_name" {
  value       = module.codebuild.codebuild_project_name
  description = "The name of the created Wordpress codebuild project."
}

output "codebuild_package_etag" {
  value       = module.codebuild.codebuild_package_etag
  description = "The etag of the codebuild package file."
}
