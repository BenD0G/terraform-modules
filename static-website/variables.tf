variable "domain" {
  description = "The domain name to use for the website. Must be registered in Route 53."
  type        = string
}

variable "subdomain" {
  description = "The subdomain to use for the website."
  type        = string
}

locals {
  fqdn      = "${var.subdomain}.${var.domain}"
  origin_id = "${var.subdomain}-website-origin-id"
}
