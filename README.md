# terraform-modules

A collection of reusable modules, to avoid having to copy code around!

## static-website
- point `foo.bar.com` to a static S3 website

## http-api-lambda-router
Given an existing subdomain (`foo.bar.com`), make `api.foo.bar.com`, and wire up a list of HTTP routes to lambda backends.

## lambda-execution-role
Centralise a lot of the boiler plate needed for running a lambda.