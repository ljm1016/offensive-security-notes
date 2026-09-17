#tools-index/web

#### `nuclei` runs community-maintained YAML templates against a target to check for known CVEs and misconfigurations fast — a scanner, not a fuzzer.

Syntax:
```
nuclei -u https://target.com
nuclei -l hosts.txt -severity critical,high
nuclei -u https://target.com -tags cve,exposure
```
Templates are pulled/updated automatically on first run (`nuclei -update-templates` to refresh). Run this after [[httpx]] has told you what's alive, not as your first move — it's noisy and its findings still need manual confirmation like anything else here.
