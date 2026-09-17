#tools-index #metasploit

Metasploit spans three phases, not one — its own module types map directly onto them. This page is the overview and the parts common to all three; the actual per-phase usage lives where that phase's other notes live.

| Type | Purpose | Used in |
| --- | --- | --- |
| Auxiliary | Deep-dive enumeration, scanning, sniffing — no payload delivered | [[Metasploit Enumeration]] |
| Exploit | Delivers a payload to a vulnerable service | [[Metasploit Exploitation]] |
| Post | Runs after you already have access — info gathering, pivoting | [[Metasploit Post-Exploitation]] |

## Why use it at all
- **Verification** — `check` can often confirm a service is exploitable without actually crashing it
- **Efficiency** — automates brute-forcing across multiple targets/services
- **Database** — saves all enumeration data (IPs, services, creds) so you're not re-typing target info between modules

## Basics that apply everywhere
```
search type:exploit name:<software>
use <module path>
show options
set RHOSTS <target>
run
```
