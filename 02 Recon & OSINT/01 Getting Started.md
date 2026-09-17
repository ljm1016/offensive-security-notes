#osint #methodology

Sequential checklist for a fresh recon target — an org name or a domain, nothing else yet. Same idea as [[11.1 Where to even start]] and web's [[Where to even start]]: work top to bottom, pull detail from the linked notes, stay passive as long as you can.

## Before you start
- [ ] Confirm scope and authorization — which assets/accounts/providers/time window are actually covered → [[Collection Methods & Evidence]]
- [ ] Passive collection first. Active (web probes, screenshots, live scans) only once passive findings justify it

## Phase 0 — The entity itself
- [ ] What it publishes vs. what others publish vs. what it must publish → [[Organization Research]]
- [ ] Check for recent M&A/consolidation — completed adds inherited systems, proposed may never happen → [[Organization Research]]
- [ ] Job postings and professional networks — systems and vendors before anything technical shows up → [[Organization Research]]

## Phase 1 — Names and domains
- [ ] Google dorking, starting from an ordinary information need → [[Dorking]]
- [ ] Exposed-material dorks — backups, directory listings, admin panels, object storage → [[Dorking]]
- [ ] WHOIS, then reverse WHOIS to pivot to other domains the same registrant owns → [[WHOIS]]
- [ ] Certificate transparency (crt.sh, gungnir) — usually the bulk of the hostname list → [[Cert information]]
- [ ] subfinder / amass / puredns / dnsgen / github-subdomains for the rest → [[Subdomain Enumeration]]

## Phase 2 — Networks and hosts
- [ ] ASN lookup — maps announced address space, not hosting or ownership → [[ASN]]
- [ ] DNS records — NS is the operator, MX is the mail provider, SOA's RNAME is a technical contact → [[DNS Recon]]
- [ ] [[Shodan]] / [[Censys]] — search what's already indexed before scanning anything yourself
- [ ] BuiltWith relationships / spidering (gospider, hakrawler) → [[Spidering]]
- [ ] httpx to see what's actually alive among everything found so far → [[Subdomain Enumeration]]

## Phase 3 — People
- [ ] Observed email addresses → inferred format (hunter.io, Gather Contacts) → [[People OSINT]]
- [ ] Reused handles across platforms (sherlock, maigret) → [[People OSINT]]
- [ ] Breach exposure (Dehashed, HIBP) — **authorized engagements only, never in a classroom/practice context** → [[People OSINT]]

## Phase 4 — Images and documents
- [ ] Document metadata (exiftool) → [[Images, Documents & Geolocation]]
- [ ] Image metadata + reverse image search (TinEye, Google Lens, Yandex) → [[Images, Documents & Geolocation]]
- [ ] Geolocation from frame clues — where and when → [[Images, Documents & Geolocation]]

## Phase 5 — Write it up
- [ ] Every finding gets an Observation + Assessment record → [[Collection Methods & Evidence]]
- [ ] Corroborate before trusting it — two independent sources agreeing is a finding, several copies of one claim is not
- [ ] Once you have live, in-scope hosts, this feeds into [[03 Scanning + Enumeration]]

---
Related:
- [[Case Studies]] — real investigations, what corroborated and what didn't
- [[Practice Resources]] — where to actually practice this
