locals {
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole", # Basic CloudWatch logging
  ]
  # Add pushover to provided inline statements
  inline_policy_statements = concat(var.inline_policy_statements, [
    {
      actions   = ["sns:Publish"]
      resources = ["arn:aws:sns:eu-west-1:982932998640:pushover-notifications"]
    }
  ])
}

data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = "${var.name}-lambda-exec-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  path               = "/service-role/" # optional, keeps things tidy
  tags = {
    ManagedBy = "terraform"
    RoleType  = "lambda-exec"
  }
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = toset(local.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# Optional inline policy with caller-provided statements
data "aws_iam_policy_document" "inline" {
  dynamic "statement" {
    for_each = local.inline_policy_statements
    content {
      sid       = lookup(statement.value, "sid", null)
      effect    = lookup(statement.value, "effect", "Allow")
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "inline" {
  count  = length(local.inline_policy_statements) > 0 ? 1 : 0
  name   = "${aws_iam_role.this.name}-inline"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.inline.json
}

output "role_arn" { value = aws_iam_role.this.arn }
