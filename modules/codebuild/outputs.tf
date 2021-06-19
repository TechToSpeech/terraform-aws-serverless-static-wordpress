output "codebuild_project_name" {
  value       = aws_codebuild_project.wordpress_docker_build.name
  description = "The name of the created Wordpress codebuild project."
}

output "codebuild_package_etag" {
  value       = filemd5("${path.module}/codebuild_files/wordpress_docker.zip")
  description = "The etag of the codebuild package file."
}
