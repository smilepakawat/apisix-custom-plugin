local ngx = ngx
local core = require("apisix.core")
local openssl_pkey = require("resty.openssl.pkey")
local ngx_encode_base64 = ngx.encode_base64
local ngx_decode_base64 = ngx.decode_base64

local plugin_name = "resty-openssl"

local schema = {
    type = "object",
    properties = {
        pkey = { type = "string" },
    },
    required = { "pkey" },
}

local _M = {
    version = 0.1,
    priority = 1003,
    plugin_name = plugin_name,
    schema = schema,
}

function _M.check_schema(conf, _)
    return core.schema.check(schema, conf)
end

function _M.access(conf, ctx)
    local pk, err = openssl_pkey.new(conf.pkey)
    if err then
        core.log.error("err: ", err)
        return core.response.exit(500)
    end

    local type = core.request.get_uri_args(ctx)["type"]
    local message = core.request.header(ctx, "x-message")
    if type == "verify" then
        local x_content_signature = core.request.header(ctx, "x-content-signature")
        local verified, err = pk:verify(ngx_decode_base64(x_content_signature), message)
        if not verified then
            core.response.exit(401, err)
        end

        core.request.set_header(ctx, "x-content-signature-verified", "yes")
    elseif type == "sign" then
        local signature, err = pk:sign(message)
        if not signature then
            core.response.exit(400, err)
        end

        core.request.set_header(ctx, "x-content-signature", ngx_encode_base64(signature))
    else
        core.response.exit(400)
    end
end

return _M
