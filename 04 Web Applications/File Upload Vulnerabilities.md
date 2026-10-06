#webapplications

An upload endpoint accepts a file; unsafe handling can leak or execute it.

## Bypass techniques
| Bypass | Weakness | Test |
| --- | --- | --- |
| Extension allowlist | Only `jpg` allowed, but server trusts the extension | Try `shell.php.jpg`, `shell.jpg.php`, `shell.phtml`, `shell.php5` |
| MIME type check | Only `image/jpeg` allowed, browser sends it in `Content-Type` | Change `Content-Type: image/jpeg` to any value, upload a `.php` file |
| File content validation | Checks magic bytes (JPEG header) | Prepend valid JPEG bytes (`FF D8 FF E0`), append PHP code — some handlers concatenate |
| Filename validation | Rejects `shell.php`, accepts `shell.txt` | Try case-variation (`shell.PhP`), null bytes (`shell.php%00.txt`), spaces (`shell.php `) |

## Exploitation
Once uploaded, code execution depends on how the server handles the file:
| Scenario | How to trigger | Mitigation |
| --- | --- | --- |
| Uploaded to web root, direct access | `GET /uploads/shell.php` → code runs | Store uploads *outside* the web root, or serve with strict `Content-Type: application/octet-stream` |
| Uploaded to a location that gets executed (e.g. auto-include, template directory) | A separate feature triggers execution | Never store uploads where they're auto-executed; use a separate unprivileged user account |
| Included via `require`/`include` in application code | Application reads the upload as code | Avoid dynamic includes; if necessary, validate the path and use a whitelist |

## Defense
```python
import os, imghdr
uploaded = request.files["file"]

# Reject by extension alone — unsafe
if not uploaded.filename.endswith(".jpg"):
    return {"error": "Must be JPG"}, 400

# Better — validate content (magic bytes)
uploaded.seek(0)
if imghdr.what(uploaded) not in ("jpeg", "png"):
    return {"error": "Not an image"}, 400

# Store outside web root, use random name, serve safely
random_name = f"{uuid4()}.jpg"
path = os.path.join("/data/uploads", random_name)  # outside public/ directory
uploaded.save(path)
```

- **Random filename** — prevents guessing
- **Outside web root** — GET requests don't reach it directly
- **Strict MIME type header** when serving: `Content-Type: application/octet-stream; Content-Disposition: attachment`
- **Unprivileged account** running the app — limits damage if a file is somehow executed
- **Size limits** — prevent resource exhaustion
- **Scan with antivirus** — catch known malware (not a substitute for the above)

## Testing
- Upload a file with a harmless extension (`.txt`, `.jpg`) containing code (`<?php system($_GET['cmd']); ?>`)
- Try direct access (`/uploads/filename`), indirect access (if the app displays the upload), and inclusion (if the app reads the file as code)
- Bypass extension filtering with alternative extensions, null bytes, case variation
- Bypass MIME type checking by changing `Content-Type` header
- Check how the filename is stored — is it predictable, or random?
