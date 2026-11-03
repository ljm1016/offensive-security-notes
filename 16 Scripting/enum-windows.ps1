<#
  enum-windows.ps1 - READ-ONLY baseline enumeration for Windows boxes
  (AD / Server 2022, Mail / Server 2019, HMI / Server 2019)
  Changes nothing on the system. Safe for assume-breach boxes.
  Works on Windows PowerShell 5.1. Extra AD section runs automatically on a DC.

  Usage (elevated PowerShell):
    powershell -ExecutionPolicy Bypass -File .\enum-windows.ps1
  Output: C:\enum\<hostname>-<timestamp>\  plus a .zip of it
#>

$ErrorActionPreference = 'SilentlyContinue'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "[!] Run from an elevated PowerShell for complete results." -ForegroundColor Red; exit 1 }

$HostName = $env:COMPUTERNAME
$TS  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = "C:\enum\$HostName-$TS"
New-Item -ItemType Directory -Path $Out -Force | Out-Null

function Save($file, $title, [scriptblock]$cmd) {
    $path = Join-Path $Out $file
    Add-Content -Path $path -Value "### $title"
    try { & $cmd | Out-String -Width 400 | Add-Content -Path $path }
    catch { Add-Content -Path $path -Value "ERROR: $_" }
    Add-Content -Path $path -Value ""
}

$cs   = Get-CimInstance Win32_ComputerSystem
$os   = Get-CimInstance Win32_OperatingSystem
$isDC = ($cs.DomainRole -ge 4)

Write-Host "[*] Enumerating $HostName -> $Out  (Domain Controller: $isDC)"

# ---------- 01 system ----------
Save 01_system.txt 'OS' { $os | Select-Object Caption, Version, BuildNumber, LastBootUpTime, InstallDate }
Save 01_system.txt 'Computer' { $cs | Select-Object Name, Domain, DomainRole, NumberOfLogicalProcessors, @{n='RAM_GB';e={[math]::Round($_.TotalPhysicalMemory/1GB,1)}} }
Save 01_system.txt 'Free RAM (GB)' { [math]::Round($os.FreePhysicalMemory/1MB,1) }
Save 01_system.txt 'Disks' { Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, @{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}}, @{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,1)}} }
Save 01_system.txt 'Hotfixes' { Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object HotFixID, Description, InstalledOn }
Save 01_system.txt 'Installed roles/features' { Get-WindowsFeature | Where-Object Installed | Select-Object Name, DisplayName }

# ---------- 02 network ----------
Save 02_network.txt 'IP config' { Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer }
Save 02_network.txt 'Routes' { Get-NetRoute -AddressFamily IPv4 | Select-Object DestinationPrefix, NextHop, InterfaceAlias }
Save 02_network.txt 'hosts file' { Get-Content C:\Windows\System32\drivers\etc\hosts }

$procs = @{}; Get-Process | ForEach-Object { $procs[$_.Id] = $_ }
Save 03_ports.txt 'TCP listening' { Get-NetTCPConnection -State Listen | Sort-Object LocalPort | Select-Object LocalAddress, LocalPort, OwningProcess, @{n='Process';e={$procs[[int]$_.OwningProcess].ProcessName}}, @{n='Path';e={$procs[[int]$_.OwningProcess].Path}} }
Save 03_ports.txt 'UDP endpoints' { Get-NetUDPEndpoint | Sort-Object LocalPort | Select-Object LocalAddress, LocalPort, OwningProcess, @{n='Process';e={$procs[[int]$_.OwningProcess].ProcessName}} }
Save 03_ports.txt 'TCP established' { Get-NetTCPConnection -State Established | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, @{n='Process';e={$procs[[int]$_.OwningProcess].ProcessName}} }

# ---------- 04 users ----------
if ($isDC) {
    Import-Module ActiveDirectory
    Save 04_users.txt 'AD users' { Get-ADUser -Filter * -Properties Enabled, LastLogonDate, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, AdminCount, Description | Select-Object SamAccountName, Enabled, LastLogonDate, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, AdminCount, Description | Sort-Object SamAccountName }
    foreach ($g in 'Domain Admins','Enterprise Admins','Schema Admins','Administrators','Account Operators','Backup Operators','Server Operators','DnsAdmins','Group Policy Creator Owners','Remote Desktop Users') {
        Save 04_users.txt "Group: $g (recursive)" { Get-ADGroupMember -Identity $g -Recursive | Select-Object SamAccountName, objectClass }
    }
    Save 04_users.txt 'Kerberoastable (user accounts with SPNs)' { Get-ADUser -Filter {ServicePrincipalName -like '*'} -Properties ServicePrincipalName | Select-Object SamAccountName, ServicePrincipalName }
    Save 04_users.txt 'AS-REP roastable (no preauth)' { Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} | Select-Object SamAccountName }
    Save 04_users.txt 'Password not required' { Get-ADUser -Filter {PasswordNotRequired -eq $true} | Select-Object SamAccountName, Enabled }
    Save 04_users.txt 'Unconstrained delegation (non-DC computers)' { Get-ADComputer -Filter {TrustedForDelegation -eq $true -and PrimaryGroupID -ne 516} | Select-Object Name }
    Save 04_users.txt 'Computers' { Get-ADComputer -Filter * -Properties OperatingSystem, LastLogonDate, IPv4Address | Select-Object Name, OperatingSystem, IPv4Address, LastLogonDate }
    Save 04_users.txt 'Domain password policy' { Get-ADDefaultDomainPasswordPolicy }
    Save 04_users.txt 'Fine-grained password policies' { Get-ADFineGrainedPasswordPolicy -Filter * }
    Save 04_users.txt 'GPOs' { Get-GPO -All | Select-Object DisplayName, GpoStatus, ModificationTime | Sort-Object ModificationTime -Descending }
    Save 04_users.txt 'Trusts' { Get-ADTrust -Filter * }
} else {
    Save 04_users.txt 'Local users' { Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordLastSet, PasswordRequired, PasswordExpires, Description }
    Save 04_users.txt 'Local Administrators' { Get-LocalGroupMember -Group 'Administrators' | Select-Object Name, ObjectClass, PrincipalSource }
    Save 04_users.txt 'Remote Desktop Users' { Get-LocalGroupMember -Group 'Remote Desktop Users' | Select-Object Name, ObjectClass }
    Save 04_users.txt 'Local password policy' { net accounts }
}
Save 04_users.txt 'Currently logged on' { quser 2>&1 }

# ---------- 05 services / processes ----------
Save 05_services.txt 'Running or auto-start services' { Get-CimInstance Win32_Service | Where-Object { $_.State -eq 'Running' -or $_.StartMode -eq 'Auto' } | Select-Object Name, DisplayName, State, StartMode, StartName, PathName | Sort-Object Name }
Save 05_services.txt 'Services NOT under C:\Windows (review these)' { Get-CimInstance Win32_Service | Where-Object { $_.PathName -and $_.PathName -notmatch '(?i)C:\\Windows\\' } | Select-Object Name, State, StartMode, StartName, PathName }
Save 06_processes.txt 'Processes' { Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine | Sort-Object Name }

# ---------- 07 persistence ----------
Save 07_persistence.txt 'Scheduled tasks outside \Microsoft\' { Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } | ForEach-Object { [pscustomobject]@{ Path=$_.TaskPath+$_.TaskName; State=$_.State; RunAs=$_.Principal.UserId; Action=(($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' ; ') } } }
foreach ($k in 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce') {
    Save 07_persistence.txt "Registry $k" { Get-ItemProperty -Path $k | Select-Object * -ExcludeProperty PS* }
}
Save 07_persistence.txt 'Winlogon Shell/Userinit' { Get-ItemProperty 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' | Select-Object Shell, Userinit }
Save 07_persistence.txt 'Image File Execution Options debuggers' { Get-ChildItem 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' | ForEach-Object { $d = (Get-ItemProperty $_.PSPath).Debugger; if ($d) { "$($_.PSChildName) -> $d" } } }
Save 07_persistence.txt 'Startup folders' { Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp', 'C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup' -Force }
Save 07_persistence.txt 'WMI event subscriptions' { Get-CimInstance -Namespace root\subscription -ClassName __EventFilter; Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer; Get-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding }

# ---------- 08 security config ----------
Save 08_security.txt 'Firewall profiles' { Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, LogAllowed, LogBlocked }
Save 08_security.txt 'Enabled inbound allow rules' { Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow | Select-Object DisplayName, Profile | Sort-Object DisplayName }
Save 08_security.txt 'Defender status' { Get-MpComputerStatus | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled, IsTamperProtected, AntivirusSignatureLastUpdated }
Save 08_security.txt 'Defender exclusions' { Get-MpPreference | Select-Object ExclusionPath, ExclusionProcess, ExclusionExtension }
Save 08_security.txt 'SMB server config' { Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, RequireSecuritySignature, EnableSecuritySignature }
Save 08_security.txt 'SMB shares' { Get-SmbShare | Select-Object Name, Path, Description }
Save 08_security.txt 'RDP enabled (0 = enabled) / NLA' { Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections; Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication }
Save 08_security.txt 'LSA protection / WDigest' { Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Lsa' | Select-Object RunAsPPL, LmCompatibilityLevel, NoLMHash; Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\WDigest' | Select-Object UseLogonCredential }
Save 08_security.txt 'PowerShell logging policy' { Get-ItemProperty 'HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'; Get-ItemProperty 'HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging' }
Save 08_security.txt 'Audit policy' { auditpol /get /category:* }
Save 08_security.txt 'Sysmon installed?' { Get-Service Sysmon*, Sysmon64 }
Save 08_security.txt 'SNMP communities (AD box scores SNMP)' { Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities' | Select-Object * -ExcludeProperty PS* }

# ---------- 09 software ----------
Save 09_software.txt 'Installed software' { Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object DisplayName | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName }

# ---------- summary ----------
$sum = Join-Path $Out '00_SUMMARY.txt'
@(
  "Host: $HostName    Collected: $TS    Domain Controller: $isDC"
  "OS:   $($os.Caption) ($($os.Version))"
  "RAM:  $([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB total, $([math]::Round($os.FreePhysicalMemory/1MB,1)) GB free    CPUs: $($cs.NumberOfLogicalProcessors)"
  ""
  "== Listening TCP ports =="
) | Set-Content $sum
Get-NetTCPConnection -State Listen | Sort-Object LocalPort -Unique | ForEach-Object { "{0,-6} {1}" -f $_.LocalPort, $procs[[int]$_.OwningProcess].ProcessName } | Add-Content $sum
Add-Content $sum "`n== Admins =="
if ($isDC) { Get-ADGroupMember 'Domain Admins' -Recursive | ForEach-Object { "Domain Admins: $($_.SamAccountName)" } | Add-Content $sum }
else { Get-LocalGroupMember Administrators | ForEach-Object { "Local Admin: $($_.Name)" } | Add-Content $sum }
Add-Content $sum "`n== Non-Microsoft scheduled tasks =="
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } | ForEach-Object { "$($_.TaskPath)$($_.TaskName)  [$($_.State)]" } | Add-Content $sum
Add-Content $sum "`n== Firewall =="
Get-NetFirewallProfile | ForEach-Object { "$($_.Name): Enabled=$($_.Enabled)" } | Add-Content $sum
Add-Content $sum "`nSMBv1 enabled: $((Get-SmbServerConfiguration).EnableSMB1Protocol)"

Compress-Archive -Path $Out -DestinationPath "$Out.zip" -Force
Write-Host "[+] Done. Read $Out\00_SUMMARY.txt first." -ForegroundColor Green
Write-Host "[+] Archive: $Out.zip" -ForegroundColor Green
