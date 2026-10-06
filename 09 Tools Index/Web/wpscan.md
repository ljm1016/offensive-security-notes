#tools #web

WordPress vulnerability and configuration scanner — identifies outdated plugins, themes, and core weaknesses specific to WordPress sites.

## Installation
```bash
gem install wpscan
# or pre-built binary from wpscan.com
```

## Basic scan
```bash
wpscan --url https://target.com
```

Output includes:
- WordPress version and known CVEs
- Active plugins/themes and their versions + CVEs
- Weak configurations (e.g. user enumeration via `?author=1`)
- Backup files, XML-RPC endpoints, common paths

## With API key (optional, for vulnerability data)
```bash
wpscan --url https://target.com --api-token YOUR_TOKEN
```
Free token from wpscan.com; adds CVE details and severity scores. Rate-limited without it, but still usable.

## Common flags
```bash
--enumerate u          # enumerate usernames
--enumerate p          # enumerate plugins
--enumerate t          # enumerate themes
--random-user-agent    # avoid WAF blocks
-o output.json         # save results
```

## In the workflow
[[Where to even start]] Phase 1 — if `whatweb` shows WordPress, run `wpscan` in parallel with the initial recon tools. It'll identify outdated plugins/themes (often the path to code execution) faster than manual enumeration.

## Notes
- Scanner is passive (no actual exploitation) — safe to run on any target
- Detects *versions*, not necessarily exploitability — a plugin version might have a CVE that requires a specific configuration or authentication
- [[Where to even start]] Phase 4 — once you know which plugins are outdated, Google or searchsploit the exact version for POCs
