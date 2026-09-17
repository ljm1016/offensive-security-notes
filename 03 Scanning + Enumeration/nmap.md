important flags:
**What to scan**

```diff
-sn        host discovery only, no port scan
-Pn        skip discovery, treat every host as up
-p 22,80   named ports
-p-        all 65535 ports
-sU        UDP instead of TCP
-sS        TCP SYN ("half-open") scan — the default when run as root, fast and relatively quiet
```

**How, and how loudly**

```diff
-sV        version detection
-sC        default scripts
-A         version, scripts, OS detection, traceroute
-T0..-T5   timing, paranoid to insane
-oN file   save normal output
```
