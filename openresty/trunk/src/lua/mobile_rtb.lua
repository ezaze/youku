local cjson = require("cjson");
local uuid = require("uuid");
local util = require("util");
local const = require("const");

local function buildQueryReq(sinaQueryList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    -- build query request
    local body = {};
    body.adunitId = table.concat(sinaQueryList, ",");

    local adSizeList = {};
    local adNumList = {};
    for _, adUnitId in ipairs(sinaQueryList) do
        adSizeList[#adSizeList + 1] = adReq.size_map[adUnitId];
        adNumList[#adNumList + 1] = adData.adUnitObj:getAdNum(adUnitId);
    end
    body.size = table.concat(adSizeList, ",");
    body.adNum = table.concat(adNumList, ",");

    body.rotateCount = tostring(adReq.rotate_count);
    body.deviceId = adReq.device_id;
    body.devicePla = adReq.device_platform;
    body.deviceType = adReq.device_type;
    body.ip = adReq.ip;
    body.carrier = adReq.carrier;
    body.client = adReq.client;
    body.intra = adReq.intra;

    for k, v in pairs(adReq.targeting) do
        body[k] = v;
    end

    local option = {};
    option.method = ngx.HTTP_POST;
    option.body = cjson.encode(body);
    option.vars = {};
    option.vars[const.NGINX_VAR_URL] = const.SINA_QUERY_URL_MOBILE;
    option.vars[const.NGINX_VAR_HASH_STR] = (adReq.device_id ~= "") and adReq.device_id or adReq.ip;

    return const.SINA_QUERY_URI, option;
end

local function isValidRsp(rsp)
    if rsp.status ~= ngx.HTTP_OK then
        return false;
    else
        return true;
    end
end

local function fillAdCreativeListForSina(ad, adCreativeList)
    local adData = ngx.ctx.adData;

    adCreativeList[ad.id] = {};
    local flag = true;

    for _, creative in ipairs(ad.value) do
        if creative.content.type[1] == const.PREFERRED_DEAL_TYPE then
            local publisherId = adData.adUnitObj:getPublisher(ad.id);
            local resourceId = adData.publisherObj:getResource(publisherId);
            local dspWhiteList = adData.resourceObj:getPdWhiteList(resourceId);

            local dspId = creative.content.src[1];
            if dspId and adData.dspObj:isValid(dspId)
               and adData.dspObj:getStatus(dspId) == const.OBJECT_STATUS_VALID
               and util.isAllowedForPd(dspWhiteList, dspId) then
                adData.pdBidList[dspId] = adData.pdBidList[dspId] or {};
                adData.pdBidList[dspId][#adData.pdBidList[dspId] + 1] = ad.id;
            end

            adCreativeList[ad.id] = nil;
            flag = false;
            break;
        else
            creative.content.begin_time = creative.content.beginTime;
            creative.content.beginTime = nil;
            creative.content.end_time = creative.content.endTime;
            creative.content.endTime = nil;
            creative.content.lineitem_id = creative.lineitemId;

            adCreativeList[ad.id][#adCreativeList[ad.id] + 1] = creative.content; 
        end
    end

    return flag;
end

local function logSinaImpress(ad)
    local lineItemList = {};
    for _, creative in ipairs(ad.value) do
        lineItemList[#lineItemList + 1] = creative.lineitemId;
    end

    ngx.log(ngx.DEBUG, "ad unit id:" .. ad.id
                       .. ", line item id:" .. table.concat(lineItemList, ","));
end

local function removeAdFromPendList(adPendList, adUnitId)
    for i, id in ipairs(adPendList) do
        if id == adUnitId then
            table.remove(adPendList, i);
            return;
        end
    end
end

local function handleQueryRsp(queryRsp, adPendList, adCreativeList)
    -- check query response
    if not isValidRsp(queryRsp) then
        ngx.log(ngx.ERR, "failed to query sina ad engine, status:" .. queryRsp.status);

        return;
    end

    -- handle query result
    local status, queryResult = pcall(cjson.decode, queryRsp.body);
    if not status then
        ngx.log(ngx.ERR, queryResult .. ":" .. queryRsp.body);

        return;
    end

    for _, ad in ipairs(queryResult) do
        if #ad.value ~= 0 then
            -- fill ad creative list
            local flag = fillAdCreativeListForSina(ad, adCreativeList);

            -- log sina impress
            logSinaImpress(ad);

            -- remove ad unit from pending list
            if flag then
                removeAdFromPendList(adPendList, ad.id);
            end
        end
    end
end

local function querySinaAdEngine(sinaQueryList, adPendList, adCreativeList)
    -- build query request
    local uri, option = buildQueryReq(sinaQueryList);

    -- send query request
    local queryRsp = ngx.location.capture(uri, option);

    -- handle query response
    handleQueryRsp(queryRsp, adPendList, adCreativeList);
end

local function getFloorPrice(adUnitId)
    local adData = ngx.ctx.adData;

    if ngx.ctx.at == const.AUCTION_TYPE_PREFERRED_DEAL then
        return 0;
    end

    local publisherId = adData.adUnitObj:getPublisher(adUnitId);
    return adData.publisherObj:getLowestPrice(publisherId);
end

local function logDspReq(dspId, adUnitList)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_REQ
                      .. ngx.ctx.bid .. "\t"
                      .. dspId .. "\t"
                      .. table.concat(adUnitList, ",")
                      .. const.LOG_SEPARATOR_DSP_REQ);
end

local function buildBidReq(dspBidList, dspIdList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    ngx.ctx.uuid = uuid.generate("random");
    ngx.ctx.bid = uuid.unparse(ngx.ctx.uuid);

    -- build bid request
    local bidReqList = {};
    for dspId, adUnitList in pairs(dspBidList) do
        local body = {};
        body.id = ngx.ctx.bid;

        body.imp = {};
        for _, adUnitId in ipairs(adUnitList) do
            local temp = {};
            temp.id = adUnitId;
            temp.bidfloor = getFloorPrice(adUnitId);
            temp.banner = {};
            temp.banner.type = adData.adUnitObj:getDisplayType(adUnitId);
            local size = util.split(adReq.size_map[adUnitId] or "", "*");
            temp.banner.w = tonumber(size[1]);
            temp.banner.h = tonumber(size[2]);
            temp.banner.num = adData.adUnitObj:getAdNum(adUnitId);

            body.imp[#body.imp + 1] = temp;
        end
        body.at = ngx.ctx.at;

        body.app = {};
        body.app.name = adReq.client;
        body.app.cat = "";

        body.device = {};
        body.device.ip = adReq.ip;
        body.device.os = tonumber(adReq.device_platform);
        body.device.devicetype = tonumber(adReq.device_type);
        body.device.connectiontype = tonumber(adReq.carrier);

        body.user = {};
        body.user.id = adReq.device_id;

        local temp = {};
        temp[1] = const.DSP_BID_URI;
        temp[2] = {};
        temp[2].method = ngx.HTTP_POST;
        temp[2].body = cjson.encode(body);

        temp[2].vars = {};
        if dspId == const.SINA_DSP_ID then
        else
            local url = adData.dspObj:getRTBUrl(dspId);
            if dspId == const.DSP_ID_IPINYOU then
                url = url .. "/app";
            end

            temp[2].vars[const.NGINX_VAR_URL] = url;
        end

        bidReqList[#bidReqList + 1] = temp;
        dspIdList[#dspIdList + 1] = dspId;
    
        -- log dsp request
        logDspReq(dspId, adUnitList);
    end

    return bidReqList;
end

local function getBidResult(bidRsp)
    local bidResult = cjson.decode(bidRsp.body);
    
    if type(bidResult) ~= "table" then
        error("invalid bid response");
    end

    if type(bidResult.id) ~= "string" then
        error("invalid field bid");
    end

    if type(bidResult.cm) ~= "number" then
        error("invalid field cm");
    end

    if bidResult.bid then
        if type(bidResult.bid) ~= "table" then
            error("invalid field bid");
        end

        for _, bid in ipairs(bidResult.bid) do
            if type(bid.id) ~= "string" then
                error("invalid field id");
            end

            if type(bid.price) ~= "number" then
                error("invalid field price");
            end

            if type(bid.ad) ~= "table" then
                error("invalid field ad");
            end

            for _, ad in ipairs(bid.ad) do
                if type(ad.id) ~= "string" then
                    error("invalid field id");
                end

                if type(ad.markup) ~= "string" then
                    error("invalid field markup");
                end
            end
        end
    end
    
    return bidResult;
end

local function isValidCreative(dspId, creativeId)
    local adData = ngx.ctx.adData;

    if not adData.creativeObj:isValid(dspId, creativeId)
       or adData.creativeObj:getStatus(dspId, creativeId) == const.OBJECT_STATUS_INVALID then
        return false;
    end

    local advertiserId = adData.creativeObj:getAdvertiserId(dspId, creativeId);
    if not adData.advertiserObj:isValid(dspId, advertiserId)
       or adData.advertiserObj:getStatus(dspId, advertiserId) == const.OBJECT_STATUS_INVALID then
        return false;
    end

    local advertiserType = adData.advertiserObj:getType(dspId, advertiserId);
    if not util.checkAdvertiserType(ngx.ctx.at, advertiserType) then
        return false;
    end

    return true;
end

local function logDspFoul(dspId, adUnitId, creativeId)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_FOUL
                     .. ngx.ctx.bid .. "\t"
                     .. dspId .. "\t"
                     .. adUnitId .. "\t"
                     .. creativeId
                     .. const.LOG_SEPARATOR_DSP_FOUL);
end

local function logDspRsp(dspId, bid)
    local adData = ngx.ctx.adData;

    local creativeLog = {};
    for _, ad in ipairs(bid.ad) do
        local id = adData.creativeObj:getUniqueId(dspId, ad.id);
        if not id then
            id = "invalid"
        end
        local str = "(" .. ad.id .. "," .. id .. ")";

        creativeLog[#creativeLog + 1] = str;
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_RSP
                      .. ngx.ctx.bid .. "\t"
                      .. dspId .. "\t"
                      .. bid.id .. "\t"
                      .. bid.price .. "\t"
                      .. table.concat(creativeLog, ",")
                      .. const.LOG_SEPARATOR_DSP_RSP);
end

local function logDspNull(dspId)
    ngx.log(ngx.DEBUG, const.LOG_SEPARATOR_DSP_NULL
                      .. ngx.ctx.bid .. "\t"
                      .. dspId 
                      .. const.LOG_SEPARATOR_DSP_NULL);
end

local function logDspInvalid(dspId)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_INVALID 
                      .. ngx.ctx.bid .. "\t"
                      .. dspId  
                      .. const.LOG_SEPARATOR_DSP_INVALID) ;
end

local function logDspFail(dspId, phase, status)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_FAIL
                     .. ngx.ctx.bid .. "\t"
                     .. dspId .. "\t"
                     .. phase .. "\t"
                     .. status
                     .. const.LOG_SEPARATOR_DSP_FAIL);
end

local function fillCmUrlList(dspId, cmUrlList)
    local args = {};
    args[const.RTB_CM_ARG_NID] = dspId;

    local url = "";
    url = const.RTB_CM_URL .. "?" .. ngx.encode_args(args);

    cmUrlList[#cmUrlList + 1] = url;
end

local function extractAdBid(bidRspList, dspIdList, cmUrlList)
    -- extract ad bid
    local adBidList = {};

    for i, bidRsp in ipairs(bidRspList) do
        if isValidRsp(bidRsp) then 
            local status, bidResult = pcall(getBidResult, bidRsp);
            if status then
                if bidResult.bid and #bidResult.bid ~= 0 then
                    for _, bid in ipairs(bidResult.bid) do
                        if bid.price >= getFloorPrice(bid.id) then
                            local temp = {};
                            temp.dsp_id = dspIdList[i];
                            temp.max_cpm_price = bid.price;

                            temp.creative = {};
                            for _, ad in ipairs(bid.ad) do
                                if isValidCreative(dspIdList[i], ad.id) then
                                    temp.creative[#temp.creative + 1] = ad;
                                else
                                    -- log dsp foul
                                    logDspFoul(dspIdList[i], bid.id, ad.id);
                                end
                            end

                            if #temp.creative ~= 0 then
                                adBidList[bid.id] = adBidList[bid.id] or {};
                                adBidList[bid.id][#adBidList[bid.id] + 1] = temp;
                            end
                        end

                        -- log dsp response
                        logDspRsp(dspIdList[i], bid);
                    end
                else   
                    -- log dsp null
                    logDspNull(dspIdList[i])
                end

                -- fill cookie mapping URL list
                if bidResult.cm == 1 then
                    fillCmUrlList(dspIdList[i], cmUrlList);
                end
            else
                ngx.log(ngx.ERR, "bid:" .. ngx.ctx.bid
                                 .. ", dsp id:" .. dspIdList[i] 
                                 .. ", " .. bidResult 
                                 .. ":" .. bidRsp.body);

                -- log dsp invalid
                logDspInvalid(dspIdList[i])
            end
        else
            -- log dsp fail
            logDspFail(dspIdList[i], const.RTB_PHASE_BID, bidRsp.status);
        end
    end

    return adBidList;
end

local function cmpPrice(a, b)
    return a.max_cpm_price > b.max_cpm_price
end

local function selectWinner(adUnitId, bidInfo)
    local adData = ngx.ctx.adData;

    -- sort bid information
    if #bidInfo ~= 1 then
        table.sort(bidInfo, cmpPrice);
    end

    -- select winner
    local second = 0;
    for i = 2, #bidInfo do
        if bidInfo[i].max_cpm_price ~= bidInfo[1].max_cpm_price then
            second = i;
            break;
        end
    end

    local winner = {};
    if second ~= 0 then
        local first = 1;
        if second - 1 ~= 1 then
            first = math.random(1, second - 1);
        end

        winner.dsp_id = bidInfo[first].dsp_id;
        winner.win_cpm_price = bidInfo[second].max_cpm_price + const.RTB_EXTRA_PRICE;
        winner.creative = bidInfo[first].creative;
    else
        local first = 1;
        if #bidInfo ~= 1 then
            first = math.random(1, #bidInfo);
        end

        winner.dsp_id = bidInfo[first].dsp_id;
        winner.win_cpm_price = getFloorPrice(adUnitId);
        winner.creative = bidInfo[first].creative;
    end

    return winner;
end

local function generateViewUrl(dspId, adUnitId, creativeId, winCpmPrice)
    local adData = ngx.ctx.adData;

    local args = {};
    args[const.RTB_VIEW_ARG_TYPE] = const.VIEW_TYPE_DSP;
    local log = ngx.ctx.bid .. "\t"
                .. dspId .. "\t"
                .. adUnitId .. "\t"
                .. winCpmPrice .. "\t"
                .. creativeId .. "\t"
                .. adData.creativeObj:getUniqueId(dspId, creativeId);

    local t = ngx.encode_base64(log);
    args[const.RTB_VIEW_ARG_T] = t;

    return const.RTB_VIEW_URL .. "?" .. ngx.encode_args(args);
end

local function generateClickUrl(dspId, adUnitId, creativeId)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    local args = {};
    args[const.RTB_CLICK_ARG_TYPE] = const.CLICK_TYPE_DSP;
    local log = ngx.ctx.bid .. "\t"
                .. dspId .. "\t"
                .. adUnitId .. "\t"
                .. creativeId .. "\t"
                .. adData.creativeObj:getUniqueId(dspId, creativeId);
    local t = ngx.encode_base64(log);
    args[const.RTB_CLICK_ARG_T] = t;
    log = "-" .. "\t"
          .. ((adReq.ip ~= "") and adReq.ip or "-") .. "\t"
          .. ((adReq.device_id ~= "") and adReq.device_id or "-");
    local targeting = ngx.encode_base64(log);
    args[const.RTB_CLICK_ARG_TARGETING] = targeting;

    return const.RTB_CLICK_URL .. "?" .. ngx.encode_args(args);
end

local function alterThirdPartyDspCreative(creative, dspId, adUnitId, winCpmPrice)
    local adData = ngx.ctx.adData;

    local status, result = pcall(cjson.decode, creative.markup)
    if status then
        -- expand winning price macro
        local eKey = adData.dspObj:getEncryptionKey(dspId);
        local iKey = adData.dspObj:getIntegrityKey(dspId);
        local msg = util.encryptPrice(ngx.ctx.uuid, eKey, iKey, winCpmPrice);
        msg = ngx.escape_uri(msg);

        for i, url in ipairs(result.view) do
            result.view[i] = ngx.re.gsub(url, const.RTB_MACRO_WIN_PRICE, msg, "jo");
        end

        -- add view url
        local url = generateViewUrl(dspId, adUnitId, creative.id, winCpmPrice);
        table.insert(result.view, 1, url);

        -- add click-through url
        url = generateClickUrl(dspId, adUnitId, creative.id);
        table.insert(result.click, 1, url);

        result.pv = result.view;
        result.view = nil;
        result.monitor = result.click;
        result.click = nil;
        result.lineitem_id = "dsp-" .. dspId .. "-" .. creative.id;

        return result;
    else 
        ngx.log(ngx.ERR, result .. ":" .. creative.markup)

        return "";
    end
end

local function fillAdCreativeListForDsp(adUnitId, winner, adCreativeList)
    adCreativeList[adUnitId] = {};

    for _, creative in ipairs(winner.creative) do
        local temp = {};
        if winner.dsp_id == const.SINA_DSP_ID then
        else
            temp = alterThirdPartyDspCreative(creative, winner.dsp_id, adUnitId, winner.win_cpm_price);
        end

        adCreativeList[adUnitId][#adCreativeList[adUnitId] + 1] = temp;
    end
end

local function logDspWin(adUnitId, winner)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    local creativeLog = {};
    for _, creative in ipairs(winner.creative) do
        local str = "(" .. creative.id .. ","
                    .. adData.creativeObj:getUniqueId(winner.dsp_id, creative.id) .. ")";
        table.insert(creativeLog, str);
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_CFM
                      .. ngx.ctx.bid .. "\t"
                      .. winner.dsp_id .. "\t"
                      .. adUnitId .. "\t"
                      .. winner.win_cpm_price .. "\t"
                      .. table.concat(creativeLog, ",")
                      .. const.LOG_SEPARATOR_DSP_CFM
                      .. const.LOG_SEPARATOR_DSP_TARGETING  
                      .. "-" .. "\t"
                      .. ((adReq.ip ~= "") and adReq.ip or "-") .. "\t"
                      .. ((adReq.device_id ~= "") and adReq.device_id or "-")
                      .. const.LOG_SEPARATOR_DSP_TARGETING);
end

local function handleBidRsp(bidRspList, dspIdList, adPendList, adCreativeList, cmUrlList)
    -- extract ad bid
    local adBidList = extractAdBid(bidRspList, dspIdList, cmUrlList);

    -- conduct auction 
    for adUnitId, bidInfo in pairs(adBidList) do
        -- select winner 
        local winner = selectWinner(adUnitId, bidInfo);
        
        -- fill ad creative list
        fillAdCreativeListForDsp(adUnitId, winner, adCreativeList);

        -- log dsp win
        logDspWin(adUnitId, winner);

        -- remove ad unit from pending list
        removeAdFromPendList(adPendList, adUnitId);
    end
end

local function launchRtbForDsp(dspBidList, adPendList, adCreativeList, cmUrlList)
    -- build bid request
    local dspIdList = {};
    local bidReqList = buildBidReq(dspBidList, dspIdList);

    -- send bid request
    local bidRspList = {ngx.location.capture_multi(bidReqList)};

    -- handle bid response
    handleBidRsp(bidRspList, dspIdList, adPendList, adCreativeList, cmUrlList);
end

local mobile_rtb = {
    querySinaAdEngine = querySinaAdEngine,
    launchRtbForDsp = launchRtbForDsp,
};

return mobile_rtb;

