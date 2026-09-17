#tools-index/web 

#### **FFUF** (short for "Fuzz Faster U Fool") is an incredibly fast, open-source command-line tool written in Go for web application fuzzing, content discovery, and security testing.

What it does:
1. Finds hidden folders or backups on web servers like `/admin`, `/login.php`, or `/backup.zip`) by brute-forcing names from a wordlist. [[1](https://hackviser.com/tactics/tools/ffuf)]
2. Tests GET and POST parameters or JSON bodies to discover hidden API endpoints, entry points, or mass-assignment vulnerabilities
3. Discovers hidden subdomains or virtual hosts on the same server IP address even when public DNS records do not list them
4. Uses advanced filters and matchers to hide unhelpful responses (like 404 Not Found errors or standard page sizes) so you only see valid or interesting HTTP responses 


Syntax:
```
ffuf -w /usr/share/wordlists/dirb/common.txt -u https://275eaef97462a45d2eb56843fadf9f21.ctf.hacker101.com/ -H "Host: FUZZ.target.url"
```

Simple example:
```
ffuf -w /path/to/wordlist.txt -u https://example.com/FUZZ
```