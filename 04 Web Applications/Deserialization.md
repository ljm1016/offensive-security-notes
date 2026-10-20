#webapplications

Unsafe deserialization re-instantiates an object from untrusted data. If the object's class defines a magic method that runs on restore (like `__wakeup()` in PHP or `__destruct()`), code executes before the application validates anything.

## How it works

**Vulnerable code:**
```php
class DemoJob {
    public $code;
    
    function __wakeup() {
        eval($this->code);  // Executes when object is unserialized
    }
}

// Attacker-controlled data
$data = json_decode($raw, true);
$obj = unserialize(base64_decode($data['payload']));  // Object restored → __wakeup() runs
```

**Attack:**
1. Create a malicious object with `$code = 'system($_GET["cmd"])'`
2. Serialize it: `serialize($obj)`
3. Base64-encode it
4. Send it to the vulnerable endpoint
5. On deserialize, `__wakeup()` executes the PHP code

## When it's exploitable

- **PHP:** `unserialize()` calls magic methods (`__wakeup()`, `__destruct()`)
- **Python:** `pickle.loads()` rebuilds objects and can execute code
- **Java:** `ObjectInputStream.readObject()` invokes constructors and methods
- **Ruby:** `Marshal.load()` can execute code via gadget chains

**Not all deserialization is dangerous** — `json_decode()` to an associative array is safe (no objects created). The danger is specifically when:
1. User input is deserialized **into object form**
2. The class has dangerous magic methods
3. No validation happens before deserialization

## Testing workflow

### Step 1: Identify deserialization points

Look for:
- Base64 or hex-encoded data in cookies, JSON fields, or POST bodies
- Magic method indicators: `__wakeup`, `__destruct`, `__toString`, `__invoke`
- Libraries: `unserialize()` (PHP), `pickle` (Python), `ObjectInputStream` (Java), `Marshal` (Ruby)

### Step 2: Detect if objects are being restored

Try sending malformed data:
```
Original: eyJjb2RlIjoiYWJjIn0=  (base64-encoded JSON)
Malformed: zzz
```

If error message says "failed to unserialize" or similar, objects are being restored (not just arrays).

### Step 3: Find a gadget chain

A gadget chain is a sequence of existing classes whose methods, when called in order, perform useful operations. For example:

```php
// Class A's __destruct() calls method in Class B
// Class B's method calls method in Class C
// Class C's method evaluates a string
// Attacker chains these together by nesting objects
```

Tools to find gadget chains:
- **phpserializer** — explore serialized PHP objects
- **ysoserial** (Java) — generates gadget chains for RCE
- **pickle libraries** (Python) — research available gadgets

### Step 4: Craft payload

Manually serialize an object with dangerous properties:

```php
// Craft a DemoJob with injected code
$job = new DemoJob();
$job->code = 'system("id")';
$payload = base64_encode(serialize($job));
// Send payload to vulnerable endpoint
```

## Defenses

**Best: Never deserialize untrusted data**
```php
// Instead of unserialize(), use json with validation
$data = json_decode($raw, true);
if (!is_array($data) || !isset($data['code'])) {
    reject(400);
}
// $data is now just strings/arrays, no objects
```

**If deserialization is required: validate before deserialization**
```php
$allowed_classes = ['DemoJob', 'SafeJob'];
$obj = unserialize(
    $raw,
    ['allowed_classes' => array_map(fn($c) => $c, $allowed_classes)]
);
```

**For Java: disable dangerous classes**
```java
ObjectInputStream ois = new ObjectInputStream(is);
ois.setObjectInputFilter(new ObjectInputFilter() {
    public Status checkIncomingClass(Class<?> clazz) {
        if (clazz.getName().contains("gadgetchain")) return Status.REJECTED;
        return Status.ALLOWED;
    }
});
```

**For Python: use `json` or `msgpack` instead of `pickle`**
```python
# Instead of: obj = pickle.loads(data)
# Use: obj = json.loads(data)  # Data is just primitives, not objects
```

---

**See also:**
- [[OWASP Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)
- ysoserial (Java gadget chain generator)
- phpserializer (explore PHP serialized objects)
