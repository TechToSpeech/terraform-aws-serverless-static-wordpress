<!-- BEGIN_TF_DOCS -->
# codebuild

This module sets up the build to take a vanilla Wordpress image and bake customisations into it for Serverless Static Wordpress.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | The AWS account ID into which resources will be launched. | `string` | n/a | yes |
| <a name="input_codebuild_bucket"></a> [codebuild\_bucket](#input\_codebuild\_bucket) | The name of the bucket used for codebuild of the image. | `string` | n/a | yes |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | The memory allocated to the container (in MB) | `number` | n/a | yes |
| <a name="input_main_vpc_id"></a> [main\_vpc\_id](#input\_main\_vpc\_id) | The VPC ID into which to launch resources. | `string` | n/a | yes |
| <a name="input_site_domain"></a> [site\_domain](#input\_site\_domain) | The site domain name to configure (without any subdomains such as 'www') | `string` | n/a | yes |
| <a name="input_site_name"></a> [site\_name](#input\_site\_name) | The unique name for this instance of the module. Required to deploy multiple wordpress instances to the same AWS account (if desired). | `string` | n/a | yes |
| <a name="input_wordpress_ecr_repository"></a> [wordpress\_ecr\_repository](#input\_wordpress\_ecr\_repository) | The ECR repository where the Wordpress image is stored. | `string` | n/a | yes |
## Modules

No modules.
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_codebuild_package_etag"></a> [codebuild\_package\_etag](#output\_codebuild\_package\_etag) | The etag of the codebuild package file. |
| <a name="output_codebuild_project_name"></a> [codebuild\_project\_name](#output\_codebuild\_project\_name) | The name of the created Wordpress codebuild project. |
## Requirements

No requirements.
## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.wordpress_docker_build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_codebuild_project.wordpress_docker_build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_iam_role.codebuild_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.codebuild_role_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.code_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_object.wordpress_dockerbuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object) | resource |
| [aws_s3_bucket_public_access_block.code_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.codebuild_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [local_file.php_ini](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [archive_file.code_build_package](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.codebuild_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
<!-- END_TF_DOCS -->
