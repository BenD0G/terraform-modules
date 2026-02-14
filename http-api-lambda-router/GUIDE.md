# http-api-lambda-router — Usage Guide

A Terraform module that creates an AWS API Gateway HTTP API (v2) with a custom domain, TLS certificate, Route53 DNS records, and Lambda-backed routes. Point it at your existing Lambda functions and it gives you a production-ready HTTPS endpoint.

---

## Quick Start

```hcl
module "api" {
  source = "git::https://github.com/BenD0G/terraform-modules//http-api-lambda-router?ref=v1.3.0"

  root_zone_name = "bend0g.com"
  subdomain      = "my-project.bend0g.com"

  routes = [
    {
      name          = "get_items"
      function_name = aws_lambda_function.my_lambda.function_name
      route_key     = "GET /items"
    },
  ]
}
```

This creates:
- An HTTP API Gateway named `http-router-my-project-bend0g-com`
- A custom domain at `https://api.my-project.bend0g.com`
- An ACM TLS certificate (DNS-validated via Route53)
- Route53 A and AAAA alias records
- A `GET /items` route that invokes your Lambda
- Lambda invoke permissions for API Gateway

Your Lambda must already exist before you call this module. The module looks it up by `function_name`.

---

## Custom Domain

The module always creates the endpoint at `api.<subdomain>`:

| `subdomain` value | Resulting endpoint |
|---|---|
| `my-project.bend0g.com` | `https://api.my-project.bend0g.com` |
| `auth.bend0g.com` | `https://api.auth.bend0g.com` |
| `photos.bend0g.com` | `https://api.photos.bend0g.com` |

The `api.` prefix is hardcoded in the module. Your frontend lives at `https://my-project.bend0g.com`; your API lives at `https://api.my-project.bend0g.com`.

**Prerequisite:** The `root_zone_name` must be a public Route53 hosted zone you control. The module creates DNS records and ACM validation records in this zone.

---

## Variables Reference

### Required

| Variable | Type | Description |
|----------|------|-------------|
| `subdomain` | `string` | Your project's subdomain. The API will be at `api.<subdomain>`. Example: `"photos.bend0g.com"` |
| `root_zone_name` | `string` | The apex Route53 hosted zone. Example: `"bend0g.com"` (with or without trailing dot) |
| `routes` | `list(object)` | One or more route definitions (see below) |

### Optional

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cors_configuration` | `object` | `null` | CORS settings (see [CORS section](#cors)) |
| `authorizer_function_name` | `string` | `"auth-authorizer"` | Lambda function name used for authorization. Only relevant when any route has `requires_auth = true`. |
| `default_route_settings` | `object` | `null` | Stage-level throttling settings |

### Route Object

Each route in the `routes` list has:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `string` | *required* | Unique short ID used as Terraform resource key. Example: `"get_items"` |
| `function_name` | `string` | *required* | Name of an **existing** Lambda function to invoke |
| `route_key` | `string` | *required* | HTTP method + path. Example: `"GET /items"`, `"POST /entries"` |
| `timeout_ms` | `number` | `29000` | Integration timeout in milliseconds (max 29000) |
| `requires_auth` | `bool` | `false` | Whether this route requires JWT authorization |

---

## Outputs

| Output | Description |
|--------|-------------|
| `api_id` | API Gateway ID |
| `execution_arn` | Execution ARN (useful for Lambda permissions) |
| `stage_invoke_url` | The default stage URL (e.g. `https://abc123.execute-api.eu-west-2.amazonaws.com/`) |
| `custom_domain_url` | The custom domain URL (e.g. `https://api.my-project.bend0g.com`) |

---

## Examples

### Basic — Single Route, No Auth

```hcl
module "api" {
  source = "git::https://github.com/BenD0G/terraform-modules//http-api-lambda-router?ref=v1.3.0"

  root_zone_name = "bend0g.com"
  subdomain      = "health.bend0g.com"

  routes = [
    {
      name          = "get_entries"
      function_name = "health-entries-prod"
      route_key     = "GET /entries"
    },
  ]

  cors_configuration = {
    allow_origins = ["https://health.bend0g.com"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}
```

Result: `https://api.health.bend0g.com/entries` invokes the `health-entries-prod` Lambda.

### Multiple Routes, One Lambda

A single Lambda can handle multiple routes (dispatch internally based on the route key):

```hcl
module "api" {
  source = "git::https://github.com/BenD0G/terraform-modules//http-api-lambda-router?ref=v1.3.0"

  root_zone_name = "bend0g.com"
  subdomain      = "auth.bend0g.com"

  routes = [
    {
      name          = "post_auth"
      function_name = aws_lambda_function.auth_handler.function_name
      route_key     = "POST /auth"
      timeout_ms    = 29000
    },
    {
      name          = "post_approve"
      function_name = aws_lambda_function.auth_handler.function_name
      route_key     = "POST /approve"
      timeout_ms    = 5000
    },
    {
      name          = "get_data"
      function_name = aws_lambda_function.auth_handler.function_name
      route_key     = "GET /data"
      timeout_ms    = 5000
      requires_auth = true
    },
  ]
}
```

### Multiple Routes, Different Lambdas

Each route can point to a different Lambda:

```hcl
routes = [
  {
    name          = "get_users"
    function_name = "users-lambda"
    route_key     = "GET /users"
  },
  {
    name          = "get_orders"
    function_name = "orders-lambda"
    route_key     = "GET /orders"
  },
]
```

### With Throttling

```hcl
module "api" {
  source = "git::https://github.com/BenD0G/terraform-modules//http-api-lambda-router?ref=v1.3.0"

  root_zone_name = "bend0g.com"
  subdomain      = "auth.bend0g.com"

  routes = [/* ... */]

  default_route_settings = {
    throttling_burst_limit = 5
    throttling_rate_limit  = 50
  }
}
```

---

## CORS

If your frontend calls the API from a browser, you need CORS configured. Without it, the browser will block the requests.

```hcl
cors_configuration = {
  allow_origins = ["https://my-project.bend0g.com"]
  allow_methods = ["GET", "POST", "OPTIONS"]
  allow_headers = ["content-type", "authorization"]
  max_age       = 3600
}
```

**Key points:**
- Always include `"OPTIONS"` in `allow_methods` — browsers send preflight OPTIONS requests before non-simple requests (POST with JSON, requests with Authorization headers).
- If your frontend sends `Authorization: Bearer ...` headers, you must include `"authorization"` in `allow_headers`.
- Use specific origins in production, not `"*"`.
- `max_age` (seconds) tells browsers how long to cache preflight responses. `3600` (1 hour) reduces OPTIONS traffic.

### Dynamic CORS Origins

If multiple frontends call the same API, you can build the origins list dynamically. The auth project does this with SSM parameters:

```hcl
data "aws_ssm_parameters_by_path" "cors_origins" {
  path = "/auth/cors_origins/"
}

module "api" {
  # ...
  cors_configuration = {
    allow_origins = nonsensitive(data.aws_ssm_parameters_by_path.cors_origins.values)
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 3600
  }
}
```

Each service registers itself by creating an SSM parameter (e.g. `/auth/cors_origins/p2p = https://p2p.bend0g.com`). The auth API picks them all up at `terraform apply` time.

---

## Auth Integration

This module has built-in support for the [auth](https://github.com/BenD0G/auth) push-to-approve authentication system. Set `requires_auth = true` on any route to protect it with JWT validation.

### How It Works

When a route has `requires_auth = true`:

1. The module creates a Lambda Authorizer on the API Gateway
2. It looks up the authorizer Lambda by name (default: `"auth-authorizer"`)
3. Every request to that route first goes through the authorizer
4. The authorizer validates the JWT from the `Authorization: Bearer ...` header
5. If valid, the request proceeds to your backend Lambda
6. If invalid, the client gets a 403 — your Lambda is never invoked

```
Client --- GET /stats (Bearer token) ---> API Gateway
                                           |
                                           +-- Lambda Authorizer (auth-authorizer)
                                           |   Reads JWT secret from SSM
                                           |   Validates HS256 signature + expiry
                                           |   Returns { isAuthorized: true/false }
                                           |
                                      if authorized:
                                           +-- Your backend Lambda runs
                                           |
Client <--- 200 { data } ---------------+

                                      if not authorized:
Client <--- 403 Forbidden -------------+
```

### Setup

**Prerequisites:**
- The `auth-authorizer` Lambda must already be deployed (it's part of the [auth project](https://github.com/BenD0G/auth))
- The auth project's SSM parameter `/auth/jwt_secret` must contain the JWT signing key

**In your Terraform:**

```hcl
module "api" {
  source = "git::https://github.com/BenD0G/terraform-modules//http-api-lambda-router?ref=v1.3.0"

  root_zone_name = "bend0g.com"
  subdomain      = "my-project.bend0g.com"

  routes = [
    {
      name          = "get_data"
      function_name = aws_lambda_function.my_lambda.function_name
      route_key     = "GET /data"
      requires_auth = true   # Protect this route
    },
    {
      name          = "health_check"
      function_name = aws_lambda_function.my_lambda.function_name
      route_key     = "GET /health"
      # requires_auth defaults to false — no auth
    },
  ]

  cors_configuration = {
    allow_origins = ["https://my-project.bend0g.com"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

# Register your origin with the auth API's CORS allowlist
resource "aws_ssm_parameter" "auth_cors_origin" {
  name  = "/auth/cors_origins/my-project"
  type  = "String"
  value = "https://my-project.bend0g.com"
}
```

**In your frontend:**

```js
const AUTH_API = 'https://api.auth.bend0g.com';
const SERVICE = 'my-project';

// Login: calls the auth API, waits for phone approval, gets a JWT
async function login() {
  const res = await fetch(`${AUTH_API}/auth`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ service: SERVICE })
  });
  const { token } = await res.json();
  sessionStorage.setItem('auth_token', token);
}

// All data requests: send the JWT as a Bearer token
async function getData() {
  const token = sessionStorage.getItem('auth_token');
  const res = await fetch('https://api.my-project.bend0g.com/data', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  return res.json();
}
```

### Using a Different Authorizer

If you deploy multiple authorizer Lambdas (e.g. one per service), override the default:

```hcl
module "api" {
  # ...
  authorizer_function_name = "my-custom-authorizer"
}
```

### End-to-End Flow

Putting it all together, here's the complete flow when a user visits a protected site:

```
1. User opens https://my-project.bend0g.com
2. Frontend checks sessionStorage for an existing token
3. No token found → show Login button
4. User clicks Login
5. Frontend POST https://api.auth.bend0g.com/auth { "service": "my-project" }
   └── Auth Lambda sends FCM push to phone
   └── Auth Lambda polls DynamoDB for 27s
6. User taps Approve on phone
   └── Phone POST https://api.auth.bend0g.com/approve { challenge_id, action, hmac }
7. Auth Lambda sees approval, generates JWT (aud: "my-project"), returns it
8. Frontend stores token in sessionStorage
9. Frontend GET https://api.my-project.bend0g.com/data (Authorization: Bearer ...)
   └── API Gateway invokes auth-authorizer
   └── Authorizer validates JWT signature + expiry → isAuthorized: true
   └── API Gateway invokes your backend Lambda
10. Backend Lambda returns data
11. Frontend displays data
```

### Real-World Example

The P2P dashboard (`p2p.bend0g.com`) uses this module with auth:

```hcl
module "lambda_router" {
  source = "git::https://github.com/BenD0G/terraform-modules//http-api-lambda-router?ref=v1.3.0"

  root_zone_name = "bend0g.com"
  subdomain      = "p2p.bend0g.com"

  routes = [
    {
      name          = "query_daily_stats"
      function_name = aws_lambda_function.lambda.function_name
      route_key     = "GET /stats"
      requires_auth = true
    }
  ]

  cors_configuration = {
    allow_origins = ["https://p2p.bend0g.com"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_ssm_parameter" "auth_cors_origin" {
  name  = "/auth/cors_origins/p2p"
  type  = "String"
  value = "https://p2p.bend0g.com"
}
```

---

## Known Limitations

### Authorizer Lambda Permission Conflict

The module uses a static `statement_id` (`"AllowInvokeFromApiGw-authorizer"`) for the authorizer Lambda permission. If multiple API Gateways share the same authorizer Lambda, the second `terraform apply` will fail because the permission already exists.

**Workaround:** After the first API Gateway creates the permission, import the existing permission into the second module's state:

```bash
terraform import 'module.api.aws_lambda_permission.authorizer_invoke[0]' auth-authorizer/AllowInvokeFromApiGw-authorizer
```

**Proper fix:** Update the module to include the API Gateway ID in the `statement_id` so each is unique.

### 29-Second Maximum Timeout

API Gateway HTTP APIs have a hard 29-second integration timeout. The `timeout_ms` variable cannot exceed 29000. If your Lambda needs to run longer, consider using a Lambda Function URL instead.

### Custom Domain Is Always `api.<subdomain>`

The `api.` prefix cannot be removed. If you want the API at the bare subdomain (e.g. `auth.bend0g.com` instead of `api.auth.bend0g.com`), you'd need to modify the module.
