#webapplications

Part of OWASP A07 (Authentication Failures). Single sign-on: the portal lets a separate identity provider authenticate the user — OpenID Connect with PKCE, the standard authorization code flow.

## The flow
```
1  Browser  →  Portal:            GET /sso/start
2  Portal   →  Browser:           302 /authorize?state&nonce&PKCE
3  Browser  →  Identity provider: GET /authorize, user signs in
4  Provider →  Browser:           302 /sso/callback?code=...&state=...
5  Browser  →  Portal:            GET /sso/callback?code&state
6  Portal   →  Provider:          POST /token  code + verifier   (server to server)
7  Provider →  Portal:            id_token + access_token         (server to server)
8  Portal   →  Browser:           Set-Cookie: sid (new session)
```
**The browser only ever carries a one-time code. The actual tokens travel server to server (step 6–7), never through the browser.** `state` (set at step 2) must come back unchanged at step 4 — it's not a CSRF token for the portal's own forms, it's what proves this callback belongs to the login attempt this browser started.

## Where SSO breaks
| Check | Without it | 
| --- | --- |
| Exact `redirect_uri` match | A loose/open redirect delivers the code to an attacker |
| `state` compared on return | Login CSRF — victim gets signed into the *attacker's* account |
| PKCE verifier | A stolen code can be redeemed by someone else |
| Single-use, short-lived code | An intercepted code gets replayed |
| ID token validation (signature, `iss`, `aud`, `exp`, `nonce`) | A forged or replayed identity gets accepted |
| Account link by `iss` + `sub` | An unverified email claim takes over an existing account — see below |

A maintained OpenID Connect library performs most of these checks for you — don't hand-roll this flow.

## Account linking
A genuine, correctly-signed ID token can still carry an **unverified email** (`"email_verified": false`). If the portal links accounts by email alone:
```python
# unsafe
user = user_by_email(claims["email"])

# fixed — link by provider identity, not a claimed email
key = (claims["iss"], claims["sub"])
account = approved_links.get(key)
if account is None:
    require_explicit_linking()
```
Without this, an attacker who controls a provider account with someone else's email string (unverified) gets signed into *that person's* local account. **Linking an existing account always requires proof of ownership** — a verified email, or an explicit one-time linking step — never a bare claim.
