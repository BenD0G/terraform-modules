# API Gateway HTTP API (v2) → Lambda Router Module

This module wires up an **AWS API Gateway HTTP API (v2)** with multiple routes, each backed by an existing Lambda function. It also provisions a custom domain (`api.<subdomain>`) with TLS, and creates the required Route 53 records.

---

## High-level flow

When a client calls https://api.health.bend0g.com/entries these pieces come into play:

1. **DNS (Route 53)** – resolves `api.health.bend0g.com` to API Gateway’s regional endpoint.
2. **ACM certificate** – proves to browsers that AWS is allowed to serve TLS for that domain.
3. **API Gateway custom domain** – tells API Gateway to accept traffic for `api.health.bend0g.com`.
4. **API Gateway stage** – the deployed version of the API (`$default` stage).
5. **API Gateway routes** – match requests like `POST /entries` to an integration.
6. **API Gateway integrations** – connect each route to the right Lambda.
7. **Lambda permissions** – allow API Gateway to invoke each Lambda.

---

## Resources explained

### `aws_route53_zone` (data)
Looks up the apex hosted zone (e.g. `bend0g.com`) where DNS records will be created.

---

### `aws_acm_certificate`
Requests a TLS certificate for `api.<subdomain>` (e.g. `api.health.bend0g.com`).  
Browsers require HTTPS, so API Gateway must present a trusted cert.

---

### `aws_route53_record` (ACM validation)
DNS records ACM uses to prove you control the domain. Once validation succeeds, the cert becomes active.

---

### `aws_acm_certificate_validation`
Waits until validation completes and the certificate is issued.

---

### `aws_apigatewayv2_api`
Defines the API Gateway HTTP API (v2). Holds routes, integrations, and configuration.  
This module uses `$default` stage with `auto_deploy`, so changes go live automatically.

---

### `aws_apigatewayv2_stage`
Represents a deployed version of the API.  
`$default` is a special stage that’s always available, and doesn’t require explicit deployments.

---

### `aws_apigatewayv2_domain_name`
Registers the custom domain (`api.subdomain`) inside API Gateway, and attaches the TLS cert.

---

### `aws_apigatewayv2_api_mapping`
Maps the custom domain → API → stage. Without this, the domain exists but isn’t connected to your API.

---

### `aws_route53_record` (A/AAAA alias)
Creates DNS alias records pointing `api.subdomain` to API Gateway’s regional endpoint.

---

### `data.aws_lambda_function`
Looks up the existing Lambda functions you want to expose.

---

### `aws_apigatewayv2_integration`
Connects an API Gateway route to a backend. Here it’s always a Lambda (AWS_PROXY integration).

---

### `aws_apigatewayv2_route`
Defines how requests are matched. A route key is **method + path**, e.g. `GET /health` or `POST /entries`.

---

### `aws_lambda_permission`
Grants API Gateway the right to invoke each Lambda function.

---

## CORS (Cross-Origin Resource Sharing)

### Why it matters
Browsers enforce the **Same-Origin Policy**:  
- If your frontend is served from `https://health.bend0g.com`, it cannot call `https://api.health.bend0g.com` unless the API explicitly allows it.  
- Without CORS, browser JavaScript fetches will be blocked.

---

### How it works
When a browser JS app calls your API:

1. For “simple” requests (e.g. `GET` with no custom headers), the browser sends the request directly.
2. For “non-simple” requests (e.g. `POST` with JSON body, or with `Authorization` header), the browser first sends a **preflight OPTIONS request**:
OPTIONS /entries
Origin: https://health.bend0g.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type,authorization
3. API Gateway must reply with CORS headers:
Access-Control-Allow-Origin: https://health.bend0g.com
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: content-type, authorization

If the preflight passes, the browser proceeds with the real request.

---

### CORS configuration fields

- **`allow_origins`**  
Which sites can call your API from JS.  
- `"*"` = any origin (good for dev, risky for prod).  
- Specific domains = safest (`["https://health.bend0g.com"]`).

- **`allow_methods`**  
Which HTTP methods are allowed (e.g. `["GET", "POST", "OPTIONS"]`).  
API Gateway will respond accordingly in preflights.

- **`allow_headers`**  
Which request headers the frontend may send.  
Common: `["content-type", "authorization"]`.

- **`expose_headers`**  
Which response headers the browser is allowed to expose to JS code.  
Normally empty, unless you need custom headers like `X-Request-Id`.

- **`allow_credentials`**  
Whether to allow cookies/credentials.  
If `true`, you must set `allow_origins` to a specific domain (cannot be `"*"`).

- **`max_age`**  
How long browsers can cache preflight responses (in seconds).  
Reduces the number of OPTIONS requests. Common values: `600` or `3600`.

---

### Best practices
- Use `"*"` only in development.  
- In production, **lock down origins and headers** to what your frontend actually uses.  
- Always include `OPTIONS` in `allow_methods`, otherwise preflights will fail.  
- If using cookies or Authorization headers, set `allow_credentials = true` and list explicit origins.

---

## Visual overview
```
Browser
│ https://api.health.bend0g.com/entries
▼
Route53 (bend0g.com hosted zone)
│ Alias A/AAAA
▼
API Gateway (custom domain)
│ Cert from ACM (validated via DNS)
│ Stage: $default
▼
Routes (GET /health, POST /entries, …)
│
▼
Integrations (Lambda proxy)
│
▼
Lambda Functions
```