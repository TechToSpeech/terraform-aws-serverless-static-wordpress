<!-- BEGIN_TF_DOCS -->
# WAF

This module creates a minimal WAF with appropriate AWS-managed Rule Groups, but
allows for rule-definition override in the event you wish to customize further.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_site_name"></a> [site\_name](#input\_site\_name) | The unique name for this instance of the module. Required to deploy multiple wordpress instances to the same AWS account (if desired). | `string` | n/a | yes |
| <a name="input_waf_acl_rules"></a> [waf\_acl\_rules](#input\_waf\_acl\_rules) | List of WAF rules to apply. Can be customized to apply others created outside of module. | `list(any)` | n/a | yes |
## Modules

No modules.
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_waf_acl_arn"></a> [waf\_acl\_arn](#output\_waf\_acl\_arn) | n/a |
## Requirements

No requirements.
## Resources

| Name | Type |
|------|------|
| [aws_wafv2_web_acl.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
<!-- END_TF_DOCS -->
