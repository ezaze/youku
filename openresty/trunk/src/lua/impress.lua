local cjson = require("cjson");
local rtb = require("rtb");
local parser = require("parser");
local sax = require("sax");
local util = require("util");
local const = require("const");

local function parseAdReq()
    ngx.ctx.adReq = {};
    local adReq = ngx.ctx.adReq;
    adReq.publisherType = const.PC_PUBLISHER;

    -- parse callback function
    local callbackFunc = parser.getCallbackFunc();
    if callbackFunc ~= "" then
        ngx.ctx.ad_rsp_header = callbackFunc .. "(";
    else
        ngx.ctx.ad_rsp_header = const.AD_RSP_DEFAULT_HEADER;
    end

    -- parse ad unit id
    local adUnitIdStr= parser.getAdUnitId();
    if adUnitIdStr == "" then
        ngx.log(ngx.ERR, "failed to parse ad unit id");
        ngx.print(ngx.ctx.ad_rsp_header .. const.AD_INVALID_RSP .. const.AD_RSP_TAIL);
        ngx.exit(ngx.HTTP_OK);
    end

    adReq.adUnitIdList = util.split(adUnitIdStr, ",");
    
    -- parse rotate count
    local rotateCount = parser.getRotateCount();
    if rotateCount == "" then
        ngx.log(ngx.ERR, "failed to parse rotate count");
        ngx.print(ngx.ctx.ad_rsp_header .. const.AD_INVALID_RSP .. const.AD_RSP_TAIL);
        ngx.exit(ngx.HTTP_OK);
    end

    adReq.rotateCount = rotateCount;

    -- parse referer
    adReq.referer = parser.getReferer();
    
    -- parse page url
    local pageUrl = parser.getPageUrl();
    adReq.pageUrl = ngx.unescape_uri(pageUrl);

    -- parse page keyword
    adReq.pageKeyword = ngx.unescape_uri(parser.getPageKeyword());

    -- parse page entry 
    adReq.pageEntry = ngx.unescape_uri(parser.getPageEntry());

    -- parse page template 
    adReq.pageTemplate = ngx.unescape_uri(parser.getPageTemplate());

    -- parse ip 
    local ip = parser.getIp();

    adReq.ip = ip;
    
    -- parse cookie
    adReq.cookie = parser.getCookie();

    -- parser user id
    adReq.userId = parser.getUserId();

    -- parser user agent
    adReq.userAgent = parser.getUserAgent();

    -- wap version vt1 vt2 vt4
    adReq.version = "";

    -- parse timestamp
    local timestamp = parser.getTimestamp();
    if timestamp == "" then
        ngx.log(ngx.ERR, "failed to parse timestamp");
        ngx.print(ngx.ctx.ad_rsp_header .. const.AD_INVALID_RSP .. const.AD_RSP_TAIL);
        ngx.exit(ngx.HTTP_OK);
    end

    adReq.timestamp = timestamp;

    -- compute hash code
    adReq.hashCode = ngx.md5(adReq.ip .. adReq.cookie
                             .. adReq.pageUrl .. adReq.timestamp);

    -- for video ad
    adReq.vid = ngx.unescape_uri(parser.getVid());
    adReq.subid = ngx.unescape_uri(parser.getSubid());
    adReq.srcid = ngx.unescape_uri(parser.getSrcid());
    adReq.sports1 = ngx.unescape_uri(parser.getSports1());
    adReq.sports2 = ngx.unescape_uri(parser.getSports2());
    adReq.sports3 = ngx.unescape_uri(parser.getSports3());
    adReq.sports4 = ngx.unescape_uri(parser.getSports4());
end

local function getAdData()
    local adReq = ngx.ctx.adReq;
    ngx.ctx.adData = {};
    local adData = ngx.ctx.adData;
    local adPendList = {};
    adData.preDealQueryList = {};

    -- get ad unit object
    local adUnitObj = sax.newObject(const.OBJECT_ADUNIT);
    adData.adUnitObj = adUnitObj;

    -- get publisher object
    local publisherObj = sax.newObject(const.OBJECT_PUBLISHER);
    adData.publisherObj = publisherObj;

    -- get resource object
    local resourceObj = sax.newObject(const.OBJECT_RESOURCE);
    adData.resourceObj = resourceObj;

    -- get dsp object
    local dspObj = sax.newObject(const.OBJECT_DSP);
    adData.dspObj = dspObj;

    -- get creative object
    adData.creativeObj = sax.newObject(const.OBJECT_CREATIVE);

    -- get advertiser object
    adData.advertiserObj = sax.newObject(const.OBJECT_ADVERTISER); 

    local publisherId = nil;
    local resourceId = nil;
    local flag = true;
    for _, adUnitId in ipairs(adReq.adUnitIdList) do
        flag = true;
        if (not adUnitObj:isValid(adUnitId)) or 
            (adUnitObj:getStatus(adUnitId) == const.OBJECT_STATUS_INVALID) then
            flag = false;
        end

        if flag then
            publisherId = adUnitObj:getPublisher(adUnitId);

            if (not publisherObj:isValid(publisherId)) or 
                (publisherObj:getStatus(publisherId) == const.OBJECT_STATUS_INVALID) then
                flag = false;
           
            end
        end

        if flag then
            resourceId = publisherObj:getResource(publisherId);

            if (not resourceObj:isValid(resourceId)) or 
                (resourceObj:getStatus(resourceId) == const.OBJECT_STATUS_INVALID) then
                flag = false;
            end
        end

        if flag then
            table.insert(adPendList, adUnitId);
        end
    end
 
    return adPendList;
end

local function checkDspQps(dspQueryList)
    --[[
    if ngx.var.arg_istest and ngx.var.arg_noqpslimit then
        return;
    end
    --]]
    local adData = ngx.ctx.adData;
    -- check whether qps threshold of dsp has been reached
    local dspWhiteList = {};

    for dspId, adInfo in pairs(dspQueryList) do
        table.insert(dspWhiteList, dspId);
    end

    local qpsList = adData.dspObj:getQpsInfoList(dspWhiteList);
    for _, dspId in ipairs(dspWhiteList) do
        if qpsList[dspId].limit <= 0 or qpsList[dspId].count > qpsList[dspId].limit then
            ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_QPS
                          .. table.concat(dspQueryList[dspId], ",") .. "\t"
                          .. dspId
                          .. const.LOG_SEPARATOR_DSP_QPS);

            dspQueryList[dspId] = nil;
        end
    end

end

local function fillNetworkAd(adPendList, adCreativeList)
    local adData = ngx.ctx.adData;
    local networkObj = sax.newObject(const.OBJECT_NETWORK)

    -- fill network ad
    local loopList = {};
    for _, adUnitId in ipairs(adPendList) do
        table.insert(loopList, adUnitId);
    end

    for _, adUnitId in ipairs(loopList) do
        local used = adCreativeList[adUnitId] and #adCreativeList[adUnitId].content or 0;
        if used == 0 then
            local networkAdList = adData.adUnitObj:getNetworkList(adUnitId);

            local validAdList = {}            
            for _, networkAd in ipairs(networkAdList) do
                if networkObj:isValid(networkAd[1]) and networkObj:getNetworkStatus(networkAd[1]) == const.OBJECT_STATUS_VALID and networkAd[4] > 0 then
                    networkAd[5] = networkObj:getNetworkUrl(networkAd[1])
                    table.insert(validAdList, networkAd)
                end 
            end

            if #validAdList ~= 0 then
                local total = 0; 
                for _, networkAd in ipairs(validAdList) do
                    total = total + networkAd[4];
                end
                local i = math.random(1, total);

                for _, networkAd in ipairs(validAdList) do
                    if i <= networkAd[4] then
                        adCreativeList[adUnitId] = {};
                        adCreativeList[adUnitId].content = {};
                        local temp = {};
                        
                        if ngx.ctx.adReq.publisherType == const.PC_PUBLISHER then
                            local wdht = util.split(adData.adUnitObj:getSize(adUnitId), '*');
                            local args = {};
                            args.w = wdht[1];
                            args.h = wdht[2];
                            -- database store 'url?pid=', we need change to 'url?pid=&w=&h='
                            temp.src = { networkAd[5] .. networkAd[3] .. "&" .. ngx.encode_args(args) };
                            temp.type = { "url" };

                        elseif ngx.ctx.adReq.publisherType == const.WAP_PUBLISHER then                        
                            temp.src = {networkAd[5], networkAd[3]};
                            temp.type = {};
                            if networkAd[1] == const.BAIDU_NETWORK_ID then
                                temp.type = {"baidu_js", "id"};
                            end

                            if networkAd[1] == const.ANMO_NETWORK_ID then
                                temp.type = {"anmo_js", "id"};
                            end
                        end

                        temp.link = {};
                        temp.pv = {};
                        temp.monitor = {};
                        table.insert(adCreativeList[adUnitId].content, temp);

                        ngx.log(ngx.INFO, const.LOG_SEPARATOR_NETWORK_IMPRESS
                        .. adUnitId .. "\t"
                        .. networkAd[1] .. "\t"
                        .. networkAd[3]
                        .. const.LOG_SEPARATOR_NETWORK_IMPRESS);

                        -- remove ad unit from pending list whatever
                        rtb.removeAdFromPendList(adPendList, adUnitId);
                        break;
                    end

                    i = i - networkAd[4];
                end
            end
        end
    end
end

local function fillBottomAd(adPendList, adCreativeList)
    local adData = ngx.ctx.adData;

    -- fill bottom ad
    local loopList = {};
    for _, adUnitId in ipairs(adPendList) do
        table.insert(loopList, adUnitId);
    end

    for _, adUnitId in ipairs(loopList) do
        local bottomAdList = adData.adUnitObj:getNadList(adUnitId);

        if #bottomAdList ~= 0 then 
            -- random bottomAdList
            local size = #bottomAdList;
            for i = 1, size do
                local j = math.random(i, size);
                if i ~= j then
                    local tmp = bottomAdList[i];
                    bottomAdList[i] = bottomAdList[j];
                    bottomAdList[j] = tmp;
                end
            end

            adCreativeList[adUnitId] = adCreativeList[adUnitId] or {};
            adCreativeList[adUnitId].content = adCreativeList[adUnitId].content or {};

            local left = rtb.getLeftAdNum(adUnitId, adCreativeList);
            for i = 0, left-1 do
                local content = bottomAdList[i % size + 1];
                if ngx.ctx.adReq.publisherType == const.WAP_PUBLISHER then
                    content.adId = ngx.md5(content.src[1]);
                end
                table.insert(adCreativeList[adUnitId].content, content);
            end

            -- remove ad unit from pending list ? not necessary
            rtb.removeAdFromPendList(adPendList, adUnitId);
        end
    end
end

local function buildNewAdRsp(adCreativeList, cmUrlList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    -- build ad response
    local adRsp = {};

    adRsp.ad = {};
    for _, adUnitId in ipairs(adReq.adUnitIdList) do
        local temp = {};
        temp.id = adUnitId;
        temp.type = adData.adUnitObj:getDisplayType(adUnitId);
        temp.size = adData.adUnitObj:getSize(adUnitId);
    
        if not adCreativeList[adUnitId] then
            temp.content = {}
        else
            temp.content = adCreativeList[adUnitId].content
        end
        table.insert(adRsp.ad, temp);
        
    end
	
    if #cmUrlList == 0 then
        adRsp.mapUrl = {};
    else
        adRsp.mapUrl = cmUrlList;
    end

    return cjson.encode(adRsp);
end

local function getDspQueryList(adPendList)
    local adData = ngx.ctx.adData;
    local dspQueryList = {};

    for _, adUnitId in ipairs(adPendList) do
        local publisherId = adData.adUnitObj:getPublisher(adUnitId);
        local resourceId = adData.publisherObj:getResource(publisherId);

        local dspIdList = adData.resourceObj:getWhiteDspList(resourceId);
        for _, dspId in ipairs(dspIdList) do
            if adData.dspObj:isValid(dspId) and adData.dspObj:getStatus(dspId) == const.OBJECT_STATUS_VALID then
                if not dspQueryList[dspId] then
                    dspQueryList[dspId] = {};
                end
                table.insert(dspQueryList[dspId], adUnitId);
            end
        end
    end

    checkDspQps(dspQueryList);
    return dspQueryList;
end

local function getSinaQueryList(adPendList)
    local adData = ngx.ctx.adData;
    local sinaQueryList = {};

    for _, adUnitId in ipairs(adPendList) do
        local publisherId = adData.adUnitObj:getPublisher(adUnitId);
        local resourceId = adData.publisherObj:getResource(publisherId);

        if adData.resourceObj:getFlag(resourceId) == const.OBJECT_FLAG_SET then
            table.insert(sinaQueryList, adUnitId);
        end
    end

    return sinaQueryList;
end

local function getPreDealQueryList()
    local adData = ngx.ctx.adData;

    checkDspQps(adData.preDealQueryList);

    return adData.preDealQueryList;
end

local function newImpress()
    -- parse ad request
    parseAdReq();
    
    -- get ad data
    local adPendList = getAdData();

    local adCreativeList = {};
    local cmUrlList = {};
    local winPriceList = {};
    local preDealWinPriceList = {};

    local sinaQueryList = getSinaQueryList(adPendList);

    -- query sina ad engine
    if #sinaQueryList ~= 0 then
        rtb.querySinaAdEngine(sinaQueryList, adPendList, adCreativeList);
    end

    -- query dsp preferred deal
    local preDealQueryList = getPreDealQueryList();
    if next(preDealQueryList) then
        ngx.ctx.adData.auction_type = const.AUCTION_TYPE_PREFERRED_DEAL;
        preDealWinPriceList = rtb.launchRtbForDsp(preDealQueryList, adPendList,
                                                      adCreativeList, cmUrlList);
    end

    -- get query dsp ad list
    local dspQueryList = getDspQueryList(adPendList);
        
    -- launch real time bidding for dsp 
    if next(dspQueryList) then
        ngx.ctx.adData.auction_type = const.AUCTION_TYPE_OPEN_AUCTION;
        winPriceList = rtb.launchRtbForDsp(dspQueryList, adPendList, 
                                               adCreativeList, cmUrlList);
    end

    -- fill network ad
    if #adPendList ~= 0 then
        fillNetworkAd(adPendList, adCreativeList);
    end

    -- fill bottom ad
    if #adPendList ~= 0 then
        fillBottomAd(adPendList, adCreativeList);
    end
    
    -- build ad response
    local adRsp = buildNewAdRsp(adCreativeList, cmUrlList);

    -- send ad response and rely on client to close the connection actively
    ngx.header.content_type = "application/javascript";
    ngx.print(ngx.ctx.ad_rsp_header .. adRsp .. const.AD_RSP_TAIL);
    ngx.eof();

    -- confirm  preferred deal winning price in asynchronous mode
    if next(preDealWinPriceList) then
        rtb.cfmWinPrice(preDealWinPriceList);
    end

    -- confirm winning price in asynchronous mode 
    if next(winPriceList) then
        rtb.cfmWinPrice(winPriceList);
    end

end

local function parseWapAdReq()
    ngx.ctx.adReq = {};
    local adReq = ngx.ctx.adReq;
    adReq.publisherType = const.WAP_PUBLISHER;
    ngx.ctx.ad_rsp_header = const.AD_RSP_DEFAULT_HEADER;

    -- parse ad request body
    local adReqBody = parser.getBodyData();
    
    local status, requestBody = pcall(cjson.decode, adReqBody)
    if not status then
        ngx.log(ngx.ERR, "json decode request body error." .. requestBody .. " : " .. adReqBody);
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end

    --check adunit id
    if #requestBody.adunit_id == 0 then
        ngx.log(ngx.ERR, "failed to parse adunit.");
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end
    adReq.adUnitIdList = requestBody.adunit_id;

    --parse version
    adReq.version = requestBody.version or "";

    --check timestamp
    if not requestBody.timestamp or requestBody.timestamp == "" then
        ngx.log(ngx.ERR, "failed to parse timestamp.");
        ngx.exit(ngx.HTTP_BAD_REQUEST);    
    end
    adReq.timestamp = requestBody.timestamp;

    --check rotate_cout
    if not requestBody.rotate_count or requestBody.rotate_count == "" then
        ngx.log(ngx.ERR, "failed to parse rotate count.");
        ngx.exit(ngx.HTTP_BAD_REQUEST); 
    end
    adReq.rotateCount = tostring(requestBody.rotate_count);

    --parse cookie id
    adReq.cookie = requestBody.cookie_id or "";
    adReq.cookie = (adReq.cookie ~= cjson.null) and adReq.cookie or "";

    --parse ip
    adReq.ip = requestBody.ip or "";

    --parse page url
    adReq.pageUrl = requestBody.page_url or "";
    if adReq.pageUrl == cjson.null then
        adReq.pageUrl = ""
    end

    --parse user agent
    adReq.userAgent = requestBody.ua or "";

    --parse referer
    adReq.referer = "";

    -- parse page keyword
    adReq.pageKeyword = "";

    -- parse page entry 
    adReq.pageEntry = "";

    -- parse page template 
    adReq.pageTemplate = "";

    -- parser user id
    adReq.userId = "";

    -- compute hash code
    adReq.hashCode = ngx.md5(adReq.ip ..adReq.cookie
                             .. adReq.pageUrl .. adReq.timestamp);
end

local function parseWapContentType(contentTypeList)
    local typeStr = "";

    if contentTypeList[1] == "text" and #contentTypeList == 1 then
         typeStr = "text";
    end

    if contentTypeList[1] == "text" and contentTypeList[2] == "text" then
        typeStr = "text";
    end

    if contentTypeList[1] == "text" and contentTypeList[2] == "image" then
        typeStr = "image_text";
    end

    if contentTypeList[1] == "image" and contentTypeList[2] == "alt" then
        typeStr = "image";
    end

    if contentTypeList[1] == "js" and #contentTypeList == 1 then
        typeStr = "rich_media";
    end

    if contentTypeList[1] == "baidu_js" and contentTypeList[2] == "id" then
        typeStr = "baidu_network";
    end

    if contentTypeList[1] == "anmo_js" and contentTypeList[2] == "id" then
        typeStr = "anmo_network";
    end

    return typeStr;
end

local function buildWapAdRsp(adCreativeList, cmUrlList)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    -- build ad response
    local adRsp = {};

    adRsp.ad = {};
    for _, adUnitId in ipairs(adReq.adUnitIdList) do
        local temp = {};
        temp.id = adUnitId;
        temp.type = adData.adUnitObj:getDisplayType(adUnitId);
        temp.size = adData.adUnitObj:getSize(adUnitId);
        temp.content = {};
        if adCreativeList[adUnitId] then
            for _, content in ipairs(adCreativeList[adUnitId].content) do
                local tempContent = {}
                tempContent.src = content.src;
                tempContent.type = parseWapContentType(content.type);
                tempContent.pv = content.pv;
                tempContent.ad_id = content.adId or "";
                tempContent.link = content.link;
                table.insert(temp.content, tempContent);
           end
        end

        table.insert(adRsp.ad, temp);
    end

    if #cmUrlList == 0 then
        adRsp.cm = {};
    else
        adRsp.cm = cmUrlList;
    end

    return cjson.encode(adRsp);
end

local function wapImpress()
    -- parse ad request
    parseWapAdReq();
    
    -- get ad data
    local adPendList = getAdData();

    local adCreativeList = {};
    local cmUrlList = {};
    local winPriceList = {};
    local preDealWinPriceList = {};

    local sinaQueryList = getSinaQueryList(adPendList);
    -- query sina ad engine
    if #sinaQueryList ~= 0 then
        rtb.querySinaAdEngine(sinaQueryList, adPendList, adCreativeList);
    end

    -- query dsp preferred deal
    local preDealQueryList = getPreDealQueryList();
    if next(preDealQueryList) then
        ngx.ctx.adData.auction_type = const.AUCTION_TYPE_PREFERRED_DEAL;
        preDealWinPriceList = rtb.launchRtbForDsp(preDealQueryList, adPendList, adCreativeList, cmUrlList);
    end
    
    -- get query dsp ad list
    local dspQueryList = getDspQueryList(adPendList);
        
    -- launch real time bidding for dsp 
    if next(dspQueryList) then
        ngx.ctx.adData.auction_type = const.AUCTION_TYPE_OPEN_AUCTION;
        winPriceList = rtb.launchRtbForDsp(dspQueryList, adPendList, adCreativeList, cmUrlList);
    end

    -- fill network ad
    if #adPendList ~= 0 and ngx.ctx.adReq.version == "vt4" then
        fillNetworkAd(adPendList, adCreativeList);
    end

    -- fill bottom ad
    if #adPendList ~= 0 then
        fillBottomAd(adPendList, adCreativeList);
    end

    -- build ad response
    local adRsp = buildWapAdRsp(adCreativeList, cmUrlList);

    -- send ad response and rely on client to close the connection actively
    ngx.header.content_type = 'application/json';
    ngx.print(adRsp);
    ngx.eof();

    -- confirm  preferred deal winning price in asynchronous mode
    if next(preDealWinPriceList) then
        rtb.cfmWinPrice(preDealWinPriceList);
    end

    -- confirm winning price in asynchronous mode 
    if next(winPriceList) then
        rtb.cfmWinPrice(winPriceList);
    end

end

local impress = {
    newImpress = newImpress,
    wapImpress = wapImpress
};

return impress;

