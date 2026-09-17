
| Record | Tells you |
| --- | --- |
| NS | Who operates the zone — e.g. `ns1.p68.dns.oraclecloud.net.` → Oracle Cloud |
| MX | The published mail provider — e.g. `sru-edu.mail.protection.outlook.com.` → Microsoft 365 |
| SOA | RNAME names a technical contact (personal details are usually redacted/omitted) |

These support vendor-relationship findings — an MX record alone doesn't show where *every* mailbox actually lives, just the published gateway.

## Public vs internal
A resolver answers DNS queries using its cache or other DNS servers. An **internal** resolver can return names that were never published publicly — so a public lookup returning nothing doesn't mean the host doesn't exist.

**A missing DNS answer does not prove a host is absent.** Check whether the result was `NXDOMAIN`, no record of the requested type, or an error — those mean different things.

## TTL and who actually answers
TTL (time-to-live) limits caching. A cached answer avoids a new request to the authoritative server; a fresh/uncached lookup contacts it directly. A small number of lookups is usually unremarkable; a large number can be detected — this is why DNS resolution counts as [[Collection Methods & Evidence|low interaction]], not fully passive.

## Address format
One published email address suggests a naming format:
```
format: first.last@sru.edu
```
Don't apply that format elsewhere as fact until more published examples confirm it — see [[People OSINT]].
