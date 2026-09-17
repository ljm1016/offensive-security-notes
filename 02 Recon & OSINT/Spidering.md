
Websites built by the same team can share identifiers in the page source — two ways to find that link.

## BuiltWith relationships — passive

BuiltWith fingerprints a site's tech stack. Its relationship view groups every domain sharing an analytics or advertising identifier with the one queried:
```
builtwith.com/relationships/sru.edu
```
Same pivot by hand: view source, find a `G-XXXXXXX` or `UA-XXXXXXX` string, search for it elsewhere. Queries an existing index — doesn't touch the target.

## Spidering — active
Follows every link, then every link on those pages, until nothing new appears. **Every page fetched is a request the target logs.** Two tools for it, same idea: [[gospider]], [[Hakrawler]] — both parse JavaScript for URLs, which a plain/manual crawl misses, so this is where client-side routes and API endpoints tend to turn up.