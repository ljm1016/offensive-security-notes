#tools-index/web

#### `httpx` is a fast HTTP toolkit for probing a list of hosts and reporting what's actually alive, on Go.

Syntax:
```
httpx -l hosts.txt -title -status-code -tech-detect
```

Turns a long hostname list (from [[Subdomain Enumeration]]) into what's actually running — status code, page title, and detected tech per host — before spending time fuzzing directories on any of them.
