#webapplications

OWASP A05 (Injection) — input reaches a file path operation and an attacker reads files the server has access to, or writes/executes code.

## Path traversal basics
```
Normal:  GET /files?name=courses.txt   → read /app/files/courses.txt
Changed: GET /files?name=../../etc/passwd   → read /etc/passwd (outside intended directory)
```
The `../` sequences climb out of the allowed directory. On Windows, `..\..\` and UNC paths (`\\server\share`) work the same way — an input meant to select a filename can instead select *any* file the application process can reach.

## Fix — constrain the path
```python
base = "/app/files"
requested = request.args.get("file")
path = os.path.normpath(os.path.join(base, requested))
if not path.startswith(base):
    return {"error": "Access denied"}, 403
with open(path) as f:
    return f.read()
```
Join the base directory with the input, then normalize to collapse `..` sequences. Check that the result still starts with the base — if it doesn't, the traversal escaped the boundary and should be rejected.

**Alternative fix**: map the input to an allowlist of known files, never interpolate a filename directly:
```python
files = {"courses": "courses.txt", "schedule": "schedule.txt"}
filename = files.get(request.args.get("file"))
if filename is None:
    return {"error": "File not found"}, 404
```

## NULL bytes (older systems)
```
Input: courses.txt%00.jpg   → courses.txt (on PHP 5.3 and earlier, %00 terminates the string)
```
Modern systems and languages reject NULL bytes in paths outright. On old PHP/Apache, this was a bypass for extension checks — the `.jpg` was supposed to prove safety, but the NULL byte cut it off.

## Testing
- Anywhere a filename/path is requested: try `../`, `..\\` (Windows), absolute paths (`/etc/passwd`, `C:\Windows\System32`), and URL-encoded variants (`%2e%2e%2f`)
- Read-access targets: `passwd`, `.env`, `.git/config`, source files, database backups
- Write-access targets: uploaded files, temp directories, anything that reaches code execution (see [[File Upload Vulnerabilities]])

## Escalation chains
Once LFI is confirmed, chain it with other vulnerabilities for code execution:
- **[[LFI Exploitation Chains]]** — upload + LFI, log poisoning + LFI, session poisoning + LFI
- **[[Remote File Inclusion]]** — include PHP from an attacker-controlled server
