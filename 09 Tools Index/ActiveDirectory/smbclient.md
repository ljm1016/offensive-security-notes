#tools #active-directory

FTP-like client for SMB shares. Two jobs in an AD attack: **list** what shares exist, and **connect** to read/write files. Run it twice in a kill chain — once anonymously early on, and again *authenticated* the moment you crack a credential.

## List shares
```bash
smbclient -L //<ip>/ -N                    # anonymous / null session
smbclient -L //<ip>/ -U <user>             # authenticated (prompts for pass)
smbclient -L //<ip>/ -U 'DOMAIN\user%pass' # inline creds, no prompt
```
`-L` list, `-N` no password, `-U` username. Authenticated listing almost always reveals more.

## Connect to a share
```bash
smbclient //<ip>/<share> -U <user>
smbclient //<ip>/<share> -U <user> -c 'ls'   # run one command, non-interactive
```

## Auth & connection flags
| Flag | Does |
| --- | --- |
| `-U 'DOMAIN\user%pass'` | Full inline credential (`%` separates pass) |
| `-N` | No password (null session) |
| `--pw-nt-hash` | Treat the `-U ...%HASH` value as an NT hash → **pass-the-hash** |
| `-p <port>` | Non-standard port |
| `-m SMB2` / `-m SMB3` | Force a dialect (fixes some connection errors) |
| `-c '<cmds>'` | Run `;`-separated commands then exit (scriptable) |
| `-k` | Use Kerberos ticket auth |
| `-t <sec>` | Timeout |

## Inside the `smb: \>` prompt
```
ls / dir            # list
cd <dir>            # navigate
get <file>          # download
put <file>          # upload (if writable)
prompt off          # disable per-file confirm
recurse on          # recurse into subdirs
mget *              # download everything (with recurse+prompt off)
mput *              # upload everything
mask ""             # clear filename mask before recursive mget
! <shellcmd>        # run a local shell command
```

## Loot pattern
The payload is often a readable share holding a **base64-encoded** credentials file. Pull it with `get`, then decode:
```bash
echo '<base64 string>' | base64 -d
```
That decoded `user:pass` is frequently the privileged account (e.g. `backup`) enabling [[Impacket]] DCSync.

## Faster alternatives
- `smbmap -H <ip> -u <user> -p <pass>` — shows **READ/WRITE access level per share** at a glance; `-R <share>` recursively lists; `-x '<cmd>'` runs commands.
- `crackmapexec smb <ip> -u <user> -p <pass> --shares` — access levels across a whole subnet; add `--spider` to crawl.
- `smbget -R smb://<ip>/<share>` — recursive download in one shot.
- Non-interactive grab: `smbclient //<ip>/<share> -U <user> -c 'recurse on; prompt off; mget *'`.

Part of the AD workflow in [[Active Directory Exploitation]].
