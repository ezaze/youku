local cjson = require("cjson");
local uuid = require("uuid");
local struct = require("struct");
local bit = require("bit");
local util = require("util");
local const = require("const");

local function buildQueryReq(sinaQueryList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    -- generate query request body
    local body = {};
    body.adunitId = table.concat(sinaQueryList, ",");
    body.rotateCount = adReq.rotateCount;
    body.cookieId = adReq.cookie;
    body.userId = adReq.userId;
    body.ip = adReq.ip;
    body.pageUrl = adReq.pageUrl; 
    body.pageKeyword = adReq.pageKeyword;
    body.pageEntry = adReq.pageEntry;
    body.pageTemplate = adReq.pageTemplate;
    body.hashCode = adReq.hashCode;
    body.version = adReq.version;
    body.ua = adReq.userAgent;

    -- add channel msg
    local adUnitObj = adData.adUnitObj
    local channelList = {}

    for _ , v in ipairs (sinaQueryList) do
        table.insert(channelList, adUnitObj:getChannel(v))
    end

    body.channel = table.concat(channelList, ",")
    local jsonStr = cjson.encode(body); 

    -- build query request
    local option = {};
    option.method = ngx.HTTP_POST;
    option.body = jsonStr;
    option.vars = {};
    option.vars[const.NGINX_VAR_URL] = const.SINA_QUERY_URL_SINA;
    option.vars[const.NGINX_VAR_HASH_STR] = (adReq.cookie ~= "") and adReq.cookie or adReq.ip

    return const.SINA_QUERY_URI, option;
end

local function isValidRsp(rsp)
    if rsp.status ~= ngx.HTTP_OK then
        return false;
    else
        return true;
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

local function fillAdCreativeListForSina(ad, adCreativeList)
    local adData = ngx.ctx.adData;
    adCreativeList[ad.id] = adCreativeList[ad.id] or {};
    adCreativeList[ad.id].content = adCreativeList[ad.id].content or {};

    for _, creative in ipairs(ad.value) do
        if next(creative.content) then
            if creative.content.type[1] == const.PREFERRED_DEAL_TYPE then
                local dspId = creative.content.src[1];
                if dspId and 
                   adData.dspObj:isValid(dspId) and 
                   adData.dspObj:getStatus(dspId) == const.OBJECT_STATUS_VALID then
                    if not adData.preDealQueryList[dspId] then
                        adData.preDealQueryList[dspId] = {};
                    end

                    table.insert(adData.preDealQueryList[dspId], ad.id);
                end
            else
                local temp = creative.content;
                temp.adId = creative.lineitemId;
                table.insert(adCreativeList[ad.id].content, temp);
            end

        end
    end
end

local function getLeftAdNum(adUnitId, adCreativeList)
    local adData = ngx.ctx.adData;
    local total;

    local adType = adData.adUnitObj:getDisplayType(adUnitId)
    if(adType == "fp") then
        total = 1;
    else
        total = adData.adUnitObj:getAdNum(adUnitId);
    end

    local used = adCreativeList[adUnitId] and #adCreativeList[adUnitId].content or 0;
    return total - used;
end

-- you need call getLeftAdNum before call this function
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
            fillAdCreativeListForSina(ad, adCreativeList);

            -- log sina impression
            logSinaImpress(ad);

            -- remove ad unit from pending list
            if getLeftAdNum(ad.id, adCreativeList) <= 0 then
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

local function getAdSizeNo(size)
    if size == "950*90" then
        return "001";
    elseif size == "300*250" then
        return "002";
    elseif size == "250*230" then
        return "003";
    elseif size == "640*90" then
        return "004";
    elseif size == "300*120" then
        return "005";
    elseif size == "240*120" then
        return "006";
    elseif size == "340*120" then
        return "007";
    elseif size == "1000*90" then
        return "008";
    elseif size == "240*60" then
        return "009";
    elseif size == "240*200" then
        return "010";
    elseif size == "250*90" then
        return "011";
    elseif size == "250*120" then
        return "012";
    elseif size == "355*200" then
        return "013";
    elseif size == "360*110" then
        return "014";
    elseif size == "585*90" then
        return "015";
    elseif size == "260*120" then
        return "016";
    elseif size == "240*170" then
        return "017";
    elseif size == "350*110" then
        return "018";
    elseif size == "125*95" then
        return "019";
    elseif size == "200*200" then
        return "020";
    elseif size == "196*130" then
        return "021";
    elseif size == "320*115" then
        return "022";
    elseif size == "230*90" then
        return "023";
    elseif size == "300*60" then
        return "024";
    elseif size == "300*100" then
        return "025"
    elseif size == "320*190" then
        return "026"
    elseif size == "210*220" then
        return "027"
    else 
        return size;
    end
end

local function logDspReq(adUnitList, dspId)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_REQ
                      .. ngx.ctx.bid .. "\t"
                      .. dspId .. "\t"
                      .. table.concat(adUnitList, ",")
                      .. const.LOG_SEPARATOR_DSP_REQ);
end

local function getAdLowestPrice(adUnitId)
    local adData = ngx.ctx.adData;

    -- preferred deal price 0
    if adData.auction_type == const.AUCTION_TYPE_PREFERRED_DEAL then
        return 0;
    end

    local publisherId = adData.adUnitObj:getPublisher(adUnitId);

    return adData.publisherObj:getLowestPrice(publisherId);
end


local function buildOldBidReqBody(adUnitList, adCreativeList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    -- build bid request body
    local body = {};
    body.version = const.RTB_VERSION;

    body.bid = ngx.ctx.bid;

    body.sid = util.sid(adReq.cookie);
    body.ip = adReq.ip;
    body.page_url = adReq.pageUrl;
    body.user_agent = adReq.userAgent;
    body.ad_unit = {};
    body.excluded_product_category = {};
    body.excluded_sensitive_category = {};
    body.excluded_click_through_url = {};

    for _, adUnitId in ipairs(adUnitList) do
        local temp = {};
        temp.id = adUnitId;
        temp.type = adData.adUnitObj:getDisplayType(adUnitId);

        local size = adData.adUnitObj:getSize(adUnitId);
        temp.size = getAdSizeNo(size);

        temp.pos = adData.adUnitObj:getLocation(adUnitId);
        temp.creative_num = getLeftAdNum(adUnitId, adCreativeList);
        temp.excluded_creative_category = adData.adUnitObj:getAdTypeList(adUnitId);
        temp.min_cpm_price = getAdLowestPrice(adUnitId);

        table.insert(body.ad_unit, temp);
    end
    return body
end

local function buildBidReqBody(adUnitList, adCreativeList)
    -- build bid request body
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    local body = {};
    body.id = ngx.ctx.bid;
    body.at = adData.auction_type;
    body.site = {
        page = adReq.pageUrl
    }
    body.device = {
        ip = adReq.ip,
        ua = adReq.userAgent
    }
    body.user = {
        id = util.sid(adReq.cookie)
    }
    body.bcat = {}
    body.badv = {}
    body.imp = {}

    for _, adUnitId in ipairs(adUnitList) do
        local temp = {};
        temp.id = adUnitId;
        temp.bidfloor = getAdLowestPrice(adUnitId);

        local wdht = util.split(adData.adUnitObj:getSize(adUnitId), "*");
        local banner = {
            type = adData.adUnitObj:getDisplayType(adUnitId),
            w = wdht[1],
            h = wdht[2],
            num = getLeftAdNum(adUnitId, adCreativeList),
            pos = adData.adUnitObj:getLocation(adUnitId),
        }
        temp.banner = banner;

        table.insert(body.imp, temp);
    end
    return body
end

local version = {}
version["17"] = true

local function buildBidReq(queryDspList, dspBidList, adCreativeList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    ngx.ctx.uuid = uuid.generate("random");
    ngx.ctx.bid = uuid.unparse(ngx.ctx.uuid);

    local bidReqList = {};
    for dspId, adUnitList in pairs(queryDspList) do
        local body;
        if not version[dspId] then
            body = buildOldBidReqBody(adUnitList, adCreativeList);
        else
            body = buildBidReqBody(adUnitList, adCreativeList);
        end

        local temp = {};
        temp[1] = const.DSP_BID_URI;
        temp[2] = {};
        temp[2].method = ngx.HTTP_POST;
        temp[2].body = cjson.encode(body);

        temp[2].vars = {};
        if dspId == const.SINA_DSP_ID then
            local sinaBidUrl = adData.dspObj:getRTBUrl(dspId);

            local notation = "";
            local capture = ngx.re.match(sinaBidUrl, [[\?]], "jo");
            if capture then
                notation = "&"; 
            else
                notation = "?";
            end

            local sinaDspArgs = {};
            sinaDspArgs[const.SINA_DSP_BID_ARG_HASHCODE] = adReq.hashCode;
            sinaDspArgs[const.SINA_DSP_BID_ARG_COOKIE] = adReq.cookie;
            sinaDspArgs[const.SINA_DSP_BID_ARG_VERSION] = adReq.version;

            temp[2].vars[const.NGINX_VAR_URL] = sinaBidUrl .. 
                                                notation .. 
                                                ngx.encode_args(sinaDspArgs);
        else
            local bidUrl = adData.dspObj:getRTBUrl(dspId);
            if dspId == "1" and adReq.publisherType == const.WAP_PUBLISHER then
                bidUrl = bidUrl .. "/gm"
            end
            temp[2].vars[const.NGINX_VAR_URL] = bidUrl;
        end
        temp[2].vars[const.NGINX_VAR_HASH_STR] = (adReq.cookie ~= "") and 
                                                  adReq.cookie or 
                                                  adReq.ip

        bidReqList[#bidReqList + 1] =  temp;
        dspBidList[#dspBidList + 1] =  dspId;

        -- log dsp request
        logDspReq(adUnitList, dspId);

    end
    return bidReqList;
end


local function getBidResult(bidRsp, new)
    local bidResult = cjson.decode(bidRsp.body);
    
    if new then return bidResult end

    for _, ad in ipairs(bidResult.ad_creative) do
        for _, creative in ipairs(ad.creative) do
            creative.markup = creative.html_snippet;
            creative.html_snippet = nil;
        end
        ad.price = ad.max_cpm_price;
        ad.max_cpm_price = nil;

        ad.ad = ad.creative;
        ad.creative = nil;
    end

    bidResult.id = bidResult.bid;
    bidResult.bid = bidResult.ad_creative;
    bidResult.cm = (bidResult.cm_flag == "true") and 1 or 0;

    return bidResult;
end

local function validBidResult(bidResult)
    if type(bidResult) ~= "table" then
        error("invalid bid response");
    end

    if type(bidResult.id) ~= "string" then
        error("invalid field rsp.id or rsp.bid");
    end

    if bidResult.cm ~= 0 and bidResult.cm ~= 1 then
        error("invalid field rsp.cm or rsp.cm_flag");
    end

    if not bidResult.bid then
        return bidResult;
    elseif type(bidResult.bid) ~= "table" then
        error("invalid field rsp.bid or rsp.ad_creative");
    end

    for _, bid in ipairs(bidResult.bid) do
        if type(bid.id) ~= "string" then
            error("invalid field bid.id or ad_creative.id");
        end

        if type(bid.price) ~= "number" then
            error("invalid field bid.price or ad_creative.max_cpm_price");
        end

        if type(bid.ad) ~= "table" or #bid.ad == 0 then
            error("invalid field bid.ad or ad_creative.creative");
        end

        for _, ad in ipairs(bid.ad) do
            if type(ad.id) ~= "string" then
                error("invalid field ad.id or creative.id");
            end

            if type(ad.markup) ~= "string" then
                error("invalid field ad.markup or craetive.html_snippet");
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

    local adLog = {};
    for _, ad in ipairs(bid.ad) do
        local id = adData.creativeObj:getUniqueId(dspId, ad.id);
        if not id then
            id = "invalid"
        end
        local str = "(" .. ad.id .. "," .. id .. ")";

        table.insert(adLog, str);
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_RSP
                      .. ngx.ctx.bid .. "\t"
                      .. dspId .. "\t"
                      .. bid.id .. "\t"
                      .. bid.price .. "\t"
                      .. table.concat(adLog, ",")
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
    if ngx.ctx.adReq.publisherType == const.WAP_PUBLISHER then
        url = const.RTB_WAP_CM_URL .. "?" .. ngx.encode_args(args);
    else 
        url = const.RTB_CM_URL .. "?" .. ngx.encode_args(args);
    end

    table.insert(cmUrlList, url);
end

local function fillBidAd(bid, dspId, adBidList)
    local bidfloor = getAdLowestPrice(bid.id);

    if bid.price >= bidfloor then
        local temp = {};

        temp.dspId = dspId;
        temp.price = bid.price;

        temp.creative = {};
        for _, ad in ipairs(bid.ad) do
            if isValidCreative(dspId, ad.id) then
                temp.creative[#temp.creative + 1] = ad;
            else
                -- log dsp creative foul
                logDspFoul(dspId, bid.id, ad.id);
            end
        end

        if #temp.creative ~= 0 then
            adBidList[bid.id] = adBidList[bid.id] or {};
            table.insert(adBidList[bid.id], temp);
        end
    end
end

local function extractAdBid(bidRspList, dspBidList, cmUrlList)
    local adData = ngx.ctx.adData;

    -- extract ad bid
    local adBidList = {};

    for i, bidRsp in ipairs(bidRspList) do
        local dspId = dspBidList[i];

        if isValidRsp(bidRsp) then 

            local bidResult = getBidResult(bidRsp, version[dspBidList[i]]);

            local status, bidResult = pcall(validBidResult, bidResult);

            if status then
                if bidResult.bid then
                    for _, bid in ipairs(bidResult.bid) do
                        fillBidAd(bid, dspId, adBidList);

                        -- log dsp response
                        logDspRsp(dspId, bid);
                    end
                else   
                    logDspNull(dspId)
                end

                -- fill cookie mapping URL list
                if bidResult.cm == 1 then
                    fillCmUrlList(dspId, cmUrlList);
                end
            else
                ngx.log(ngx.ERR, "bid:", ngx.ctx.bid,
                ", dsp id:", dspId,
                ", ", bidResult,
                ":", bidRsp.body);

                logDspInvalid(dspId)
            end

        else
            -- log dsp bid fail
            logDspFail(dspId, const.RTB_PHASE_BID, bidRsp.status);
        end
    end

    return adBidList;
end

local function cmpPrice(a, b)
    return a.price > b.price
end

local function selectWinner(bidInfo, adUnitId)
    local adData = ngx.ctx.adData;

    -- sort bid information
    if #bidInfo ~= 1 then
        table.sort(bidInfo, cmpPrice);
    end

    -- select winner
    local second = 0;
    for i = 2, #bidInfo do
        if bidInfo[i].price ~= bidInfo[1].price then
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

        winner.dspId = bidInfo[first].dspId;
        winner.price = bidInfo[second].price + const.RTB_EXTRA_PRICE;
        winner.creative = bidInfo[first].creative;
    else
        local first = 1;
        if #bidInfo ~= 1 then
            first = math.random(1, #bidInfo);
        end

        winner.dspId = bidInfo[first].dspId;
        winner.price =  getAdLowestPrice(adUnitId);
        winner.creative = bidInfo[first].creative;
    end

    return winner;
end

local function logDspCfm(adUnitId, winner)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    local creativeLog = {};
    for _, creative in ipairs(winner.creative) do
        local str = "(" .. creative.id .. ","
                    .. adData.creativeObj:getUniqueId(winner.dspId, creative.id) .. ")";
        table.insert(creativeLog, str);
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_CFM
                      .. ngx.ctx.bid .. "\t"
                      .. winner.dspId .. "\t"
                      .. adUnitId .. "\t"
                      .. winner.price .. "\t"
                      .. table.concat(creativeLog, ",")
                      .. const.LOG_SEPARATOR_DSP_CFM
                      .. const.LOG_SEPARATOR_DSP_TARGETING  
                      .. ((adReq.pageUrl ~= "") and adReq.pageUrl or "-") .. "\t"
                      .. ((adReq.ip ~= "") and adReq.ip or "-") .. "\t"
                      .. ((adReq.cookie ~= "") and adReq.cookie or "-")
                      .. const.LOG_SEPARATOR_DSP_TARGETING);
end

local function fillWinPriceList(adUnitId, winner, winPriceList)
    local adData = ngx.ctx.adData;

    if adData.dspObj:getConfirmUrl(winner.dspId) ~= "" then
        local temp = {};
        temp.id = adUnitId;
        temp.price = winner.price;

        if not winPriceList[winner.dspId] then
            winPriceList[winner.dspId] = {};
        end
        table.insert(winPriceList[winner.dspId], temp);
    end

    -- log dsp confirm 
    logDspCfm(adUnitId, winner);
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
    log = ((adReq.pageUrl ~= "") and adReq.pageUrl or "-") .. "\t"
          .. ((adReq.ip ~= "") and adReq.ip or "-") .. "\t"
          .. ((adReq.cookie ~= "") and adReq.cookie or "-");
    local targeting = ngx.encode_base64(log);
    args[const.RTB_CLICK_ARG_TARGETING] = targeting;

    return const.RTB_CLICK_URL .. "?" .. ngx.encode_args(args);
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

local function alterSinaDspCreative(creative, adUnitId, dspId, winCpmPrice)
    local adData = ngx.ctx.adData;

    local status, result = pcall(cjson.decode, creative.markup)
    if status then 
        -- add click-through url
        local url = generateClickUrl(dspId, adUnitId, creative.id);
        table.insert(result.monitor, url);

        -- add view url
        local viewUrl = generateViewUrl(dspId, adUnitId, creative.id, winCpmPrice);
        table.insert(result.pv, viewUrl);

        -- add winning price
        local notation = "";
        local capture = ngx.re.match(result.monitor[1], [[\?]], "jo");
        if capture then
            notation = "&"; 
        else
            notation = "?";
        end       

        local eKey = adData.dspObj:getEncryptionKey(dspId)
        local iKey = adData.dspObj:getIntegrityKey(dspId)
        local msg = util.encryptPrice(ngx.ctx.uuid, eKey, iKey, winCpmPrice);
        local args = {};
        args[const.SINA_DSP_CLICK_ARG_P] = msg;

        result.monitor[1] = result.monitor[1] .. notation .. ngx.encode_args(args); 

        return result;
    else 
        ngx.log(ngx.ERR, result .. ":" .. creative.markup)

        return "";
    end
end

local function expandMacro(creative, adUnitId, dspId, winCpmPrice)
    local adData = ngx.ctx.adData;

    -- expand click-through macro
    local url_unesc = generateClickUrl(dspId, adUnitId, creative.id)
                      .. "&" .. ngx.encode_args({[const.RTB_CLICK_ARG_URL] = ""});
    local url_esc = ngx.escape_uri(url_unesc);

    local result = ngx.re.gsub(creative.markup, const.RTB_MACRO_CLICK_UNESC, url_unesc, "jo");
    result = ngx.re.gsub(result, const.RTB_MACRO_CLICK_ESC, url_esc, "jo");

    -- expand winning price macro
    local eKey = adData.dspObj:getEncryptionKey(dspId);
    local iKey = adData.dspObj:getIntegrityKey(dspId);
    local msg = util.encryptPrice(ngx.ctx.uuid, eKey, iKey, winCpmPrice);
    msg = ngx.escape_uri(msg);
    
    result = ngx.re.gsub(result, const.RTB_MACRO_WIN_PRICE, msg, "jo");

    return result;
end

local function alterWapDspCreative(creative, adUnitId, dspId, winCpmPrice)
    local adData = ngx.ctx.adData;

    local status, result = pcall(cjson.decode, creative.markup)
    if status then
        -- expand click-through macro
        local url_unesc = generateClickUrl(dspId, adUnitId, creative.id)
                      .. "&" .. ngx.encode_args({[const.RTB_CLICK_ARG_URL] = ""});
        local url_esc = ngx.escape_uri(url_unesc);
        
        if #result.link ~= 0 then
            result.link[1] = ngx.re.gsub(result.link[1], const.RTB_MACRO_CLICK_UNESC, url_unesc, "jo");
            result.link[1] = ngx.re.gsub(result.link[1], const.RTB_MACRO_CLICK_ESC, url_esc, "jo");        
        end

        -- expand winning price macro
        local eKey = adData.dspObj:getEncryptionKey(dspId);
        local iKey = adData.dspObj:getIntegrityKey(dspId);
        local msg = util.encryptPrice(ngx.ctx.uuid, eKey, iKey, winCpmPrice);
        msg = ngx.escape_uri(msg);

        for i, pvUrl in ipairs(result.pv) do
            result.pv[i] = ngx.re.gsub(pvUrl, const.RTB_MACRO_WIN_PRICE, msg, "jo");
        end

        -- add view url
        local viewUrl = generateViewUrl(dspId, adUnitId, creative.id, winCpmPrice);
        table.insert(result.pv, 1, viewUrl);

        result.monitor = {};

        return result;
    else 
        ngx.log(ngx.ERR, result .. ":" .. creative.markup)

        return "";
    end
end

local function fillAdCreativeListForDsp(adUnitId, winner, adCreativeList)
    adCreativeList[adUnitId] = adCreativeList[adUnitId] or {};

    adCreativeList[adUnitId].content = adCreativeList[adUnitId].content or {}
    for _, creative in ipairs(winner.creative) do
        local temp = {};
        if winner.dspId == const.SINA_DSP_ID then
            temp = alterSinaDspCreative(creative, adUnitId, 
                                        winner.dspId, winner.price);    
        else
            if ngx.ctx.adReq.publisherType == const.WAP_PUBLISHER then
                temp = alterWapDspCreative(creative, adUnitId, 
                                           winner.dspId, winner.price);
			else
            	temp.src = { expandMacro(creative, adUnitId, 
                                         winner.dspId, winner.price) }; 
            	temp.type = { "html" }; 
            	temp.link = {}
            	temp.pv = { generateViewUrl(winner.dspId, adUnitId, 
                            creative.id, winner.price) }
            	temp.monitor = {}
            end

        end
        table.insert(adCreativeList[adUnitId].content, temp);
    end
end

local function handleBidRsp(bidRspList, adPendList, dspBidList, adCreativeList, cmUrlList)
    local adData = ngx.ctx.adData;

    -- extract ad bid
    local adBidList = extractAdBid(bidRspList, dspBidList, cmUrlList);

    -- conduct auction 
    local winPriceList = {};

    for adUnitId, bidInfo in pairs(adBidList) do
        -- select winner
        local winner = selectWinner(bidInfo, adUnitId);

        -- fill winning price list
        fillWinPriceList(adUnitId, winner, winPriceList);
        
        -- fill ad creative list
        fillAdCreativeListForDsp(adUnitId, winner, adCreativeList);

        -- remove ad unit from pending list
        if getLeftAdNum(adUnitId, adCreativeList) <= 0 then
            removeAdFromPendList(adPendList, adUnitId);
        end
    end

    if next(winPriceList) then
        winPriceList.bid = ngx.ctx.bid;
    end

    return winPriceList;
end

local function cfmWinPrice(winPriceList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    ngx.ctx.bid = winPriceList.bid;
    winPriceList.bid = nil;

    -- confirm winning price
    local reqList = {};
    local dspIdList = {};

    for dspId, priceInfo in pairs(winPriceList) do
        local body = {};
        body.version = const.RTB_VERSION;
        body.bid = ngx.ctx.bid;
        body.ad_price = {};
        for _, ad in ipairs(priceInfo) do
            local temp = {};
            temp.id = ad.id;
            temp.price = ad.price;

            table.insert(body.ad_price, temp);
        end
        local jsonStr = cjson.encode(body);

        local temp = {};
        temp[1] = const.DSP_CFM_URI;
        temp[2] = {};
        temp[2].method = ngx.HTTP_POST;
        temp[2].body = jsonStr;
        temp[2].vars = {};
        temp[2].vars[const.NGINX_VAR_URL] = adData.dspObj:getConfirmUrl(dspId);
        temp[2].vars[const.NGINX_VAR_HASH_STR] = (adReq.cookie ~= "") and adReq.cookie or adReq.ip

        table.insert(reqList, temp);
        table.insert(dspIdList, dspId);
    end

    local rspList = {ngx.location.capture_multi(reqList)};

    for i, rsp in ipairs(rspList) do
        if not isValidRsp(rsp) then
            -- log dsp confirm fail
            logDspFail(dspIdList[i], const.RTB_PHASE_CFM, rsp.status);
        end
    end
end

local function launchRtbForDsp(dspQueryList, adPendList, adCreativeList, cmUrlList)
    local dspBidList = {};

    -- build bid request
    local bidReqList = buildBidReq(dspQueryList, dspBidList, adCreativeList);

    -- send bid request
    local bidRspList = {ngx.location.capture_multi(bidReqList)};

    -- handle bid response
    local winPriceList = handleBidRsp(bidRspList, adPendList, dspBidList, adCreativeList, cmUrlList);

    return winPriceList;
end

local rtb = {
    querySinaAdEngine = querySinaAdEngine,
    launchRtbForDsp = launchRtbForDsp,
    cfmWinPrice = cfmWinPrice,
    removeAdFromPendList = removeAdFromPendList,
    getLeftAdNum = getLeftAdNum
};

return rtb;

