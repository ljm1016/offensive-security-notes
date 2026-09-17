
Find public assets that a company or domain is utilizing via certificates. Searches hosts, web properties, and certificates using its own query language.

```
cert.names: sru.edu
```
This is a certificate-name query. Legacy Censys examples online may use different field names than the current platform — check the docs if a query doesn't return what you expect.

Searching the existing index is passive relative to the target. An on-demand scan or live rescan is not — that actually contacts the target.

See also [[Shodan]] — same idea (search an existing index of banners/services), different index and query syntax:
```
hostname:sru.edu
```

[Censys Platform docs](https://search.censys.io) · [Query vs scan credits](https://censys.io)