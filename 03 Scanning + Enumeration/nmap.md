important flags:
**What to scan**

```diff
-sn        host discovery only, no port scan
-Pn        skip discovery, treat every host as up
-p 22,80   named ports
-p-        all 65535 ports
-sU        UDP instead of TCP
-sS        TCP SYN ("half-open") scan — the default when run as root, fast and relatively quiet
-O         Check the OS running
-sV        version detection
-sC        default scripts
-A         version, scripts, OS detection, traceroute and very loud
-T0..-T5   timing, paranoid to insane
-v..-vv    up the verbosity (-vv) is best to start
-oN file   save normal output
-oG        save to a grepable format
--script   utilize a script (lotta options here)
-sN        null scan
-sF        sends FIN flag
-sX        sends malformed TCP packet
           -sN -sF and -sX can be used to evade firewalls
```

cant use SYN scans if not sudo
if UDP ports dont respond, they will return open|filtered
if UDP port is closed - responds with ICMP 

#### NSE - nmap script engine

***stored at:***
/usr/share/nmap/scripts

***search for what you have here:***
/usr/share/nmap/scripts/script.db
eg:
grep "ftp" /usr/share/nmap/scripts/script.db

```
Categories include:

	safe -       wont affect target
	instrusive - will affact target
	vuln -       scan for vulnerabilities
	exploit -    attempt to exploit a vulnerability
	auth -       attempt to bypass authentication
	brute -      attempt to bruteforce credentials
	discovery -  attempt to get more info on services and network
	

```

**To run a specific script:**

```
--script=<script-name>
```

eg.

```
--script=http-fileupload-exploiter
```

or multiple:
```
--script=smb-enum-users,smb-enum-shares
```
to get info on what args a script may need:
```
nmap --script-help <script-name>
```

#### Firewall evasion things:

https://nmap.org/book/man-bypass-firewalls-ids.html