#webapplications

Cross-site request forgery: an attacker induces a victim's browser to send a state-changing request using the victim's *existing* login — the browser auto-attaches cookies to any request, including ones triggered by a page the victim didn't mean to trust.
```
https://vulnerable-website.com/email/change?email=pwned@evil-user.net
```
If that's a plain `GET` with no other check, visiting an attacker's page (an auto-submitting form, an `<img>` tag, etc.) silently changes the victim's email while they're logged in.

## How it works
```
Victim is logged in to bank.com with a session cookie.
Attacker's site (attacker.com) loads this hidden form:
<form action="https://bank.com/transfer" method="POST">
  <input name="to" value="attacker-account">
  <input name="amount" value="1000">
</form>
<script>document.forms[0].submit();</script>
```
Victim's browser sends the POST to `bank.com` with the session cookie auto-attached — the bank sees an authenticated request and processes the transfer. Victim never saw it coming.

## Testing workflow
1. **Identify state-changing endpoints:** any `GET` that modifies data, or a `POST`/`PUT`/`DELETE` without token/origin checks.
   ```
   GET  /preferences/email?email=pwned@attacker.com
   POST /password/change (no Content-Type check, no CSRF token field)
   ```

2. **Craft the forged request.** For a `GET`, an `<img>` or auto-submitting form works:
   ```html
   <!-- GET request via <img> -->
   <img src="https://target.com/email/change?email=pwned@attacker.com" style="display:none">
   
   <!-- POST request via auto-submit form -->
   <form action="https://target.com/transfer" method="POST">
     <input name="to" value="attacker-account">
     <input name="amount" value="1000">
     <input type="submit" value="Click here">
   </form>
   <script>document.forms[0].submit();</script>
   ```

3. **Verify the victim's cookies are sent.** Open DevTools → Network, trigger the request. Check that the `Cookie` header is present and contains the session token. If it's not there, the page has `SameSite=Strict` or other protections (you found the fix, not a vulnerability).

4. **Proof:** Submit the form from an attacker-controlled domain (not the target domain). If the state changes, CSRF is confirmed. You don't need JavaScript execution — just the blind request.

### Common bypasses
| Bypass | When it works |
| --- | --- |
| Content-Type not validated | `POST` accepts `application/x-www-form-urlencoded` from a `<form>`, even if the API normally expects `application/json` |
| `Referer` header checked but forgeable | `Referer` is compared to whitelist, but can be spoofed in some contexts (not cross-origin, but within-origin open redirects) |
| Custom header not required | `X-Requested-With: XMLHttpRequest` check missing; attacker can't set custom headers from a cross-origin `<form>`, but if the app doesn't require it, the form still works |
| CSRF token present but not bound to session | Token is the same for all users/sessions; attacker pre-fetches it and reuses it across victims |
| State change in a redirect chain | A 302 in the middle obscures which origin sent the real action |

## Fix
```python
def handle_preference_change(request):
    require_method('POST')                    # state changes only via POST (or PUT/DELETE, not GET)
    require_origin_match(request.referrer)    # Origin/Referer must match target domain
    require_csrf_token(request.form, session) # Token must be present and valid for this session
    update_preference(request.user)
    return {"status": "ok"}
```
Three independent checks, not one: the request must be the right method, from the right origin, and carry a token the attacker's page can't know (since it's scoped to the victim's own session and not readable cross-origin — see [[CORS]]).

## Interaction with XSS
**XSS on the same site defeats CSRF defenses entirely** — a script running inside the trusted page can read the CSRF token itself and send the forged request from inside the origin. CSRF protections assume the attacker can only make the browser *send* a request blind, not read the page or its tokens; see [[Cross-Site Scripting]] for why that assumption breaks.
