#webapplications

## Front end vs back end
- **Front end — runs in the browser:** HTML supplies structure, CSS styles it, JavaScript changes the DOM (the browser's live copy of the page)
- **Back end — runs on the server:** identifies the caller, loads the record, decides whether this caller may see it

**Editing the page in the browser (devtools, a userscript) changes what one person sees. It does not change what the server allows.** Protected decisions happen on the server — never trust a client-side check as the real gate. This is the root cause behind most of [[Broken Access Control]].

## State, cookies, and sessions
HTTP treats every request independently. **State** is the information an application keeps between requests.

| Where state lives | Example |
| --- | --- |
| Browser | Live page, cookies, stored preference |
| Server session | Signed-in account, expiry |
| Database | Account, saved comment, record owner |

How a cookie links two requests:
```
Response:  Set-Cookie: sid=opaque-value
Later:     Cookie: sid=opaque-value
```
The cookie carries an opaque value; the server's session record gives that value its meaning (which account, when it expires). See [[Session & Cookie Security]] for how this gets attacked, and [[JWT]] for the alternative (self-contained) credential model.

## A normal login and permission check
| Step | Example | Decision |
| --- | --- | --- |
| 1. Authenticate | Verify Alice's credentials | Which account is this? |
| 2. Create a session | Fresh random `sid` identifies Alice | Which later requests share this login? |
| 3. Authorize | Alice requests record 101, owned by Alice | May this account read this record? |
| 4. Return the result | Only the permitted record leaves the server | What data reaches the browser? |

**Authentication establishes identity. Authorization checks a specific action on a specific resource.** They are not the same check, and both are required on every protected route.

## OWASP Top 10 (2025)
Awareness guide to major web app risks — A01, A05, and A07 are the ones this vault has worked examples for:
| | |
| --- | --- |
| A01 Broken Access Control | A06 Insecure Design |
| A02 Security Misconfiguration | A07 Authentication Failures |
| A03 Software Supply Chain Failures | A08 Software or Data Integrity Failures |
| A04 Cryptographic Failures | A09 Security Logging and Alerting Failures |
| A05 Injection | A10 Mishandling of Exceptional Conditions |

See [[Broken Access Control]] (A01), [[SQL Injection]] / [[NoSQL Injection]] / [[Command Injection]] / [[Server Side Template Injection]] (A05), and [[Session & Cookie Security]] / [[MFA & Password Reset]] / [[JWT]] / [[SSO & OAuth]] (A07).

## Defense recap
| Boundary | Primary correction | Additional layer |
| --- | --- | --- |
| Account and record / A01 | Trusted identity + object/action policy → [[Broken Access Control]] | Least privilege and audit |
| Credential and session / A07 | Verification, rotation, lifetime, revocation → [[Session & Cookie Security]], [[JWT]] | HTTPS, cookie policy, rate limits |
| MFA, reset, SSO / A07 | Server-held MFA state, single-use reset tokens, full OIDC checks → [[MFA & Password Reset]], [[SSO & OAuth]] | Phishing-resistant factors, link accounts by `iss`+`sub` |
| Content and interpreter / A05 | Safe output APIs, prepared statements, fixed template source → [[Cross-Site Scripting]], [[SQL Injection]], [[Server Side Template Injection]] | CSP and restricted execution |
| Server fetch / A01 | Approved destinations and connection policy → [[SSRF]] | Network restrictions and service authentication |
| Browser read or frame | Intended CORS and framing policies → [[CORS]], [[Clickjacking]] | CSRF controls and server permissions → [[CSRF]] |

**Retest the original failure and the legitimate feature after every correction** — a fix that blocks the exploit but also breaks the real feature isn't done, and a fix that doesn't get retested against the original exact payload isn't verified.
