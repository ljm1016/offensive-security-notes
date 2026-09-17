
## SMB (445)
```bash
enum4linux -a <target>              # users, shares, groups, OS info, password policy — good first pass
smbclient -L //<target>/ -N         # list shares anonymously (-N = no password)
smbclient //<target>/<share> -N     # connect to a specific share
```

## SNMP (161)
Only worth trying if the port's open — SNMP is UDP and often skipped in a default TCP-only scan.
```bash
snmpwalk -c public -v1 <target>     # 'public' is the default read-only community string, try it first
```
A misconfigured SNMP service with the default community string can leak an enormous amount — running processes, installed software, sometimes even routing tables.
