local const = require("const")
local parser = require("parser")
local util  = require("util")
local cjson = require ("cjson")
local util = require("util")
local str = require "resty.string"

local pcall = pcall;
local concat = table.concat;
local ipairs = ipairs;
local pairs = pairs;

local function notifySinaAdEngine(args)
    local body = {} 
    body.adunit_id = args.posid 
    body.ad_id = args.adid
    body.uid = args.uid
    body.platform = args.platform
    body.type = args.type
    body.sdk = args.sdk
    body.adurl = args.adurl
    body.wm = args.wm
    body.from = args.from
    body.tokenid = args.tokenid
    local  jsonStr = cjson.encode(body)

    local option = {}
    option.method = ngx.HTTP_POST
    option.body = jsonStr
    option.vars = {}
    option.vars[const.NGINX_VAR_URL] = const.SINA_QUERY_URL_WEIBO_CLICK
    option.vars[const.NGINX_VAR_HASH_STR] = (args.uid ~= "") and args.uid or args.ip

    local rsp = ngx.location.capture(const.SINA_QUERY_URI, option)
    if rsp.status ~= ngx.HTTP_OK then
        ngx.log(ngx.ERR, "fail to notify sina AD engine to get weibo click log , http status is:", rsp.status)
        return const.EMPTY_TABLE
    end
end

local function logT(logSeparator, t)
    ngx.log(ngx.INFO, logSeparator,
                      t,
                      logSeparator)
end

local function handleDspClick()
    local t = util.decodeLogStr(parser.getClickT())
    local targeting = util.decodeLogStr(parser.getClickTargeting())
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_CLICK,
                      t,
                      const.LOG_SEPARATOR_DSP_CLICK,
                      const.LOG_SEPARATOR_DSP_TARGETING,
                      targeting,
                      const.LOG_SEPARATOR_DSP_TARGETING)
end

local function handleSinaClick()
    local t = util.decodeLogStr(parser.getClickT())
    logT(const.LOG_SEPARATOR_SINA_CLICK, t)
end

local function handleVideoClick()
    local t =  util.decodeLogStr(parser.getClickT())
    logT(const.LOG_SEPARATOR_VIDEO_CLICK, t)
end

local function handleMobileClick()
    local t = util.decodeLogStr(parser.getClickT())
    logT(const.LOG_SEPARATOR_MOBILE_CLICK, t);
end


local function handleWeiboClick()
    local bodyData = parser.getBodyData()
    local status, args = pcall(cjson.decode, bodyData)

    if not status then
        ngx.log(ngx.ERR, args, ":", bodyData)
        ngx.print(const.WEIBO_CLICK_RSP_FAIL)
        ngx.exit(ngx.HTTP_OK);
    end

    ngx.print(const.WEIBO_CLICK_RSP_OK)
    ngx.eof()

    notifySinaAdEngine(args)
end

local function handleYihaodianClick()
    local no1_network_id = "3"
    local separator = "$YHD_CLICK_LOG$"
    local t =  parser.getClickT()
    t = ngx.unescape_uri(t)
    ngx.log(ngx.INFO, separator,
                      t, "\t",
                      no1_network_id,
                      separator)
end

local function handleLoadClick()
    local separator = "$MONITOR_LOAD_LOG$"
    local t = parser.getClickT()
    t = ngx.unescape_uri(t) 
    logT(separator, t)
end

local function handleSubmitClick()
    local separator = "$MONITOR_SUBMIT_LOG$"
    local t = parser.getClickT()
    t = ngx.unescape_uri(t)
    logT(separator, t)
end

local function handleUnLoadClick()
    local separator= "$MONITOR_UNLOAD_LOG$"
    local t = parser.getClickT()
    t = ngx.unescape_uri(t)
    logT(separator, t)
end

local function handleNonStdClick()
    local separator = "$NONSTD_CLICK_LOG$" 
    local t = util.decodeLogStr(parser.getClickT())
    local cookie = parser.getCookie()
    if cookie == "" then cookie = "-" end
    logT(separator, t .. "\t" ..  cookie)
end

local function handleOpenClick()
    local separator = "$FEED_OPEN_LOG$"
    local t = ngx.unescape_uri( parser.getClickT())
    logT(separator, t)
    ngx.header.content_type = 'application/javascript';
end


local function handleStayClick()
    local separator = "$FEED_STAY_LOG$"
    local t = ngx.unescape_uri( parser.getClickT())
    logT(separator, t)
    ngx.header.content_type = 'application/javascript';
end

local function handlePlayClick()
    local separator = "$PLAY_CLICK_LOG$"
    local t = ngx.unescape_uri(parser.getClickT())
   
    logT(separator, t)
end

local function handleNetworkClick()
    local separator = const.LOG_SEPARATOR_NETWORK_CLICK
    local t = util.decodeLogStr(parser.getClickT())
    logT(separator, t)
end

local function handleSaxmobClick()
    local separator =const.LOG_SEPARATOR_SAXMOB_CLICK
    local t = util.decodeLogStr(parser.getClickT())
    logT(separator, t)
end

local function click()
    local clickType = parser.getClickType()
    if clickType == "" then 
        ngx.log(ngx.ERR, "fail to get click type")
        ngx.exit(ngx.HTTP_OK);
    end
 
    if clickType == const.CLICK_TYPE_DSP then 
        handleDspClick()
    elseif clickType == const.CLICK_TYPE_SINA then
        handleSinaClick()
    elseif clickType == const.CLICK_TYPE_MOBILE then
        handleMobileClick()
    elseif clickType == const.CLICK_TYPE_VIDEO then
        handleVideoClick()
    elseif clickType == const.CLICK_TYPE_WEIBO then
        handleWeiboClick()
    elseif clickType == "10" then 
        handleYihaodianClick()
    elseif clickType == "load" then
        handleLoadClick()
    elseif clickType == "submit" then
        handleSubmitClick()
    elseif clickType == "unload" then
        handleUnLoadClick()
    elseif clickType == "nonstd" then
        handleNonStdClick()
    elseif clickType == "open" then
        handleOpenClick()
    elseif clickType == "stay" then
        handleStayClick()
    elseif clickType == "play" then
        handlePlayClick()
    elseif clickType == const.CLICK_TYPE_NETWORK then
        handleNetworkClick()
    elseif clickType == const.CLICK_TYPE_SAXMOB then
        handleSaxmobClick()
    else
        ngx.log(ngx.ERR, "click type not support type=", clickType);
        ngx.exit(ngx.HTTP_OK)
    end
    
    local url = parser.getClickUrl()
    if url == "" then
        return;
    end

    url = ngx.unescape_uri(url)
    local s = parser.getClickSign()

    if s ~= "" then
        local digest = ngx.hmac_sha1(const.NONSTD_CLK_SIGN_KEY, url);
        local sign = string.sub(str.to_hex(digest), 1, 16)
        if sign ~= s then
            return;
        end
    elseif string.find(url, "[\r\n]") then
        return;
    end
    
    ngx.redirect(url)
end

local click = {
    click = click
};

return click;

