#tools-index/recon

(needs a paid api key)

Shodan indexes the banners returned by internet-connected devices/services — search engine for infrastructure, not content.

## Setup
```bash
pip install -U shodan
shodan init YOUR_API_KEY
shodan info      # check query/scan credits
shodan myip      # your current public IP
```

## Dorks
| Filter | Description | Example |
| --- | --- | --- |
| `org` | Company name | `org:"Target Corp"` |
| `net` | CIDR range | `net:192.168.1.0/24` |
| `product` | Specific software | `product:"Apache httpd"` |
| `os` | Operating system | `os:"Windows 7"` |
| `port` | Devices with a port open | `port:3389` |
| `vuln` | Devices flagged for a CVE | `vuln:CVE-2014-0160` |
| `has_screenshot` | Devices with a captured screenshot | `has_screenshot:true` |

## Host analysis
Check Shodan's history before running a loud Nmap scan and tripping an IDS:
```bash
shodan host 1.2.3.4
```

## Finding "shadow IT"
Search by SSL cert issued to the target, to find servers not on their known IP range:
```bash
shodan search ssl:"TargetName"
```

## Honeypot check
```bash
shodan honeyscore 1.2.3.4   # 0.0 = real, 1.0 = honeypot
```

## Bulk download + parse
```bash
shodan download target_data "org:'Target Corp' port:443"
shodan parse --fields ip_str,port target_data.json.gz > targets.txt
```

## Useful queries
- Open databases: `product:elastic port:9200`, `product:mongodb`
- Unprotected ICS: `port:502` (Modbus), `port:44818` (EtherNet/IP)
- Expired certs: `ssl.cert.expired:true org:"TargetName"`
- Webcams/IoT: `device:webcam`, `has_screenshot:true`
