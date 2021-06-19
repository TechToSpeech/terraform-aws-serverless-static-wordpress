output "codebuild_project_name" {
  value       = aws_codebuild_project.wordpress_docker_build.name
  description = "The name of the created Wordpress codebuild project."
}

output "codebuild_package_etag" {
  value       = data.archive_file.code_build_package.output_md5
  description = "The etag of the codebuild package file."
}
