#linux #privesc

Linux **capabilities** split root's power into units that can be granted to a single binary — a middle ground between "normal" and SUID-root. A binary with the right capability can do one privileged thing without being fully SUID. Misassigned caps = privesc. The challenge phrasing to recognize: *"a copy of X carries one slice of root"* = a capability on a binary.

## Detection
```bash
getcap -r / 2>/dev/null          # list file capabilities everywhere
getcap /path/to/binary           # check one binary directly
```
> [!warning] `getcap -r /` can lie in containers
> On overlayfs (common in container/CTF boxes), the recursive scan may silently miss caps. If a binary looks suspicious — a private interpreter copy in `/opt`, e.g. `/opt/pypriv/python3` — **check it directly** with `getcap <file>` rather than trusting an empty `getcap -r /`.

## Caps worth finding (and the idea)
The suffix `+ep` / `=ep` = Effective + Permitted (the cap is actually active).

- **`cap_setuid+ep`** — binary can call `setuid(0)`. An interpreter with this = instant root. Python:
  ```bash
  /opt/pypriv/python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'
  # or read a file directly, since you ARE root after setuid(0):
  /opt/pypriv/python3 -c 'import os; os.setuid(0); print(open("/root/flag.txt").read())'
  ```
  `setuid(0)` sets the **real** uid to 0 — you're fully root, no `-p` needed. `setuid(N)` → become a *specific* user.
- **`cap_dac_read_search+ep`** — bypass file *read* permission checks → read any file (`/etc/shadow`, a `0400` flag) **without** becoming its owner.
- **`cap_dac_override`** — bypass read/write/execute checks.
- **`cap_setcap`** — grant caps to other files → bootstrap further.

## Match the cap to the goal
- Target = **root** → you want `cap_setuid` (gives uid 0).
- Target = read one protected file, box says "not root" → a reader cap (`cap_dac_read_search`) fits, or the setuid interpreter is a decoy.
- GTFOBins lists per-binary "Capabilities" techniques.

---
## Case study — CYBR401 Lab 8 (c10 → root)
`getcap -r /` reported:
```
/opt/pypriv/python3 = cap_setuid+ep
```
A root-owned **copy** of python3 with `cap_setuid`. Target was root, so:
```bash
/opt/pypriv/python3 -c 'import os; os.setuid(0); print(open("/root/flag.txt").read())'
```
One misconfiguration: `cap_setuid` on an interpreter.

**The box-1 connection:** `/opt/pypriv/python3` existed on box 1 too, but `getcap -r /` came back empty there and `getcap /opt/pypriv/python3` also showed nothing — it was a **decoy** (overlayfs can also just mean no cap was set). On c10 the cap was real and the scan surfaced it. Lesson both ways: a lone interpreter copy in `/opt` is a cap flag to check *directly*, and an empty `getcap -r /` doesn't prove innocence.

**Takeaways logged:** lone interpreter in `/opt` → `getcap` it directly. `cap_setuid` → `setuid(0)` → root (real uid, no `-p`). `cap_dac_read_search` → read protected files without being root. Match cap to the stated target.

---
Related: [[11.4 SUID + GTFO Bins]] · [[11.1 Where to start]] (Phase 3) · [[11.5 Hunting Leaked Credentials]] (reading protected files)
