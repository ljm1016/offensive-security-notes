#tools #active-directory

General-purpose Windows/AD enumeration over SMB, LDAP and RPC. First thing to run against a box showing 139/445/389 — it fingerprints the domain, OS, users, groups, shares and policies from a single command. `enum4linux-ng` (the rewrite, `-ng`) is the modern version and what's usually on the box; it supports JSON/YAML output and is more reliable.

## Quick start
```bash
enum4linux -A <ip>                 # do everything, null session
enum4linux -A -u <user> -p <pass> <ip>   # everything, authenticated
```
`-A` is the one you'll run most. Authenticated (`-u`/`-p`) almost always returns more — re-run it the moment you get any credential.

## Flag reference
| Flag | Does |
| --- | --- |
| `-A` | All simple enumeration (-U -S -G -P -o -n -i, etc.) |
| `-U` | User list |
| `-S` | Share list |
| `-G` | Group + member list |
| `-P` | Password policy (lockout threshold — read before spraying) |
| `-o` | OS information |
| `-n` | nmblookup / NetBIOS name info |
| `-i` | Printer info |
| `-r` | **RID cycling** — enumerate users even when direct listing is denied |
| `-R <range>` | RID range for cycling (e.g. `500-550,1000-1050`) |
| `-u <user>` / `-p <pass>` | Authenticate instead of null session |
| `-w <workgroup>` | Set workgroup/domain manually |
| `-M` | Machine enumeration |
| `-d` | Verbose/detailed output |

`enum4linux-ng` extras: `-oJ <file>` / `-oY <file>` write JSON/YAML; `-C` enumerate via LDAP; `-A -c` adds more checks.

## RID cycling — when user listing is denied
If `-U` returns `STATUS_ACCESS_DENIED` but a null session is allowed, RID cycling can still recover names by walking the SID + RID space (every account is `DomainSID-RID`; Administrator is always RID 500):
```bash
enum4linux -r -R 500-1100 <ip>
# or with creds:
lookupsid.py <domain>/<user>:<pass>@<ip>   # Impacket equivalent, cleaner
```

## What you're reading in the output
- **Listener scan** — which of LDAP/LDAPS/SMB/NetBIOS are reachable.
- **Domain info via LDAP** — the **DNS domain** (e.g. `spookysec.local`) and whether it's a root/parent DC. Kerberos tools need this name.
- **Domain info via SMB** — NetBIOS computer name + **NetBIOS domain name** (e.g. `THM-AD`). Don't confuse it with the DNS name.
- **RPC session check** — whether a **null session** (`''`/`''`) is allowed.
- **Domain SID** — needed for RID cycling / SID history attacks.
- **Password policy** — lockout threshold decides whether spraying is safe.

## When RPC enum is denied
Normal on modern DCs. Pivot to [[Kerbrute]] for usernames (no RPC), or `lookupsid.py` / `rpcclient` for RID cycling.

## Alternatives / siblings
- `crackmapexec smb <ip> -u <user> -p <pass> --users --groups --shares --pass-pol` — faster, one tool for all of it, works across a subnet.
- `rpcclient -U '' -N <ip>` then `enumdomusers`, `queryuser 0x<rid>`, `lsaenumsid`.
- `ldapsearch -x -H ldap://<ip> -b "dc=domain,dc=local"` — raw LDAP when anonymous bind is allowed.

Part of the AD workflow in [[Active Directory Exploitation]].
