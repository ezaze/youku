local cjson = require("cjson");
local parser = require("parser");
local util = require("util");
local const = require("const");

local function buildAdRsp(retCode, creativeList)
    -- build ad response
    local adRsp = {};
    adRsp.retcode = retCode;
    adRsp.creatives = creativeList;

    return cjson.encode(adRsp);
end


local function parseAdReq()
    -- parse ad request
    local data = parser.getBodyData();
    local status, adReq = pcall(cjson.decode, data);
    if not status then
        ngx.log(ngx.ERR, adReq .. ":" .. data); 

        local adRsp = buildAdRsp(-10001, {});
        ngx.print(adRsp);
        ngx.exit(ngx.HTTP_OK);
    end

    ngx.ctx.adReq = adReq;
end

local function querySinaAdEngine()
    local adReq = ngx.ctx.adReq;

    -- query sina ad engine
    local body = {};
    body.adunit_id = adReq.posid;
    body.size = adReq.sw .. "*" .. adReq.sh;
    body.ad_num = adReq.adcnt;
    body.uid = adReq.uid;
    body.ip = adReq.ip;
    body.ua = adReq.ua;
    body.area = adReq.area;
    body.carries = adReq.carries;
    local jsonStr = cjson.encode(body);

    local option = {};
    option.method = ngx.HTTP_POST;
    option.body = jsonStr;
    option.vars = {};

    --add platform as get param
    local platform = adReq.platform
    if platform ~= nil and platform ~= "" then
        option.vars[const.NGINX_VAR_URL] = const.SINA_QUERY_URL_WEIBO_IMPRESS .. "?" .. "platform=" .. platform
    else
        option.vars[const.NGINX_VAR_URL] = const.SINA_QUERY_URL_WEIBO_IMPRESS;    
    end

    option.vars[const.NGINX_VAR_HASH_STR] = (adReq.uid ~= "") and adReq.uid or adReq.ip

    local queryRsp = ngx.location.capture(const.WEIBO_QUERY_URI, option);
    if queryRsp.status ~= ngx.HTTP_OK then
        ngx.log(ngx.ERR, "failed to query sina ad engine, status:" .. queryRsp.status);

        return -20001, {};
    end

    local status, queryResult = pcall(cjson.decode, queryRsp.body);
    if not status then
        ngx.log(ngx.ERR, queryResult .. ":" .. queryRsp.body);
        
        return -20002, {};
    end

    local creativeList = {};
    for _, creative in ipairs(queryResult.ad) do
        local temp = {};
        temp.adid =  creative.ad_id;
        temp.sourceurl = creative.src[1];
        temp.adurl = creative.link[1];
        temp.type = creative.type[1];
        temp.begintime = creative.begin_time;
        temp.endtime = creative.end_time;
        temp.tokenid = creative.tokenid;
        temp.freq = creative.freq
        table.insert(creativeList, temp);
    end

    return 0, creativeList;
end

local function impress()
    -- parse ad request
    parseAdReq();

    -- query sina ad engine
    local retCode, creativeList = querySinaAdEngine();

    -- build ad response
    local adRsp = buildAdRsp(retCode, creativeList);

    -- send ad response and rely on client to close the connection actively
    ngx.print(adRsp);
end

local function notifySinaAdEngine() 
    local logReq = ngx.ctx.logReq;

    -- build request body
    local body = {}
    body.adunit_id = logReq.posid
    body.size = logReq.sw .. "*" .. logReq.sh
    body.uid = logReq.uid
    body.ip = logReq.ip
    body.ua = logReq.ua
    body.area = logReq.area
    body.carries = logReq.carries
    body.ad_show = logReq.ads
    body.ad_count = logReq.adshowcount
    body.ad_close = logReq.adclose
    local jsonStr = cjson.encode(body)

    local option = {}
    option.body = jsonStr
    option.vars = {}
    option.vars[const.NGINX_VAR_URL] = const.SINA_QUERY_URL_WEIBO_LOG;
    option.vars[const.NGINX_VAR_HASH_STR] = (logReq.uid ~= "") and logReq.uid or logReq.ip

    local queryRsp = ngx.location.capture(const.SINA_QUERY_URI, option);
    if queryRsp.status ~= ngx.HTTP_OK then
        ngx.log(ngx.ERR, "failed to notify sina ad engine to process impress log, status:" )
        return const.EMPTY_TABLE,   const.EMPTY_TABLE,  const.EMPTY_TABLE
    end

    local status, queryResult = pcall(cjson.decode, queryRsp.body)
    if not status  then
         ngx.log(ngx.ERR, queryResult .. ":" .. queryRsp.body)
         return const.EMPTY_TABLE,  const.EMPTY_TABLE,  const.EMPTY_TABLE
    end

    return queryResult.url
end

local function log()
    -- log weibo impression
    local data = parser.getBodyData();
    local status, logReq = pcall(cjson.decode, data);
    if not status then
        ngx.log(ngx.ERR, logReq.. ":" .. data)
        ngx.print("FAIL");
        ngx.exit(ngx.HTTP_OK)
    end

    ngx.print("OK")
    ngx.eof();

    -- notify sina engine 
    ngx.ctx.logReq = logReq
    local urlList = notifySinaAdEngine()

    -- send third party monitor
    if urlList and #urlList ~= 0 then
        util.notifyThirdPartyMonitor(urlList)
    end
end 

local weibo = {
    impress = impress,
    log = log
    
};

return weibo;

