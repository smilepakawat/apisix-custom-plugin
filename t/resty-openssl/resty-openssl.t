use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();

add_block_preprocessor(sub {
    my ($block) = @_;

    my $extra_yaml_config = $block->extra_yaml_config // <<_EOC_;
plugins:
    - resty-openssl
_EOC_

    $block->set_value("extra_yaml_config", $extra_yaml_config);

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if (!defined $block->error_log && !defined $block->no_error_log) {
        $block->set_value("no_error_log", "[error]");
    }
});

run_tests;

__DATA__

=== TEST 1: sanity, check schema
--- config
    location = /t {
        content_by_lua_block {
            local plugin = require("apisix.plugins.resty-openssl")
            local conf = {
                pkey = "mock-pkey",
            }

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say(require("toolkit.json").encode(conf))
        }
    }
--- response_body
{"pkey":"mock-pkey"}
--- no_error_log
[error]


=== TEST 2: check schema pkey key does not exist
--- config
    location = /t {
        content_by_lua_block {
            local plugin = require("apisix.plugins.resty-openssl")
            local conf = {}

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say("done")
        }
    }
--- response_body
property "pkey" is required
done


=== TEST 3: check schema wrong type pkey key
--- config
    location = /t {
        content_by_lua_block {
            local plugin = require("apisix.plugins.resty-openssl")
            local conf = {
                pkey = 999,
            }

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say("done")
        }
    }
--- response_body
property "pkey" validation failed: wrong type: expected string, got number
done


=== TEST 4: set wrong pkey to the resty-openssl plugin
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t("/apisix/admin/routes/1",
                ngx.HTTP_PUT,
                [[{
                    "plugins": {
                        "resty-openssl": {
                            "pkey": "invalid-pkey"
                        }
                    },
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:1980": 1
                        },
                        "type": "roundrobin"
                    },
                    "uri": "/echo"
                }]]
            )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- response_body
passed


=== TEST 5: should exit 500 when set wrong pkey
--- request
GET /echo
--- error_code: 500
--- error_log
pkey.new:load_key: error:


=== TEST 6: set wrong pkey to the resty-openssl plugin
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t("/apisix/admin/routes/1",
                ngx.HTTP_PUT,
                [[{
                    "plugins": {
                        "resty-openssl": {
                            "pkey": "-----BEGIN PRIVATE KEY-----\nMIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBALExiCSJY1q3GKKld5HlF0rq/Xj5+p76SVrK/Q9lYBpSyiEAHiOgdmGqWtxiOHnqIcvR6mspXCbo2nEBrtCCpH4jNQhcghD6pECMjhLtlKSpHA7hVmUaaGvqVx2l75Q5gR83gjwHYeFChp4GKGIwj1R5fwgZS2Z+JpcZ+Y49Zx2nAgMBAAECgYBW9PndBFdv018RoqZ1QLoXmA7gab0me6m4FtntzlBFWs+7NjWUQlEWSOXiNYmFuvLu9YtXH6sLpUZeIvdJeHOEabzPdXpmarSV8cU7xFJkMpIxCUbtMAwi1fWPgFtDs8Nl5DHqhoeQqA6iL2lKTcBDo/IuW8TShk+f2FTijzIkAQJBAOdT5vVBE0kd1+NVG3Cv4G7r6QtY3i13KDtAZ0IlOlkwgeir0vT2htHQTvbEoNL4beZcMgNTuGoUWmW+L42ygwECQQDEF5C5t6/ay8veMWSOJiS1CPkng5CUtOADAz9QNBZalUcTZWB84zufkZCdqmRbKkmTbI5/IzuwPUxB9OM2+6inAkBkt50ZLyosbXfvnMCDwa+f28rti9XASd8UXSgYHolXB82n9he1XBi7BU08F8RF1rBS2dVUqYDjftUU80dVFGIBAkEApbakf85TtrtzVhq3t8lUTAmBRXtRu9n/VYxw/P6HxZVRs3qAyAngYUFKzXMpzEE4XHXpFlhYIOAsibDCM70JEQJBAI6lKiTdies0AIcrS1iS1OF/WdLkb/3R42DL2UGZn++ZsE6VTIeukUkAGYf9J0xAIHrBQrdj5ZA/dlGF3DyvFNA=\n-----END PRIVATE KEY-----"
                        }
                    },
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:1980": 1
                        },
                        "type": "roundrobin"
                    },
                    "uri": "/echo"
                }]]
            )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- response_body
passed


=== TEST 7: access with sign signature
--- request
GET /echo?type=sign
--- more_headers
x-message: hello
--- response_headers
x-message: hello
x-content-signature: TVfLUs9xR7COXBA4+zffrl2DYc5ywyPVwDZzZm/Ip2ExBJDNRpVGT+PzvsfXRJkuHVpXskYRe35Vx93O4cV6cXeHyxjMLzcPeAxTEe1MMg4je2Pu+vJplLlqCC7Cc9BPtUu0WoMmdqNkE4QwfbS5M7hmAlPLZgp7UzVHqm7mbuY=


=== TEST 8: should exit 400 when sign signature with no x-message
--- request
GET /echo?type=sign
--- error_code: 400
--- response_body
{"message":"pkey:sign: expect a digest instance or a string at #1"}


=== TEST 9: access with verify signature
--- request
GET /echo?type=verify
--- more_headers
x-message: hello
x-content-signature: TVfLUs9xR7COXBA4+zffrl2DYc5ywyPVwDZzZm/Ip2ExBJDNRpVGT+PzvsfXRJkuHVpXskYRe35Vx93O4cV6cXeHyxjMLzcPeAxTEe1MMg4je2Pu+vJplLlqCC7Cc9BPtUu0WoMmdqNkE4QwfbS5M7hmAlPLZgp7UzVHqm7mbuY=
--- response_headers
x-message: hello
x-content-signature: TVfLUs9xR7COXBA4+zffrl2DYc5ywyPVwDZzZm/Ip2ExBJDNRpVGT+PzvsfXRJkuHVpXskYRe35Vx93O4cV6cXeHyxjMLzcPeAxTEe1MMg4je2Pu+vJplLlqCC7Cc9BPtUu0WoMmdqNkE4QwfbS5M7hmAlPLZgp7UzVHqm7mbuY=
x-content-signature-verified: yes


=== TEST 10: should exit 401 when verify with wrong signature
--- request
GET /echo?type=verify
--- more_headers
x-message: wrong
x-content-signature: TVfLUs9xR7COXBA4+zffrl2DYc5ywyPVwDZzZm/Ip2ExBJDNRpVGT+PzvsfXRJkuHVpXskYRe35Vx93O4cV6cXeHyxjMLzcPeAxTEe1MMg4je2Pu+vJplLlqCC7Cc9BPtUu0WoMmdqNkE4QwfbS5M7hmAlPLZgp7UzVHqm7mbuY=
--- error_code: 401
--- response_body
{"message":"pkey:verify: error:1C880004:Provider routines:rsa_verify_directly:RSA lib:implementations/signature/rsa_sig.c:1041:"}

=== TEST 11: should exit 400 when invalid query param
--- request
GET /echo?type=invalid
--- error_code: 400
