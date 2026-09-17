#tools-index/web 

#### Gobuster is an open-source command-line tool written in Go, widely used in cybersecurity for brute-forcing and enumerating hidden directories, files, and subdomains on web servers. 


Example:
```
gobuster dir -u http://target:port/ -w /usr/share/seclists/Discovery/Web-Content/common.txt -x php,html,txt,js
```