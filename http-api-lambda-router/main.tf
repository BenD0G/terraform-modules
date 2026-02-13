locals {
  # Normalize zone (strip trailing dot if present)
  root_zone_name = trim(var.root_zone_name, ".")
  api_domain     = "api.${var.subdomain}"

  # Re-key for convenience
  routes_by_name = { for r in var.routes : r.name => r }

  # Whether any route needs the authorizer
  needs_authorizer = anytrue([for r in var.routes : r.requires_auth])
}

# Hosted zone lookup (public)
data "aws_route53_zone" "root" {
  name         = "${local.root_zone_name}."
  private_zone = false
}

# ────────────────────────────────────────────────────────────────────────────────
# TLS certificate for api.<subdomain> (Regional; must be in SAME region as API)
# ────────────────────────────────────────────────────────────────────────────────
resource "aws_acm_certificate" "api" {
  domain_name       = local.api_domain
  validation_method = "DNS"
}

# One DNS record per validation option
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.root.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60
}

# Wait for all validations
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ────────────────────────────────────────────────────────────────────────────────
# HTTP API (v2) and stage
# ────────────────────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "this" {
  name          = "http-router-${replace(var.subdomain, ".", "-")}"
  protocol_type = "HTTP"
  dynamic "cors_configuration" {
    for_each = var.cors_configuration == null ? [] : [var.cors_configuration]
    content {
      allow_credentials = lookup(cors_configuration.value, "allow_credentials", null)
      allow_headers     = lookup(cors_configuration.value, "allow_headers", null)
      allow_methods     = lookup(cors_configuration.value, "allow_methods", null)
      allow_origins     = lookup(cors_configuration.value, "allow_origins", null)
      expose_headers    = lookup(cors_configuration.value, "expose_headers", null)
      max_age           = lookup(cors_configuration.value, "max_age", null)
    }
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  dynamic "default_route_settings" {
    for_each = var.default_route_settings != null ? [var.default_route_settings] : []
    content {
      throttling_burst_limit = default_route_settings.value.throttling_burst_limit
      throttling_rate_limit  = default_route_settings.value.throttling_rate_limit
    }
  }
}

# ────────────────────────────────────────────────────────────────────────────────
# Custom domain + mapping
# ────────────────────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_domain_name" "custom" {
  domain_name = local.api_domain

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "root" {
  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.custom.domain_name
  stage       = aws_apigatewayv2_stage.default.name
}

# Route53 A/AAAA alias to API Gateway regional target
resource "aws_route53_record" "api_alias_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.api_domain
  type    = "A"
  alias {
    name                   = aws_apigatewayv2_domain_name.custom.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.custom.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_alias_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.api_domain
  type    = "AAAA"
  alias {
    name                   = aws_apigatewayv2_domain_name.custom.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.custom.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# ────────────────────────────────────────────────────────────────────────────────
# Per route: look up existing Lambda, create integration, route, permission
# ────────────────────────────────────────────────────────────────────────────────
data "aws_lambda_function" "fn" {
  for_each      = local.routes_by_name
  function_name = each.value.function_name
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each               = local.routes_by_name
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.fn[each.key].invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = each.value.timeout_ms
}

resource "aws_apigatewayv2_route" "route" {
  for_each = local.routes_by_name
  api_id   = aws_apigatewayv2_api.this.id

  route_key          = each.value.route_key
  target             = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
  authorization_type = each.value.requires_auth ? "CUSTOM" : null
  authorizer_id      = each.value.requires_auth ? aws_apigatewayv2_authorizer.this[0].id : null
}

resource "aws_lambda_permission" "invoke" {
  for_each      = local.routes_by_name
  statement_id  = "AllowInvokeFromApiGw-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.fn[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ────────────────────────────────────────────────────────────────────────────────
# Optional Lambda authorizer
# ────────────────────────────────────────────────────────────────────────────────
data "aws_lambda_function" "authorizer" {
  count         = local.needs_authorizer ? 1 : 0
  function_name = var.authorizer_function_name
}

resource "aws_apigatewayv2_authorizer" "this" {
  count                             = local.needs_authorizer ? 1 : 0
  api_id                            = aws_apigatewayv2_api.this.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = data.aws_lambda_function.authorizer[0].invoke_arn
  authorizer_payload_format_version = "2.0"
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "jwt-authorizer"
  enable_simple_responses           = true
}

resource "aws_lambda_permission" "authorizer_invoke" {
  count         = local.needs_authorizer ? 1 : 0
  statement_id  = "AllowInvokeFromApiGw-authorizer"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.authorizer[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
