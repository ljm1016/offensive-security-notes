#webapplications

Part of OWASP A07 (Authentication Failures). A credential model, as an alternative to the opaque-session-lookup model in [[Session & Cookie Security]].

## Opaque sessions vs JWTs
| Credential model | Client carries | Server does |
| --- | --- | --- |
| Opaque session | An unpredictable reference | Looks up the session and lifetime |
| Signed JWT (JSON Web Token) | Claims + an integrity signature | Verifies signature and acceptance policy |

```
base64url(header).base64url(payload).signature
```
**Signing protects integrity when verified. The claims themselves remain readable** — base64url is encoding, not encryption. Never put secrets in a JWT payload. Common claims: `sub` (account subject), `iss` (issuing authority), `aud` (intended recipient). A cookie or `Authorization` header can carry either credential type.

## Tampering and validation
Editing a claim (e.g. `"role":"student"` → `"role":"admin"`) doesn't touch the signature — an unverified decode will happily show you the edited value. The server must actually verify it:
```python
claims = jwt.decode(
    token, KEY, algorithms=["HS256"],
    issuer=ISSUER, audience="portal-api",
    options={"require": ["sub", "iss", "aud", "exp"]}
)
```
**Verify with trusted keys and an explicit allowed-algorithm list** (never trust an `alg` the token itself claims — that's the classic `alg:none` / key-confusion bypass), **then check required claims, token purpose, and resource permissions.** An altered role, wrong issuer/audience, or expired/wrong-purpose token should all fail closed (401), not just claims that fail a signature check.

## Expiry, refresh, and revocation
| Event | Copied access token | Server decision |
| --- | --- | --- |
| Token issued | Valid until its expiry | Signature + required claims pass |
| Browser logs out | A copy still exists elsewhere | Pure local (signature-only) verification may still accept it |
| Server revokes session/token | Signature can remain valid | A revocation lookup is what actually rejects it |

**A JWT's signature staying valid is not the same as the server still trusting it.** If logout/revocation needs to take effect immediately, verification must also check a server-side revocation list — signature + expiry alone will keep accepting a token the server "revoked." A refresh token requests replacement access tokens; rotating it on each use can detect reuse (a stolen refresh token used after the legitimate one rotates signals compromise).

## Testing checklist
- Decode a captured JWT (base64, no key needed) — read every claim, look for a role/permission field
- Edit a claim, re-send unsigned/with a stripped `alg` — does the server actually verify, or just decode?
- Check whether logout/password-reset/role-change actually revokes outstanding tokens, or whether an old one still works until natural expiry
