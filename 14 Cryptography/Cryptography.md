#cryptography

## Key terms
| Term | Meaning |
| --- | --- |
| Plaintext | The original, readable message/data before encryption |
| Ciphertext | The scrambled, unreadable version after encryption |
| Cipher | The algorithm/method that converts plaintext ↔ ciphertext |
| Key | The string of bits the cipher uses to encrypt/decrypt |
| Encryption | Plaintext → ciphertext, using a cipher + key |
| Decryption | Ciphertext → plaintext, using a cipher + key |

## Symmetric vs asymmetric
- **Symmetric (private key)** — same key encrypts and decrypts. Requires a secure channel to share the key in the first place.
- **Asymmetric (public key)** — two different keys. Encrypt with the public key, decrypt with the private key, so the public key can be shared openly without compromising confidentiality.

## Caesar cipher
Shift every letter by N positions (A shifted 3 = D). Only 25 possible keys, so it's trivially brute-forceable — good first thing to try on a short ciphertext with no other clues.
Play with it: https://cryptii.com/pipes/caesar-cipher

## RSA (asymmetric)
Relies on the difficulty of factoring the product of two large primes.

| Variable | Meaning |
| --- | --- |
| `p`, `q` | Large prime numbers (~300 digits in real-world use) |
| `n` | `p × q` |
| `e` | Public exponent |
| `d` | Private exponent |
| Public key | `(n, e)` |
| Private key | `(n, d)` |
| `m` | Plaintext message |
| `c` | Ciphertext |

**Worked example** (small numbers for clarity — real RSA uses far larger primes):
- Bob picks `p = 157`, `q = 199` → `n = p × q = 31243`
- `φ(n) = (p-1)(q-1) = n - p - q + 1 = 30888`
- Bob picks `e = 163` (coprime to φ(n)), then finds `d = 379` such that `e × d ≡ 1 mod φ(n)`:
  `163 × 379 = 61777`, and `61777 mod 30888 = 1` ✓
- Public key: `(n, e) = (31243, 163)`. Private key: `(n, d) = (31243, 379)`.
- To encrypt `m = 13`: `c = m^e mod n = 13^163 mod 31243 = 16341`
- To decrypt: `m = c^d mod n = 16341^379 mod 31243 = 13` ✓ — original message recovered
