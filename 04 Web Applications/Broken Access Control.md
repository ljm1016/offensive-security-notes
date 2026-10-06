#webapplications

OWASP A01 — a server allows an operation outside the caller's intended permissions. The record/action ID selects an object; the authenticated account and policy are what's supposed to determine permission.

## IDOR — Insecure Direct Object Reference
An identifier selects a resource without the required authorization check.
```
Normal:  GET /records/unsafe/101   Cookie: sid=<Alice session>   → {"id": 101, "owner": "Alice", "data": "..."}
Changed: GET /records/unsafe/202   Cookie: sid=<same Alice session>   → 200, {"id": 202, "owner": "Bob", "data": "secret"}
```
Both requests return 200 — the second one leaks another account's private data because the server never checked ownership.

### Testing workflow
1. **Identify ID-like parameters.** Anything that looks like it selects data:
   ```
   GET /api/records/42
   GET /api/user?id=101
   POST /export?invoice_id=2024-001
   GET /profile/user_123456
   ```

2. **Map which objects you have access to.** Log in as one account and note the IDs you see:
   ```
   Alice's account: /user/101
   Alice's invoice: /invoice/5001
   Alice's project: /project/42
   ```

3. **Try sequential IDs.** Change the ID to nearby values while staying authenticated:
   ```
   GET /api/records/101  → 200, your record
   GET /api/records/102  → 200, someone else's record! (IDOR found)
   GET /api/records/103  → 200, another record
   ```

4. **Verify it's a permission bug, not a 404.** The response should contain data, not `{"error": "Not found"}`. If you get 403 (Forbidden), the app *is* checking permissions — that's the fix, not the bug.

5. **Test all methods.** The vulnerability might exist for reads but not writes, or vice versa:
   ```
   GET    /api/records/202  → 200, Bob's record (read works)
   DELETE /api/records/202  → 200, deleted Bob's record (write also works)
   ```

### ID patterns to try
| Pattern | Example | Notes |
| --- | --- | --- |
| Sequential integers | `id=1`, `id=2`, `id=42` | Easiest to discover |
| UUID/GUID | `id=550e8400-e29b-41d4-a716-446655440000` | Harder to guess; try the pattern from legitimate requests |
| Username or email | `user=alice`, `email=bob@example.com` | Often directly usable as identifiers |
| Base64-encoded | `id=YWxpY2U=` (base64 for "alice") | Decode captured IDs and fuzz the decoded value |
| Timestamp or sequence | `id=1730000000`, `invoice=2024-001` | Real-world data often has patterns |
| Hash or encoded data | Look for `/user/a1b2c3d4` patterns | Try common hash/encode formats; sometimes they're MD5 or JWT |

### Common gotchas
| Gotcha | Symptom | Test |
| --- | --- | --- |
| ID exists but is empty/null | `GET /user/999` returns `{}` or null | Try an ID you know is valid, then an invalid one — see if the response differs |
| Soft delete (data hidden, not truly deleted) | `DELETE` returns 200 but data reappears later | Verify the data is actually gone (request it again, check database if you have access) |
| ID is account-specific | `/my/invoice/42` always returns your invoice 42 | Try absolute paths (`/invoice/42`) without the `/my/` prefix |
| IDOR exists for export/report only | Web UI shows auth check, but API endpoint doesn't | Try `GET /api/report?user=bob` vs the normal web form |

### Proof
- Normal request returns your own data (200, ownership confirmed)
- Changed ID returns someone else's data (200, no ownership check)
- Error handling shows the data exists (not a 404) — the server found it, just didn't check if you own it

Missing vs fixed:
```python
# missing decision
user = identity()
record = RECORDS[record_id]
return record

# server-side policy
user = identity()
record = RECORDS[record_id]
if record["owner"] != user:
    if USERS[user]["role"] != "admin":
        return {"error": "Denied"}, 403
return record
```
Apply the policy to reads, updates, exports, and deletion — not just the view route. **Random IDs only make discovery harder, they don't fix the missing check.**

## Hidden endpoints and HTTP method bypass
A guard on one method isn't a guard on the route:
```python
# one method has a guard — unsafe
if request.method == "GET":
    require_admin()
return generate_report()

# every path to the action has a guard — correct
user = authenticated_user()
require_permission(user, "admin_report")
return generate_report()
```
Same session, same endpoint: `GET /admin/...` → 403 either way, but `POST /admin/...` → 200 on the unsafe route (report released) vs 403 on the corrected one. **An absent button does not disable an endpoint — there's no such thing as a "hidden" API route, only one you haven't tried yet. Authorization belongs before the operation runs, checked the same way regardless of method.**

## Cookie tampering and privilege claims
```
Cookie: sid=<Alice session>; role=admin
```
Unsafe: trusting a client-supplied value —
```python
role = request.cookies.get("role")
if role == "admin":
    release_admin_report()
```
Corrected: look up trusted account state server-side —
```python
user = identity()
if USERS[user]["role"] != "admin":
    deny()
```
Editing a cookie only grants privilege when the server wrongly trusts its contents. Any value the client can set (cookie, hidden form field, JSON body key) is not a security boundary on its own.

## Where this comes up during testing
- Any URL/body/query param that looks like an ID, record number, username, or filename → try changing it to another valid value while authenticated as someone else → [[Where to even start]] Phase 5
- Try every HTTP method a route might accept (GET/POST/PUT/DELETE), not just the one the UI uses
- Check cookies and JWTs ([[JWT]]) for claims (`role`, `admin`, `isAdmin`) the client can edit — see if the server actually re-validates them
