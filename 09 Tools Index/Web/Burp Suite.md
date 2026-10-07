#tools #web

Interactive proxy and web application testing framework — intercepts requests between browser and server, lets you tamper with anything mid-flight, and replays requests for systematic testing.

## What Burp does vs manual testing
| Task | Manual (curl) | Burp |
| --- | --- | --- |
| Observe a request | `curl -i` shows it once | Intercept, edit, replay without leaving browser |
| Change one parameter | Re-type the curl command | Edit in the UI, click "Send" |
| Test all inputs systematically | Write a bash loop or use sqlmap | Repeater tab: keep session, edit one value at a time |
| Decode a cookie | Base64 decoder in DevTools | Burp Decoder tab (handles URL, HTML, Base64, Hex, etc.) |
| Check for hidden fields | View source | Repeater shows you the full response |

**Burp is your "middle ground"** — more interactive than curl, less heavy than writing an exploitation script. Critical for [[Where to even start]] Phase 3 (cataloging inputs) and Phase 5 (testing each one).

## Installation & setup

### Community Edition (free, sufficient for CTF/homework)
```bash
# Download from portswigger.net/burp/communitydownload
# Or on Kali:
apt install burpsuite

# Run it
burpsuite &
```

### First-time setup
1. **Open Burp** — accept the license, leave all defaults
2. **Go to Proxy tab** → Intercept subtab
3. **Enable interceptor:** `Is Intercept on?` toggle in the top-left corner should be **ON**
4. **Configure browser proxy:**
   - Chrome DevTools Settings → Network (or use a proxy switcher extension)
   - Proxy: `127.0.0.1:8080` (Burp's default)
   - HTTPS: same
5. **Install Burp's CA certificate** (so HTTPS traffic isn't rejected as untrusted):
   - Navigate to `http://127.0.0.1:8080` in the browser while Burp is running
   - Download the certificate
   - Add to browser's trusted CAs (Chrome: Settings → Privacy → Manage certificates)
6. **Test it:** Visit any HTTPS site; Burp should intercept the request

### Turn off intercept when you don't need it
**Leave Intercept ON during testing, OFF when just browsing** — otherwise every single request hangs waiting for your approval. Use the toggle or the checkbox in Proxy → Intercept.

## Core tabs & what they do

| Tab | Purpose | When to use |
| --- | --- | --- |
| **Proxy** → Intercept | Catch live requests, edit, forward | Real-time tampering while browsing |
| **Repeater** | Replay a captured request, edit, resend | Test one input at a time (e.g., change `id=101` to `id=102`) |
| **Intruder** (Pro) | Automate parameter fuzzing with payloads | Brute-force IDs, test many values; Community limited to slow single-threaded |
| **Decoder** | Encode/decode: Base64, URL, HTML, Hex, etc. | Decode cookies, JWT tokens, obfuscated payloads |
| **Comparer** | Diff two responses side-by-side | Compare "true" response vs "false" for blind injection testing |
| **Logger** | History of all requests/responses | Audit trail; search/filter requests |
| **Target** | Sitemap and scope configuration | Define what you're testing, exclude out-of-scope |

## Typical workflow — Phase 3 & 5

### Phase 3 — Catalog every input
1. **Browse the app normally** with Intercept ON
2. **For each form/request:**
   - Burp intercepts it in the Proxy tab
   - Read the full request (all parameters, headers, cookies, body)
   - Right-click → "Send to Repeater"
   - Click "Forward" to let the request through
3. **In Repeater tab:** You now have that request saved and editable
4. **Repeat for all user interactions** (login, submit form, click button, etc.)

Now you have every input documented without needing curl commands.

### Phase 5 — Test inputs one by one
1. **In Repeater:** Pick a captured request
2. **Edit one parameter** (e.g., change `name=alice` to `name=bob`)
3. **Click "Send"** (or `Ctrl+Enter`)
4. **Compare responses:** Did the output change? Same status code?
5. **If something looks weird:** Copy the response to Comparer, compare against a baseline
6. **Move to the next parameter** — rinse and repeat

## Common testing patterns

### IDOR — changing an ID
```
Captured request:
GET /api/records/101 HTTP/1.1
Cookie: sid=abc123

Repeater workflow:
1. Change 101 to 102, send
2. Compare response — is it someone else's record?
3. Try 103, 104, etc.
```

### SQL Injection — testing a search field
```
Captured request:
GET /search?q=alice HTTP/1.1

Repeater workflow:
1. Change q=alice to q=alice' AND 1=1--
2. Send, compare response
3. Change q=alice to q=alice' AND 1=2--
4. Send, compare — do the two responses differ?
```

### XSS — testing a comment field
```
Captured POST:
POST /comment HTTP/1.1
Body: text=hello

Repeater workflow:
1. Change text=hello to text=<img src=x onerror=alert(1)>
2. Send, check response
3. Navigate to the page that displays the comment
4. Does the alert fire? (Stored XSS confirmed)
```

### CSRF — checking for token validation
```
Captured request:
POST /transfer HTTP/1.1
Body: to=bob&amount=100&csrf_token=abc123xyz

Repeater workflow:
1. Try removing csrf_token entirely — does it still work?
2. Try a wrong token — does it reject it?
3. Try re-sending the same token twice — does it still accept it?
```

## Practical tips & gotchas

### Issue: Certificate errors on HTTPS
**Symptom:** "Your connection is not private" even after installing Burp's CA.

**Fix:**
- Burp → Proxy Settings → CA Certificate → "Save CA certificate"
- Browser Settings → Certificates → Import the PEM file
- Restart browser

### Issue: Intercept hangs, nothing shows up
**Symptom:** Request sent but Intercept tab stays empty.

**Cause:** Intercept is OFF or Repeater ate the request.

**Fix:**
- Check the toggle: `Is Intercept on?` must be ON
- Open Repeater tab, see if it's there — right-click → "Send to Repeater" from Logger if needed

### Issue: Can't see POST body
**Symptom:** Proxy shows the request but body is empty or shows "Body parameter not shown."

**Fix:**
- Change the request type: top-left dropdown, select `GET` vs `POST` vs `PUT`
- Or scroll down in the Proxy Intercept tab — the body is often below the headers

### Issue: Session expires while testing
**Symptom:** After a few requests, you get 401 (not authenticated).

**Cause:** Session cookie expired or your repeated testing triggered logout.

**Fix:**
- Re-capture a fresh login request, send to Repeater
- Extract the new session cookie
- In Repeater, update the `Cookie:` header with the new value
- Alternatively: Burp → Options → Sessions → define a session handling rule to auto-refresh

### Issue: Intruder is too slow (Community edition)
**Symptom:** Testing 100 IDs by hand would take forever.

**Cause:** Community edition limits Intruder to single-threaded slow speed.

**Fix:**
- For small fuzzing: use Repeater + manual iteration (10-20 tries is fast)
- For large fuzzing: use `ffuf` or `sqlmap` from the command line instead
- Upgrade to Pro if Intruder speed is critical (not needed for CTF)

## Decoder — practical examples

### Decode a JWT
1. Copy the token: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhbGljZSJ9.abc123`
2. Decoder tab → paste → select "Base64" (it auto-detects)
3. See the decoded payload: `{"sub":"alice"}`
4. Edit it (add `"role":"admin"`), click "Encode"
5. Re-encode and test if the app accepts the modified token ([[JWT]] tampering)

### Decode a URL-encoded parameter
```
Captured: id=%7B%22user%22%3A%22alice%22%7D
Decoder: paste → select "URL" → see: {"user":"alice"}
```

### Obfuscated XSS evasion
```
Received: <img src=x onerror="eval(atob('YWxlcnQoMSk='))">
Decoder: paste YWxlcnQoMSk= → select "Base64" → see: alert(1)
Confirms the payload is XSS with atob() deobfuscation
```

## Integration with other tools

| Tool | How Burp helps |
| --- | --- |
| [[sqlmap]] | Capture a request in Burp Repeater → right-click "Copy as curl" → paste into sqlmap command |
| [[ffuf]] | Burp shows you the exact parameter to fuzz; use ffuf for high-volume testing |
| DevTools Network tab | Burp Repeater is like DevTools' Network tab but with full editing and history |
| Manual curl | Burp Repeater UI is easier than re-typing curl commands for each test |

## Quick reference

```
Setup:
- Run burpsuite, install CA cert, set browser proxy to 127.0.0.1:8080
- Proxy → Intercept: toggle ON

Testing:
- Intercept requests, send to Repeater
- Repeater: edit one parameter, send, compare response
- Decoder: decode cookies/tokens/obfuscated payloads
- Logger: search/filter history of all requests

Shortcuts:
- Ctrl+Enter: Send request (Repeater)
- Ctrl+I: Open Intruder
- Right-click → Send to Repeater / Comparer / Intruder
```

## See also
- [[Where to even start]] Phase 3 & 5 — when Burp fits into your testing workflow
- [[HTTP Requests]] — understanding what you're intercepting
- [[SQL Injection]], [[Cross-Site Scripting]], [[CSRF]] — testing specific vulnerabilities
- [[Payload Reference]] — payloads to test with Repeater
