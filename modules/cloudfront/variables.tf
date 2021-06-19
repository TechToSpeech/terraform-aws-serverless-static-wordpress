variable "site_domain" {
  type        = string
  description = "The site domain name to configure (without any subdomains such as 'www')"
}

variable "site_prefix" {
  type        = string
  description = "The subdomain prefix of the website domain. E.g. www"
  default     = "www"
}

variable "cloudfront_ssl" {
  type        = string
  description = "The ARN of the ACM certificate used for the CloudFront domain."
}

variable "site_name" {
  type        = string
  description = "The unique name for this instance of the module. Required to deploy multiple wordpress instances to the same AWS account (if desired)."
}

variable "cloudfront_aliases" {
  type        = list(any)
  description = "The domain and sub-domain aliases to use for the cloudfront distribution."
  default     = []
}

variable "cloudfront_class" {
  type        = string
  description = "The [price class](https://aws.amazon.com/cloudfront/pricing/) for the distribution. One of: PriceClass_All, PriceClass_200, PriceClass_100"
  default     = "PriceClass_All"
}

variable "waf_acl_arn" {
  type        = string
  default     = null
  description = "The ARN of the WAF ACL applied to the CloudFront distribution."
}
