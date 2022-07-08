#tfsec:ignore:AWS089
resource "aws_cloudwatch_log_group" "object_rewrite" {
  name              = "/aws/cloudfront/function/${var.site_name}_rewrite"
  retention_in_days = 7
  # CloudFront Functions always creates log streams in us-east-1, no matter which edge location ran the function.
  # The purpose of this resource is to set the retention days.
  provider = aws.ue1
}

resource "aws_cloudfront_function" "object_rewrite" {
  depends_on = [
    aws_cloudwatch_log_group.object_rewrite
  ]

  name    = "${var.site_name}_rewrite"
  runtime = "cloudfront-js-1.0"
  publish = true
  code = templatefile(
    "${path.module}/function_rewrite/index.js.tftpl",
    {
      CANONICAL_DOMAIN = var.canonical_domain
      REDIRECTS        = var.cloudfront_function_301_redirects
    }
  )
}

#tfsec:ignore:AWS089
resource "aws_cloudwatch_log_group" "viewer_response_function" {
  name              = "/aws/cloudfront/function/${var.site_name}_viewer_response"
  retention_in_days = 7
  provider          = aws.ue1
}

resource "aws_cloudfront_function" "viewer_response" {
  depends_on = [
    aws_cloudwatch_log_group.viewer_response_function
  ]

  name    = "${var.site_name}_viewer_response"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = file("${path.module}/functions/viewer_response.js")
}
