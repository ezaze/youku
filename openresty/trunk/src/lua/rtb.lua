local cjson = require("cjson");
local uuid = require("uuid");
local struct = require("struct");
local bit = require("bit");
local util = require("util");
local const = require("const");
local sax = require("sax")

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

    -- for video ad
    body.vid = adReq.vid;
    body.subid = adReq.subid;
    body.srcid = adReq.srcid;
    body.v_sports1 = adReq.sports1;
    body.v_sports2 = adReq.sports2;
    body.v_sports3 = adReq.sports3;
    body.v_sports4 = adReq.sports4;

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
                local publisherId = adData.adUnitObj:getPublisher(ad.id);
                local resourceId = adData.publisherObj:getResource(publisherId);
                local dspWhiteList = adData.resourceObj:getPdWhiteList(resourceId);
                
                if dspId and adData.dspObj:isValid(dspId) and
                   adData.dspObj:getStatus(dspId) == const.OBJECT_STATUS_VALID and
                   util.isAllowedForPd(dspWhiteList, dspId) then

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

local function buildBidReq(queryDspList, dspBidList, adCreativeList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    ngx.ctx.uuid = uuid.generate("random");
    ngx.ctx.bid = uuid.unparse(ngx.ctx.uuid);

    -- build bid request
    local bidReqList = {};
    for dspId, adUnitList in pairs(queryDspList) do
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

            temp[2].vars[const.NGINX_VAR_URL] = sinaBidUrl .. notation .. ngx.encode_args(sinaDspArgs);
        else
            local bidUrl = adData.dspObj:getRTBUrl(dspId);
            if dspId == "1" and adReq.publisherType == const.WAP_PUBLISHER then
                bidUrl = bidUrl .. "/gm"
            end
            temp[2].vars[const.NGINX_VAR_URL] = bidUrl;
        end
        temp[2].vars[const.NGINX_VAR_HASH_STR] = (adReq.cookie ~= "") and adReq.cookie or adReq.ip

        table.insert(bidReqList, temp);
        table.insert(dspBidList, dspId);
    
        -- log dsp request
        logDspReq(adUnitList, dspId);
    end

    return bidReqList;
end

local function getBidResult(bidRsp)
    local bidResult = cjson.decode(bidRsp.body);
    
    if type(bidResult) ~= "table" then
        error("invalid bid response");
    end

    if type(bidResult.version) ~= "string" then
        error("invalid field version");
    end

    if type(bidResult.bid) ~= "string" then
        error("invalid field bid");
    end

    if type(bidResult.ad_creative) ~= "table" then
        error("invalid field ad_creative");
    end

    for _, ad in ipairs(bidResult.ad_creative) do
        if type(ad.id) ~= "string" then
            error("invalid field id");
        end

        if type(ad.max_cpm_price) ~= "number" then
            error("invalid field max_cpm_price");
        end

        if type(ad.creative) ~= "table" then
            error("invalid field creative");
        end

        for _, creative in ipairs(ad.creative) do
            if type(creative.id) ~= "string" then
                error("invalid field id");
            end

            if type(creative.html_snippet) ~= "string" then
                error("invalid field html_snippet");
            end
        end
    end

    if type(bidResult.cm_flag) ~= "string" then
        error("invalid field cm_flag");
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
    if not util.checkAdvertiserType(adData.auction_type, advertiserType) then
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

local function logDspRsp(dspId, ad)
    local adData = ngx.ctx.adData;

    local creativeLog = {};
    for _, creative in ipairs(ad.creative) do
        local id = adData.creativeObj:getUniqueId(dspId, creative.id);
        if not id then
            id = "invalid"
        end
        local str = "(" .. creative.id .. "," .. id .. ")";

        table.insert(creativeLog, str);
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_RSP
                      .. ngx.ctx.bid .. "\t"
                      .. dspId .. "\t"
                      .. ad.id .. "\t"
                      .. ad.max_cpm_price .. "\t"
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

local function logDspFail(dspId, phase, status)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_FAIL
                     .. ngx.ctx.bid .. "\t"
                     .. dspId .. "\t"
                     .. phase .. "\t"
                     .. status
                     .. const.LOG_SEPARATOR_DSP_FAIL);
end

local function extractAdBid(bidRspList, dspBidList, cmUrlList)
    local adData = ngx.ctx.adData;

    -- extract ad bid
    local adBidList = {};
    for i, bidRsp in ipairs(bidRspList) do
        if isValidRsp(bidRsp) then 
            local status, bidResult = pcall(getBidResult, bidRsp);
            if status then

                if #bidResult.ad_creative ~= 0 then
                    for _, ad in ipairs(bidResult.ad_creative) do

                        local lowestPrice = getAdLowestPrice(ad.id);
                        if lowestPrice and ad.max_cpm_price >= lowestPrice then
                            local temp = {};
                            temp.dsp_id = dspBidList[i];
                            temp.max_cpm_price = ad.max_cpm_price;
                            temp.creative = {};
                            for _, creative in ipairs(ad.creative) do
                                if isValidCreative(dspBidList[i], creative.id) then
                                    table.insert(temp.creative, creative);
                                else
                                    -- log dsp creative foul
                                    logDspFoul(dspBidList[i], ad.id, creative.id);
                                end
                            end

                            if #temp.creative ~= 0 then
                                if not adBidList[ad.id] then
                                    adBidList[ad.id] = {};
                                end
                                table.insert(adBidList[ad.id], temp);
                            end
                        end

                        -- log dsp response
                        logDspRsp(dspBidList[i], ad);
                    end
                else   
                    logDspNull(dspBidList[i])
                end
                -- fill cookie mapping URL list
                if bidResult.cm_flag == const.RTB_CM_FLAG then
                    fillCmUrlList(dspBidList[i], cmUrlList);
                end
            else
                ngx.log(ngx.ERR, "bid:" .. ngx.ctx.bid
                                 .. ", dsp id:" .. dspBidList[i] 
                                 .. ", " .. bidResult 
                                 .. ":" .. bidRsp.body);

                logDspInvalid(dspBidList[i])
            end
        else
            -- log dsp bid fail
            logDspFail(dspBidList[i], const.RTB_PHASE_BID, bidRsp.status);
        end
    end

    return adBidList;
end

local function cmpPrice(a, b)
    return a.max_cpm_price > b.max_cpm_price
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
        winner.win_cpm_price =  getAdLowestPrice(adUnitId);
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
                      .. ((adReq.pageUrl ~= "") and adReq.pageUrl or "-") .. "\t"
                      .. ((adReq.ip ~= "") and adReq.ip or "-") .. "\t"
                      .. ((adReq.cookie ~= "") and adReq.cookie or "-")
                      .. const.LOG_SEPARATOR_DSP_TARGETING);
end

local function fillWinPriceList(adUnitId, winner, winPriceList)
    local adData = ngx.ctx.adData;

    if adData.dspObj:getConfirmUrl(winner.dsp_id) ~= "" then
        local temp = {};
        temp.id = adUnitId;
        temp.win_cpm_price = winner.win_cpm_price;

        if not winPriceList[winner.dsp_id] then
            winPriceList[winner.dsp_id] = {};
        end
        table.insert(winPriceList[winner.dsp_id], temp);
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

local function fillSign(content, dspId)
    local dspObj = sax.newObject(const.OBJECT_DSP)
    local signkey = dspObj:getSignKey(dspId)
    local tempLink = {}
    local needSign = true    

    if #content.link == 0 then
        table.insert(content.link, "")
        needSign = false
    end
       
    for _, link in ipairs(content.link) do
        local linkUrl = link

        for i = #content.monitor , 1, -1 do
            local monitorUrl = content.monitor[i]
            if moniorUrl ~= "" then 
                local notatation;
                local capture = ngx.re.match(monitorUrl, [[\?]], "jo");
                if capture then
                    notation = "&"
                else
                    notation = "?"
                end

                linkUrl =  monitorUrl ..
                           notation .. 
                           const.RTB_CLICK_ARG_URL .. "=" .. 
                           ngx.escape_uri(linkUrl)
            end 
        end

        if needSign then
            local sign = util.generateSign(signkey, linkUrl)
            linkUrl = linkUrl .."&" ..  const.RTB_CLICK_ARG_SIGN .. "=" .. sign
        end
           
        table.insert(tempLink, linkUrl)                   
    end
    content.link = tempLink 
end

local function alterSinaDspCreative(creative, adUnitId, dspId, winCpmPrice)
    local adData = ngx.ctx.adData;

    local status, result = pcall(cjson.decode, creative.html_snippet)
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
        ngx.log(ngx.ERR, result .. ":" .. creative.html_snippet)

        return "";
    end
end

local function expandMacro(creative, adUnitId, dspId, winCpmPrice)
    local adData = ngx.ctx.adData;

    -- expand click-through macro
    local url_unesc = generateClickUrl(dspId, adUnitId, creative.id)
                      .. "&" .. ngx.encode_args({[const.RTB_CLICK_ARG_URL] = ""});
    local url_esc = ngx.escape_uri(url_unesc);

    local result = ngx.re.gsub(creative.html_snippet, const.RTB_MACRO_CLICK_UNESC, url_unesc, "jo");
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

    local status, result = pcall(cjson.decode, creative.html_snippet)
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
        ngx.log(ngx.ERR, result .. ":" .. creative.html_snippet)

        return "";
    end
end

local function fillAdCreativeListForDsp(adUnitId, winner, adCreativeList)
    adCreativeList[adUnitId] = adCreativeList[adUnitId] or {};

    adCreativeList[adUnitId].content = adCreativeList[adUnitId].content or {}
    for _, creative in ipairs(winner.creative) do
        local temp = {};
        if winner.dsp_id == const.SINA_DSP_ID then
            temp = alterSinaDspCreative(creative, adUnitId, winner.dsp_id, winner.win_cpm_price);
            fillSign(temp, winner.dsp_id)    
        else
            if ngx.ctx.adReq.publisherType == const.WAP_PUBLISHER then
                temp = alterWapDspCreative(creative, adUnitId, winner.dsp_id, winner.win_cpm_price);
                fillSign(temp, winner.dsp_id)
			else
            	temp.src = { expandMacro(creative, adUnitId, winner.dsp_id, winner.win_cpm_price) }; 
            	temp.type = { "html" }; 
            	temp.link = {}
            	temp.pv = { generateViewUrl(winner.dsp_id, adUnitId, creative.id, winner.win_cpm_price) }
            	temp.monitor = {}
            end

        end
        ngx.log(ngx.INFO, "<after>" ..  cjson.encode(temp)  .. "<after>")
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
            temp.win_cpm_price = ad.win_cpm_price;

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

