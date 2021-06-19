module "lambda_slack" {
  count           = length(var.slack_webhook) > 5 ? 1 : 0
  source          = "./modules/lambda_slack"
  site_name       = var.site_name
  slack_webhook   = var.slack_webhook
  ecs_cluster_arn = aws_ecs_cluster.wordpress_cluster.arn
}

module "codebuild" {
  source                   = "./modules/codebuild"
  site_name                = var.site_name
  site_domain              = var.site_domain
  codebuild_bucket         = "${var.site_name}-build"
  main_vpc_id              = var.main_vpc_id
  wordpress_ecr_repository = aws_ecr_repository.serverless_wordpress.name
  aws_account_id           = var.aws_account_id
  container_memory         = var.ecs_memory
}

module "cloudfront" {
  source             = "./modules/cloudfront"
  site_name          = var.site_name
  site_domain        = var.site_domain
  cloudfront_ssl     = aws_acm_certificate.wordpress_site.arn
  cloudfront_aliases = var.cloudfront_aliases
  providers = {
    aws.ue1 = aws.ue1
  }
  depends_on = [aws_acm_certificate_validation.wordpress_site,
  module.waf]
  cloudfront_class = var.cloudfront_class
  waf_acl_arn      = var.waf_enabled ? module.waf[0].waf_acl_arn : null
}

module "waf" {
  count         = var.waf_enabled ? 1 : 0
  source        = "./modules/waf"
  site_name     = var.site_name
  waf_acl_rules = var.waf_acl_rules
  providers = {
    aws.ue1 = aws.ue1
  }
}
