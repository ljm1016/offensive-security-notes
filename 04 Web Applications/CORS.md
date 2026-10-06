#webapplications

## Origins and the same-site/same-origin boundary
```
Origin = scheme + host + port
```
| Compared with `http://127.0.0.1:8766` | Same origin? | Same site? |
| --- | --- | --- |
| `http://127.0.0.1:8766/courses` | Yes | Yes |
| `http://127.0.0.1:8769` (different port) | No | Yes |
| `http://localhost:8766` (different host) | No | No |
| `https://127.0.0.1:8766` (different scheme) | No | No |

Site uses scheme + registrable domain (or just the host, in loopback examples like these); **ports don't isolate cookies**, but do isolate origins. The same-origin policy limits cross-origin *reads* by default — some cross-origin requests and embedding remain possible unless explicitly blocked (see [[Clickjacking]]).

## Cross-Origin Resource Sharing
CORS is how a server *opts in* to letting another origin's browser script read its response.
```
Access-Control-Allow-Origin: http://127.0.0.1:8769
Access-Control-Allow-Credentials: true
```
Unsafe: echoing back whatever `Origin` header the request sent, so *any* origin gets permitted. Fixed — match an exact configured origin, never reflect the request's Origin blindly, and never pair `Access-Control-Allow-Credentials: true` with a wildcard (`*`):
```python
if origin == "http://127.0.0.1:8770":
    allow_origin(origin)
    allow_credentials()
# Also send Vary: Origin
```

## CORS vs CSRF — different problems
| Policy boundary | What it's for | What remains necessary |
| --- | --- | --- |
| CORS — cross-origin response *reading* | Stops another origin's JS from reading Alice's authenticated response | Server authentication and authorization still has to be correct |
| CSRF — unintended state-changing *requests* | A blocked CORS read doesn't stop the request from being sent and acted on | Intent checks ([[CSRF]]) even when the response is unreadable |

**A blocked browser read does not establish that the server never received or acted on the request.** CORS failing closed stops the attacker from seeing the response; it does nothing to stop a forged POST from taking effect server-side — that's what CSRF defenses are for, and the two must both be correct independently.
