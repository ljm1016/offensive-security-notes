#webapplications

Part of OWASP A07 (Authentication Failures). See [[Front End, Back End & State|State, cookies, and sessions]] for the baseline model this section attacks.

## Session fixation

The attacker knows the session identifier *before* login, and a vulnerable server preserves it across authentication.
```
1. Victim adopts attacker's known ID  → anonymous
2. Victim signs in as Alice           → same ID now identifies Alice
3. Attacker replays the known ID      → server returns Alice
```

### Testing workflow
1. **Get an unauthenticated session ID:** Visit the site without logging in, capture the `Set-Cookie` response (DevTools → Network or Burp).
   ```
   Set-Cookie: sid=ATTACKER_KNOWN_123; Path=/; HttpOnly
   ```

2. **Force the victim to use that ID.** Either:
   - Send them a link with `?sid=ATTACKER_KNOWN_123` in the query (if the app reads it)
   - Use a session fixation payload in `<img src=https://target.com/?sid=ATTACKER_KNOWN_123>` to pre-set their cookie (if the app doesn't validate origin)

3. **Victim logs in normally** using that pre-set session ID (because the server didn't rotate it).

4. **You replay the same ID** — now authenticated as Alice:
   ```bash
   curl -i -b "sid=ATTACKER_KNOWN_123" https://target.com/account
   # Returns Alice's account, 200 OK
   ```

### Proof
- Unauthenticated request with the known ID returns generic data
- After victim logs in (you observe via another channel or by waiting), the same ID now returns authenticated data
- The ID was never rotated — that's the vulnerability

**Defense — rotate the identifier when authentication succeeds, and kill the old one:**
```python
old = request.cookies.get("sid")
SESSIONS.pop(old, None)
sid = new_session(verified_user)
set_session_cookie(sid)
```
Issuing a new cookie is only half the fix — the *old* identifier must lose its authenticated meaning too.

## Session hijacking and logout

Hijacking reuses a session that *already* carries an authenticated identity (stolen/copied cookie), as opposed to fixation's share-before-login.

### Testing workflow
1. **Steal or copy a valid session ID.** Options:
   - Capture from your own login (if you have account access, this tests the app's logout behavior)
   - XSS to read a `fetch` or network request and extract the cookie (if `HttpOnly` is missing)
   - Intercept in transit (if `Secure` flag is missing and you're on HTTP or a proxied connection)

2. **Use the session in a new browser/context** (simulate the attacker).
   ```bash
   curl -i -b "sid=STOLEN_SESSION_123" https://target.com/account
   # If logout didn't work, returns the victim's account
   ```

3. **Test logout behavior:**
   - Log in as User A, capture the session ID
   - Click logout, observe the response (does it `Set-Cookie: sid=; Max-Age=0`?)
   - In a new tab/window, use the old session ID from step 1
   - **Vulnerable:** Old ID still works (200, account data returns)
   - **Fixed:** Old ID returns 401 (session invalidated server-side)

### Proof
- Logout clears only the cookie (`Set-Cookie: ... Max-Age=0`)
- A copied session ID from *before* logout still works after logout
- This means the server never invalidated the session record

**Defense — kill the session server-side, not just the cookie:**
```python
def logout(request):
    sid = request.cookies.get("sid")
    SESSIONS.pop(sid, None)           # Kill server-side record first
    response = redirect("/login")
    response.delete_cookie("sid")     # Then tell browser to clear cookie
    return response
```
Clearing only the cookie leaves a copied session valid elsewhere. Invalidating the server-side record is what actually ends it.

## Cookie flags
```
Set-Cookie: sid=<random>; Path=/; Secure; HttpOnly; SameSite=Lax
```
| Flag | Protects | Limit |
| --- | --- | --- |
| `Secure` (+ HTTPS) | Cookie transport | No ownership or role check |
| `HttpOnly` | Stops page JS from reading the cookie | Browser still attaches it to requests |
| `SameSite` + narrow host scope | Reduces unintended cookie attachment | Some navigations/same-site requests still send it |
| Random ID + server expiry | Resists guessing, bounds reuse | Needs invalidation on logout/compromise |

Idle expiry limits inactivity; absolute expiry limits total session age. None of these flags substitute for the server-side ownership/role check in [[Broken Access Control]] — they reduce *how* a session leaks, not *what happens* if it does.
