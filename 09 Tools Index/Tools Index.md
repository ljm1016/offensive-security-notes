#tools-index

A directory, not a duplicate. Command-syntax cards live in this folder (Web, C2); broader technique/methodology notes live in their phase folder. Every entry links to wherever the real content actually is.

Recon & OSINT → [[01 Getting Started]]:
- [[Dorking]]
- [[WHOIS]]
- [[Cert information]] — crt.sh, gungnir
- [[Subdomain Enumeration]] — subfinder, amass, puredns, dnsgen, github-subdomains, gau
- [[ASN]]
- [[DNS Recon]]
- [[Censys]]
- [[Shodan]]
- [[Recon-ng]]
- [[Wayback Machine & Google Dorks]] — Internet Archive snapshots, advanced search operators
- [[Spidering]] — BuiltWith, [[gospider]], [[Hakrawler]]
- [[Organization Research]]
- [[People OSINT]] — hunter.io, Gather Contacts, sherlock, maigret, Dehashed, HIBP
- [[Images, Documents & Geolocation]] — exiftool, TinEye, Google Lens, Yandex
- [[Collection Methods & Evidence]] — how to record any of the above
- [[SpiderFoot]]

Scanning + Enumeration → [[03 Scanning + Enumeration]]:
- [[nmap]]
- [[netcat]]
- [[SMB + SNMP Enum]] — enum4linux, smbclient, snmpwalk
- [[SSH Brute Force & Attacks]] — Hydra, sshpass, Paramiko, key attacks, config exploits
- [[Metasploit Enumeration|Metasploit]] — Auxiliary modules, `check`, database integration

Exploitation → [[05 Exploitation]]:
- [[File Transfer]] — HTTP/SMB/FTP servers, payload delivery, target-side download methods
- [[Metasploit Exploitation|Metasploit]] — Exploit modules, msfvenom
- [[Active Directory Exploitation]]

Active Directory (command-syntax and tool cards, live in this folder):
- [[Enum4Linux]] — SMB/LDAP/RPC enumeration, domain/OS/user/share fingerprint
- [[Kerbrute]] — Kerberos username enumeration + password spraying (unauthenticated)
- [[smbclient]] — list and read SMB shares, anonymous then authenticated
- [[Impacket]] — GetNPUsers (AS-REP roast) + secretsdump (DCSync / NTDS)
- [[Hashcat]] — offline hash cracking; AS-REP 18200, Kerberoast 13100, NTLM 1000
- [[evil-winrm]] — WinRM shell, password or pass-the-hash

Post Exploitation → [[Post-Exploitation Basics]] (06 Post Exploitation):
- [[Privilege Escalation]]
- [[Persistence]]
- [[Credential Dumping]]
- [[Pivoting]]
- [[Cleanup & Reporting]]
- [[Metasploit Post-Exploitation|Metasploit]] — Post modules, sessions, autoroute

Metasploit overview (module types, why/when, basics common to all three phases): [[Metasploit]]

Web Application Security → [[1. Where to even start]] (04 Web Applications):
- [[HTTP Requests]] — methods, status codes, URL anatomy, Burp Repeater/Caido Replay, curl
- [[Front End, Back End & State]] — client/server split, cookies/sessions, OWASP Top 10:2025 map, defense recap
- [[Broken Access Control]] — IDOR, hidden-endpoint/method bypass, cookie tampering (A01)
- [[Web Login Brute Force]] — Hydra, ffuf, Burp Intruder, rate limiting evasion
- [[Basic Authentication Brute Force]] — Base64 encoding, curl, Hydra, ffuf, rate limiting bypass
- [[Session & Cookie Security]] — fixation, hijacking, cookie flags (A07)
- [[MFA & Password Reset]] (A07)
- [[JWT]] — tampering, validation, revocation (A07)
- [[SSO & OAuth]] — OIDC authorization code flow, PKCE, account linking (A07)
- [[Cross-Site Scripting]] — reflected, stored, DOM-based, CSS injection, CSP
- [[CSRF]]
- [[CORS]]
- [[Clickjacking]]
- [[SQL Injection]] — UNION, blind, prepared statements (A05)
- [[NoSQL Injection]] (A05)
- [[Command Injection]] (A05)
- [[Server Side Template Injection]] (A05)
- [[SSRF]]
- [[Remote File Inclusion]] (A05)
- [[XXE Injection]] (A05)
- [[Deserialization]] (A08)
- [[Request Smuggling]]
- [[HTTP Parameter Pollution]]
- [[WAF Bypasses]] — encoding/obfuscation techniques (Levels 1-7)
- [[LFI Exploitation Chains]] — upload/log/session poisoning + LFI
- [[Headers]]

Web (command-syntax and tool cards, live in this folder):
- [[httpx]]
- [[gospider]]
- [[Hakrawler]]
- [[eyewitness|EyeWitness]]
- [[dig]]
- [[gobuster]]
- [[ffuf]]
- [[Nuclei]]
- [[Wappalyzer]] — tech stack fingerprinting
- [[wpscan]] — WordPress-specific scanning
- [[Wordlists]] — dictionaries for fuzzing
- [[sqlmap]] — automated SQL injection detection and exploitation
- [[Burp Suite]] — interactive proxy, request tampering, systematic testing

C2:
- [[Armitage]]
- [[Better Silver (unfinished)]]
