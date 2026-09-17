
Metasploit's enumeration side — Auxiliary modules gather information or verify a weakness without delivering a payload. See [[Metasploit]] in Tools Index for the module-type overview and basics that apply everywhere.

## Auxiliary modules
```
search type:auxiliary name:smb
use auxiliary/scanner/smb/smb_version
set RHOSTS 10.10.10.0/24
run
```
No payload delivered — safe to run broadly across a range as a first pass, same spirit as [[nmap]]'s `-sV`.

## Verify without exploiting
```
use exploit/windows/smb/ms17_010_eternalblue
check
```
`check` asks the target if it looks vulnerable without actually firing the exploit — confirms a lead from [[nmap]] or [[Subdomain Enumeration]] without risking a crash, before you move to [[Metasploit Exploitation]].

## Database integration
Metasploit keeps enumeration data in a local database instead of scattered terminal output — worth using once you have more than a couple hosts:
```
db_status
db_nmap -sV 10.10.10.5          # run nmap through msf, results land in the db automatically
hosts
services
creds
```
Cross-reference this against what [[nmap]] and [[Subdomain Enumeration]] already found rather than re-scanning from scratch.
