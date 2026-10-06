#webapplications

An `<iframe>` embeds another page. A deceptive overlay on the attacker's page can position a real button from the framed page under what looks like a harmless control, so a genuine click lands on the framed page's control instead — **the attack needs no access to the framed DOM at all, so same-origin policy alone does not stop it.**

## Defense
```
Content-Security-Policy: frame-ancestors 'none'
```
(`frame-ancestors 'self'` to allow only your own site to frame it.) This tells the browser to refuse to render the page inside a frame at all — the older `X-Frame-Options: DENY` header does the same thing for browsers that don't read CSP's `frame-ancestors`.
| Captured test | Result |
| --- | --- |
| Unprotected embedding | Framed button receives the click |
| Corrected embedding (`frame-ancestors 'none'`) | Browser refuses to render the frame |

Any page with a real consequence to a click — changing a setting, confirming a payment, approving a permission — should send this header unless it's specifically meant to be embedded.
