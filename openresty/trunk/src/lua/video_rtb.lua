local cjson  = require "cjson";
local uuid   = require "uuid";
local util   = require "util";
local const  = require "const";
local log    = require "log";
local lxp    = require "lxp";
local pairs = pairs;
local ipairs = ipairs;
local tostring = tostring;
local tonumber = tonumber;
local type = type;
local error = error;
local concat = table.concat;
local insert = table.insert;
local sort = table.sort;
local random = math.random;
local floor = math.floor;

local function buildBidBody(adPendList)
    local bidctx = ngx.ctx.bidctx;
    local adData = ngx.ctx.adData;
    local adReq = ngx.ctx.adReq;

    -- generate bid request body 
    local body = {};
    
    body.id = bidctx.bid;
    body.at = bidctx.at;
    --[[
    body.badv = {};
    body.bcat = {};
    --]]
    body.imp = {};
    for _, adUnitId in ipairs(adPendList) do
        local temp = {};
        temp.id = adUnitId;

        if bidctx.at == const.AUCTION_TYPE_PREFERRED_DEAL then
            temp.bidfloor = 0;
        else
            temp.bidfloor = adData.pubObj:getLowestPrice(adData.pub[adUnitId]); 
        end

        local video = {
            minduration = 15,
            maxduration = 15,
            mimes = {"video/x-flv"},
            protocol = 3,
            linearity = 1
        };

        local size = adData.adUnitObj:getSize(adUnitId);
        local wdht = util.split(size, "*");
        video.w = tonumber(wdht[1]);
        video.h = tonumber(wdht[2]);

        temp.video = video;
        body.imp[#body.imp + 1] =  temp;
    end

    local device = {};
    device.ip = adReq.ip;
    device.ua = adReq.ua;
    body.device = device;

    local site = {};
    site.page = adReq.pageUrl;

    local content = {};
    content.channel = adReq.sports1;
    local len = tonumber(adReq.length);
    if len then
        content.len = floor(len / 1000);
    end
    site.content = content;

    body.site = site;

    if adReq.sid ~= "" then
        local user = {};
        user.id = adReq.sid;
        body.user = user;
    end

-- we need set body.istest = 0 when the code is in product
    body.istest = ngx.var.arg_istest and 1 or 0;
    bidctx.istest = ngx.var.arg_istest;
    return body;
end

local function buildBidReq()
    local bidctx = ngx.ctx.bidctx;
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    bidctx.uuid = uuid.generate("random");
    bidctx.bid = uuid.unparse(bidctx.uuid);

    local dspAdList = bidctx.dspAdList;

    -- build bid request
    local bidReqList = {};
    local dspBidList = {}
    for dspId, adPendList in pairs(dspAdList) do
        dspBidList[#dspBidList + 1] = dspId;
        local body = buildBidBody(adPendList);

        local temp = {};
        temp[1] = const.DSP_BID_URI;
        temp[2] = {};
        temp[2].method = ngx.HTTP_POST;
        temp[2].body = cjson.encode(body);

        temp[2].vars = {};

        if dspId == const.SINA_DSP_ID then
            local sinaBidUrl = adData.dspObj:getRTBUrl(dspId) .. "/video.do";

            local notation = "";
            local capture = string.find(sinaBidUrl, "?", 1, true);
            if capture then
                notation = "&"; 
            else
                notation = "?";
            end

            local sinaDspArgs = {};
            sinaDspArgs[const.SINA_DSP_BID_ARG_HASHCODE] = adReq.hashCode;
            sinaDspArgs[const.SINA_DSP_BID_ARG_COOKIE] = adReq.cookie;

            temp[2].vars[const.NGINX_VAR_URL] = sinaBidUrl .. 
                                                notation .. 
                                                ngx.encode_args(sinaDspArgs);
        elseif dspId == "1" then
            temp[2].vars[const.NGINX_VAR_URL] = adData.dspObj:getRTBUrl(dspId) .. "/omg";
        elseif dspId == "21" then
            temp[2].vars[const.NGINX_VAR_URL] = adData.dspObj:getRTBUrl(dspId) .. "&video=1";
        else
            temp[2].vars[const.NGINX_VAR_URL] = adData.dspObj:getRTBUrl(dspId);
        end

        temp[2].vars[const.NGINX_VAR_HASH_STR] = (adReq.cookie ~= "") and adReq.cookie or
                                                  adReq.ip
        insert(bidReqList, temp);

        -- log dsp request
        log.logDsp("request", adPendList, dspId);
    end
     
    bidctx.dspBidList = dspBidList;
    return bidReqList;
end


local function getBidResult(bidRsp)
    local bidResult = cjson.decode(bidRsp.body);

    if type(bidResult) ~= "table" then
        error("invalid bid response");
    end

    if type(bidResult.id) ~= "string" then
        error("invalid field rsp.id");
    end

    if not bidResult.bid then 
        return bidResult;
    elseif type(bidResult.bid) ~= "table" then
        error("invalid field rsp.bid");
    end

    for _, bid in ipairs(bidResult.bid) do
        if type(bid.id) ~= "string" then
            error("invalid field bid.id");
        end

        if type(bid.price) ~= "number" then
            error("invalid field bid.price");
        end

        if type(bid.ad) ~= "table" or #bid.ad == 0 then
            error("invalid field bid.ad")
        end

        for _, ad in ipairs(bid.ad) do
            if type(ad.id) ~= "string" then
                error("invalid field ad.id")
            end

            if type(ad.markup) ~= "string" then
                error("invalid field ad.markup")
            end
        end
    end

    if bidResult.cm ~= 0 and bidResult.cm ~= 1 then
        error("invalid field rsp.cm");
    end

    return bidResult;
end

local function isValidRsp(status)
    return status == ngx.HTTP_OK
end

local function isValidCreative(dspId, creativeId)
    local crvObj = ngx.ctx.adData.crvObj;
    local advObj = ngx.ctx.adData.advObj;

    if not crvObj:isValid(dspId, creativeId)
        or crvObj:getStatus(dspId, creativeId) == const.OBJECT_STATUS_INVALID then
        return false;
    end

    local advertiserId = crvObj:getAdvertiserId(dspId, creativeId);
    if not advObj:isValid(dspId, advertiserId)
        or advObj:getStatus(dspId, advertiserId) == const.OBJECT_STATUS_INVALID then
        return false;
    end
    
    local advertiserType = advObj:getType(dspId, advertiserId);
    if not util.checkAdvertiserType(ngx.ctx.bidctx.at, advertiserType) then
        return false;
    end

    return true;
end
local function fillCmUrlList(dspId, cmUrlList)
    local args = {};
    args[const.RTB_CM_ARG_NID] = dspId;
    local url = const.RTB_CM_URL .. "?" .. ngx.encode_args(args);

    cmUrlList[#cmUrlList + 1] =  url;
end

local function extractAdBid(bidRspList)
    local bidctx = ngx.ctx.bidctx;
    local adData = ngx.ctx.adData;

    local dspAdList = bidctx.dspAdList;
    local dspBidList = bidctx.dspBidList;
    local cmUrlList = bidctx.cmUrlList;

    -- extract ad bid
    local adBidList = {};

    for i, bidRsp in ipairs(bidRspList) do
        local dspId = dspBidList[i];

        if isValidRsp(bidRsp.status) then
            local status, bidResult = pcall(getBidResult, bidRsp);

            if status then

                if bidResult.bid then
                    for _, bid in ipairs(bidResult.bid) do
                        local bidfloor;

                        if bidctx.at ~= const.AUCTION_TYPE_PREFERRED_DEAL then
                            bidfloor = adData.pubObj:getLowestPrice(adData.pub[bid.id]);
                        end

                        if bidctx.at == const.AUCTION_TYPE_PREFERRED_DEAL or 
                           bid.price >= bidfloor then
                            local temp = {};

                            temp.dspId = dspId;

                            if bidctx.at == const.AUCTION_TYPE_PREFERRED_DEAL then
                                temp.price = 0;
                                bid.price = 0;
                            else
                                temp.price = bid.price;
                            end

                            temp.creative = {};
                            for _, ad in ipairs(bid.ad) do
                                if isValidCreative(dspId, ad.id) then
                                    temp.creative[#temp.creative + 1] = ad;
                                else
                                    log.logDsp("foul", dspId, bid.id, ad.id);
                                end
                            end

                            if #temp.creative ~= 0 then
                                adBidList[bid.id] = adBidList[bid.id] or {};
                                insert(adBidList[bid.id], temp);
                            end
                        end
                        
                        -- log dsp response
                        log.logDsp("response", dspId, bid);
                    end
                    
                else   
                    log.logDsp("null", dspId);

                end
                -- fill cookie mapping URL list
                if bidResult.cm == 1 then
                    fillCmUrlList(dspId, cmUrlList);
                end
            else
                if bidctx.istest then
                    ngx.log(ngx.INFO, "bid:", bidctx.bid,
                                      ", dspid:", dspId,
                                      ", ", bidResult,
                                      ":", bidRsp.body);
                end
                log.logDsp("invalid", dspId);
            end
        else
            -- log dsp bid fail
            log.logDsp("fail", dspId, const.RTB_PHASE_BID, bidRsp.status);
        end
    end
    return adBidList;
end

local function selectWinner(adUnitId, bidInfo)
    local bidctx = ngx.ctx.bidctx;
    local adData = ngx.ctx.adData;

    -- sort bid information
    if #bidInfo ~= 1 then
        sort(bidInfo, function(a, b) return a.price > b.price end);
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
            first = random(1, second - 1);
        end

        winner.dspId = bidInfo[first].dspId;
        winner.price = bidInfo[second].price + const.RTB_EXTRA_PRICE;
        winner.creative = bidInfo[first].creative;
    else
        local first = 1;
        if #bidInfo ~= 1 then
            first = random(1, #bidInfo);
        end

        winner.dspId = bidInfo[first].dspId;
        if bidctx.at == const.AUCTION_TYPE_PREFERRED_DEAL then
            winner.price = 0
        else
            winner.price = adData.pubObj:getLowestPrice(adData.pub[adUnitId]);
        end

        winner.creative = bidInfo[first].creative;
    end

    return winner;
end

local function formatType(tp)
    local tmp = util.split(tp, "/")
    if tmp[2] == "x-shockwave-flash" then
        return "swf";
    elseif tmp[2] == "x-flv" then
        return "flv";
    elseif tmp[1] == "image" then
        return "image";
    else
        return tmp[2];
    end
end

local function generateClickUrl(dspId, adUnitId, creativeId)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    local args = {};

    args[const.RTB_CLICK_ARG_TYPE] = const.CLICK_TYPE_DSP;
    local log = { ngx.ctx.bidctx.bid, dspId, adUnitId, creativeId,
                  adData.crvObj:getUniqueId(dspId, creativeId) 
                };
    local t = ngx.encode_base64(concat(log, "\t"));
    args[const.RTB_CLICK_ARG_T] = t;
    
    log = { ((adReq.pageUrl ~= "") and adReq.pageUrl or "-"),
            ((adReq.ip ~= "") and adReq.ip or "-"),
            ((adReq.cookie ~= "") and adReq.cookie or "-")
          };
    local targeting = ngx.encode_base64(concat(log, "\t"));
    args[const.RTB_CLICK_ARG_TARGETING] = targeting;

    return const.RTB_CLICK_URL .. "?" .. ngx.encode_args(args);
end

local function generateViewUrl(dspId, adUnitId, creativeId, winCpmPrice)
    local adData = ngx.ctx.adData;
    local args = {};
    args[const.RTB_VIEW_ARG_TYPE] = const.VIEW_TYPE_DSP;
    local log = { ngx.ctx.bidctx.bid, dspId, adUnitId, winCpmPrice, creativeId,
                  adData.crvObj:getUniqueId(dspId, creativeId)
                };

    local t = ngx.encode_base64(concat(log, "\t"));
    args[const.RTB_VIEW_ARG_T] = t;

    return const.RTB_VIEW_URL .. "?" .. ngx.encode_args(args);
end

local function expandMacro(creative, str, adUnitId, dspId, winCpmPrice)
    local adData = ngx.ctx.adData;
    local num = 0;
    -- expand click-through macro
    local url_unesc = generateClickUrl(dspId, adUnitId, creative.id)
                      .. "&" .. ngx.encode_args({[const.RTB_CLICK_ARG_URL] = ""});
    local url_esc = ngx.escape_uri(url_unesc);
    
    local result, n = ngx.re.gsub(str, const.RTB_MACRO_CLICK_UNESC, url_unesc, "jo");
    num = num + n;

    result, n = ngx.re.gsub(result, const.RTB_MACRO_CLICK_ESC, url_esc, "jo");
    num = num + n;

    -- expand winning price macro
    local eKey = adData.dspObj:getEncryptionKey(dspId);
    local iKey = adData.dspObj:getIntegrityKey(dspId);
    local msg = util.encryptPrice(ngx.ctx.bidctx.uuid, eKey, iKey, winCpmPrice);
    msg = ngx.escape_uri(msg);
    
    result = ngx.re.gsub(result, const.RTB_MACRO_WIN_PRICE, msg, "jo");
    return result, num;
end


local nullret = {
    src = {}, len = {}, size = {},
    type = {}, volume = {},
    link = {}, monitor = {},
    pvBegin = {}, pvEnd = {}
}

local function getContent(dspId, markup) 

    local content = {
        src = {}, len = {}, size = {},
        type = {}, volume = {},
        link = {}, monitor = {},
        pvBegin = {}, pvEnd = {}
    }

    local callbacks = {}

    callbacks = {
        StartElement = function(parser, tagName, attrs)
            if tagName == "Duration" then
                callbacks.CharacterData = function(parser, str)
                    local hms = util.split(util.trim(str), ":")
                    local h, m, s = tonumber(hms[1]), tonumber(hms[2]), tonumber(hms[3])
                    local len = 0;
                    if h and m and s then
                        len = h * 3600 + m * 60 + s
                    end
                    content.len[#content.len + 1] = len  
                end
            elseif tagName == "MediaFile" then
                content.type[#content.type + 1] = formatType(attrs.type)
                content.size[#content.size + 1] = attrs.width .. "_" .. attrs.height
                callbacks.CharacterData = function(parser, str)
                    content.src[#content.src + 1] = util.trim(str)
                end
            elseif tagName == "Tracking" then
                if attrs.event == "start" then
                    callbacks.CharacterData = function(parser, str)
                        content.pvBegin[#content.pvBegin + 1] = util.trim(str)
                    end
                elseif attrs.event == "complete" then
                    callbacks.CharacterData = function(parser, str)
                        content.pvEnd[#content.pvEnd + 1] = util.trim(str)
                    end
                end
            elseif tagName == "ClickTracking" then
                callbacks.CharacterData = function(parser, str)
                    content.monitor[#content.monitor + 1] = util.trim(str)
                end
            elseif tagName == "ClickThrough" then
                callbacks.CharacterData = function(parser, str)
                    content.link[#content.link + 1] = util.trim(str)
                end
            end
        end,

        EndElement = function (parser, name)
            callbacks.CharacterData = false -- restores placeholder
        end,

        CharacterData = false,
    }

    local p = lxp.new(callbacks)

    local succ, msg, line = p:parse(markup)
    if not succ then
        ngx.log(ngx.ERR, dspId, "\tinvalid vast response: ", msg, " ", line);

        log.logDsp("invalid", dspId);
        return nil;
    else
        p:parse();
        p:close();
    end

    return content;
end

local function dspParseVast(creative, adUnitId, dspId, winCpmPrice)
    local content = getContent(dspId, creative.markup);
    if not content then
        return nullret;
    end

    local pvBegin = content.pvBegin;
    local pvEnd = content.pvEnd;
    local monitor = content.monitor;
    local link = content.link;
    
    local click = 0;
    local n = 0;

    for i, pv in ipairs(pvBegin) do
        pvBegin[i] = expandMacro(creative, pv, adUnitId, dspId, winCpmPrice) 
    end
    insert(pvBegin, 1, generateViewUrl(dspId, adUnitId,
                                             creative.id, winCpmPrice));

    for i, pv in ipairs(pvEnd) do
        pvEnd[i] = expandMacro(creative, pv, adUnitId, dspId, winCpmPrice) 
    end

    for i, mnr in ipairs(monitor) do
        monitor[i], n = expandMacro(creative, mnr, adUnitId, dspId, winCpmPrice);
        click = click + n;
    end

    for i, lnk in ipairs(link) do
        link[i], n = expandMacro(creative, lnk, adUnitId, dspId, winCpmPrice);
        click = click + n;
    end
    
    if click == 0 then
        insert(monitor, 1, generateClickUrl(dspId, adUnitId, creative.id));
    end

    return content;
end

local function alterSinaDspCreative(creative, adUnitId, dspId, winCpmPrice)
    local adData = ngx.ctx.adData;

    local status, result = pcall(cjson.decode, creative.markup)
    if status then 
        -- add click-through url
        local url = generateClickUrl(dspId, adUnitId, creative.id);
        result.monitor = result.monitor or {};
        result.monitor[#result.monitor + 1] =  url;

        -- add view url
        local viewUrl = generateViewUrl(dspId, adUnitId, creative.id, winCpmPrice);
        result.pvBegin = result.pvBegin or {};
        result.pvBegin[#result.pvBegin + 1] =  viewUrl;

        -- add winning price
        local notation = "";
        local capture = string.find(result.monitor[1], "?", 1, true);
        if capture then
            notation = "&"; 
        else
            notation = "?";
        end       

        local eKey = adData.dspObj:getEncryptionKey(dspId)
        local iKey = adData.dspObj:getIntegrityKey(dspId)
        local msg = util.encryptPrice(ngx.ctx.bidctx.uuid, eKey, iKey, winCpmPrice);
        local args = {};
        args[const.SINA_DSP_CLICK_ARG_P] = msg;

        result.monitor[1] = result.monitor[1] .. notation .. ngx.encode_args(args); 

        local capture = string.find(result.pvBegin[1], "?", 1, true);
        if capture then
            notation = "&"; 
        else
            notation = "?";
        end

        result.pvBegin[1] = result.pvBegin[1] .. notation .. ngx.encode_args(args);
        return result;
    else 
        ngx.log(ngx.ERR, result .. ":" .. creative.markup)

        return {};
    end
end

local function fillAdCreativeListForDsp(adUnitId, winner)
    local bidctx = ngx.ctx.bidctx;

    local adCreativeList = bidctx.adCreativeList;
    adCreativeList[adUnitId] = adCreativeList[adUnitId] or {};

    local content = adCreativeList[adUnitId];

    for _, creative in ipairs(winner.creative) do
        if winner.dspId == const.SINA_DSP_ID then
            content[#content + 1] = alterSinaDspCreative(creative, adUnitId, 
                                                        winner.dspId, winner.price);    
        else
            content[#content + 1] = dspParseVast(creative, adUnitId, 
                                                winner.dspId, winner.price);
        end
    end
       
end

local function removeAdFromPendList(adPendList, adUnitId)
    for i, id in ipairs(adPendList) do
        if id == adUnitId then
            table.remove(adPendList, i);
            return;
        end
    end
end

local function handleBidRsp(bidRspList)
    -- extract ad bid
    local adBidList = extractAdBid(bidRspList);


    for adUnitId, bidInfo in pairs(adBidList) do
        -- select winner 
        local winner = selectWinner(adUnitId, bidInfo);

        log.logDsp("confirm", adUnitId, winner);

        -- fill ad creative list
        fillAdCreativeListForDsp(adUnitId, winner);

        removeAdFromPendList(ngx.ctx.adData.adPendList, adUnitId);
    end

end

local function launchRtbForDsp()
    -- build bid request
    local bidReqList = buildBidReq();

    -- send bid request
    local bidRspList = {ngx.location.capture_multi(bidReqList)};

    -- handle bid response
    handleBidRsp(bidRspList);
end

local video_rtb = {
    launchRtbForDsp = launchRtbForDsp
}

return video_rtb
