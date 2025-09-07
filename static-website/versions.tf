terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.11"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

data "aws_region" "us_east_1_provider" {
  provider = aws.us_east_1
}

resource "null_resource" "guard" {
  lifecycle {
    precondition {
      condition     = data.aws_region.us_east_1_provider.region == "us-east-1"
      error_message = "The supplied aws.us_east_1 provider must be for us-east-1."
    }
  }
}
