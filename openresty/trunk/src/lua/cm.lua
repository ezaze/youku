local parser = require "parser"
local const = require "const"
local dsp = require "dsp"
local util = require "util"

local function cookieMapping()
    local dspId = parser.getDspId()
    local dspObj = dsp:new()

    if dspId == "" or (not dspObj:isValid(dspId)) 
       or dspObj:getStatus(dspId) == const.OBJECT_STATUS_INVALID then
        ngx.exit(204)
    end

    local baseUrl = dspObj:getRedirectUrl(dspId)
    if baseUrl == "" then
        ngx.exit(204)
    end

    local capture = ngx.re.match(baseUrl, [[\?]], "jo")
    local notation = ""
    if capture then
        notation = "&"
    else
        notation = "?"
    end

    local args = ngx.req.get_uri_args()
    args[const.CM_MATCH_TAG_ARG_SINA_NID] = nil

    local cookie = parser.getCookie()
    if cookie ~= "" then
        local sid = const.CM_REDIRECT_URL_ARG_SINA_SID
        if dspId == const.DSP_ID_ACXIOM then
            sid = const.CM_REDIRECT_URL_ARG_ACXIOM_SID
        end

        args[sid] =  util.sid(cookie)
    else
        args[const.CM_REDIRECT_URL_ARG_SINA_ERROR] = const.CM_ERROR_CODE_NO_COOKIE
    end    
       
    local url = baseUrl .. notation .. ngx.encode_args(args)
    ngx.redirect(url)
end

local cm = {
    cookieMapping = cookieMapping
}

return cm
