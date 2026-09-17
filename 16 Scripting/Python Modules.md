#scripting

Reference for useful stdlib functions when writing quick recon/exploit scripts. WIP — sections with no example haven't been filled in yet.

## `os`
| Function | What it does |
| --- | --- |
| `os.name` | Current OS |
| `os.getpid()` | This script's process ID |
| `os.umask(mask)` | Sets the script's umask (decimal), returns the previous one |
| `os.uname()` | 5-tuple: system name, node name, OS release, OS version, machine |
| `os.getcwd()` | Current working directory as a string |
| `os.listdir(path)` | Filenames in a given directory |
| `os.system(cmd)` | Executes `cmd` as a system command |

```python
import os
print(f"Script executing on a {os.name}")
print(f"Current PID: {os.getpid()}")
print(f"Executing from {os.getcwd()}")
scripts = os.listdir(os.getcwd())
```

## System-specific — [[Python|sys]]
- `sys.argv` — TODO
- `sys.exit()` — TODO

## Pseudo-random — `random`
- `random.randrange()` — TODO
- `random.randint()` — TODO
- `random.choice()` — TODO
- `random.shuffle()` — TODO
- `random.sample()` — TODO

## Networking — `socket`
- `socket.gethostname()` — TODO
- `socket.gethostbyname()` — TODO
- `socket.socket()` — TODO
- `socket.setsockopt()` — TODO
- `socket.bind()` — TODO
- `socket.listen()` — TODO
- `socket.connect()` — TODO
- `socket.accept()` — TODO
- `socket.recv()` — TODO
- `socket.send()` — TODO
- `socket.close()` — TODO

## Hashing — `hashlib`
- `hashlib.md5()` — TODO
- `hashlib.sha256()` — TODO
- `hashlib.sha512()` — TODO
- `hashobj.hexdigest()` — TODO
