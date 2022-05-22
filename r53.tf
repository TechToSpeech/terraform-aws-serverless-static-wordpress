resource "aws_route53_record" "domain" {
  zone_id = var.hosted_zone_id
  name    = local.domain
  type    = "A"

  alias {
    name                   = module.cloudfront.wordpress_cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.wordpress_cloudfront_distrubtion_hostedzone_id
    evaluate_target_health = false
  }
}
