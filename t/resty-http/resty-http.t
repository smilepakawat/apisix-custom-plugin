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
--- error_code: 200
--- response_body_like eval
qr/{"uri":"127.0.0.1:1980"}/
--- no_error_log
[error]


=== TEST 2: wrong uri type
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
--- error_code: 200
--- response_body
property "uri" validation failed: wrong type: expected string, got number
done


=== TEST 3: enable resty-http plugin with invlid config using admin api
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t("/apisix/admin/routes/1",
                ngx.HTTP_PUT,
                [[{
                    "plugins": {
                        "resty-http": {}
                    },
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:1980": 1
                        },
                        "type": "roundrobin"
                    },
                    "uri": "/hello"
                }]]
            )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- error_code: 400


=== TEST 4: verify
--- request
GET /hello
--- error_code: 404
--- response_body
{"error_msg":"404 Route Not Found"}


