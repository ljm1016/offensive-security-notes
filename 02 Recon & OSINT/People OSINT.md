#osint

## Addresses
Infrastructure records (certs, DNS, docs) can contain email addresses. An observed address *suggests* a format — it doesn't verify someone else's address or prove an account is active.
```
format: first.last@sru.edu
# the staff directory supplies the names
# inferred addresses remain unverified
```
- **hunter.io** — suggests domain email patterns from observed addresses. Its verification features may contact mail servers — check the method and whether that's authorized before using it.
- **Gather Contacts** (github.com/clr2of8/GatherContacts) — browser extension that builds employee lists from search results.

A metadata "author" field is the same kind of clue — it doesn't prove a link to a particular account either.

## Identity resolution
A reused handle can link accounts across platforms:
```bash
sherlock jsmith1987
maigret jsmith1987 --html
```
(github.com/sherlock-project/sherlock · github.com/soxoj/maigret)

## Breach data
**Dehashed** searches breach records. **Have I Been Pwned** reports known exposure. Available fields, access rules, and pricing vary by service. Historical records can *suggest* account relationships — they do not establish current contact details or account access.

**Do not use breach-data lookups outside an authorized engagement.** A classroom or practice exercise should not use them at all — use a synthetic/offline evidence pack instead.

## Tradecraft — don't let collection reach the subject
- Use research accounts, never personal ones — platforms can notify a person when their profile is viewed
- No connection requests, messages, or follows
- Never authenticate to a system belonging to the subject
- Record the source and date for every claim — published material changes and disappears. **Archive the page at the moment of collection** (archive.org, archive.today); an unsourced, undated claim can't be checked later.
