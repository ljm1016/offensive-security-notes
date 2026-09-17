#scripting

Quick syntax reference, not pentest-specific.

**Read / print**
```powershell
$var = Read-Host
Write-Host $var
```

**Arithmetic**
```powershell
$count = $count + 1   # or $count++
$count += 3
$count *= 7
```

**Variables**
```powershell
$count = 1
$portlist = 20, 21, 25, 80, 143, 443
$ip = "192.168.1.1"
```

**If/elseif/else**
```powershell
$count = 53
if ($count -lt 0) {
    Write-Host "$count is less than 0"
} elseif ($count -gt 0) {
    Write-Host "$count is greater than 0"
} else {
    Write-Host "$count is 0"
}
```

**While loop**
```powershell
$count = 0
while ($count -lt 5) {
    Write-Host $count
    $count += 1
}
```

**For loop**
```powershell
$portlist = 20, 21, 25, 80, 143, 443
foreach ($portNum in $portlist) {
    Write-Host "Port Number: $portNum"
}
```
