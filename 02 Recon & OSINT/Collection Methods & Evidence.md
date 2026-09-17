#osint #methodology

## Collection categories
| Category | What it is | Contact with target? |
| --- | --- | --- |
| Passive | Reads records held by someone else — cert logs, registries, search indexes, scan archives, public repos | None, ever |
| Low interaction | DNS resolution — a cached answer avoids the authoritative server | Sometimes — only the zone operator, only if uncached |
| Active | Requests to the target's own systems — web probes, content discovery, screenshots | Yes — logged, linkable to your source address |

**Use passive collection first. Move to active only once passive findings justify it.**

## Scope & authorization
- An authorization defines the assets, accounts, providers, time window, and actions in scope. The systems actually covered by those terms may not be obvious at the start.
- A newly found server may or may not fall inside the existing scope — **check the authorization before testing it. Discovery alone does not authorize access.**
- A cloud tenant, payment processor, or separate legal entity is in scope only when the authorization includes it. **Ownership and hosting are separate questions** — record evidence for each ownership claim separately.

## Coverage
The main site gets the most attention by default. Other systems (a department's, a project's, a previous owner's) can stay online long after everyone stops paying attention to them. Cast broad on initial collection — a small host list can omit the system that actually matters.

## The recon cycle
Findings feed back into earlier steps — it's a loop, not a line:
```
a name → domains → hosts → services → people → (back to a name)
```
A new domain needs its own search/cert/DNS/network pass ([[WHOIS]], [[Cert information]], [[DNS Recon]], [[ASN]]). A new person is another route into a system. Repeat the relevant step instead of treating the pipeline as one-and-done.

## Recording evidence
A finding without its origin and collection history (its *provenance*) can't be checked later. Use two linked records per finding:

**Observation**
- Asset — what was found
- Finding — what it shows
- Source — where it came from
- Observed — the date the source itself is dated
- Collected — the date you captured it

**Assessment**
- Confidence — how sure, and why
- Scope — what this evidence does and doesn't cover
- Next check — what would raise or lower confidence

Example:
```
E-01 · OBSERVATION
Asset: portal.lab.internal
Finding: A certificate lists the name
Source: E-01, certificate snapshot
Observed: 2026-08-01
Collected: 2026-09-16

E-01 · ASSESSMENT
Confidence: High for the historical listing. Current service status is unknown.
Scope: Offline evidence pack only.
Next check: Read the dated DNS snapshot.
```

**Corroboration** = independent support from a second, unrelated source — that's what turns a lead into a finding. Several copies of one original claim, repeated across many places, are not independent evidence no matter how often they appear.
