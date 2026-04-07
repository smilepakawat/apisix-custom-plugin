local core = require("apisix.core")
local http = require("resty.http")

local plugin_name = "resty-http"

local schema = {
    type = "object",
    properties = {
        uri = { type = "string" },
    },
    required = { "uri" },
}

local _M = {
    version = 0.1,
    priority = 1001,
    plugin_name = plugin_name,
    schema = schema,
}

function _M.check_schema(conf, _)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)
    local x_client = core.request.header(ctx, "x-client")
    local httpc = http.new()
    httpc:set_timeout(3000)
    local res, err = httpc:request_uri(
        conf.uri,
        {
            method = "GET",
            headers = {
                ["x-client"] = x_client,
            },
        }
    )
    if err then
        core.log.error("http error: ", err)
        return core.response.exit(500)
    end

    if res.status ~= 200 then
        core.response.exit(res.status)
    end
    core.request.set_header(ctx, "x-http-verified", "yes")
end

return _M
