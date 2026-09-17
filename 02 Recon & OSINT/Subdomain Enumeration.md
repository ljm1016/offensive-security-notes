
## The pipeline
Recon moves from organization records to live hosts — each stage adds something the last one couldn't see:

| Stage | Tooling | Adds | Mode |
| --- | --- | --- | --- |
| Hostnames | [[Cert information\|crt.sh, gungnir]], subfinder, amass | the bulk of the target | passive |
| More hostnames | puredns, dnsgen, github-subdomains | unlinked and sequential names | mixed |
| Live hosts | httpx, masscan, nmap, EyeWitness, FavFreak, gau, ffuf | what answers, what it runs, what to review first | mixed |

## Wider hostname discovery
```bash
subfinder -d sru.edu
amass enum -d sru.edu
puredns resolve subdomains.txt          # bulk-resolve a candidate list against many resolvers
dnsgen subdomains.txt | puredns resolve -  # generate + test permutations (dev-, staging-, etc.)
github-subdomains -d sru.edu -t <token>    # subdomains leaked in public repos/commits
```

## Confirming what's actually alive
[[httpx]] is the fastest way to turn a long hostname list into "what's actually running here" — status code, page title, and detected tech per host, before you spend time on anything with [[gobuster]] or [[ffuf]].

Other pieces of this stage:
- [[eyewitness|EyeWitness]] — screenshots every live host, for fast visual triage of a long list
- **FavFreak** — fingerprints hosts by favicon hash, useful for spotting the same app across many hostnames
- **gau** (get-all-urls) — pulls historical URLs from the Wayback Machine, Common Crawl, etc. for a domain
- [[ffuf]] — directory/vhost fuzzing once you're down to specific hosts
- [[Nuclei]] — once hosts are confirmed alive, a template-based sweep for known CVEs/misconfigs

## Subdomain takeover
Once you have a hostname list, check for ones with a CNAME pointing at a service (cloud host, SaaS platform) that's no longer claimed — e.g. `subzy`, or the manual checklist at [[Subdomain Takeover]]. A dangling CNAME can sometimes be claimed on the third-party service, letting you serve content on the target's own subdomain.
