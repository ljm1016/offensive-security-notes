#enumeration #active-directory

Runas is a legitimate Windows binary that injects AD credentials into memory for network authentication. Essential when you have valid AD credentials but no domain-joined machine or RDP access.

---

## Runas Basics

### What Runas does
- Injects AD credentials into memory for network authentication
- Executes commands/applications with injected credentials
- `/netonly` flag ensures only network connections use injected creds (local commands run as current user)
- Password is NOT verified (accepted even if wrong) when using `/netonly`

### When to use Runas
- You have AD credentials but no domain-joined machine
- You have a Windows machine but can't RDP to domain controllers
- You want to test credentials before full compromise
- You need to run tools requiring AD authentication

---

## Basic Runas Command

### Syntax
```powershell
runas.exe /netonly /user:<domain>\<username> <program.exe>
```

### Parameters
- `/netonly` — Load credentials for network auth only (not domain controller verification)
- `/user:<domain>\<username>` — AD credentials in FQDN format
- `<program>` — Application to execute (cmd.exe, powershell.exe, etc.)

### Example
```powershell
runas.exe /netonly /user:za.tryhackme.com\gordon.stevens cmd.exe
# Prompts for password (any input accepted with /netonly)
# New CMD window opens with injected credentials
```

---

## Testing Injected Credentials

### Verify with SYSVOL access
```powershell
# Any AD user can read SYSVOL
# If this works, credentials are valid

dir \\<domain>\SYSVOL\
dir \\za.tryhackme.com\SYSVOL\

# Output shows domain folder structure if successful
# Access denied if credentials are invalid
```

### Using hostname vs IP
**Hostname:** Triggers Kerberos authentication
```powershell
dir \\domain.com\SYSVOL\
# Uses Kerberos (ticket-based)
```

**IP address:** Forces NTLM authentication
```powershell
dir \\10.10.10.1\SYSVOL\
# Uses NTLM (challenge-response)
```

**Impact:** Hostnames are noisier (Kerberos tickets logged), IPs may be stealthier but still detectable.

---

## DNS Configuration (if needed)

If internal DNS isn't automatically configured:

```powershell
# Set DNS to domain controller IP
$dnsip = "10.10.10.1"
$index = Get-NetAdapter -Name 'Ethernet' | Select-Object -ExpandProperty 'ifIndex'
Set-DnsClientServerAddress -InterfaceIndex $index -ServerAddresses $dnsip

# Verify DNS works
nslookup domain.com
# Should resolve to DC IP
```

---

## Using Injected Credentials with Tools

### Command Prompt
```powershell
# From Runas CMD window, all network activity uses injected creds
net user /domain
net group /domain
net group "Domain Admins" /domain
```

### PowerShell
```powershell
# From Runas PowerShell window, AD cmdlets use injected creds
Get-ADUser -Identity username -Server domain.com
Get-ADGroup -Server domain.com
Get-ADGroupMember -Identity "Domain Admins" -Server domain.com
```

### Database tools
```powershell
# SQL Server with Windows Authentication
# From Runas CMD, SQL Server tools will use injected AD creds
sqlcmd -S server.domain.com -W
# Authenticates as injected user automatically
```

### SMB shares
```powershell
# Access domain file shares
net use \\fileserver.domain.com\share
# Uses injected credentials for authentication
```

---

## Important Notes

### Local vs Network authentication
- **Local commands:** Run as your original Windows user
- **Network connections:** Use injected AD credentials

**Example:**
```powershell
# From Runas window
whoami
# Shows: MACHINE\localuser (local context)

dir \\domain.com\share
# Uses injected: domain\aduser (network context)
```

### Password doesn't matter with /netonly
```powershell
# /netonly doesn't verify password against DC
# Any password input accepted
runas.exe /netonly /user:domain\user cmd.exe
# Password prompt accepts anything
```

### Without /netonly (requires domain-joined or DC access)
```powershell
# Password IS verified against DC
runas.exe /user:domain\user cmd.exe
# Password must be correct or fails
```

---

## Common Errors & Fixes

### "Access Denied" on SYSVOL
```
Error: Access Denied
Cause: Credentials invalid or user lacks SYSVOL read permissions
Fix: Verify password, check user exists, test with different user
```

### DNS resolution fails
```
Error: The specified domain either does not exist or could not be contacted
Cause: DNS not configured to DC
Fix: Set DNS to DC IP manually (see DNS Configuration section)
```

### Kerberos authentication failures
```
Error: You do not have permission to access the network location
Cause: Kerberos ticket validation failed
Fix: Use IP instead of hostname to force NTLM
     Verify DNS is pointing to DC
```

---

## Detection & Evasion

### What gets logged
- Process creation (runas.exe execution)
- Network authentication attempts (NTLM/Kerberos)
- File access (SYSVOL, shares)
- Domain controller logon attempts

### Evasion techniques
- Run from non-obvious directory
- Use legitimate tools (net, dir, powershell) to minimize suspicious binary execution
- Test credentials during off-hours
- Use hostnames instead of IPs (looks more legitimate)
- Don't immediately access highly sensitive shares
- Avoid Domain Admin accounts for testing

---

## Workflow: Credential Testing

### Step 1: Gain Windows machine access
```
- Phishing (initial access)
- Pivot from compromised server
- Physical access
```

### Step 2: Obtain valid AD credentials
```
- Discovered during recon (docs, emails)
- Captured from previous compromise
- Found in configs/databases
```

### Step 3: Use Runas to inject
```powershell
runas.exe /netonly /user:domain.com\username cmd.exe
# Enter password (real or dummy with /netonly)
```

### Step 4: Verify credentials work
```powershell
# From Runas CMD window
dir \\domain.com\SYSVOL\

# If successful, credentials are valid
```

### Step 5: Enumerate with valid creds
```powershell
# Use PowerShell or Command Prompt to enumerate AD
Get-ADUser -Filter * -Server domain.com
Get-ADGroup -Server domain.com
```

### Step 6: Plan next steps
```
- Identify high-value targets
- Check group memberships
- Find privilege escalation paths
- Plan lateral movement
```

---

## Tools that integrate with Runas

### Built-in Windows tools
- `net` commands (user enumeration, group info)
- PowerShell AD cmdlets (Get-ADUser, Get-ADGroup, etc.)
- `dir` (SMB share access)
- `nslookup` (DNS queries)
- `tasklist`, `taskkill` (process management on remote hosts)

### Third-party tools
- Bloodhound/Sharphound (AD enumeration)
- Mimikatz (credential dumping)
- PsExec (remote execution)
- Evil-WinRM (RDP-like access)

---

## Benefits

- Works on non-domain-joined machines
- Uses legitimate Windows binary (hard to detect)
- Password not verified with `/netonly` (can test even if password wrong)
- Allows testing credentials before full compromise
- All network tools automatically use injected credentials

---

## Drawbacks

- Requires Windows machine with GUI
- Process creation (runas.exe) can be monitored
- Network authentication will be logged on DC
- Limited to what local user permissions allow
- Requires knowing valid AD credentials first

---

**See also:**
- [[PowerShell AD Enumeration]] — AD cmdlet-based enumeration
- [[Bloodhound Analysis]] — graph-based AD attack path discovery
- [[NTLM Password Spraying]] — finding valid AD credentials
- [[Web Login Brute Force]] — credential discovery techniques
