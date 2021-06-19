resource "aws_acm_certificate" "wordpress_site" {
  domain_name       = var.site_domain
  validation_method = "DNS"

  subject_alternative_names = ["${var.site_prefix}.${var.site_domain}"]

  lifecycle {
    create_before_destroy = true
  }
  provider = aws.ue1
}

resource "aws_route53_record" "wordpress_acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wordpress_site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

resource "aws_acm_certificate_validation" "wordpress_site" {
  provider                = aws.ue1
  certificate_arn         = aws_acm_certificate.wordpress_site.arn
  validation_record_fqdns = [for record in aws_route53_record.wordpress_acm_validation : record.fqdn]
}
