#webapplications

OWASP A05 (Injection) — the same class of bug as [[SQL Injection]], against a document database. MongoDB stores documents and accepts structured query *objects*, not just strings — so the injection vector is JSON structure, not quote characters.

```json
{"code": "CYBR401"}          // expected: a plain value
{"code": {"$ne": null}}      // operator object: "not equal to null"
```
`$ne` selects every non-null value for that field — sent where the app expected a plain string, it can return every row instead of one (including unpublished/hidden records).

## Fix — constrain type, then structure
```python
code = body.get("code")
if not isinstance(code, str):
    return {"error": "Expected string"}, 400
query = {"code": code, "published": True}
```
Rejecting anything that isn't a plain string closes the operator-object vector entirely — a JSON body with `{"$ne": null}` as the value now fails type validation (400) instead of reaching the query.

## Testing
- Anywhere a JSON API accepts a field normally filled with a string/number, try sending an object instead: `{"$ne": null}`, `{"$gt": ""}`, `{"$regex": ".*"}`
- Constrain types, allowed fields, and allowed operators server-side; add the same publication/ownership policy checks as [[Broken Access Control]], plus least-privilege database credentials
