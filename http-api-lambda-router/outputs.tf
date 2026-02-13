output "api_id" {
  description = "ID of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.id
}

output "execution_arn" {
  description = "Execution ARN of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "stage_invoke_url" {
  description = "Invoke URL for the $default stage"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "custom_domain_url" {
  description = "Custom domain URL (https://api.<subdomain>)"
  value       = "https://${aws_apigatewayv2_domain_name.custom.domain_name}"
}
