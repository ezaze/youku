local cjson = require("cjson");
local parser = require("parser");
local util = require("util");
local const = require("const");
local sax = require("sax");
local mobile_rtb = require("mobile_rtb");

local function parseAdReq()
    -- parse ad request
    local data = parser.getBodyData();
    local status, adReq = pcall(cjson.decode, data);
    if not status then
        ngx.log(ngx.ERR, adReq, ":", data); 
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end

    adReq.device_id = adReq.device_id or "";
    adReq.ip = parser.getIp();
    adReq.targeting = adReq.targeting or {};
    if adReq.targeting.v_length then
        local len = tonumber(adReq.targeting.v_length);
        if len then
            if len >= 30000 then
                adReq.targeting.v_length = "long";
            else
                adReq.targeting.v_length = "short";
            end
        end
    end

    ngx.ctx.adReq = adReq;
end

local function getAdData()
    local adReq = ngx.ctx.adReq;
    
    -- get ad data
    ngx.ctx.adData = {};
    local adData = ngx.ctx.adData;

    adData.adUnitObj = sax.newObject(const.OBJECT_ADUNIT);
    adData.publisherObj = sax.newObject(const.OBJECT_PUBLISHER);
    adData.resourceObj = sax.newObject(const.OBJECT_RESOURCE);
    adData.dspObj = sax.newObject(const.OBJECT_DSP);
    adData.creativeObj = sax.newObject(const.OBJECT_CREATIVE);
    adData.advertiserObj = sax.newObject(const.OBJECT_ADVERTISER); 

    adReq.size_map = {};
    for i, adUnitId in ipairs(adReq.adunit_id) do
        if adReq.size[i] and adReq.size[i] ~= "unknown" then
            adReq.size_map[adUnitId] = adReq.size[i];
        else
            adReq.size_map[adUnitId] = adData.adUnitObj:getSize(adUnitId); 
        end
    end

    adData.pdBidList = {};

    local adPendList = {};
    for _, adUnitId in ipairs(adReq.adunit_id) do
        if adData.adUnitObj:isValid(adUnitId) 
           and adData.adUnitObj:getStatus(adUnitId) == const.OBJECT_STATUS_VALID then
            local publisherId = adData.adUnitObj:getPublisher(adUnitId);

            if adData.publisherObj:isValid(publisherId)
               and adData.publisherObj:getStatus(publisherId) == const.OBJECT_STATUS_VALID then
                local resourceId = adData.publisherObj:getResource(publisherId);

                if adData.resourceObj:isValid(resourceId)
                   and adData.resourceObj:getStatus(resourceId) == const.OBJECT_STATUS_VALID then
                    adPendList[#adPendList + 1] = adUnitId;
                end
            end
        end
    end
 
    return adPendList;
end

local function getSinaQueryList(adPendList)
    local adData = ngx.ctx.adData;

    -- get sina query list
    local sinaQueryList = {};
    for _, adUnitId in ipairs(adPendList) do
        local publisherId = adData.adUnitObj:getPublisher(adUnitId);
        local resourceId = adData.publisherObj:getResource(publisherId);

        if adData.resourceObj:getFlag(resourceId) == const.OBJECT_FLAG_SET then
            sinaQueryList[#sinaQueryList + 1] = adUnitId;
        end
    end

    return sinaQueryList;
end

local function checkDspQps(dspBidList)
    local adData = ngx.ctx.adData;

    -- check whether qps threshold of dsp has been reached
    local dspIdList = {};
    for dspId, _ in pairs(dspBidList) do
        dspIdList[#dspIdList + 1] = dspId;
    end

    local qpsList = adData.dspObj:getQpsInfoList(dspIdList);
    for _, dspId in ipairs(dspIdList) do
        if qpsList[dspId].limit <= 0 or qpsList[dspId].count > qpsList[dspId].limit then
            ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_QPS
                          .. table.concat(dspBidList[dspId], ",") .. "\t"
                          .. dspId
                          .. const.LOG_SEPARATOR_DSP_QPS);

            dspBidList[dspId] = nil;
        end
    end
end

local function getPdBidList()
    local adData = ngx.ctx.adData;

    -- get preferred deal bid list
    local pdBidList = adData.pdBidList;

    checkDspQps(pdBidList);

    return pdBidList;
end

local function getOaBidList(adPendList)
    local adData = ngx.ctx.adData;

    -- get private auction bid list
    local oaBidList = {};
    for _, adUnitId in ipairs(adPendList) do
        local publisherId = adData.adUnitObj:getPublisher(adUnitId);
        local resourceId = adData.publisherObj:getResource(publisherId);

        local dspWhiteList = adData.resourceObj:getWhiteDspList(resourceId);
        for _, dspId in ipairs(dspWhiteList) do
            if adData.dspObj:isValid(dspId)
               and adData.dspObj:getStatus(dspId) == const.OBJECT_STATUS_VALID then
                oaBidList[dspId] = oaBidList[dspId] or {};
                oaBidList[dspId][#oaBidList[dspId] + 1] = adUnitId;
            end
        end
    end

    checkDspQps(oaBidList);

    return oaBidList;
end

local function fillBottomAd(adPendList, adCreativeList)
    local adData = ngx.ctx.adData;

    for _, adUnitId in ipairs(adPendList) do
        local bottomAdList = adData.adUnitObj:getNadList(adUnitId);

        if #bottomAdList ~= 0 then 
            -- random bottomAdList
            local i = 1;
            if #bottomAdList > 1 then
                i = math.random(1, #bottomAdList);
            end
            
            adCreativeList[adUnitId] = {};
            adCreativeList[adUnitId][#adCreativeList[adUnitId] + 1] = bottomAdList[i];
        end
    end
end 


local function buildAdRsp(adCreativeList, cmUrlList)
    local adReq = ngx.ctx.adReq;

    -- build ad response
    local rsp = {};
    rsp.ad = {};
    for _, id in ipairs(adReq.adunit_id) do
        local temp = {};
        temp.id = id;
        if adCreativeList[id] then
            temp.content = adCreativeList[id];
        else
            temp.content = {};
        end

        if #temp.content == 0
           and adReq.client == "sportapp" and adReq.device_platform == "2"
           and (id == 'applivehead' or id == 'applivehead2' or id == 'applivehead3') then
            -- don't fill 
        else
            rsp.ad[#rsp.ad + 1] = temp;
        end
    end
    
    return cjson.encode(rsp);
end

local function impress()
    -- parse ad request
    parseAdReq();

    -- get ad data
    local adPendList = getAdData();

    local adCreativeList = {};
    local cmUrlList = {};

    -- query sina ad engine
    local sinaQueryList = getSinaQueryList(adPendList);
    if #sinaQueryList ~= 0 then
        mobile_rtb.querySinaAdEngine(sinaQueryList, adPendList, adCreativeList);
    end

    -- preferred deal for dsp
    local pdBidList = getPdBidList();
    if next(pdBidList) then
        ngx.ctx.at = const.AUCTION_TYPE_PREFERRED_DEAL;
        mobile_rtb.launchRtbForDsp(pdBidList, adPendList, adCreativeList, cmUrlList);
    end
        
    -- open auction for dsp
    local oaBidList = getOaBidList(adPendList);
    if next(oaBidList) then
        ngx.ctx.at = const.AUCTION_TYPE_OPEN_AUCTION;
        mobile_rtb.launchRtbForDsp(oaBidList, adPendList, adCreativeList, cmUrlList);
    end

    -- fill bottom ad
    if #adPendList ~= 0 then
        fillBottomAd(adPendList, adCreativeList);
    end

    -- build ad response
    local adRsp = buildAdRsp(adCreativeList, cmUrlList);

    -- send ad response
    ngx.print(adRsp);
end

local mobile = {
    impress = impress
}

return mobile;

