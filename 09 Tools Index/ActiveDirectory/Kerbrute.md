#tools #active-directory

A fast Kerberos pre-authentication tool for **username enumeration** and **password spraying** against a DC. Its superpower: username enumeration is effectively unauthenticated and quiet — it never generates a failed-logon (Event 4625), only odd-looking TGT requests. Reach for it when [[Enum4Linux]] RPC enum returns `STATUS_ACCESS_DENIED`.

## Why it works
The KDC responds differently to a preauth request for a **valid** username vs a **nonexistent** one. Kerbrute reads that difference — no password needed.

## The four modes
| Mode | Purpose | Shape |
| --- | --- | --- |
| `userenum` | Validate which usernames exist | many users, no password |
| `passwordspray` | One password vs many users | many users, 1 password |
| `bruteuser` | Many passwords vs one user | 1 user, many passwords |
| `bruteforce` | Arbitrary user:pass combos from stdin/file | `user:pass` lines |

```bash
kerbrute userenum      --dc <ip> -d <domain> userlist.txt
kerbrute passwordspray --dc <ip> -d <domain> users.txt 'Season2026!'
kerbrute bruteuser     --dc <ip> -d <domain> passwords.txt administrator
cat combos.txt | kerbrute bruteforce --dc <ip> -d <domain> -
```

## Global flags (apply to every mode)
| Flag | Does |
| --- | --- |
| `--dc <ip>` | **Target DC.** Required — without it you get `Couldn't find any KDCs for realm` |
| `-d <domain>` | **DNS domain** (`spookysec.local`), not the NetBIOS name (`THM-AD`) |
| `-o <file>` | Write results to a log file |
| `-t <n>` | Threads (default 10) — raise to go faster, lower to be gentle |
| `--delay <ms>` | Delay between requests (evade rate detection) |
| `--safe` | **Abort on first account lockout** — use before spraying to avoid locking the domain |
| `-v` | Verbose (show invalid attempts too) |
| `--downgrade` | Use weaker RC4 enc type |
| `--dc-timeout <s>` | Timeout per request |

## Spraying safely
Read the lockout policy first (`enum4linux -P` / `crackmapexec smb <ip> --pass-pol`). Then one password per round, with `--safe`, and wait out the observation window between rounds. Spraying beats brute-forcing a single account because it stays under the per-account lockout counter.

## Casing note
AD is case-insensitive on names, so the same account validates in every casing present in your wordlist. Dedupe to bare lowercase before feeding [[Impacket]] `GetNPUsers.py`.

## Alternatives
- `crackmapexec smb <ip> -u users.txt -p 'Password1' --continue-on-success` — spray over SMB (noisier, generates 4625s).
- `kerbrute` is preferred for stealth; CME is preferred when you also want share/session info.

## Next step
Feed validated users into [[Impacket]] `GetNPUsers.py` to AS-REP roast. Part of [[Active Directory Exploitation]].
