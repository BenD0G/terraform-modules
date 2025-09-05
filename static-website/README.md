# static-website
Module for hosting a static HTML website from an S3 bucket, at a (new) subdomain of an existing, registered domain.

## Resources Created
1. S3 bucket for hosting the website
2. CloudFront Origin Access Identity (OAI) for accessing the bucket
3. A valid certificate for the subdomain (registered in `us-east-1`)
4. A CloudFront distribution for serving the site
5. Route53 A (Ipv4) and AAAA (Ipv6) records for the subdomain

## Requirements
- `domain`
- `subdomain`
- A default `aws` provider, and a `us_east_1` aliased provider

## Outputs
- The ARN of the S3 bucket where you must place the `website.html` file