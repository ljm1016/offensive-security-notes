#tools-index/recon

recon-ng is a reconnaissance framework for OSINT — modular like Metasploit, but focused entirely on information gathering.

## Setup
```bash
sudo apt install recon-ng
recon-ng
workspaces create MyProject   # isolate data per engagement
```

API keys (most useful modules need one — Shodan, Censys, GitHub):
```
keys add shodan_api YOUR_API_KEY
keys list
```

## Installing & loading modules
Modern recon-ng pulls modules from a marketplace rather than shipping them all by default.
| Command | Description |
| --- | --- |
| `marketplace search <term>` | Find available modules |
| `marketplace install <path>` | Install one, e.g. `recon/domains-hosts/shodan_hostname` |
| `modules load <path>` | Load an installed module |
| `modules search <term>` | Search modules you've already installed |

## Workflow
**1. Seed the database** — give it a domain to work from:
```
db insert domains
show domains
```
**2. Run modules against it:**
```
modules load recon/domains-hosts/brute_hosts
run

modules load recon/domains-hosts/bing_domain_web   # no API key needed
run
```
**3. Query what it found** — everything lands in a local SQLite DB:
```
show hosts
db query SELECT host, ip_address FROM hosts WHERE ip_address IS NOT NULL
```

## Snapshot before anything loud
```
db snapshot take
```

## Export a report
```
modules load reporting/html
options set FILENAME /tmp/recon_report.html
options set CUSTOMER MyClient
run
```

## High-value modules
- Contacts: `recon/domains-contacts/whois_pocs`, `recon/domains-contacts/pgp_search`
- Subdomains: `recon/domains-hosts/shodan_hostname`, `recon/domains-hosts/hackertarget`
- Leaked creds: `recon/domains-credentials/pwnedlist/leaked_domains`
- Cross-reference with [[Shodan]]: `recon/hosts-ports/shodan_ip`
