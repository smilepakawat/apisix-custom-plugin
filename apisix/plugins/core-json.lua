local core = require("apisix.core")

local plugin_name = "core-json"

local schema = {}

local _M = {
    version = 0.1,
    priority = 1000,
    plugin_name = plugin_name,
    schema = schema,
}

function _M.check_schema(conf, _)
    return core.schema.check(schema, conf)
end

function _M.access(_, ctx)
    core.request.set_header(ctx, "x-json-message", core.json.encode({ foo = "bar" }))
end

return _M
