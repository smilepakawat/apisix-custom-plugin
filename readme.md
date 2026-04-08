# POC apisix custom plugins

```sh
curl -v localhost:9080/resty-http -H "x-client:smile"
```
```sh
curl -v localhost:9080/resty-jwt?type=sign -H "x-message:{\"x-message\":\"foo\"}"
curl -v localhost:9080/resty-jwt?type=verify -H "x-token:eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KIzOcRhdz9fVKHayLQt7VWlj-3isDB0j13vLvXLd8us"
```

```sh
curl -v localhost:9080/resty-openssl?type=sign -H "x-message:foo"
curl -v localhost:9080/resty-openssl?type=verify -H "x-message:foo" -H "x-content-signature:GFwHbQEbxYHLfOPk3qpggIKYGttUy8He71UnoV8wqt3TWIm/ikAkQVqsa/9k2F5HUO0vNa8a35bGjv4JeXhkXgn8+c1IQPH46RWph1t2hKi06FQLV1do+4+0vwYqHECaUvXv2pMwrpmTUQ7/wKl8cWdq6uCCXhchUESY82D0Ruo="
```
