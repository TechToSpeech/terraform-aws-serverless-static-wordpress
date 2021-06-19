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
