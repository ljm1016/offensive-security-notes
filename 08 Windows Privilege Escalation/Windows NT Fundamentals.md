#windows #privilege-escalation #fundamentals

Windows NT security model divides execution into kernel mode and user-mode processes. Understanding the architecture is essential for identifying privilege escalation vectors.

---

## Architecture Overview

### Kernel vs User Mode
**Kernel Mode:**
- Full hardware access
- Ring 0 (highest privilege)
- Handles protected operations
- Drivers execute here

**User Mode:**
- Restricted hardware access
- Ring 3 (lowest privilege)
- Standard applications
- Cannot directly access hardware

### System Calls
Applications request protected operations through system calls:
```powershell
# User-mode application requests kernel operation
# OS validates permission via access token
# Kernel performs operation if allowed
```

---

## Key Processes

### System (PID 4)
```powershell
tasklist | findstr System
# Output: System 4 Services

# System hosts:
# - Kernel worker threads
# - Driver execution context
# - Cannot be killed
```

### LSASS (Local Security Authority Subsystem)
```powershell
tasklist | findstr lsass
# Output: lsass.exe 728 Services

# LSASS handles:
# - User authentication
# - Password verification
# - Credential storage (encrypted)
# - Token generation
```

### svchost.exe
Hosts Windows services:
```powershell
tasklist /svc
# Shows which services run in each svchost instance
```

---

## Security Identifiers (SIDs)

### SID Structure
```
S-1-5-21-1234567890-1234567890-1234567890-1001
│ │ │  │  Domain/Machine ID                  │ RID
│ │ │  └─ Authority (5 = NT Authority)
│ │ └──── version (1 = revision 1)
└────Revision Level (always S)
```

### SID Components
**Prefix:** Identifies machine or domain that issued the SID
```powershell
whoami /user
# S-1-5-21-XXXXX-XXXXX-XXXXX-RID
#        └─ Domain/Machine identifier
```

**Relative ID (RID):** Account within the domain
```
500 = Administrator
501 = Guest
1001+ = Regular accounts
```

### Well-Known SIDs
```powershell
S-1-5-18 = LocalSystem (highest privilege local account)
S-1-5-19 = LocalService (network service account)
S-1-5-20 = NetworkService (network operations)
S-1-5-32-544 = BUILTIN\Administrators (local admin group)
S-1-5-32-545 = BUILTIN\Users (standard users)
S-1-1-0 = Everyone
```

### Verifying SIDs
```powershell
whoami /user
# Shows: User SID

whoami /groups
# Shows: All SIDs user is member of (including groups)

Get-LocalUser | Select-Object Name, SID
# Lists all local accounts and SIDs
```

---

## Access Tokens

### Token Contents
Every process has an access token containing:
```
- User SID
- Group SIDs (all groups user is member of)
- Privileges (capabilities)
- Integrity Level
- Default DACL (permissions)
```

### Viewing Token Contents
```powershell
whoami /user
# Shows user SID

whoami /groups
# Shows all group SIDs

whoami /priv
# Shows all privileges and their state (Enabled/Disabled)

whoami /groups | findstr /i "admin label"
# Shows admin status and integrity level
```

### Privilege States
```powershell
# Enabled = Currently active in token
# Disabled = Held but not active

# Example: SeShutdownPrivilege might be held but disabled
# Process can enable privileges it already holds
```

---

## Integrity Levels

### The Four Levels
```
System (4096)    ← Kernel drivers, LocalSystem
High (3072)      ← Elevated admin processes  
Medium (2048)    ← Standard admin/user processes
Low (1024)       ← Restricted/sandbox contexts
```

### Integrity Enforcement
Default policy: Process cannot write to objects at higher integrity
```powershell
# Medium integrity process (user account)
whoami /groups | findstr "Mandatory"
# Output: Mandatory Label\Medium Mandatory Level S-1-16-8192

# Cannot write to High integrity files/registry
# Cannot interact with system services
```

### Elevation via UAC
```powershell
# Before elevation
whoami /groups | findstr "admin label"
# Shows: Administrators (Group used for deny only)
#        Medium Mandatory Level

# User clicks "Yes" on UAC prompt

# After elevation
whoami /groups | findstr "admin label"
# Shows: Administrators (Mandatory group, Enabled)
#        High Mandatory Level
```

---

## Privileges

### Common Privileges
```powershell
SeImpersonatePrivilege   - Run code as another user
SeAssignPrimaryToken     - Create new token with arbitrary permissions
SeChangeNotifyPrivilege  - Detect file/registry changes
SeShutdownPrivilege      - Shutdown system
SeDebugPrivilege         - Debug any process
SeLoadDriverPrivilege    - Load kernel drivers
SeBackupPrivilege        - Backup files (bypass permissions)
SeRestorePrivilege       - Restore files (bypass permissions)
SeTakeOwnershipPrivilege - Take ownership of objects
```

### Privilege Escalation via Privileges
Some privileges enable direct escalation:
```powershell
# SeImpersonate + SeAssignPrimary
# = Can create process as SYSTEM

# SeLoadDriver
# = Can load malicious kernel driver (SYSTEM code execution)

# SeDebugPrivilege
# = Can inject into admin processes
```

### Checking Privilege State
```powershell
whoami /priv | findstr "Enabled"
# Lists currently enabled privileges

whoami /priv | findstr "Disabled"
# Lists held but disabled privileges
```

---

## User Accounts

### Local vs Domain Accounts
```powershell
# Local account
whoami
# Output: MACHINE\username
# Verified against machine's SAM database

# Domain account
whoami
# Output: DOMAIN\username
# Verified against domain controller
```

### Enumerating Accounts
```powershell
net user
# Lists all local accounts

net user administrator
# Shows properties of specific account

Get-LocalUser | Select-Object Name, Enabled, SID
# PowerShell enumeration with SIDs

net localgroup administrators
# Shows admin group membership (includes domain groups)
```

### Key Attributes
```powershell
# Account enabled/disabled status
# Password never expires flag
# Last logon date
# Account creation date
# Description/comments
# Group memberships (direct + nested)
```

---

## Group Memberships

### Direct vs Nested
```powershell
# Direct membership
Get-ADGroupMember -Identity "IT Staff"
# User is direct member of IT Staff

# Nested membership
Get-ADGroupMember -Identity "IT Staff"
# IT Staff is member of "Domain Users"
# User gets both groups' permissions
```

### Local Admin Groups
```powershell
net localgroup administrators
# Output shows:
# - Local accounts (machine\user)
# - Domain groups (domain\groupname)

# Adding domain group = all domain group members are local admins
```

---

## Privilege Escalation Patterns

### Hijack the Check
Obtain credentials or hashes:
```
- SAM hive (local account hashes)
- SECURITY hive (service passwords)
- LSASS memory (active credentials)
- Credential Manager (saved creds)
- NTDS.dit (domain account hashes)
```

### Hijack the Execution
Replace privileged process binary:
```
- Unquoted service path (place Program.exe)
- Writable service executable
- Registry ImagePath modification
- Startup folder hijacking
```

### Hijack the Kernel
Exploit driver vulnerability:
```
- Kernel-mode drivers run in Ring 0
- Vulnerability = full system compromise
- POC must be compiled for target OS/architecture
```

---

## Detection & Evasion

### What Gets Logged
- `whoami` execution (command line auditing)
- Token queries (detailed audit logging)
- Privilege elevation (UAC events)
- Group membership queries
- Process access to privileged processes

### Evasion Techniques
- Run enumeration at off-hours
- Use legitimate admin tools (avoid suspicious binaries)
- Batch queries (one complex query vs many simple ones)
- Avoid accessing high-privilege groups early
- Use `-Server` parameter to appear intentional

---

## Related Guides
- [[Windows Privilege Escalation]] — complete privilege escalation techniques
- [[SUID + GTFO Bins]] — similar patterns on Linux
- [[Service Misconfiguration]] — services as escalation vector
- [[UAC Bypass]] — circumventing elevation prompts
