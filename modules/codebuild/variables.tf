locals {
  # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html
  # Regions supporting Graviton for CodeBuild
  arm_container_regions = [
    "us-east-2",
    "us-east-1",
    "us-west-1",
    "us-west-2",
    "ap-south-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "ap-northeast-1",
    "ap-northeast-2",
    "ca-central-1",
    "eu-west-1",
    "eu-west-2",
    "eu-west-3",
    "eu-central-1"
  ]
}

variable "codebuild_bucket" {
  type        = string
  description = "The name of the bucket used for codebuild of the image. "
}

variable "main_vpc_id" {
  type        = string
  description = "The VPC ID into which to launch resources."
  validation {
    condition     = length(var.main_vpc_id) > 4 && substr(var.main_vpc_id, 0, 4) == "vpc-"
    error_message = "The main_vpc_id value must be a valid VPC id, starting with \"vpc-\"."
  }
}

variable "wordpress_ecr_repository" {
  type        = string
  description = "The ECR repository where the Wordpress image is stored."
}

variable "aws_account_id" {
  type        = string
  description = "The AWS account ID into which resources will be launched."
}

variable "site_domain" {
  type        = string
  description = "The site domain name to configure (without any subdomains such as 'www')"
}

variable "site_name" {
  type        = string
  description = "The unique name for this instance of the module. Required to deploy multiple wordpress instances to the same AWS account (if desired)."
}

variable "container_memory" {
  type        = number
  description = "The memory allocated to the container (in MB)"
}

variable "graviton_codebuild_enabled" {
  type        = bool
  default     = false
  description = "Flag that controls whether CodeBuild should use Graviton-based build agents in [supported regions](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html)."
}

variable "wp2static_version" {
  type        = string
  description = "Version of WP2Static to use from https://github.com/WP2Static/wp2static/releases"
  default     = "7.1.7"
}

variable "wp2static_s3_addon_version" {
  type        = string
  description = "Version of the WP2Static S3 Add-on to use from https://github.com/leonstafford/wp2static-addon-s3/releases/"
  default     = "1.0"
}
