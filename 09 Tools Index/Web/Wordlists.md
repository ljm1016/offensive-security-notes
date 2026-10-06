#tools #web

Pre-built dictionaries for fuzzing paths, parameters, subdomains, and credentials.

## Common locations
```
/usr/share/seclists/         # SecLists repo (dirb, passwords, discovery wordlists)
/usr/share/wordlists/        # System default (often symlink to above)
```

On Kali Linux, install SecLists:
```bash
apt install seclists
# or git clone https://github.com/danielmiessler/SecLists
```

## Useful lists for web recon
| Task | Path |
| --- | --- |
| Directory brute force | `Discovery/Web-Content/common.txt`, `big.txt`, `raft-medium.txt` |
| Parameter fuzzing | `Discovery/Web-Content/WebContent/api-paths.txt`, `Burp-lists.txt` |
| Subdomain enumeration | `Discovery/DNS/*.txt` |
| Virtual host fuzzing | `Discovery/Web-Content/common.txt` (used with `Host:` header) |
| Credential spraying | `Passwords/Common-Credentials/*.txt`, `darkweb2017-top10000.txt` |

## Custom wordlists
```bash
# Extract words from the site itself
cewl https://target.com -w custom-wordlist.txt -d 3

# Extract words from robots.txt, JS files, responses
# and build from them
```

## In the workflow
[[Where to even start]] Phase 2 — `gobuster` and `ffuf` use these wordlists to discover paths, params, and vhosts. Start with `common.txt`; if it's too noisy or too quiet, swap to `big.txt` or domain-specific lists.

## Notes
- Different lists have different coverage (common.txt ~4700 entries, big.txt ~20k)
- Bigger wordlist = slower scan, but finds more; start small, expand if needed
- Custom lists (cewl, harvested from the target) are often better than generic ones for a specific target
- `directory-list-*.txt` from DIRB repo is older/outdated — prefer SecLists equivalents
