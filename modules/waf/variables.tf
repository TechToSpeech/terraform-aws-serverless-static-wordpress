variable "site_name" {
  type        = string
  description = "The unique name for this instance of the module. Required to deploy multiple wordpress instances to the same AWS account (if desired)."
}

variable "waf_acl_rules" {
  type        = list(any)
  description = "List of WAF rules to apply. Can be customized to apply others created outside of module."
}
