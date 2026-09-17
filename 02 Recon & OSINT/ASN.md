
ASN (Autonomous System Number) data maps *announced* address space — which network operator advertises a block of IPs. Not the same thing as who owns or hosts a domain.

```
# search by organization name
https://bgp.he.net/search?search=slippery+rock

# or resolve a known IP to its ASN
whois -h whois.cymru.com " -v 205.149.70.1"
```

Example result:
```
AS398643  SRU-ASN - Slippery Rock
          University of Pennsylvania
          205.149.64.0/19   ARIN 1995
```

## Limits
A domain can resolve into a completely different ASN than the org's own registered one — `www.sru.edu` resolves into **AS23033, Wowrack** (a hosting provider), not the university's own **AS398643**. ASN data describes the network that announces a prefix, not physical hosting or legal ownership. Corroborate it against [[DNS Recon]] and RIR (ARIN/RIPE/etc.) data before treating it as fact.

## Corroboration
Two unrelated sources agreeing turns a lead into a finding — e.g. a published mail policy independently listing an IP range (`205.149.70.0/24`) that falls inside an ASN's announced prefix. Agreement between two unrelated sources is what makes it real; one source repeated in multiple places is not the same thing.
