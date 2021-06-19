resource "aws_route53_record" "www" {
  zone_id = var.hosted_zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = "600"
  records = [var.site_domain]
}

resource "aws_route53_record" "apex" {
  zone_id = var.hosted_zone_id
  name    = var.site_domain
  type    = "A"
  alias {
    name                   = module.cloudfront.wordpress_cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.wordpress_cloudfront_distrubtion_hostedzone_id
    evaluate_target_health = false
  }
}
