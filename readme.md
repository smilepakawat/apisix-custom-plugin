# POC apisix custom plugins

## `resty-http`
```sh
curl -v localhost:9080/resty-http -H "x-client:smile"
```

**Execution Flow:**
1. Extract `x-client` header from incoming request
2. Send HTTP GET request to `conf.uri` passing the `x-client` header
   - **If Success (HTTP 200)** ➔ Set header `x-http-verified: yes` and **Proceed**
   - **If Error or != 200** ➔ **Exit 500** (or upstream status code)

## `resty-jwt`
```sh
curl -v localhost:9080/resty-jwt?type=sign -H "x-message:{\"x-message\":\"foo\"}"
curl -v localhost:9080/resty-jwt?type=verify -H "x-token:eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KIzOcRhdz9fVKHayLQt7VWlj-3isDB0j13vLvXLd8us"
```

**Execution Flow:**
1. Check `type` query argument:
   - **If `type=sign`**:
     1. Read `x-message` header and parse as JSON (Exit 500 on failure)
     2. Sign payload using `conf.signed_key`
     3. Set generated JWT to `x-token` header ➔ **Proceed**
   - **If `type=verify`**:
     1. Read `x-token` header
     2. Verify token validity using `conf.signed_key` (Exit 401 on failure)
     3. Set header `x-token-verified: yes` ➔ **Proceed**
   - **If Other/Missing** ➔ **Exit 400**

## `resty-openssl`
```sh
curl -v localhost:9080/resty-openssl?type=sign -H "x-message:foo"
curl -v localhost:9080/resty-openssl?type=verify -H "x-message:foo" -H "x-content-signature:GFwHbQEbxYHLfOPk3qpggIKYGttUy8He71UnoV8wqt3TWIm/ikAkQVqsa/9k2F5HUO0vNa8a35bGjv4JeXhkXgn8+c1IQPH46RWph1t2hKi06FQLV1do+4+0vwYqHECaUvXv2pMwrpmTUQ7/wKl8cWdq6uCCXhchUESY82D0Ruo="
```

**Execution Flow:**
1. Try loading `conf.pkey` (Exit 500 on error)
2. Check `type` query argument:
   - **If `type=sign`**:
     1. Read `x-message` header
     2. Sign message using the loaded Private Key (Exit 400 on error)
     3. Set Base64 encoded signature to `x-content-signature` header ➔ **Proceed**
   - **If `type=verify`**:
     1. Read `x-message` and `x-content-signature` headers
     2. Verify signature using the key (Exit 401 on verification failure)
     3. Set header `x-content-signature-verified: yes` ➔ **Proceed**
   - **If Other/Missing** ➔ **Exit 400**
