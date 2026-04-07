# POC apisix custom plugins

```sh
curl -v localhost:9080/resty-http -H "x-client:smile"
```
```sh
curl -v localhost:9080/resty-jwt -H "x-token:eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KIzOcRhdz9fVKHayLQt7VWlj-3isDB0j13vLvXLd8us"
```
