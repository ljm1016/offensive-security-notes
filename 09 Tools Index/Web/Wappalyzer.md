#tools #web

Browser extension and standalone CLI: identifies the tech stack running a web app — CMS, framework, language, web server, libraries.

## Browser extension
Install from the browser store, visit any website, click the Wappalyzer icon — a sidebar shows detected technologies and version numbers. **Version info is gold** — once you know it's WordPress 5.8.1 or Apache 2.4.41, search for CVEs targeting that exact version (searchsploit, Google) before trying anything manual.

## CLI
```bash
# npm install -g wappalyzer
wappalyzer https://target.com
```

## What it finds
- CMS (WordPress, Joomla, Drupal)
- Frameworks (Django, Flask, Laravel, Spring)
- Languages (PHP, Python, Java, C#)
- Web servers (Apache, Nginx, IIS)
- JavaScript libraries (jQuery, React, Vue)
- Analytics, CDNs, security tools

## Notes
- Detection is heuristic (CSS classes, HTML comments, X-Powered-By headers, JS library signatures) — not always 100% accurate, but fast and requires no interaction
- A missing detection doesn't mean the tech isn't there; a false positive is possible but rare
- Version numbers are often uncertain (shown with a `?`) — verify with manual probing if the version matters for CVE selection

## In the workflow
[[Where to even start]] Phase 1 — after you've opened the page in a browser and viewed the source, Wappalyzer gives you the stack, then you search for known CVEs before Phase 2 recon starts.
