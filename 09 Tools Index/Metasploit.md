#tools-index #metasploit

Metasploit spans three phases, not one — its own module types map directly onto them. This page is the overview and the parts common to all three; the actual per-phase usage lives where that phase's other notes live.

| Type | Purpose | Used in |
| --- | --- | --- |
| Auxiliary | Deep-dive enumeration, scanning, sniffing — no payload delivered | [[Metasploit Enumeration]] |
| Exploit | Delivers a payload to a vulnerable service | [[Metasploit Exploitation]] |
| Post | Runs after you already have access — info gathering, pivoting | [[Metasploit Post-Exploitation]] |

## Why use it at all
- **Verification** — `check` can often confirm a service is exploitable without actually crashing it
- **Efficiency** — automates brute-forcing across multiple targets/services
- **Database** — saves all enumeration data (IPs, services, creds) so you're not re-typing target info between modules

## Basics that apply everywhere

### Starting msfconsole
```
msfconsole          # start
msfconsole -q       # start quiet (skip banner)
```

### Find and load modules
```
search <keyword>              # find modules (e.g., search eternalblue)
search type:exploit name:<sw> # filter by type and name
use <number>                  # load by search result number
use <module/path>             # load by full path
info                          # show module details, options, targets
show options                  # list required vs optional variables
```

### Configure before running
```
set RHOSTS <ip>         # target IP (or CIDR range, comma list)
set RPORT <port>        # target port
set LHOST <ip>          # your IP (for reverse shells)
set LPORT <port>        # your listening port
unset VAR               # clear a value
```

### Execute
```
check                   # test if vulnerable (not all modules support it)
exploit                 # fire the module
exploit -j              # run as background job
run                     # alias for exploit (used in some modules)
```

### Session management
```
sessions -l             # list all active sessions
sessions -i <id>        # interact with session (connect to shell)
background              # (or Ctrl+Z) park session back to msfconsole
sessions -k <id>        # kill a session
```

### Meterpreter essentials (once you have a session)
```
sysinfo               # host and user context
getuid                # current user
shell                 # drop to target shell; exit to return to meterpreter
migrate <PID>         # jump into a different process (stability)
hashdump              # dump SAM hashes (Windows, needs SYSTEM privilege)
download <file>       # pull file from target
upload <file>         # push file to target
search -f <pattern>   # find files on target by pattern
```

### Database and scanning
```
db_status             # check if database is connected (should be green)
db_nmap -sV <ip>      # run nmap and store results in msf database
hosts                 # list all hosts in the database
services              # list all services discovered by db_nmap
```
