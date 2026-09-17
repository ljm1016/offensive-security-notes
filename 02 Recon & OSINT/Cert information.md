
Certificate transparency logs are public and append-only — every cert issued for a domain gets logged, including for subdomains nobody linked to publicly. This is usually the single biggest source of hostnames for a target.

**crt.sh** — search the CT logs directly:
```
https://crt.sh/?q=sru.edu
```

**gungnir** — watches CT logs in real time and alerts on new certs matching a pattern, instead of a one-time historical search:
```bash
echo "sru.edu" | gungnir
```
Useful for catching new/test/staging subdomains the moment they get a cert, not just what's already been issued.

A cert only proves a name was requested at some point — not that the host is still live. Feed results into [[Subdomain Enumeration]] to confirm what's actually up.