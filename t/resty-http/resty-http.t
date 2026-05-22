use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();

add_block_preprocessor(sub {
    my ($block) = @_;

    my $extra_yaml_config = $block->extra_yaml_config // <<_EOC_;
plugins:
    - resty-http
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
            local plugin = require("apisix.plugins.resty-http")
            local conf = {
                uri = "127.0.0.1:1980"
            }

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say(require("toolkit.json").encode(conf))
        }
    }
--- response_body_like eval
qr/{"uri":"127.0.0.1:1980"}/
--- no_error_log
[error]


=== TEST 2: check schema uri does not exist
--- config
    location = /t {
        content_by_lua_block {
            local plugin = require("apisix.plugins.resty-http")
            local conf = {}

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say("done")
        }
    }
--- response_body
property "uri" is required
done


=== TEST 3: check schema wrong type uri
--- config
    location = /t {
        content_by_lua_block {
            local plugin = require("apisix.plugins.resty-http")
            local conf = {
                uri = 999
            }

            local ok, err = plugin.check_schema(conf, _)
            if not ok then
                ngx.say(err)
            end

            ngx.say("done")
        }
    }
--- response_body
property "uri" validation failed: wrong type: expected string, got number
done


=== TEST 4: set unreal uri to the resty-http plugin
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t("/apisix/admin/routes/1",
                ngx.HTTP_PUT,
                [[{
                    "plugins": {
                        "resty-http": {
                            "uri": "http://127.0.0.1:199999/dead-api"
                        }
                    },
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:1980": 1
                        },
                        "type": "roundrobin"
                    },
                    "uri": "/trigger-error"
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


=== TEST 5: verify the plugin handles the httpc error and exits with 500
--- request
GET /trigger-error
--- error_code: 500
--- error_log
http error:


=== TEST 6: set uri to the resty-http plugin
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t("/apisix/admin/routes/1",
                ngx.HTTP_PUT,
                [[{
                    "plugins": {
                        "resty-http": {
                            "uri": "http://127.0.0.1:1984/mock_endpoint"
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


=== TEST 7: should pass through when custom route to verify http request return 200
--- config
    location /mock_endpoint {
        return 200 'hello world';
    }
--- request
GET /echo
--- more_headers
x-client: smile
--- response_headers
x-client: smile
x-http-verified: yes


=== TEST 8: should exit 500 when custom route to verify http request return 500
--- config
    location /mock_endpoint {
        return 500 'server error';
    }
--- request
GET /echo
--- more_headers
x-client: smile
--- error_code: 500
