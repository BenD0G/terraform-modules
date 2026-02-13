variable "subdomain" {
  description = "Existing subdomain to prefix with 'api.'. Example: 'foo.bar.com'"
  type        = string
}

variable "root_zone_name" {
  description = "Public Route53 hosted zone name (apex). Accepts 'bar.com' or 'bar.com.'"
  type        = string
}

variable "routes" {
  description = <<EOT
Non-empty list of route specs. Each object:
{
  name          = "entries"          # unique short id for Terraform resource keys
  function_name = "entries-prod"     # EXISTING Lambda function name to invoke
  route_key     = "POST /entries"    # HTTP API v2 route key (e.g., "GET /health")
  timeout_ms    = 29000             # integration timeout in ms (default 29000)
  requires_auth = false             # whether this route requires authorization
}
EOT
  type = list(object({
    name          = string
    function_name = string
    route_key     = string
    timeout_ms    = optional(number, 29000)
    requires_auth = optional(bool, false)
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

variable "authorizer_function_name" {
  description = "Lambda function name for the JWT authorizer. Used automatically when any route has requires_auth = true."
  type        = string
  default     = "auth-authorizer"
}

variable "default_route_settings" {
  description = "Optional default route settings for the stage (throttling)."
  type = object({
    throttling_burst_limit = optional(number)
    throttling_rate_limit  = optional(number)
  })
  default = null
}
