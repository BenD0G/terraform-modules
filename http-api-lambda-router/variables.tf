variable "subdomain" {
  description = "Existing subdomain to prefix with 'api.'. Example: 'health.bend0g.com'"
  type        = string
}

variable "root_zone_name" {
  description = "Public Route53 hosted zone name (apex). Accepts 'bend0g.com' or 'bend0g.com.'"
  type        = string
}

variable "routes" {
  description = <<EOT
Non-empty list of route specs. Each object:
{
  name          = "entries"          # unique short id for Terraform resource keys
  function_name = "entries-prod"     # EXISTING Lambda function name to invoke
  route_key     = "POST /entries"    # HTTP API v2 route key (e.g., "GET /health")
}
EOT
  type = list(object({
    name          = string
    function_name = string
    route_key     = string
  }))
}

variable "cors_configuration" {
  description = "Optional CORS config for the API (passed directly to aws_apigatewayv2_api.cors_configuration)."
  type = object({
    allow_credentials = optional(bool)
    allow_headers     = optional(list(string))
    allow_methods     = optional(list(string))
    allow_origins     = optional(list(string))
    expose_headers    = optional(list(string))
    max_age           = optional(number)
  })
  default = null
}
