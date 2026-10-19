#tools #active-directory #password-cracking

GPU-accelerated offline password cracker. General-purpose, but filed here because the AD chain produces hashes you'll crack constantly: AS-REP (18200), Kerberoast (13100), NTLM (1000), NetNTLMv2 (5600). Offline = no lockouts, no logs, no touching the target.

## Two things decide success: the mode and the attack
`hashcat -m <mode> -a <attack> <hashfile> <wordlist/mask> [options]`

### -m — hash mode (from the hash's prefix)
Wrong `-m` is the #1 cause of "No hashes loaded."
| Hash prefix / source | Type | `-m` |
| --- | --- | --- |
| `$krb5asrep$23$` | AS-REP roast | **18200** |
| `$krb5tgs$23$` | Kerberoast / TGS, RC4 | **13100** |
| `$krb5tgs$18$` | Kerberoast, AES256 | 19700 |
| NT hash from NTDS/secretsdump | NTLM | 1000 |
| LM hash | LM | 3000 |
| `...::...:...:...` capture | NetNTLMv1 | 5500 |
| NetNTLMv2 (Responder/relay) | NetNTLMv2 | 5600 |
| `$6$` | sha512crypt (Linux shadow) | 1800 |
| `$5$` | sha256crypt | 7400 |
| `$2a$/$2y$/$2b$` | bcrypt | 3200 |
| `$1$` | md5crypt | 500 |
| raw MD5 / SHA1 / SHA256 | unsalted | 0 / 100 / 1400 |
| `$krb5pa$...` | Kerberos preauth (etype 23) | 7500 |
Don't know it? `hashcat --identify hashes.txt` suggests modes. `hashcat --example-hashes | less` shows a sample for every mode.

### -a — attack mode
| `-a` | Attack | Use |
| --- | --- | --- |
| 0 | **Straight** (dictionary, optional rules) | default; wordlist + `-r` |
| 1 | Combinator | join two wordlists |
| 3 | **Mask / brute force** | known pattern/length |
| 6 | Hybrid wordlist + mask | `word?d?d?d` |
| 7 | Hybrid mask + wordlist | `?d?d?dword` |

## Dictionary attack (-a 0)
```bash
hashcat -m 18200 hashes.txt rockyou.txt --force
hashcat -m 18200 hashes.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule --force
```
`-r` mutates each word (capitalize, leetspeak, append digits) — turns a small list huge. Stack rules by repeating `-r`. Good rule files: `best64`, `rockyou-30000`, `OneRuleToRuleThemAll`.

## Mask / brute force (-a 3)
Charsets: `?l` a–z · `?u` A–Z · `?d` 0–9 · `?s` symbols · `?a` all · `?b` raw bytes.
```bash
hashcat -m 1000 hash.txt -a 3 '?u?l?l?l?l?d?d'      # Abcde12 pattern
hashcat -m 1000 hash.txt -a 3 '?a?a?a?a?a?a' -i     # all 1–6 char combos (incremental)
hashcat -m 1000 hash.txt -a 3 -1 '?l?d' '?1?1?1?1?1?1'  # custom charset ?1 = lower+digits
```
`-i` / `--increment` grows the mask length; `--increment-min/--increment-max` bound it.

## Key options
| Option | Does |
| --- | --- |
| `--show` | Reprint already-cracked hashes from the potfile |
| `--username` | Hash file has `user:hash` lines — strip the username |
| `-o <file>` | Write cracked results to a file |
| `--potfile-path <f>` | Use/point at a specific potfile |
| `--force` | Ignore no-GPU warning (needed on VMs/AttackBox) |
| `-O` | Optimized kernels — much faster, caps password length (~32) |
| `-w 1..4` | Workload profile (4 = max, desktop lag) |
| `--session <name>` | Name the session for resuming |
| `--restore` | Resume an interrupted `--session` |
| `-b` | Benchmark |
| `--status --status-timer 10` | Periodic progress readout |
| `--remove` | Remove cracked hashes from the input file |

## `--show` gotcha
`--show` only displays hashes **already** in the potfile. Running it before you actually crack returns nothing (not an error). Crack first, `--show` after. Cleartext is appended after the final `:`.

## Status readout
- `Status: Cracked` + `Recovered: 1/1` → done, go to `--show`.
- `Status: Exhausted` → not in the list; bigger wordlist, add rules, or switch to mask.

## John the Ripper equivalent
```bash
john --wordlist=rockyou.txt --format=krb5asrep hashes.txt
john --show hashes.txt
```
John auto-detects format and is handy for odd hash types; hashcat is faster on GPU. For AD, convert with the right `*2john` helper if needed.

Feeds the cracked credential back into [[smbclient]] / [[evil-winrm]] in [[Active Directory Exploitation]].
