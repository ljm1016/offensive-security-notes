#scripting

Quick syntax reference, not pentest-specific. See [[Python Modules]] for the `os` module and others.

**Read / print**
```python
var = input()
print(var)
```

**Variables**
```python
count = 1
portlist = [20, 21, 25, 80, 143, 443]
ip = "192.168.1.1"
again = True
```

**Arithmetic**
```python
count = count + 1   # or count += 1
count -= 1
```

**If/elif/else**
```python
count = 53
if count < 0:
    print("count is less than 0")
elif count > 0:
    print("count is greater than 0")
else:
    print("count is 0")
```

**While loop**
```python
count = 0
while count < 5:
    print(count)
    count += 1
```

**For loop**
```python
portlist = [20, 21, 25, 80, 143, 443]
for portNum in portlist:
    print(f"Port #: {portNum}")
```
