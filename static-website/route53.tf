data "aws_route53_zone" "root" {
  name         = var.domain
  private_zone = false
}

resource "aws_route53_record" "health_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.fqdn
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "health_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.fqdn
  type    = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
