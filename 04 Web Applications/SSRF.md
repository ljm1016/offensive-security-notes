#webapplications

Server-side request forgery (OWASP A01-adjacent — a broken trust boundary): input redirects a server's *own* network request to a destination the attacker chose, not the user's browser's request.
```
Normal:  http://127.0.0.1:8772/public
Changed: http://127.0.0.1:8772/internal
```
The browser calls the public-facing app; the app's server then fetches a second URL on the attacker's behalf. If that second fetch's destination is attacker-influenced, it can reach internal services, cloud metadata endpoints, or anything else the server (but not the original browser) can route to — stuff normally sitting behind a firewall specifically because it's not meant to be internet-reachable.

## Fix — remove arbitrary destination selection
```python
sources = {"catalog": "http://127.0.0.1:8772/public"}
url = sources.get(input_source)
if url is None:
    return {"error": "Unknown source"}, 400
fetch_with_limits(url)
```
An allowlist of known destinations, keyed by an opaque name the client picks — never a raw URL/host/IP the client supplies directly.

## If arbitrary URLs are genuinely required
- Restrict outbound connections (network policy, egress allowlist)
- Authenticate internal services — don't rely on network position alone as the only control
- Limit request duration and response size
- **Validate scheme, host, port, and the resolved address, including every redirect hop** — a URL that resolves to a public hostname at check-time can still redirect to `169.254.169.254` or `127.0.0.1` at fetch-time (DNS rebinding / open-redirect-to-SSRF)

## Testing
- Any feature that fetches a URL server-side on your behalf — webhooks, "import from URL," PDF/screenshot generators, link previews, SSO/OAuth discovery endpoints
- Try internal/loopback targets (`127.0.0.1`, `169.254.169.254` for cloud metadata, `localhost`, internal hostnames) and see what comes back in the response or timing
