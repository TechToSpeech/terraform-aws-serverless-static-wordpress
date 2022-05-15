resource "aws_route53_record" "www" {
  count   = var.site_prefix == "www" ? 0 : 1
  zone_id = var.hosted_zone_id
  name    = "www.${var.site_prefix}.${var.site_domain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${var.site_prefix}${var.site_prefix == "" ? "" : "."}${var.site_domain}"]
}

resource "aws_route53_record" "apex" {
  zone_id = var.hosted_zone_id
  name    = "${var.site_prefix}${var.site_prefix == "" ? "" : "."}${var.site_domain}"
  type    = "A"
  alias {
    name                   = module.cloudfront.wordpress_cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.wordpress_cloudfront_distrubtion_hostedzone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apex_aaaa" {
  zone_id = var.hosted_zone_id
  name    = "${var.site_prefix}${var.site_prefix == "" ? "" : "."}${var.site_domain}"
  type    = "AAAA"
  alias {
    name                   = module.cloudfront.wordpress_cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.wordpress_cloudfront_distrubtion_hostedzone_id
    evaluate_target_health = false
  }
}
