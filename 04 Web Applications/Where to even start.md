#webapplications #methodology

Sequential checklist for a fresh web app target — you've got a URL/IP and nothing else. Same idea as [[11.1 Where to even start]]: work top to bottom, click through to the note with the actual detail, and fill in the red/unresolved links once you've learned that technique on a box.

## Run these first (off rip)
```bash
curl -i http://target/                                  # headers, server banner, redirects
whatweb http://target/                                  # tech stack fingerprint
gobuster dir -u http://target/ -w /usr/share/seclists/Discovery/Web-Content/common.txt -x php,html,txt,js
nikto -h http://target/                                 # quick known-vuln/misconfig sweep
```
Kick these off in parallel (separate terminals/tabs) — they're slow and you can read the page manually while they run.

## Phase 0 — Look at it like a person first
- [ ] Open it in a browser, click around, note every page and every input (forms, search boxes, upload buttons)
- [ ] View source (`Ctrl+U`) — comments, hidden fields, JS files worth pulling separately
- [ ] Check `robots.txt` and `sitemap.xml` — disallowed paths are often the interesting ones
- [ ] Check cookies set (dev tools → Application/Storage) — session tokens, anything that looks decodable (JWT?)
- [ ] `curl -i` the root and a couple pages → server header, `X-Powered-By`, anything forgeable → [[Headers]]
- [ ] Check and replace unfiltered tags/elements to see if you can get alerts: <img src=x onerror=alert(document.domain)>

## Phase 1 — Fingerprint the stack
- [ ] `whatweb` / [[Wappalyzer]] — CMS, framework, language, web server + version
- [ ] Once you know the stack, go looking for known CVEs against that exact version (searchsploit, Google) before you do anything manual
- [ ] If it's WordPress specifically → [[wpscan]]

## Phase 2 — Map what's actually there
- [ ] Directory/file brute force → [[gobuster]] or [[ffuf]] (dirbuster is outdated, use gobuster — see [[dirbuster]])
- [ ] Vhost/subdomain fuzzing if you only have an IP or a base domain → [[ffuf]]'s `Host: FUZZ` trick
- [ ] DNS enumeration if it's a real domain, not just an IP → [[dig]]
- [ ] Grab a bigger/better wordlist if common.txt comes up empty → [[Wordlists]]

## Phase 3 — Catalog every input before you test anything
- [ ] Every form field, query param, header, cookie, and JSON body key → [[HTTP Requests]]
- [ ] Get a proxy in the middle so you can intercept/replay/tamper → [[Burp Suite]]
- [ ] Replay/forge requests from the command line → [[Headers]]

## Phase 4 — Cheap wins before deep testing
- [ ] Default or guessable creds on any login form found so far
- [ ] Hit admin/backup/debug paths turned up by the brute force directly (`/admin`, `/backup.zip`, `/.git`, `/.env`)
- [ ] `/.git` present? → dump it and read history for secrets
- [ ] JS files — search them for hardcoded API keys, hidden endpoints, comments

## Phase 5 — Input testing sweep
Go input by input from Phase 3, try each of these:
- [ ] [[Server Side Template Injection]] — already documented, test template-looking fields first
- [ ] [[SQL Injection]] — manual probe (`'`, `"`, `1=1`), then sqlmap once you have a live candidate
- [ ] [[Cross-Site Scripting]] — reflected/stored, anywhere input gets echoed back
- [ ] [[Local File Inclusion]] / path traversal — any param that looks like a filename or path
- [ ] [[Command Injection]] — any param that might reach a shell call
- [ ] [[IDOR]] — any param that looks like an ID/reference to something else's data
- [ ] [[File Upload Vulnerabilities]] — if there's an upload feature at all

## Phase 6 — Escalate to shell
- [ ] Once something gives code execution or arbitrary file write, get a listener up → [[netcat]]
- [ ] From there you're on the box — pick up at [[11.1 Where to even start]] Phase 0

## Phase 7 — Log it
- [ ] Note which technique actually got you in, under [[10 CTFs + Labs]] or here — same reasoning as the Linux checklist, this list gets sharper the more boxes you run it against

---
Related reference:
- [[Ports]] — what's likely running alongside the web port (80/443 rarely stands alone)
- [[Tools Index]] — tool-specific notes
