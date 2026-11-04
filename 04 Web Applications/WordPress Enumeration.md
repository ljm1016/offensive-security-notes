#webapplications

WordPress is one of the most widely deployed CMS platforms. Enumeration reveals the installed version, active plugins/themes, users, and potential vulnerabilities.

---

## Quick Identification

### Check if WordPress is installed
```bash
# Look for WordPress-specific paths
curl -s http://target.com/wp-admin/ | grep -i wordpress

# Check common WordPress files
curl -I http://target.com/wp-login.php
# HTTP 200 = WordPress installed

# Look for wp-content directory
curl -I http://target.com/wp-content/
```

### WordPress installation paths
```
/wp-admin/          — admin panel
/wp-login.php       — login page
/wp-content/        — plugins, themes, uploads
/wp-includes/       — core WordPress files
/wp-json/           — REST API endpoint
/xmlrpc.php         — XML-RPC endpoint
```

---

## Version Detection

### From HTML source
```bash
curl -s http://target.com | grep -i "wp-content" | grep "ver="
# Look for: src="/wp-content/themes/theme/style.css?ver=6.4.1"
# Version: 6.4.1
```

### From meta tags
```bash
curl -s http://target.com | grep "generator"
# Look for: <meta name="generator" content="WordPress 6.4.1">
```

### From RSS feed
```bash
curl -s http://target.com/feed/ | grep -i "wordpress"
# Check the XML feed for version info
```

### From wp-includes directory listing
```bash
curl -I http://target.com/wp-includes/
# Some servers expose directory listing
```

### Check readme.html
```bash
curl -s http://target.com/readme.html | grep -i version
# Older WordPress versions had version in readme.html
```

---

## Plugin Enumeration

### Via wp-content/plugins directory
```bash
# Enumerate plugins (many servers expose directory listing)
curl -s http://target.com/wp-content/plugins/ | grep -oP 'href="[^"]+' | cut -d'"' -f2 | grep -v "^?"

# Visit specific plugin to confirm
curl -I http://target.com/wp-content/plugins/plugin-name/
# HTTP 200 = plugin exists
```

### Plugin detection via JavaScript
```bash
# Plugins often load JS files
curl -s http://target.com | grep -oP '(wp-content/plugins/[^/"]+)' | sort -u

# Example output:
# wp-content/plugins/akismet/
# wp-content/plugins/wordfence/
# wp-content/plugins/yoast-seo/
```

### Check plugin readme.txt
```bash
# Many plugins have a readme.txt file that reveals version
curl -s http://target.com/wp-content/plugins/plugin-name/readme.txt | grep "Stable tag"
# Output: Stable tag: 1.2.3
```

### Common plugin paths
```
/wp-content/plugins/plugin-name/
/wp-content/plugins/plugin-name/readme.txt
/wp-content/plugins/plugin-name/plugin-name.php
/wp-content/plugins/plugin-name/changelog.txt
```

### Vulnerable plugins list
Common targets:
- **Wordfence** — Security plugin (sometimes misconfigured)
- **Yoast SEO** — Commonly installed
- **Akismet** — Anti-spam plugin
- **WooCommerce** — E-commerce (if applicable)
- **Elementor** — Page builder (vulnerabilities known)
- **Contact Form 7** — Form plugin (RCE vulnerabilities in old versions)

---

## Theme Enumeration

### Via wp-content/themes directory
```bash
curl -s http://target.com/wp-content/themes/ | grep -oP 'href="[^"]+' | grep -v "^?"

# Visit theme directory
curl -I http://target.com/wp-content/themes/theme-name/
# HTTP 200 = theme exists
```

### Theme version detection
```bash
# Check theme style.css for version
curl -s http://target.com/wp-content/themes/theme-name/style.css | grep -i "version"
# Output: Version: 1.2.3

# Check theme functions.php (sometimes exposed)
curl -s http://target.com/wp-content/themes/theme-name/functions.php
```

### Common theme paths
```
/wp-content/themes/theme-name/
/wp-content/themes/theme-name/style.css
/wp-content/themes/theme-name/readme.txt
/wp-content/themes/theme-name/functions.php
```

---

## User Enumeration

### Via author posts
```bash
# WordPress exposes authors in post URLs
curl -s http://target.com | grep -oP '(?<=/author/)[^/"]+' | sort -u

# Visit author pages directly
curl -I http://target.com/author/admin/
# HTTP 200 = user exists
```

### Via REST API
```bash
# WordPress REST API exposes user data
curl -s http://target.com/wp-json/wp/v2/users/ | jq '.[] | {id, name, slug}'

# Output:
# {"id": 1, "name": "Admin", "slug": "admin"}
# {"id": 2, "name": "Editor", "slug": "editor"}
```

### Via JSON feed
```bash
curl -s http://target.com/wp-json/wp/v2/users?per_page=100 | grep -oP '"slug":"[^"]+' | cut -d'"' -f4
```

### Via wp-json endpoint
```bash
# List all public users
curl -s http://target.com/wp-json/wp/v2/users | jq '.[] | .name'

# Get user details
curl -s http://target.com/wp-json/wp/v2/users/1 | jq .
```

### Via archive pages
```bash
# Some WordPress instances list author names
curl -s http://target.com/blog/ | grep -oP '(?<=By )[\w\s]+' | sort -u
```

### Disable REST API user enumeration
**Note:** Some sites restrict REST API user enumeration with plugins, but checking is still worth attempting.

---

## Tool: WPScan

### Installation
```bash
# Install from RubyGems
gem install wpscan

# Or use apt (on Debian/Kali)
sudo apt install wpscan
```

### Basic scan
```bash
wpscan --url http://target.com
```

**Output includes:**
- WordPress version
- Installed plugins (with vulnerabilities)
- Installed themes (with vulnerabilities)
- Users enumerated from REST API
- Known vulnerabilities from WPVulnDB

### Enumerate plugins only
```bash
wpscan --url http://target.com --enumerate p
# p = plugins
# t = themes
# u = users
# all = all of the above
```

### Aggressive enumeration
```bash
wpscan --url http://target.com --enumerate ap,at,u
# ap = all plugins
# at = all themes
# u = users
# This takes longer but finds more
```

### Check for specific vulnerabilities
```bash
wpscan --url http://target.com --plugins-detection aggressive --plugins-version-detection aggressive
```

### Output to file
```bash
wpscan --url http://target.com --format json -o wordpress_scan.json
wpscan --url http://target.com --format cli -o wordpress_scan.txt
```

---

## Configuration File Enumeration

### wp-config.php (usually not accessible)
```bash
curl -s http://target.com/wp-config.php
# Usually returns 404 or 403 (not exposed)

# But try variants
curl -I http://target.com/wp-config.php.bak
curl -I http://target.com/wp-config.php.old
curl -I http://target.com/wp-config.backup
```

### .htaccess exposure
```bash
curl -s http://target.com/.htaccess
# May reveal rewrite rules and structure
```

### Database backup files
```bash
curl -I http://target.com/wp-content/db.sql
curl -I http://target.com/wp-content/backup.sql
curl -I http://target.com/backup.zip
```

### XML-RPC endpoint
```bash
curl -s http://target.com/xmlrpc.php | head -5
# Check if XML-RPC is enabled (can be used for attacks)
```

---

## Automated Enumeration Workflow

### Complete reconnaissance script
```bash
#!/bin/bash
target=$1

echo "[*] WordPress Enumeration for $target"

# 1. Check WordPress installation
echo "[*] Checking WordPress installation..."
curl -I "$target/wp-login.php" | grep -q "200" && echo "[+] WordPress found"

# 2. Get version
echo "[*] Getting WordPress version..."
curl -s "$target" | grep "generator" | grep -oP '(?<=WordPress )[0-9.]+'

# 3. Enumerate plugins
echo "[*] Enumerating plugins..."
curl -s "$target/wp-content/plugins/" | grep -oP 'href="[^"]+' | cut -d'"' -f2 | grep -v "^?"

# 4. Enumerate themes
echo "[*] Enumerating themes..."
curl -s "$target/wp-content/themes/" | grep -oP 'href="[^"]+' | cut -d'"' -f2 | grep -v "^?"

# 5. Enumerate users
echo "[*] Enumerating users..."
curl -s "$target/wp-json/wp/v2/users" | jq '.[] | {id, name, slug}'

echo "[*] Done!"
```

### Using WPScan (comprehensive)
```bash
wpscan --url http://target.com --enumerate ap,at,u --format json -o wp_enum.json
```

---

## Common Vulnerabilities Found

### Plugin vulnerabilities
- **RCE in older versions** — Unpatched plugins with remote code execution
- **SQL Injection** — Database access via plugin filters
- **LFI/Path Traversal** — File inclusion vulnerabilities in plugins
- **Privilege Escalation** — Plugins allowing unauthorized admin access
- **Authentication Bypass** — Login bypass in authentication plugins

### Theme vulnerabilities
- **Backdoors** — Malicious code in theme functions.php
- **Insecure file upload** — Theme allowing arbitrary file uploads
- **Cross-Site Scripting** — XSS in theme templates

### Core WordPress vulnerabilities
- **Unauthenticated password reset** — CVE-2019-17566 (older versions)
- **XML-RPC brute force** — /xmlrpc.php allows password brute forcing
- **REST API information disclosure** — User enumeration via /wp-json/

---

## Complete Enumeration Checklist

```
□ Identify WordPress installation
□ Determine WordPress version
□ Enumerate active plugins
  □ Check plugin versions
  □ Identify vulnerable plugins
□ Enumerate active themes
  □ Check theme version
□ Enumerate users via REST API
□ Check XML-RPC enabled
□ Look for exposed config files
□ Search for database backups
□ Check for common misconfigurations
  □ Weak admin credentials
  □ Exposed debug.log
  □ Directory listing enabled
□ Use WPScan for comprehensive scan
□ Document all findings
```

---

## Tools needed

- **curl/wget** — manual enumeration
- **WPScan** — comprehensive WordPress scanning
- **jq** — JSON parsing for REST API results
- **grep/sed** — text filtering
- **Browser** — manual verification

---

**See also:**
- [[Web Login Brute Force]] — brute forcing WordPress admin panel
- [[Broken Access Control]] — IDOR and authorization issues
- [[HTTP Requests]] — understanding HTTP requests
- [[wpscan]] — WPScan command reference
