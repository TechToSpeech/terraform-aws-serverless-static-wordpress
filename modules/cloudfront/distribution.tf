# TODO: Add optional logging for S3 bucket
# TODO: Add optional versioning for S3 bucket
#tfsec:ignore:AWS002 #tfsec:ignore:AWS077
resource "aws_s3_bucket" "wordpress_bucket" {
  bucket        = "${var.site_prefix}.${var.site_domain}"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "wordpress_bucket" {
  bucket                  = aws_s3_bucket.wordpress_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_identity" "wordpress_distribution" {
  comment = "${var.site_name} OAI for S3"
}

# TODO: Add optional Access Logging configuration for Cloudfront
# TODO: Add optional WAF configuration in front of Cloudfront
#tfsec:ignore:AWS045 #tfsec:ignore:AWS071
resource "aws_cloudfront_distribution" "wordpress_distribution" {
  origin {
    domain_name = aws_s3_bucket.wordpress_bucket.bucket_regional_domain_name
    origin_id   = "${var.site_name}_WordpressBucket"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.wordpress_distribution.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.site_name} Distribution for Wordpress"
  default_root_object = "index.html"
  web_acl_id          = var.waf_acl_arn

  aliases = var.cloudfront_aliases

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.site_name}_WordpressBucket"
    compress         = true

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type = "origin-request"
      lambda_arn = "${aws_lambda_function.object_redirect.arn}:${aws_lambda_function.object_redirect.version}"
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 600
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = var.cloudfront_class

  viewer_certificate {
    minimum_protocol_version = "TLSv1.2_2019"
    acm_certificate_arn      = var.cloudfront_ssl
    ssl_support_method       = "sni-only"

  }

}

resource "aws_s3_bucket_policy" "wordpress_bucket" {
  bucket = aws_s3_bucket.wordpress_bucket.id

  policy = jsonencode(
    {
      "Version" : "2008-10-17",
      "Id" : "PolicyForCloudFrontPrivateContent",
      "Statement" : [
        {
          "Sid" : "1",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : aws_cloudfront_origin_access_identity.wordpress_distribution.iam_arn
          },
          "Action" : "s3:GetObject",
          "Resource" : "${aws_s3_bucket.wordpress_bucket.arn}/*"
        }
      ]
    }
  )
}
