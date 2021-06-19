output "wordpress_bucket_id" {
  value = aws_s3_bucket.wordpress_bucket.id
}

output "wordpress_bucket_arn" {
  value = aws_s3_bucket.wordpress_bucket.arn
}

output "wordpress_cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.wordpress_distribution.domain_name
}

output "wordpress_cloudfront_distrubtion_hostedzone_id" {
  value = aws_cloudfront_distribution.wordpress_distribution.hosted_zone_id
}
