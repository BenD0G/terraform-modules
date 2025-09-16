variable "name" {
  description = "Logical name for the role (suffix allowed by name_prefix)."
  type        = string
}

variable "inline_policy_statements" {
  description = <<EOT
List of additional IAM statements to include inline on the role.
Each element is an object with actions, resources, and optional effect.
EOT
  type = list(object({
    sid       = optional(string)
    actions   = list(string)
    resources = list(string)
    effect    = optional(string, "Allow")
  }))
  default = []
}
