#recon #osint

Passive reconnaissance using the Internet Archive (Wayback Machine) and Google Dorks to find historical data, exposed files, and information about a target without direct interaction.

---

## Wayback Machine (Internet Archive)

The Internet Archive captures snapshots of websites at different points in time. Historical pages often reveal:
- Old admin panels and endpoints
- Forgotten files and directories
- Database backups
- Credentials in old pages
- Subdomain history
- Previous technology stacks

### Manual browsing
```
https://web.archive.org/web/20230101000000*/target.com
# Shows all snapshots starting from 2023-01-01
```

**Visit:** https://web.archive.org/ and enter target domain

### waybackurls tool (automated)
```bash
# Install
go install github.com/tomnomnom/waybackurls@latest

# Extract all URLs archived for target.com
waybackurls target.com > urls.txt

# Filter for specific patterns
waybackurls target.com | grep -i "admin\|login\|backup\|sql\|api"
```

**Output example:**
```
https://target.com/admin
https://target.com/api/v1/users
https://target.com/backup.sql
https://target.com/old-login.php
```

### Find old endpoints
```bash
# Get all endpoints from Wayback
waybackurls target.com > all_urls.txt

# Filter for potentially vulnerable paths
grep -E "(admin|backup|upload|login|config|debug|test)" all_urls.txt

# Common vulnerable paths from Wayback
waybackurls target.com | grep -E "\.(sql|bak|zip|tar|config|env|xml)$"
```

### Discover old subdomains
```bash
# Extract all unique subdomains from Wayback history
waybackurls target.com | cut -d/ -f3 | sort -u | grep "\.target\.com$"
```

---

## Google Dorks (Advanced Search)

Google Dorks use advanced search operators to find specific information indexed by Google. Highly effective for reconnaissance.

### Basic operators

| Operator | Purpose | Example |
| --- | --- | --- |
| `site:` | Limit search to specific domain | `site:target.com filetype:php` |
| `inurl:` | Search in URL path | `inurl:admin` |
| `intitle:` | Search in page title | `intitle:"Index of /"` |
| `intext:` | Search in page content | `intext:"password"` |
| `filetype:` | Search for specific file types | `filetype:sql` |
| `-` | Exclude results | `site:target.com -www` |
| `*` | Wildcard | `site:*.target.com` |
| `..` | Number range | `site:target.com 2020..2023` |

### Admin panel discovery
```
site:target.com inurl:admin
site:target.com intitle:"login"
site:target.com inurl:panel
site:target.com inurl:manage
site:target.com inurl:dashboard
```

### Find exposed files
```
site:target.com filetype:sql
site:target.com filetype:bak
site:target.com filetype:zip
site:target.com filetype:tar
site:target.com filetype:env
site:target.com filetype:conf
site:target.com filetype:config
site:target.com filetype:xml
```

### Find backups and archives
```
site:target.com "backup"
site:target.com "database"
site:target.com "download"
site:target.com filetype:sql OR filetype:bak OR filetype:zip
```

### Find config files
```
site:target.com inurl:config
site:target.com intext:"database connection"
site:target.com filetype:properties
site:target.com filetype:yaml
site:target.com filetype:json intext:"password"
```

### Find log files
```
site:target.com filetype:log
site:target.com inurl:logs
site:target.com "error log"
site:target.com "access log"
```

### Find API endpoints
```
site:target.com inurl:api
site:target.com inurl:/api/v1
site:target.com inurl:/api/v2
site:target.com filetype:json
```

### Find exposed credentials
```
site:target.com "password"
site:target.com "username"
site:target.com "api_key"
site:target.com "secret"
site:target.com intext:"password =" 
```

### Find documents and PDFs
```
site:target.com filetype:pdf
site:target.com filetype:doc
site:target.com filetype:xls
site:target.com filetype:ppt
```

### Discover subdomains
```
site:target.com
site:*.target.com
inurl:dev.target.com
inurl:staging.target.com
inurl:admin.target.com
inurl:api.target.com
```

### Find test pages and debug endpoints
```
site:target.com "test"
site:target.com "debug"
site:target.com inurl:test
site:target.com inurl:dev
intitle:"index of"
intitle:"directory listing"
```

---

## Combining Wayback + Google Dorks

### Workflow 1: Find old admin panels
```bash
# Step 1: Find admin paths with Google Dorks
# Search: site:target.com inurl:admin

# Step 2: Check Wayback for those paths
waybackurls target.com | grep admin

# Step 3: Visit archived versions
# https://web.archive.org/web/20220101000000*/target.com/admin
```

### Workflow 2: Discover all APIs
```bash
# Step 1: Google Dork for API endpoints
# Search: site:target.com/api

# Step 2: Get all versions from Wayback
waybackurls target.com | grep "/api"

# Step 3: Enumerate API versions
waybackurls target.com | grep -E "/api/v[0-9]" | sort -u
```

### Workflow 3: Find exposed configuration
```bash
# Step 1: Google Dork for config files
# Search: site:target.com (filetype:env OR filetype:conf OR filetype:config)

# Step 2: Check Wayback for historical versions
waybackurls target.com | grep -E "\.(env|conf|config|xml|yaml)$"

# Step 3: Look for old API keys, database connections
```

---

## Advanced Google Dork Combinations

### Information disclosure
```
site:target.com intext:"database" OR intext:"password" OR intext:"secret"
site:target.com "internal use only"
site:target.com "confidential"
```

### Vendor-specific dorks
```
# Confluence
site:target.com/confluence
intitle:"Confluence" site:target.com

# Jenkins
site:target.com/jenkins
intitle:"Jenkins" site:target.com

# Elasticsearch
site:target.com:9200
inurl:_search

# AWS S3
site:s3.amazonaws.com target.com
```

### Technology stack discovery
```
site:target.com intext:"Powered by"
site:target.com intext:"Built with"
site:target.com "WordPress"
site:target.com "Joomla"
```

---

## Common Patterns to Search

### Login pages
```
site:target.com (inurl:login OR inurl:signin OR inurl:auth)
intitle:"login" site:target.com
```

### Backup files
```
site:target.com (filetype:bak OR filetype:backup OR filetype:old OR filetype:orig)
site:target.com (intext:backup OR intext:"backup file")
```

### Database files
```
site:target.com (filetype:sql OR filetype:sqlite OR filetype:db)
site:target.com (intext:"database" AND filetype:sql)
```

### Source code and Git
```
site:target.com/.git
site:target.com inurl:".git/"
site:target.com filetype:php (intext:password OR intext:secret)
```

### Old documentation
```
site:target.com filetype:pdf
site:target.com/docs
site:target.com/documentation
```

---

## Tools for Automation

### waybackurls (extract all archived URLs)
```bash
go install github.com/tomnomnom/waybackurls@latest
waybackurls target.com | tee urls.txt
```

### getallurls (gau - alternative)
```bash
go install github.com/lc/gau/v2/cmd/gau@latest
gau target.com | tee urls.txt
```

### Web-based dork tools
- **SearchDiggity** — automated dork queries
- **Shodan dorks** — shodan.io with custom queries
- **Censys dorks** — censys.io for certificate data
- **Archive.is** — alternative to Wayback Machine

---

## Complete Reconnaissance Workflow

### Step 1: Wayback Machine enumeration
```bash
# Get all archived URLs
waybackurls target.com > archived_urls.txt

# Look for interesting paths
grep -E "(admin|api|backup|config)" archived_urls.txt

# Check for old endpoints
curl -s "https://web.archive.org/web/20210101000000/target.com/admin"
```

### Step 2: Google Dork information gathering
```
# Admin panels
site:target.com inurl:admin

# Exposed files
site:target.com filetype:sql

# API endpoints
site:target.com/api

# Backups
site:target.com filetype:bak
```

### Step 3: Cross-reference results
```bash
# Combine findings
comm -12 <(waybackurls target.com | sort) \
         <(cat google_dork_results.txt | sort)
```

### Step 4: Manual verification
- Visit archived versions of found endpoints
- Check for historical vulnerabilities
- Extract old credentials if visible
- Document all findings

---

## OSINT Tips

- **Check multiple Wayback snapshots** — some may have been indexed multiple times
- **Use advanced operators** — combine multiple dorks for better results
- **Search for employee names** — `site:target.com email OR linkedin OR gmail`
- **Look for CDN/third-party services** — sometimes leaks configuration
- **Check subdomains independently** — `site:api.target.com`, `site:dev.target.com`
- **Save results** — use `tee` to log all findings for later analysis

---

**See also:**
- [[Subdomain Enumeration]] — finding subdomains via other methods
- [[WHOIS]] — domain registration data
- [[Cert information]] — SSL certificate reconnaissance
- [[Collection Methods & Evidence]] — how to document findings
