#tools-index/web

#### `gospider` is a fast web spider written in Go — follows every link on a page, then every link on those pages, until nothing new appears.

Syntax:
```
gospider -s https://www.sru.edu -d 3
```
`-d 3` caps crawl depth. Parses JavaScript for URLs, which a plain/manual crawl misses.

**Active** — every page it fetches is a request the target logs. See [[Hakrawler]] for the same idea via a different tool.
