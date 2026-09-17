
```bash
whois sru.edu
```
Most registrant detail is redacted today, so a plain WHOIS lookup often won't hand you a name or contact anymore.

## Reverse WHOIS
Pivots from one registrant to every other domain they own. **Historical WHOIS often still holds the pre-redaction record** — that's the actual product a reverse-WHOIS service sells.
```
https://api.whoxy.com/?key=KEY
  &reverse=whois
  &keyword=slippery+rock
  &mode=domains
```
([whoxy.com](https://whoxy.com) — check current access terms)

An apex domain is the root of a DNS zone (e.g. `lab.internal`). A reverse-WHOIS pivot returns other apex domains tied to the same registrant — applied here, that returns a second apex domain: `rockathletics.com`.

**When a pivot returns a new domain, loop back to the top of the recon pipeline for it** — it needs its own search, certificate history ([[Cert information]]), DNS lookup ([[DNS Recon]]), and network check ([[ASN]]). One result in this class actually required every earlier technique to be repeated.
