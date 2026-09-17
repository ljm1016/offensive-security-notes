#scripting

Quick syntax reference, not pentest-specific — for actual scripting during an engagement/CTF, not enumeration technique.

**Read / print**
```bash
read var
echo "$var"
```

**Arithmetic**
```bash
count=$((count + 1))       # preferred
count=$(expr $count + 1)   # older style, command substitution — not 'expr ...' in single quotes, that's just a literal string
```

**Variables**
```bash
count=1
portlist=(20 21 25 80 143 443)
ip=192.168.1.1
```

**If/elif/else**
```bash
count=53
if [ $count -lt 0 ]; then
    echo "$count is less than 0"
elif [ $count -gt 0 ]; then
    echo "$count is greater than 0"
else
    echo "$count is 0"
fi
```

**While loop**
```bash
count=0
while [ $count -lt 5 ]; do
    echo $count
    count=$((count + 1))
done
```

**For loop**
```bash
portlist=(20 21 25 80 143 443)
for portNum in ${portlist[*]}; do
    echo "Port Number: $portNum"
done
```
