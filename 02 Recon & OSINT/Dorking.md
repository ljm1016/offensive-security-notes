
A dork combines keywords with search operators. Start from an ordinary information need and narrow it:
```
Slippery Rock annual report
site:sru.edu annual report
site:sru.edu filetype:pdf annual report
site:sru.edu filetype:pdf "annual report"
```

| Operator | Purpose |
| --- | --- |
| `site:sru.edu` | Restrict to a domain |
| `filetype:pdf` | Restrict to a file format |
| `"annual report"` | Match an exact phrase |
| `-athletics` | Exclude a term |

Stack exclusions to skip areas already reviewed — each one changes the question, so record the exact query and date:
```
site:sru.edu -site:www.sru.edu
site:sru.edu -site:www.sru.edu -site:my.sru.edu
```

Important dorks:
- Directory listings: `site:sru.edu intitle:"index of"` # shows the entire listing of files in a folder
- S3 Buckets: `site:s3.amazonaws.com "slippery rock"`
- Backups left in web root: `site:sru.edu ext:bak OR ext:old OR ext:sql`
- Admin interfaces: `site:sru.edu inurl:admin OR inurl:portal`
- Forgotten properties (search an old copyright string): `"© 2019 Slippery Rock University" -site:sru.edu`

[Google Hacking Database](https://exploit-db.com/google-hacking-database) organizes more of these by exposure type. Different search engines support different operators and index different material — don't rely on one alone.
