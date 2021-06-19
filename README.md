<!-- BEGIN_TF_DOCS -->
# terraform-aws-serverless-static-wordpress

[![Test Suite](https://github.com/techtospeech/terraform-aws-serverless-static-wordpress/workflows/test-suite-master/badge.svg?branch=master&event=push)](https://github.com/techtospeech/terraform-aws-serverless-static-wordpress/actions/workflows/testsuite-master.yaml?query=branch%3Amaster+event%3Apush+workflow%3Atest-suite)
<a href="https://twitter.com/intent/follow?screen_name=TechToSpeech"><img src="https://img.shields.io/twitter/follow/TechToSpeech?style=social&logo=twitter" alt="follow on Twitter"></a>

## Introduction

Serverless Static Wordpress is a Community Terraform Module from TechToSpeech that needs nothing more than a registered
domain name with its DNS pointed at AWS.

It creates a complete infrastructure framework that allows you to launch a temporary, transient Wordpress container.
You then log in and customize it like any Wordpress site, and finally publish it as a static site fronted by a global
CloudFront CDN and S3 Origin. When you’re done you shut down the Wordpress container and it costs you almost nothing.

The emphasis is on extremely minimal configuration as the majority of everything you’d need is pre-installed and
pre-configured in line with industry best practices and highly efficient running costs.

## Architecture Overview

![Architecture](docs/serverless-static-wordpress.png)

## Pre-requisites

- A domain name either hosted with AWS, or with its DNS delegated to a Route53 hosted zone.
- A VPC configured with at least one public subnet in your desired deployment region.

## Provider Set-up

Terraform best practice is to configure providers at the top-level module and pass them downwards through implicit
inheritance or explicit passing. Whilst the module and child-modules reference `required_providers`, it is also necessary
for you to provide a regional alias for operations that _must_ be executed in us-east-1 (CloudFront, ACM, and WAF).
As such you should include the following in your provider configuration:

```
terraform {
  required_version = "> 0.15.1"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 3.0"
      configuration_aliases = [aws.ue1]
    }
  }
}

provider "aws" {
  alias   = "ue1"
  region  = "us-east-1"
}

```

The `ue1` alias is essential for this module to work correctly.

## Module instantiation example

```
locals {
  aws_account_id = "998877676554"
  aws_region     = "eu-west-1"
  site_name      = "peterdotcloud"
  profile        = "peterdotcloud"
  site_domain    = "peter.cloud"
}

data "aws_caller_identity" "current" {}

module "peterdotcloud_website" {
  source         = "TechToSpeech/serverless-static-wordpress/aws"
  version        = "0.1.0"
  main_vpc_id    = "vpc-e121c09b"
  subnet_ids     = ["subnet-04b97235","subnet-08fb235","subnet-04b97734"]
  aws_account_id = data.aws_caller_identity.current.account_id

  # site_name will be used to prepend resource names - use no spaces or special characters
  site_name           = local.site_name
  site_domain         = local.site_domain
  wordpress_subdomain = "wordpress"
  hosted_zone_id      = "Z00437553UWAVIRHANGCN"
  s3_region           = local.aws_region

  # Send ECS and RDS events to Slack
  slack_webhook       = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
  ecs_cpu             = 1024
  ecs_memory          = 2048
  cloudfront_aliases  = ["www.peter.cloud", "peter.cloud"]
  waf_enabled         = true

  # Provides the toggle to launch Wordpress container
  launch         = 0

  ## Passing in Provider block to module is essential
  providers = {
    aws.ue1 = aws.ue1
  }
}
```

Do not to set `launch` to 1 initially as the module uses a Codebuild pipeline to take a vanilla version
of the Wordpress docker container and rebake it to include all of the pre-requisites required to publish the Wordpress
site to S3.

The step to push the required Wordpress container from Dockerhub to your own ECR repository can be tied into your
module instantiation using our [helper module](https://github.com/TechToSpeech/terraform-aws-ecr-mirror) as follows:

Note this requires Docker to be running on your Terraform environment with either a named AWS profile or credentials
otherwise available.
```
module "docker_pullpush" {
  source         = "TechToSpeech/ecr-mirror/aws"
  version        = "0.0.6"
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = local.aws_region
  docker_source  = "wordpress:php7.4-apache"
  aws_profile    = "peterdotcloud"
  ecr_repo_name  = module.peterdotcloud_website.wordpress_ecr_repository
  ecr_repo_tag   = "base"
  depends_on     = [module.peterdotcloud_website]
}
```

The CodeBuild pipeline takes a couple of minutes to run and pushes back a 'latest' tagged version of the container,
which is what will be used for the Wordpress container. This build either needs to be triggered manually from the
CodeBuild console, or you can use this snippet to trigger the build as part of your Terraform flow:

```
resource "null_resource" "trigger_build" {
  triggers = {
    codebuild_etag = module.peterdotcloud_website.codebuild_package_etag
  }
  provisioner "local-exec" {
    command = <<-EOT
    aws codebuild start-build --project-name "${module.peterdotcloud_website.codebuild_project_name}"
    --profile "${local.profile}" --region "${local.aws_region}"
    EOT
  }
  depends_on = [
    module.peterdotcloud_website, module.docker_pullpush
  ]
}
```

Whilst this might feel convoluted (and you might ask: why not just provide a public customized Docker image?), it was
felt important that users should 'own' their own version of the Wordpress container, built transparently from the official Wordpress docker image with full provenance.

Finally, if you wish to fully automate the creation _and_ update of the domain's nameservers if it's registered in
Route53 within the same account, you can add these additional snippets to include this in your flow.

```
resource "aws_route53_zone" "apex" {
  name = "peter.cloud"
}

resource "null_resource" "update_nameservers" {
  triggers = {
    nameservers = aws_route53_zone.apex.id
  }
  provisioner "local-exec" {
    command = <<-EOT
    aws route53domains update-domain-nameservers --region us-east-1 --domain-name "${local.site_domain}"
    --nameservers Name="${aws_route53_zone.apex.name_servers.0}" Name="${aws_route53_zone.apex.name_servers.1}"
        Name="${aws_route53_zone.apex.name_servers.2}" Name="${aws_route53_zone.apex.name_servers.3}" --profile peterdotcloud
    EOT
  }
  depends_on = [aws_route53_zone.apex]
}
```
See [examples](docs/examples) for full set-up example.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | The AWS account ID into which resources will be launched. | `number` | n/a | yes |
| <a name="input_cloudfront_aliases"></a> [cloudfront\_aliases](#input\_cloudfront\_aliases) | The domain and sub-domain aliases to use for the cloudfront distribution. | `list(any)` | `[]` | no |
| <a name="input_cloudfront_class"></a> [cloudfront\_class](#input\_cloudfront\_class) | The [price class](https://aws.amazon.com/cloudfront/pricing/) for the distribution. One of: PriceClass\_All, PriceClass\_200, PriceClass\_100 | `string` | `"PriceClass_All"` | no |
| <a name="input_ecs_cpu"></a> [ecs\_cpu](#input\_ecs\_cpu) | The CPU limit password to the Wordpress container definition. | `number` | `256` | no |
| <a name="input_ecs_memory"></a> [ecs\_memory](#input\_ecs\_memory) | The memory limit password to the Wordpress container definition. | `number` | `512` | no |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | The Route53 HostedZone ID to use to create records in. | `string` | n/a | yes |
| <a name="input_launch"></a> [launch](#input\_launch) | The number of tasks to launch of the Wordpress container. Used as a toggle to start/stop your Wordpress management session. | `number` | `"0"` | no |
| <a name="input_main_vpc_id"></a> [main\_vpc\_id](#input\_main\_vpc\_id) | The VPC ID into which to launch resources. | `string` | n/a | yes |
| <a name="input_s3_region"></a> [s3\_region](#input\_s3\_region) | The regional endpoint to use for the creation of the S3 bucket for published static wordpress site. | `string` | n/a | yes |
| <a name="input_site_domain"></a> [site\_domain](#input\_site\_domain) | The site domain name to configure (without any subdomains such as 'www') | `string` | n/a | yes |
| <a name="input_site_name"></a> [site\_name](#input\_site\_name) | The unique name for this instance of the module. Required to deploy multiple wordpress instances to the same AWS account (if desired). | `string` | n/a | yes |
| <a name="input_site_prefix"></a> [site\_prefix](#input\_site\_prefix) | The subdomain prefix of the website domain. E.g. www | `string` | `"www"` | no |
| <a name="input_slack_webhook"></a> [slack\_webhook](#input\_slack\_webhook) | The Slack webhook URL where ECS Cluster EventBridge notifications will be sent. | `string` | `""` | no |
| <a name="input_snapshot_identifier"></a> [snapshot\_identifier](#input\_snapshot\_identifier) | To create the RDS cluster from a previous snapshot in the same region, specify it by name. | `string` | `null` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of subnet IDs within the specified VPC where resources will be launched. | `list(any)` | n/a | yes |
| <a name="input_waf_acl_rules"></a> [waf\_acl\_rules](#input\_waf\_acl\_rules) | List of WAF rules to apply. Can be customized to apply others created outside of module. | `list(any)` | <pre>[<br>  {<br>    "cloudwatch_metrics_enabled": true,<br>    "managed_rule_group_name": "AWSManagedRulesAmazonIpReputationList",<br>    "metric_name": "AWS-AWSManagedRulesAmazonIpReputationList",<br>    "name": "AWS-AWSManagedRulesAmazonIpReputationList",<br>    "priority": 0,<br>    "sampled_requests_enabled": true,<br>    "vendor_name": "AWS"<br>  },<br>  {<br>    "cloudwatch_metrics_enabled": true,<br>    "managed_rule_group_name": "AWSManagedRulesKnownBadInputsRuleSet",<br>    "metric_name": "AWS-AWSManagedRulesKnownBadInputsRuleSet",<br>    "name": "AWS-AWSManagedRulesKnownBadInputsRuleSet",<br>    "priority": 1,<br>    "sampled_requests_enabled": true,<br>    "vendor_name": "AWS"<br>  },<br>  {<br>    "cloudwatch_metrics_enabled": true,<br>    "managed_rule_group_name": "AWSManagedRulesBotControlRuleSet",<br>    "metric_name": "AWS-AWSManagedRulesBotControlRuleSet",<br>    "name": "AWS-AWSManagedRulesBotControlRuleSet",<br>    "priority": 2,<br>    "sampled_requests_enabled": true,<br>    "vendor_name": "AWS"<br>  }<br>]</pre> | no |
| <a name="input_waf_enabled"></a> [waf\_enabled](#input\_waf\_enabled) | Flag to enable default WAF configuration in front of CloudFront. | `bool` | n/a | yes |
| <a name="input_wordpress_admin_email"></a> [wordpress\_admin\_email](#input\_wordpress\_admin\_email) | The email address of the default wordpress admin user. | `string` | `"admin@example.com"` | no |
| <a name="input_wordpress_admin_password"></a> [wordpress\_admin\_password](#input\_wordpress\_admin\_password) | The password of the default wordpress admin user. | `string` | `"techtospeech.com"` | no |
| <a name="input_wordpress_admin_user"></a> [wordpress\_admin\_user](#input\_wordpress\_admin\_user) | The username of the default wordpress admin user. | `string` | `"supervisor"` | no |
| <a name="input_wordpress_subdomain"></a> [wordpress\_subdomain](#input\_wordpress\_subdomain) | The subdomain used for the Wordpress container. | `string` | `"wordpress"` | no |
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloudfront"></a> [cloudfront](#module\_cloudfront) | ./modules/cloudfront | n/a |
| <a name="module_codebuild"></a> [codebuild](#module\_codebuild) | ./modules/codebuild | n/a |
| <a name="module_lambda_slack"></a> [lambda\_slack](#module\_lambda\_slack) | ./modules/lambda_slack | n/a |
| <a name="module_waf"></a> [waf](#module\_waf) | ./modules/waf | n/a |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudfront_ssl_arn"></a> [cloudfront\_ssl\_arn](#output\_cloudfront\_ssl\_arn) | The ARN of the ACM certificate used by CloudFront. |
| <a name="output_codebuild_package_etag"></a> [codebuild\_package\_etag](#output\_codebuild\_package\_etag) | The etag of the codebuild package file. |
| <a name="output_codebuild_project_name"></a> [codebuild\_project\_name](#output\_codebuild\_project\_name) | The name of the created Wordpress codebuild project. |
| <a name="output_wordpress_ecr_repository"></a> [wordpress\_ecr\_repository](#output\_wordpress\_ecr\_repository) | The name of the ECR repository where wordpress image is stored. |
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.15.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.1.0 |
## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.wordpress_site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.wordpress_site](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudwatch_log_group.serverless_wordpress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.wordpress_container](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_db_subnet_group.main_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_ecr_repository.serverless_wordpress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecs_cluster.wordpress_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.wordpress_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.wordpress_container](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_efs_access_point.wordpress_efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_efs_file_system.wordpress_persistent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.wordpress_efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_iam_policy.wordpress_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.wordpress_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.wordpress_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.wordpress_role_attachment_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.wordpress_role_attachment_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_rds_cluster.serverless_wordpress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_route53_record.apex](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.wordpress_acm_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.www](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.aurora_serverless_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.efs_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.wordpress_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.aurora_sg_ingress_3306](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.efs_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.wordpress_sg_egress_2049](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.wordpress_sg_egress_3306](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.wordpress_sg_egress_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.wordpress_sg_egress_80](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.wordpress_sg_ingress_80](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [random_id.rds_snapshot](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.serverless_wordpress_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_iam_policy_document.ecs_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.wordpress_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
<!-- END_TF_DOCS -->
