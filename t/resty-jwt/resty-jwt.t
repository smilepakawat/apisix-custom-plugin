use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();

add_block_preprocessor(sub {
    my ($block) = @_;

    my $extra_yaml_config = $block->extra_yaml_config // <<_EOC_;
plugins:
    - resty-jwt
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
            local plugin = require("apisix.plugins.resty-jwt")
            local conf = {
                signed_key = "mock-signed-key",
            }

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say(require("toolkit.json").encode(conf))
        }
    }
--- response_body
{"signed_key":"mock-signed-key"}
--- no_error_log
[error]


=== TEST 2: check schema signed key does not exist
--- config
    location = /t {
        content_by_lua_block {
            local plugin = require("apisix.plugins.resty-jwt")
            local conf = {}

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say("done")
        }
    }
--- response_body
property "signed_key" is required
done


=== TEST 3: check schema wrong type signed key
--- config
    location = /t {
        content_by_lua_block {
            local plugin = require("apisix.plugins.resty-jwt")
            local conf = {
                signed_key = 999,
            }

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say("done")
        }
    }
--- response_body
property "signed_key" validation failed: wrong type: expected string, got number
done


=== TEST 4: set uri to the resty-jwt plugin
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t("/apisix/admin/routes/1",
                ngx.HTTP_PUT,
                [[{
                    "plugins": {
                        "resty-jwt": {
                            "signed_key": "mock-signed-key"
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


=== TEST 5: access with sign
--- request
GET /echo?type=sign
--- more_headers
x-message: {"foo":"bar"}
--- response_headers
x-message: {"foo":"bar"}
--- response_headers_like
x-token: ^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]*$


=== TEST 6: should exit 500 when sign invalid header
--- request
GET /echo?type=sign
--- more_headers
x-message: foo
--- error_code: 500


=== TEST 7: access with verify
--- request
GET /echo?type=verify
--- more_headers
x-token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJmb28iOiJiYXIifQ.BTyGN5cUPW7F0yDK32nb3IaUvKNj2q2ATGYa3Qt7MtI
--- response_headers
x-token-verified: yes


=== TEST 8: should exit 401 when verify invalid token signature
--- request
GET /echo?type=verify
--- more_headers
x-token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJmb28iOiJiYXIifQ.0xVRluiMGBzjSQ5peD3liSzU6pN6ETu1ZcVYZTyd2N4
--- error_code: 401
--- response_body
{"message":"signature mismatch: 0xVRluiMGBzjSQ5peD3liSzU6pN6ETu1ZcVYZTyd2N4"}


=== TEST 9: should exit 401 when verify expired token
--- request
GET /echo?type=verify
--- more_headers
x-token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJmb28iOiJiYXIiLCJleHAiOjE3NzYwNzQ3MDF9.EV61YpL6APO50NOYX1qUbN9zgMPr9-18N0CqT-GuaXA
--- error_code: 401
--- response_body
{"message":"'exp' claim expired at Mon, 13 Apr 2026 10:05:01 GMT"}


=== TEST 7: should exit 400 when invalid query param
--- request
GET /echo?type=invalid
--- error_code: 400
