<!-- BEGIN_TF_DOCS -->
# cloudfront

This module sets up the CloudFront distribution that fronts the static wordpress site.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudfront_aliases"></a> [cloudfront\_aliases](#input\_cloudfront\_aliases) | The domain and sub-domain aliases to use for the cloudfront distribution. | `list(any)` | `[]` | no |
| <a name="input_cloudfront_class"></a> [cloudfront\_class](#input\_cloudfront\_class) | The [price class](https://aws.amazon.com/cloudfront/pricing/) for the distribution. One of: PriceClass\_All, PriceClass\_200, PriceClass\_100 | `string` | `"PriceClass_All"` | no |
| <a name="input_cloudfront_ssl"></a> [cloudfront\_ssl](#input\_cloudfront\_ssl) | The ARN of the ACM certificate used for the CloudFront domain. | `string` | n/a | yes |
| <a name="input_site_domain"></a> [site\_domain](#input\_site\_domain) | The site domain name to configure (without any subdomains such as 'www') | `string` | n/a | yes |
| <a name="input_site_name"></a> [site\_name](#input\_site\_name) | The unique name for this instance of the module. Required to deploy multiple wordpress instances to the same AWS account (if desired). | `string` | n/a | yes |
| <a name="input_site_prefix"></a> [site\_prefix](#input\_site\_prefix) | The subdomain prefix of the website domain. E.g. www | `string` | `"www"` | no |
| <a name="input_waf_acl_arn"></a> [waf\_acl\_arn](#input\_waf\_acl\_arn) | The ARN of the WAF ACL applied to the CloudFront distribution. | `string` | `null` | no |
## Modules

No modules.
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_wordpress_bucket_arn"></a> [wordpress\_bucket\_arn](#output\_wordpress\_bucket\_arn) | n/a |
| <a name="output_wordpress_bucket_id"></a> [wordpress\_bucket\_id](#output\_wordpress\_bucket\_id) | n/a |
| <a name="output_wordpress_cloudfront_distribution_domain_name"></a> [wordpress\_cloudfront\_distribution\_domain\_name](#output\_wordpress\_cloudfront\_distribution\_domain\_name) | n/a |
| <a name="output_wordpress_cloudfront_distrubtion_hostedzone_id"></a> [wordpress\_cloudfront\_distrubtion\_hostedzone\_id](#output\_wordpress\_cloudfront\_distrubtion\_hostedzone\_id) | n/a |
## Requirements

No requirements.
## Resources

| Name | Type |
|------|------|
| [aws_cloudfront_distribution.wordpress_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_identity.wordpress_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_identity) | resource |
| [aws_cloudwatch_log_group.object_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.object_redirect_ue1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.object_redirect_ue1_local](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.lambda-edge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda-edge-cloudwatch-logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.object_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_s3_bucket.wordpress_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.wordpress_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.wordpress_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [archive_file.index_html](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_iam_policy_document.lambda-edge-cloudwatch-logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda-edge-service-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
<!-- END_TF_DOCS -->
