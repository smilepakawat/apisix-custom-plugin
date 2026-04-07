local core = require("apisix.core")
local jwt = require("resty.jwt")

local plugin_name = "resty-name"

local schema = {
    type = "object",
    properties = {
        signed_key = { type = "string" },
    },
    required = { "signed_key" },
}

local _M = {
    version = 0.1,
    priority = 1000,
    plugin_name = plugin_name,
    schema = schema,
}

function _M.check_schema(conf, _)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)
    local type = core.request.get_uri_args(ctx)["type"]
    if type == "verify" then
        local token = core.request.header(ctx, "x-token")
        local result = jwt:verify(conf.signed_key, token)
        if not result.verified then
            core.response.exit(401, result.reason)
        end
        core.request.set_header(ctx, "x-token-verifeid", "yes")
    elseif type == "sign" then
        local x_message = core.request.header(ctx, "x-message")
        local header = {
            type = "JWT",
            alg = "HS256",
        }
        local jwt_table = {
            header = header,
            payload = core.json.decode(x_message),
        }
        local jwt_token = jwt:sign(conf.signed_key, jwt_table)
        core.request.set_header(ctx, "x-token", jwt_token)
    else
        core.response.exit(400)
    end
end

return _M
