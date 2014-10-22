local cjson = require("cjson");
local parser = require("parser");
local util = require("util");
local const = require("const");
local sax = require "sax";
local video_rtb = require "video_rtb";
local pairs = pairs;
local ipairs = ipairs;
local tostring = tostring;
local tonumber = tonumber;
local type = type;
local error = error;
local concat = table.concat;
local insert = table.insert;

local function parseAdReq()
    ngx.ctx.adReq = {};
    local adReq = ngx.ctx.adReq;

    -- parse ad request
    adReq.position = parser.getPosition(); 
    adReq.rotateCount = parser.getRotateCount();
    adReq.length = parser.getLength();
    adReq.site = ngx.unescape_uri(parser.getSite());
    adReq.hostname = ngx.unescape_uri(parser.getHostname());
    adReq.client = ngx.unescape_uri(parser.getClient());
    adReq.vid = ngx.unescape_uri(parser.getVid());
    adReq.movietvid = ngx.unescape_uri(parser.getMovietvid());
    adReq.subid = ngx.unescape_uri(parser.getSubid());
    adReq.srcid = ngx.unescape_uri(parser.getSrcid());
    adReq.channel = ngx.unescape_uri(parser.getChannel());
    adReq.subject = ngx.unescape_uri(parser.getSubject());
    adReq.sports1 = ngx.unescape_uri(parser.getSports1());
    adReq.sports2 = ngx.unescape_uri(parser.getSports2());
    adReq.sports3 = ngx.unescape_uri(parser.getSports3());
    adReq.sports4 = ngx.unescape_uri(parser.getSports4());
    adReq.room = ngx.unescape_uri(parser.getRoom());
    adReq.ip = parser.getIp();
    adReq.cookie = parser.getCookie();
    adReq.userId = parser.getUserId();
    adReq.timestamp = parser.getTimestamp();
    adReq.liveId = ngx.unescape_uri(parser.getLiveId());
    adReq.mediaTags = ngx.unescape_uri(parser.getMediaTags());
    adReq.liveTags = ngx.unescape_uri(parser.getLiveTags());
    adReq.pageUrl = ngx.unescape_uri(parser.getVideoPageUrl());
    adReq.hashCode = ngx.md5(adReq.ip .. adReq.cookie .. adReq.timestamp);

    -- parse referer
    adReq.referer = parser.getReferer();
    adReq.ua = parser.getUserAgent();
    adReq.sid = util.sid(adReq.cookie);
    adReq.adUnitIdList = util.split(adReq.position, ",");
end

local function isValid(adUnitId)
    local adData = ngx.ctx.adData;

    local adUnitObj = adData.adUnitObj;
    if not adUnitObj:isValid(adUnitId) then
        ngx.log(ngx.ERR, "failed to get data of ad unit ", adUnitId);
        return false;
    elseif adUnitObj:getStatus(adUnitId) == const.OBJECT_STATUS_INVALID then
        return false;
    end

    -- get publisher data
    local pubObj = adData.pubObj;

    local pubId = adUnitObj:getPublisher(adUnitId);
    if not pubId then
        return false;
    elseif not pubObj:isValid(pubId) then
        ngx.log(ngx.ERR, "failed to get data of publisher ", pubId);
        return false;
    elseif pubObj:getStatus(pubId) == const.OBJECT_STATUS_INVALID then
        return false;
    end

    -- get resource data
    local resId = pubObj:getResource(pubId);

    local resObj = adData.resObj;
    if not resId then
        return false;
    elseif not resObj:isValid(resId) then
        ngx.log(ngx.ERR, "failed to get data of resource ", resId);
        return false;
    elseif resObj:getStatus(resId) == const.OBJECT_STATUS_INVALID then
        return false;
    end
    
    return true, pubId, resId;

end

local function getAdData()
    local adReq = ngx.ctx.adReq;

    ngx.ctx.adData = {};
    local adData = ngx.ctx.adData;

    adData.adUnitObj = sax.newObject(const.OBJECT_ADUNIT);
    adData.pubObj = sax.newObject(const.OBJECT_PUBLISHER);
    adData.resObj = sax.newObject(const.OBJECT_RESOURCE);
    adData.dspObj = sax.newObject(const.OBJECT_DSP);
    adData.crvObj = sax.newObject(const.OBJECT_CREATIVE);
    adData.advObj = sax.newObject(const.OBJECT_ADVERTISER); 
    -- get publisher data
    adData.pub = {};
    adData.res = {};

    local adPendList = {};
    for _, adUnitId in ipairs(adReq.adUnitIdList) do
        local succ, pubId, resId = isValid(adUnitId);

        if succ then
            adData.pub[adUnitId] = pubId;
            adData.res[adUnitId] = resId;
            adPendList[#adPendList + 1] = adUnitId;
        end
    end

    adData.adPendList = adPendList;
end

local function  buildVideoReq(position)
    local adReq = ngx.ctx.adReq;

    -- query sina ad engine
    local body = {};
    body.adunitId = position;
    body.rotation = adReq.rotateCount; 
    body.length = adReq.length;
    local len = tonumber(adReq.length);
    if len then
        if len < const.VIDEO_LENGTH_THRESH_SHORT then
            body.v_length = const.VIDEO_LENGTH_TYPE_SHORT;
        elseif len > const.VIDEO_LENGTH_THRESH_LONG then
            body.v_length = const.VIDEO_LENGTH_TYPE_LONG;
        else
            body.v_length = const.VIDEO_LENGTH_TYPE_MEDIUM;
        end
    else
        body.v_length = "";
    end
    body.site = adReq.site;
    body.hostname = adReq.hostname;
    body.client = adReq.client;
    body.vid = adReq.vid;
    body.movietvid = adReq.movietvid;
    body.subid = adReq.subid;
    body.srcid = adReq.srcid;
    body.v_cha = adReq.channel;
    body.v_sub = adReq.subject;
    body.v_sports1 = adReq.sports1;
    body.v_sports2 = adReq.sports2;
    body.v_sports3 = adReq.sports3;
    body.v_sports4 = adReq.sports4;
    body.room = adReq.room;
    body.ip = adReq.ip
    body.cookieId = adReq.cookie;
    body.userId = adReq.userId;
    body.hashCode = adReq.hashCode;
    body.liveid = adReq.liveId;
    body.media_tags = adReq.mediaTags;
    body.live_tags = adReq.liveTags;
    body.pageUrl = adReq.pageUrl;
    local jsonStr = cjson.encode(body);

    local option = {};
    option.method = ngx.HTTP_POST;
    option.body = jsonStr;
    option.vars = {};
    option.vars[const.NGINX_VAR_URL] = const.SINA_QUERY_URL_VIDEO;
    option.vars[const.NGINX_VAR_HASH_STR] = (adReq.cookie ~= "") and adReq.cookie or adReq.ip
    return option
   
end


local function checkDspQps(dspAdList)
    --[[
    if ngx.var.arg_istest and ngx.var.arg_noqpslimit then
        return;
    end
    --]]

    local adData = ngx.ctx.adData;
    -- check whether qps threshold of dsp has been reached
    local dspWhiteList = {};

    for dspId, _ in pairs(dspAdList) do
        dspWhiteList[#dspWhiteList + 1] =  dspId;
    end

    local qpsList = adData.dspObj:getQpsInfoList(dspWhiteList);
    for _, dspId in ipairs(dspWhiteList) do
        if qpsList[dspId].limit <= 0 or qpsList[dspId].count > qpsList[dspId].limit then
            ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_QPS,
                          concat(dspAdList[dspId], ","), "\t",
                          dspId,
                          const.LOG_SEPARATOR_DSP_QPS);

            dspAdList[dspId] = nil;
        end
    end
end

local function buildAdRsp(bidctx)
    local result = { ad = {}, cm = {} };

    local adCreativeList = bidctx.adCreativeList;
    local ids  = ngx.ctx.adReq.adUnitIdList;
    for _, id in ipairs (ids) do
        local temp = {}
        temp.pos = id
        if not adCreativeList[id] then
            temp.content  = {}
        else 
            temp.content = adCreativeList[id];
        end
        result.ad[#result.ad + 1] = temp;
    end

    local cmUrlList = bidctx.cmUrlList;

    local tmp = {};
    for i = 1, #cmUrlList do
        tmp[cmUrlList[i]] = true
    end

    cmUrlList = {};
    for k, _ in pairs(tmp) do
        cmUrlList[#cmUrlList + 1] = k
    end

    result.cm = cmUrlList;
    
    local callback = parser.getCallbackFunc()
    if callback ~= "" then
        ngx.print(callback, "(", cjson.encode(result), ")");
    else
        ngx.print(cjson.encode(result));
    end
end

local function logSinaImpress(ad)
    local lineitem = {};
    for _, creative in ipairs(ad.value) do
        lineitem[#lineitem + 1] = creative.lineitemId;
    end

    ngx.log(ngx.DEBUG, "adunit id: ", ad.id,
                       ", limeitem id: ", table.concat(lineitem, " "));
end


local function fillAdCreativeListForSina(ad)
    local adData = ngx.ctx.adData;
    local dspObj = adData.dspObj;
    local resObj = adData.resObj;

    local adCreativeList = ngx.ctx.bidctx.adCreativeList;

    adCreativeList[ad.id] = adCreativeList[ad.id] or {};

    for _, creative in ipairs(ad.value) do
        adCreativeList[ad.id][#adCreativeList[ad.id] + 1] =  creative.content;
    end

    local dspPdAdList = ngx.ctx.bidctx.dspAdList;
    for _, creative in ipairs(ad.value) do

        if not creative.content.src or #creative.content.src == 0 then
            adCreativeList[ad.id] = nil;
            return false;

        elseif creative.content.type[1] == const.PREFERRED_DEAL_TYPE then
            
            local dspId = creative.content.src[1];
            local dspWhiteList = resObj:getPdWhiteList(adData.res[ad.id]);

            if dspId and dspObj:isValid(dspId) and
               dspObj:getStatus(dspId) == const.OBJECT_STATUS_VALID and
               util.isAllowedForPd(dspWhiteList, dspId) then

                dspPdAdList[dspId] = dspPdAdList[dspId] or {};
                dspPdAdList[dspId][#dspPdAdList[dspId] + 1] = ad.id;
            end

            adCreativeList[ad.id] = nil;
            return false;
        end
    end
    return true;
end

local function removeAdFromPendList(adPendList, adUnitId)
    for i, id in ipairs(adPendList) do
        if id == adUnitId then
            table.remove(adPendList, i);
            return;
        end
    end
end

local function handleVideoRsp(queryRsp)
    
    if queryRsp.status ~= ngx.HTTP_OK then
        ngx.log(ngx.ERR, "failed to query sina ad engine, status:" .. queryRsp.status);
        return;
    end

    local status, queryResult = pcall(cjson.decode, queryRsp.body);
    if not status then
        ngx.log(ngx.ERR, queryResult, ":", queryRsp.body);
        return;
    end

    local adPendList = ngx.ctx.adData.adPendList;

    for _, ad in ipairs(queryResult) do
        if #ad.value ~= 0 then
            local flag = fillAdCreativeListForSina(ad);

            -- log sina impression
            logSinaImpress(ad);

            if flag then    -- no null src and no dsp prefel deal
                removeAdFromPendList(adPendList, ad.id);
            end
        end
    end
end

local function querySinaAdEngine(sinaAdList)
    -- query sina video engine
    local option = buildVideoReq(concat(sinaAdList, ","));

    local queryRsp = ngx.location.capture(const.SINA_QUERY_URI, option);

    handleVideoRsp(queryRsp);
end

local function getSinaAdList()
    local adData = ngx.ctx.adData;
    local adPendList = adData.adPendList;

    local sinaAdList = {};
    for _, adUnitId in ipairs(adPendList) do
        if adData.resObj:getFlag(adData.res[adUnitId]) == const.OBJECT_FLAG_SET then
            sinaAdList[#sinaAdList + 1] = adUnitId;
        end
    end
    return sinaAdList;
end

local function getDspPdAdList()
    local dspAdList = ngx.ctx.bidctx.dspAdList;
    checkDspQps(dspAdList);
    return dspAdList;
end

local function getDspAdList()
    local adData = ngx.ctx.adData;
    local dspObj = adData.dspObj;
    local resObj = adData.resObj;
    local adPendList = adData.adPendList;

    local dspAdList = {};
    for _, adUnitId in ipairs(adPendList) do
        -- get dsp data
        local dspIdList = resObj:getWhiteDspList(adData.res[adUnitId]);

        for _, dspId in ipairs(dspIdList) do

            if not dspObj:isValid(dspId) then
                ngx.log(ngx.ERR, "failed to get data of dsp ", dspId);

            elseif dspObj:getStatus(dspId) == const.OBJECT_STATUS_VALID then
                dspAdList[dspId] = dspAdList[dspId] or {};
                dspAdList[dspId][#dspAdList[dspId] + 1] = adUnitId;
            end
        end
    end

    checkDspQps(dspAdList);
    ngx.ctx.bidctx.dspAdList = dspAdList; 
    return dspAdList;
end

local function newimpress()

    parseAdReq();
    
    getAdData();

    ngx.ctx.bidctx = {
        cmUrlList = {},
        adCreativeList = {},
        dspAdList = {}
    };

    local sinaAdList = getSinaAdList();
    if #sinaAdList ~= 0 then
        querySinaAdEngine(sinaAdList);
    end

    local bidctx = ngx.ctx.bidctx;

    -- dsp prefel deal
    local dspPdAdList = getDspPdAdList();
    if next(dspPdAdList) then
        bidctx.at = const.AUCTION_TYPE_PREFERRED_DEAL;
        video_rtb.launchRtbForDsp();
    end 

    -- open rtb
    local dspAdList = getDspAdList();
    if next(dspAdList) then
        bidctx.at = const.AUCTION_TYPE_OPEN_AUCTION;
        video_rtb.launchRtbForDsp();
    end

    buildAdRsp(bidctx);
end

local video = {
    newimpress= newimpress
};

return video;
