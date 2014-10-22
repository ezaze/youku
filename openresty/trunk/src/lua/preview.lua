local rtb = require "rtb"
local parser = require "parser"
local const = require "const"
local sax = require "sax"
local util = require "util"
local impress  = require "impress"
local cjson = require "cjson"

local function buildSinaPreviewReq()
    ngx.ctx.adReq = {}; 
    local adReq = ngx.ctx.adReq
    local adunitObj = sax.newObject(const.OBJECT_ADUNIT)
    adReq.adunitObj = adunitObj
    local body = {}

    local callbackFunc = parser.getCallbackFunc(); 
    if callbackFunc ~= "" then
        ngx.ctx.ad_rsp_header = callbackFunc .. "("; 
    else
      ngx.ctx.ad_rsp_header = const.AD_RSP_DEFAULT_HEADER;                                                                                                       
    end

    body.adunitId = parser.getAdUnitId()
    body.rotateCount = parser.getRotateCount()
    body.cookieId = parser.getCookie()
    body.userId = parser.getUserId()
    body.ip  = parser.getIp();
    local pageUrl = parser.getPageUrl();
    
    body.pageUrl = ngx.unescape_uri(pageUrl)
    body.pageKeyword = ngx.unescape_uri(parser.getPageKeyword())
    body.pageEntry = ngx.unescape_uri(parser.getPageEntry())
    body.pageTemplate = ngx.unescape_uri(parser.getPageTemplate())

    local timestamp = parser.getTimestamp();
    if timestamp == "" then
        ngx.log(ngx.ERR, "failed to parse timestamp");
        ngx.print(ngx.ctx.ad_rsp_header .. const.AD_INVALID_RSP .. const.AD_RSP_TAIL);
        ngx.exit(ngx.HTTP_OK);
    end 
    local hashCode = ngx.md5(body.ip .. body.cookieId
                             .. body.pageUrl .. timestamp);
    body.hashCode = hashCode
   
    local channelList = {}
    local adunitIdList = util.split(body.adunitId, ",")
    adReq.adunitIdList = adunitIdList

    for _ , v in ipairs (adunitIdList) do
        local channel = adunitObj:getChannel(v)
        if channel == nil then channel = "" end
        table.insert(channelList, channel)
    end
    
    body.channel = table.concat(channelList, ",")
    body.version = ""
    body.ua = parser.getUserAgent();
    body.date = parser.getPreviewDate();
    body.deid = parser.getDeId()
 
    local jsonStr = cjson.encode(body) 
    -- build request
    local option ={}
    option.method = ngx.HTTP_POST
    option.body = jsonStr
    option.vars = {}
    option.vars[const.NGINX_VAR_URL] = const.SINA_PREVIEW_URL_SINA;
    option.vars[const.NGINX_VAR_HASH_STR] = (body.cookieId ~= "") and body.cookieId or body.ip        
    return option
end

local function fillAdCreativeListForSina(ad, adCreativeList)
    adCreativeList[ad.id] = adCreativeList[ad.id] or {};
    adCreativeList[ad.id].content = adCreativeList[ad.id].content or {};

    for _, creative in ipairs(ad.value) do
        if next(creative.content) then
            local temp = creative.content;
            temp.adId = creative.lineitemId;
            table.insert(adCreativeList[ad.id].content, temp);
        end
    end
end

local function querySinaEngine(option)
    local queryRsp = ngx.location.capture(const.PREVIEW_QUERY_URI, option);
    if queryRsp.status ~= ngx.HTTP_OK then
        ngx.log(ngx.ERR, "failed to query sina ad engine, status:" .. queryRsp.status);
        ngx.log(ngx.INFO,cjson.encode(queryRsp))
        return {}; 
    end 
    
    local status, queryResult = pcall(cjson.decode, queryRsp.body);
    if not status then
        ngx.log(ngx.ERR, queryResult .. ":" .. queryRsp.body);
        return {}; 
    end 

    return queryResult
end

local function  handleSinaPreviewRsp(queryResult, adCreativeList)
--    local queryResult = querySinaEngine()    

    for _ , ad in ipairs(queryResult) do
        if #ad.value ~= 0 then 
            fillAdCreativeListForSina(ad, adCreativeList)
        end
    end
    
end

local function buildSinaRsp(adCreativeList)
    local adReq = ngx.ctx.adReq
    local adRsp = {}
    adRsp.ad= {} 
     
    for  _, adunitId in ipairs (adReq.adunitIdList) do
        local temp = {}
        temp.id = adunitId
        temp.type = adReq.adunitObj:getDisplayType(adunitId);
        temp.size = adReq.adunitObj:getSize(adunitId);
        
        if not adCreativeList[adunitId] then
            temp.content = {}
        else
            temp.content = adCreativeList[adunitId].content
        end 
        table.insert(adRsp.ad, temp);       
    end

    adRsp.mapUrl = {}; 

    return cjson.encode(adRsp);
end


local function sinaPreview()
    local  adCreativeList = {};
    local option = buildSinaPreviewReq()
    local queryResult = querySinaEngine(option)
    handleSinaPreviewRsp(queryResult, adCreativeList);        
    local adRsp = buildSinaRsp(adCreativeList); 
    ngx.header.content_type = "application/javascript";   
    ngx.print(ngx.ctx.ad_rsp_header .. adRsp .. const.AD_RSP_TAIL); 
end

--build req for 
local function buildVideoPreviewReq()
    local body ={}
    body.adunitId = parser.getPosition();
    ngx.ctx.position = body.adunitId;
    body.rotation = parser.getRotateCount();
    local length = tonumber(parser.getLength());
    if length then
        if length < const.VIDEO_LENGTH_THRESH_SHORT then
            body.v_length = const.VIDEO_LENGTH_TYPE_SHORT;
        elseif length > const.VIDEO_LENGTH_THRESH_LONG then
            body.v_length = const.VIDEO_LENGTH_TYPE_LONG;
        else 
            body.v_length = const.VIDEO_LENGTH_TYPE_MEDIUM;
        end
    else
        body.v_length = ""
    end

    body.site = ngx.unescape_uri(parser.getSite());
    body.hostname = ngx.unescape_uri(parser.getHostname());
    body.client = ngx.unescape_uri(parser.getClient());
    body.vid = ngx.unescape_uri(parser.getVid());
    body.movietvid = ngx.unescape_uri(parser.getMovietvid());
    body.subid = ngx.unescape_uri(parser.getSubid());
    body.srcid = ngx.unescape_uri(parser.getSrcid());
    body.v_cha = ngx.unescape_uri(parser.getChannel());
    body.v_sub = ngx.unescape_uri(parser.getSubject());
    body.v_sports1 = ngx.unescape_uri(parser.getSports1());
    body.v_sports2 = ngx.unescape_uri(parser.getSports2());
    body.v_sports3 = ngx.unescape_uri(parser.getSports3());
    body.v_sports4 = ngx.unescape_uri(parser.getSports4());
    body.room = ngx.unescape_uri(parser.getRoom());
    body.ip = parser.getIp();
    body.cookieId = parser.getCookie();
    body.userId  = parser.getUserId();
    -- build hash code
    local timestamp = parser.getTimestamp();
    body.hashCode = ngx.md5(body.ip .. body.cookieId .. timestamp); 
    body.liveid = ngx.unescape_uri(parser.getLiveId()) 
    body.media_tags = ngx.unescape_uri(parser.getMediaTags());
    body.live_tags = ngx.unescape_uri(parser.getLiveTags());
    body.pageUrl = parser.getVideoPageUrl(); 
    -- add preview date
    body.date = parser.getPreviewDate()
    body.deid = parser.getDeId()
    local jsonStr = cjson.encode(body);
    
    local option = {}
    option.method = ngx.HTTP_POST
    option.body = jsonStr
    option.vars = {}    
    option.vars[const.NGINX_VAR_URL]= const.SINA_PREVIEW_URL_VIDEO 
    option.vars[const.NGINX_VAR_HASH_STR] = (body.cookieId ~= "") and body.cookieId or body.ip
    return option
end

local function validVideoAd(ad) 
    if type(ad.value) ~= "table" then 
       error("invalid field ad.value") 
    end 

    for _,creative in ipairs(ad.value) do  
        if type(creative.content) ~= "table" then
            error("invalid field  creative.content")
        end 
    
        if type(creative.t)~= "string" then
           error("invalid field creative.t")
        end 
    end 
end 


local function buildVideoResult(adCreativeList)
    local result ={}
    local ids  = util.split(ngx.ctx.position)
    for _, id in ipairs (ids) do   
        local temp = {}
        temp.pos = id
        if not adCreativeList[id] then 
            temp.content  = {}
        else 
            temp.content = adCreativeList[id].content
        end
        table.insert(result,temp)
    end
    return result
end

local function handleVideoRsp(queryResult)
    --    local result =  buildResult()
    local adCreativeList = {}
    for _, ad in ipairs(queryResult) do

        adCreativeList[ad.id]= adCreativeList[ad.id] or {}
        adCreativeList[ad.id].content= adCreativeList[ad.id].content or {}
        local status, res = pcall(validVideoAd, ad)

        if status then
            for _ ,adCreative in ipairs(ad.value) do
                local str = ngx.decode_base64(adCreative.t)
                if not str then
                    ngx.log(ngx.ERR, "invalid base64 str t:" .. adCreative.t .. " pos:" .. ad.id )
                else
                    if next(adCreative) then
                         table.insert(adCreativeList[ad.id].content, adCreative.content)
                         ngx.log(ngx.INFO, const.LOG_SEPARATOR_VIDEO_IMPRESS
                              .. str
                              .. const.LOG_SEPARATOR_VIDEO_IMPRESS);
                    end
                 end
            end
        else
           ngx.log(ngx.ERR, res .. ":" .. cjson.encode(ad))
        end
    end

    local result = buildVideoResult(adCreativeList)
    local res ={}
    res.ad = result
    return  res    
end

local function videoPreview()
   local callbackFunc = parser.getCallbackFunc()
   local option =  buildVideoPreviewReq()
   local queryResult = querySinaEngine(option)
   local adList = handleVideoRsp(queryResult)
   local jsonStr = cjson.encode(adList)
   if callbackFunc ~= "" then
        ngx.print( callbackFunc .. "(" ..  jsonStr ..")")
   else
        ngx.print(jsonStr)
   end
  
end

local function parseWapAdReq()
    ngx.ctx.adReq= {}
    local adReq = ngx.ctx.adReq
    local adunitObj = sax.newObject(const.OBJECT_ADUNIT)
    adReq.adunitObj = adunitObj
    ngx.ctx.ad_rsp_header = const.AD_RSP_DEFAULT_HEADER;
    
    -- parse body data
    local adReqBodyData = parser.getBodyData();
    local status, requestBody = pcall(cjson.decode, adReqBodyData)
    if not status then
        ngx.log(ngx.ERR, "failed parser requestbody" .. requestBody .. ":" .. adReqBodyData  )
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end  

    local adunitIdList = requestBody.adunit_id

    local body = {}
    if #adunitIdList == 0 then
        ngx.log(ngx.ERR, "failed to parse adunit") 
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    body.adunitId = table.concat(adunitIdList, ",")
    body.rotateCount = tostring(requestBody.rotate_count)
    body.cookieId = requestBody.cookie_id or ""
    body.cookieId = (body.cookie_Id ~= cjson.null)and body.cookieId or ""
    body.userId = ""
    if requestBody.tgip and requestBody.tgip ~= "" then
        body.ip = requestBody.tgip
    else
        body.ip = requestBody.ip or ""
    end
    local pageUrl = requestBody.page_url or ""
    body.pageUrl = ngx.unescape_uri(pageUrl)
    body.pageKeyword = ""
    body.pageEntry =  ""
    body.pageTemplate = ""

    local timestamp = requestBody.timestamp or ""
    if timestamp == "" then
        ngx.log(ngx.ERR, "failed to parse timestamp")
        ngx.print(ngx.ctx.ad_rsp_header .. const.AD_INVALID_RSP .. const.AD_RSP_TAIL)
        ngx.exit(ngx.HTTP_OK)
    end

    local hashCode = ngx.md5(body.ip .. body.cookieId .. body.pageUrl .. timestamp)
    body.hashCode = hashCode 
    local channelList ={}   
    adReq.adunitIdList = adunitIdList

    for _ , v in ipairs (adunitIdList) do
        local channel = adunitObj:getChannel(v)
        if channel == nil then channel = "" end
        table.insert(channelList, channel)
    end

    body.version = ""
    body.ua = requestBody.ua or ""
    body.date = requestBody.date or ""
    body.deid = requestBody.deid or ""    
    local jsonStr = cjson.encode(body) 
  
    local option = {}
    option.method = ngx.HTTP_POST
    option.body = jsonStr
    option.vars = {}
    option.vars[const.NGINX_VAR_URL] = const.SINA_PREVIEW_URL_WAP;
    option.vars[const.NGINX_VAR_HASH_STR] = (body.cookieId ~= "") and body.cookieId or body.ip

    return option

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

    return typeStr;
end

local function  buildWapRsp(adCreativeList)
    local adReq = ngx.ctx.adReq
    local adRsp = {}
    adRsp.ad ={}
    
    for _ , adunitId in ipairs(adReq.adunitIdList) do
        local temp = {}
        temp.id = adunitId
        temp.type = adReq.adunitObj:getDisplayType(adunitId)
        temp.size = adReq.adunitObj:getSize(adunitId);
        temp.content = {}

        if adCreativeList[adunitId] then
            for _, content in ipairs(adCreativeList[adunitId].content) do
                local tempContent = {}
                tempContent.src = content.src
                tempContent.type =  parseWapContentType(content.type);
                tempContent.pv = content.pv
                tempContent.ad_id = content.adId or "";
                tempContent.link = content.link
                
                table.insert(temp.content, tempContent);
            end      
        end
        table.insert(adRsp.ad, temp);
    end
 
    adRsp.cm = {}
    return cjson.encode(adRsp)
end

local function wapPreview()
    local option = parseWapAdReq()
    local queryResult = querySinaEngine(option)
    local adCreativeList = {}
    handleSinaPreviewRsp(queryResult, adCreativeList)
    local rsp = buildWapRsp(adCreativeList)
    ngx.header.content_type = 'application/json';
    ngx.print(rsp);      
end


local preview = {
    sinaPreview = sinaPreview,
    videoPreview = videoPreview,
    wapPreview = wapPreview
}

return preview
