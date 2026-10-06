#webapplications

OWASP A05 (Injection) — remote code execution via a shell: input reaches a shell command and unintended instructions run on the server.
```python
name = request.args.get("name", "courses")
command = "printf 'Report: '; printf '%s\\n' " + name
subprocess.run(command, shell=True, ...)
```
| Input (`name=`) | Command the shell runs | Output |
| --- | --- | --- |
| `courses` | `printf 'Report: '; printf '%s\n' courses` | `Report: courses` |
| `courses; id` | `printf 'Report: '; printf '%s\n' courses; id` | `Report: courses` + `id` output |

`;` ends the intended command and lets a second one run — it executes as whatever OS account the application runs as (ideally an unprivileged one, not root).

## Fix
**Generate the output without a shell at all** when the "command" is really just a known, fixed operation:
```python
if name != "courses":
    return {"error": "Unknown report"}, 400
return {"output": f"Report: {name}\n"}
```
If a real external process is genuinely required:
```python
subprocess.run([executable, "--arg", validated_value], shell=False)
```
A fixed executable path + an argument *array* with `shell=False` — never a single interpolated string handed to a shell. Validate what each argument actually means (an argument that happens to start with `-` can still change behavior even without `shell=True`).

## Independent containment
Even with the injection fixed, limit the blast radius of anything still missed:
- Dedicated unprivileged OS account for the app process
- Restricted file, mount, and network access for that account
- Execution time and resource limits on any subprocess

## Testing
- Any field that looks like it might reach a filename, hostname, or CLI tool server-side (ping/traceroute utilities, image conversion, report generators, "export" features)
- Try `; id`, `| id`, `` `id` ``, `$(id)`, and newline-separated commands; a delayed response to `; sleep 5` is a blind-injection signal when output isn't reflected
