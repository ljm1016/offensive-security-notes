#tools-index/web

#### `dig` is a powerful, flexible command-line tool used for querying DNS name servers

Syntax:
`dig @TARGET_IP target.url`

To attempt a zone transfer:
`dig axfr @targetip target.url`

Check for hidden strings:
`dig TXT target.url`

Find authoritative nameservers:
`dig NS target.url`