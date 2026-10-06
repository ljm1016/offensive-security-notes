#webapplications

Part of OWASP A07 (Authentication Failures).

## MFA — enforce the completed state
Multi-factor authentication combines distinct factors (password + security key/TOTP). **The server, not the page, must track which factors are done** — gate every protected route on the completed state, not just the login page:
```python
s = session()
if not s or not s["user"] or not s["mfa"]:
    return deny(403)
return protected_report()
```
A page that *asks* for a code does not enforce MFA by itself — if a protected endpoint only checks the password step, a direct request to it can skip the second factor entirely.

| Weakness | What goes wrong | Defense |
| --- | --- | --- |
| Skipped step | A protected route checks the password but not the second factor | Gate every endpoint on the completed state |
| Code guessing | Six digits = 1M values; unlimited tries eventually win | Few attempts per challenge, short expiry, then a new challenge |
| Replay | An accepted code works a second time | Consume the challenge once it succeeds |
| Client-side decision | The page trusts `{"mfa":"ok"}` in a response the attacker can edit | Keep MFA state on the server only |
| Weaker fallback | SMS, email links, backup codes, "remember this device" skip the strong factor | Hold every fallback/recovery path to the same assurance |
| Push fatigue / live phishing | Repeated prompts get approved; a proxy relays the code and keeps the session | Number matching; phishing-resistant passkeys/security keys |

## Password reset — a temporary credential
A reset token temporarily stands in for the password of **one specific account**.
```python
r = RESETS.get(token)
if not r or r["used"] or now() > r["expires"]:
    reject()
if user != r["user"]:
    reject()
change_password(user)
r["used"] = True
end_all_sessions(user)
```
The token decides which account changes — it must be random, single-use, and short-lived, and must end existing sessions once used (so a stolen old session dies along with the password change).

| Weakness | What goes wrong | Defense |
| --- | --- | --- |
| Token not bound to an account | A token issued for Alice resets Bob | Look up the account from the token alone, not from a separately-supplied username |
| Guessable or long-lived token | Sequential/time-based values; links valid for days | ≥128 random bits, minutes of validity, single use |
| Reset link poisoning | The link is built from the request's `Host` header, so the victim's email points at the attacker | Build links from a configured base URL, never the request's Host |
| Token leaks from the URL | Referer headers, analytics scripts, and logs capture the link | `Referrer-Policy: no-referrer`; no third-party scripts on the reset page |
| Account enumeration | Different replies reveal which accounts exist | Same response and timing either way, whether the account exists or not |
| Reset bypasses other controls | Reset logs straight in past MFA; old sessions keep working | Require the second factor; end existing sessions on reset |

Recovery is a second way into the account — it needs the same strength as the front door, not a weaker shortcut.
