resource "aws_wafv2_web_acl" "default" {
  provider    = aws.ue1
  name        = "${var.site_name}-WAF"
  description = "${var.site_name} WAF"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.site_name}-WAF"
  }

  dynamic "rule" {
    for_each = toset(var.waf_acl_rules)
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = rule.value.managed_rule_group_name
          vendor_name = rule.value.vendor_name
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = rule.value.cloudwatch_metrics_enabled
        metric_name                = rule.value.metric_name
        sampled_requests_enabled   = rule.value.sampled_requests_enabled
      }
    }
  }
}
