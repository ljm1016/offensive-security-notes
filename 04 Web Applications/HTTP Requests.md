#webapplications

## Anatomy of a URL
```
http   ://   127.0.0.1:8766   /courses   ?code=CYBR401   #details
scheme        host + port      path        query          fragment
```
- **Sent to the server:** path and query identify the resource and its input
- **Stays in the browser:** the fragment can select a location or feed browser-side code — never reaches the server

## Methods
| Method | Typical use | Safe | Idempotent |
| --- | --- | --- | --- |
| GET | Retrieve a resource | Yes | Yes |
| HEAD | Same as GET, headers only, no body | Yes | Yes |
| POST | Submit data: create a record, run an action | No | No |
| PUT | Replace the resource at this URL | No | Yes |
| PATCH | Change part of a resource | No | No |
| DELETE | Remove the resource | No | Yes |
| OPTIONS | List allowed methods; CORS preflight | Yes | Yes |
| TRACE / CONNECT | Echo the request / open a tunnel through a proxy | Yes/No | Yes/No |

**Safe** = should not change server state. **Idempotent** = sending it twice has the same effect as once. The method states intent, not permission — every method a route accepts needs the same authorization check (see [[Broken Access Control]]).

## Reading a request/response
```
POST /preferences HTTP/1.1
Host: 127.0.0.1:8766
Content-Type: application/json

{"theme":"dark"}
```
| Part | Meaning |
| --- | --- |
| First line | Method + path in a request. Status in a response. |
| Headers, then a blank line | Metadata such as Content-Type. Body follows the blank line. |
| Body | JSON carries structured values — a form can send `theme=dark` instead |

## Status codes
| Class | Meaning | Codes you'll see |
| --- | --- | --- |
| 1xx | Informational | 101 switching protocols |
| 2xx | Success | 200 OK · 201 Created · 204 No Content |
| 3xx | Redirect | 301/302 moved · 304 not modified |
| 4xx | Client error | 400 bad request · 401 not authenticated · 403 forbidden · 404 not found · 405 method not allowed · 429 too many requests |
| 5xx | Server error | 500 internal error · 502 bad gateway · 503 unavailable |

The status code reports what the server decided — it does not show what data was exposed. A 200 can still leak something it shouldn't.

## Tools for observing and replaying requests
| Task | Tool | First operation |
| --- | --- | --- |
| Observe the browser | Chrome DevTools | Network tab: select a request, inspect headers and response |
| Change and repeat one request | Burp Repeater / Caido Replay | Keep the same login, edit one value, compare the result |
| Make a reproducible request | curl | Display response headers and body directly |

```bash
curl -i 'http://127.0.0.1:8766/api/courses?code=CYBR401'
```
A proxy (Burp/Caido) sits between browser and application; Replay resends a captured request without going back through the form — this is how you test every input systematically (see [[Where to even start]] Phase 3).

*note to include any session cookies into your requests when you make them as needed:*

```
curl -i -b "sid=8ZuAoT97Y0A0T2q6Nwpp36HDHTSUJjrm" -X POST http://target02:8080/admin
```