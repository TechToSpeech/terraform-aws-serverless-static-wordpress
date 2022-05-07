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
- Desired deployment region **cannot** be one of the following, as Aurora Serverless v1 is not yet supported there:
    - Africa (Cape Town)
    - Asia Pacific (Hong Kong)
    - Asia Pacific (Osaka)
    - Europe (Milan)
    - Europe (Stockholm)
    - Middle East (Bahrain)
    - South America (São Paulo)
    - AWS GovCloud (US-East)
    - AWS GovCloud (US-West)
    - China (Beijing)
    - China (Ningxia)

Alternatives for Aurora Serverless will be supported in a future release.

## Provider Set-up

Terraform best practice is to configure providers at the top-level module and pass them downwards through implicit
inheritance or explicit passing. Whilst the module and child-modules reference `required_providers`, it is also necessary
for you to provide a regional alias for operations that _must_ be executed in us-east-1 (CloudFront, ACM, and WAF).
As such you should include the following in your provider configuration:

```
terraform {
  required_version = "> 1.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4.0"
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

## Severless Static Wordpress V2 Upgrade Guide
See [UPGRADING](docs/UPGRADING.md) for Version 2 upgrade guidance, including for Version 4 of the AWS Terraform Provider.

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
    command = "aws codebuild start-build --project-name ${module.peterdotcloud_website.codebuild_project_name} --profile ${local.profile} --region ${local.aws_region}"
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
    command = "aws route53domains update-domain-nameservers --region us-east-1 --domain-name ${local.site_domain} --nameservers Name=${aws_route53_zone.apex.name_servers.0} Name=${aws_route53_zone.apex.name_servers.1} Name=${aws_route53_zone.apex.name_servers.2} Name=${aws_route53_zone.apex.name_servers.3} --profile peterdotcloud"
  }
  depends_on = [aws_route53_zone.apex]
}
```
See [examples](docs/examples) for full set-up example.

## Launching container, customize Wordpress and publish static site

Check that the CodeBuild job for the container has built successfully.

Toggle the `launch` value of the module to 1, and re-run Terraform plan/apply, which will launch the instance of the
Wordpress management container.

First-time launch of container will take 5-6 minutes as the installation of Wordpress completes. You can
check status if you wish in CloudWatch log groups for ECS. It will come up within a few seconds on subsequent launches.

The Wordpress management container will become available at http://wordpress.yourdomain.com (note HTTP, not HTTPS) by
default, unless you specified your own `wordpress_subdomain` prefix.

Default admin is: supervisor
Default password: techtospeech.com

Change these on first log in or specify your own in module instantiation.

You will find WP2Static with S3 Add-on installed. Go to the WP2Static Menu->Addons, and click the 'Disabled' button to
Enable the Add-on.

The configuration of the plugin has been set up such that no additional configuration is required unless you wish to
change any options.

You may now edit Wordpress as you would normally, customize your site as you like, and when ready proceed to the 'Run'
section of the WP2Static plugin, and click the 'Generate Static Site' button. This will take some minutes depending on
the size of your site. When complete the site will be published in S3, and available via the public URL configured
in your module definition.

Gentle reminder that no backup options are currently bundled with this module - the most effective means would be to
generate and retain a backup from within Wordpress for maximum flexibility. We recommend the UpdraftPlus plugin.

## Permanent Redirects

Basic url path based permanent redirects are supported via the CloudFront function. The variable `cloudfront_function_301_redirects` can be set with a custom map of match to destination mappings.

Some aspects that need to be taken into consideration for the match:

* It's a regular expression
* Group replacements are supported
* Runs in a Javascript function, escaping needs to be taken into consideration
* Passed through a TF var, so escaping that needs to be taking into account as well

An example to match a path like `/category-name`, a suitable match would be `"^\\/(category-name)$"`. Breaking down the `\\/` part, the first `\` tells TF to escape the second `\`, which is the Regex escape for the `/` character.

An example:

```
cloudfront_function_301_redirects = {
  # Redirects /travel to /category/travel/
  "^\\/(travel)$": "/category/$1/",
}
```

## Troubleshooting

If you experience issues with the publish element of WP2Static, you can retry. It can be more reliable to proceed to
'Caches' section and select to delete all caches. Currently you need to additionally delete the S3 deploy cache manually.

You should also try increasing the CPU/Memory allocated to the container. Undersizing the container can cause timeout
issues that are currently not well handled in the plugin.

If the job fails immediately and your site has previously generated a sitemaps.xml file, ensure you restore the plugin
that generates this file and the crawl job can fail fast if it cannot locate it. For all other features and issues
relating to WP2Static, [raise an issue on their repo](https://github.com/leonstafford/wp2static/issues).
For any issues relating to this module, [raise an issue against this repo.](https://github.com/TechToSpeech/terraform-aws-serverless-static-wordpress/issues)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | The AWS account ID into which resources will be launched. | `string` | n/a | yes |
| <a name="input_cloudfront_aliases"></a> [cloudfront\_aliases](#input\_cloudfront\_aliases) | The domain and sub-domain aliases to use for the cloudfront distribution. | `list(any)` | `[]` | no |
| <a name="input_cloudfront_class"></a> [cloudfront\_class](#input\_cloudfront\_class) | The [price class](https://aws.amazon.com/cloudfront/pricing/) for the distribution. One of: PriceClass\_All, PriceClass\_200, PriceClass\_100 | `string` | `"PriceClass_All"` | no |
| <a name="input_cloudfront_function_301_redirects"></a> [cloudfront\_function\_301\_redirects](#input\_cloudfront\_function\_301\_redirects) | A list of key value pairs of Regex match and destination for 301 redirects at CloudFront. | `map(any)` | <pre>{<br>  "^(.*)index\\.php$": "$1"<br>}</pre> | no |
| <a name="input_ecs_cpu"></a> [ecs\_cpu](#input\_ecs\_cpu) | The CPU limit password to the Wordpress container definition. | `number` | `256` | no |
| <a name="input_ecs_healthcheck_enabled"></a> [ecs\_healthcheck\_enabled](#input\_ecs\_healthcheck\_enabled) | Runs an healtchcheck against the container. | `bool` | `true` | no |
| <a name="input_ecs_memory"></a> [ecs\_memory](#input\_ecs\_memory) | The memory limit password to the Wordpress container definition. | `number` | `512` | no |
| <a name="input_graviton_codebuild_enabled"></a> [graviton\_codebuild\_enabled](#input\_graviton\_codebuild\_enabled) | Flag that controls whether CodeBuild should use Graviton-based build agents in [supported regions](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html). | `bool` | `false` | no |
| <a name="input_graviton_fargate_enabled"></a> [graviton\_fargate\_enabled](#input\_graviton\_fargate\_enabled) | Flag that controls whether ECS Fargate should use Graviton-based containers in [supported regions]https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate-Regions.html). | `bool` | `false` | no |
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
| <a name="input_wordpress_memory_limit"></a> [wordpress\_memory\_limit](#input\_wordpress\_memory\_limit) | The memory to allow the Wordpress process to use (in M) | `string` | `"256M"` | no |
| <a name="input_wordpress_subdomain"></a> [wordpress\_subdomain](#input\_wordpress\_subdomain) | The subdomain used for the Wordpress container. | `string` | `"wordpress"` | no |
| <a name="input_wp2static_s3_addon_version"></a> [wp2static\_s3\_addon\_version](#input\_wp2static\_s3\_addon\_version) | Version of the WP2Static S3 Add-on to use from https://github.com/leonstafford/wp2static-addon-s3/releases/ | `string` | `"1.0"` | no |
| <a name="input_wp2static_version"></a> [wp2static\_version](#input\_wp2static\_version) | Version of WP2Static to use from https://github.com/WP2Static/wp2static/releases | `string` | `"7.1.7"` | no |
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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.0 |
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
| [aws_ecs_cluster_capacity_providers.wordpress_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.wordpress_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.wordpress_container](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_efs_access_point.wordpress_efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_efs_file_system.wordpress_persistent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.wordpress_efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_iam_policy.wordpress_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.wordpress_ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.wordpress_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.wordpress_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.wordpress_ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
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
| [aws_iam_policy_document.wordpress_ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
<!-- END_TF_DOCS -->
