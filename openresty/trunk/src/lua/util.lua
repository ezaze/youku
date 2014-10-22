local cjson = require("cjson");
local const = require("const");
local struct = require("struct");
local bit = require("bit");
local db = require("db")
local resty_string = require("resty.string");

local function split(str, delim, maxNb)   
    -- Eliminate bad cases...
    if delim == nil then delim = "," end

    if string.find(str, delim) == nil then  
        return { str }  
    end  
    if maxNb == nil or maxNb < 1 then  
        maxNb = 0    -- No limit   
    end  
    local result = {}  
    local pat = "(.-)" .. delim .. "()"   
    local nb = 0  
    local lastPos   
    for part, pos in string.gfind(str, pat) do  
        nb = nb + 1  
        result[nb] = part   
        lastPos = pos   
        if nb == maxNb then break end  
    end  
    -- Handle the last field   
    if nb ~= maxNb then  
        result[nb + 1] = string.sub(str, lastPos)   
    end  
    return result   
end

local function sid(cookie)
    if cookie == "" then
        return "";
    else
        local digest = ngx.md5_bin(cookie);

        return ngx.encode_base64(digest);
    end
end

local function isAllowedForPd(dspWhiteList, dspId)
    for _, id in ipairs(dspWhiteList) do
        if id == dspId then
            return true
        end
    end

    return false
end

local function checkAdvertiserType(auctionType, advertiserType)
    local i
    if auctionType == const.AUCTION_TYPE_PREFERRED_DEAL then
        i = 1
    elseif auctionType == const.AUCTION_TYPE_PRIVATE_AUCTION then
        i = 2
    elseif auctionType == const.AUCTION_TYPE_OPEN_AUCTION then
        i = 3
    else
        i = 0
    end

    if string.sub(advertiserType, i, i) == "1" then
        return true
    else
        return false
    end
end

local function encryptPrice(iv, eKey, iKey, winCpmPrice)
    local pad = string.sub(ngx.hmac_sha1(eKey, iv), 1, 8); 
    local price = struct.pack(">i8", winCpmPrice);
    local enc_price = {}; 
    for i = 1, 8 do
        local str = string.char(bit.bxor(string.byte(pad, i), string.byte(price, i)));
        table.insert(enc_price, str);
    end 
    enc_price = table.concat(enc_price);
    local signature = string.sub(ngx.hmac_sha1(iKey, price .. iv), 1, 4); 
    local msg = ngx.encode_base64(iv .. enc_price .. signature);

    return msg
end

local function decodeLogStr(str)
    local res = ngx.unescape_uri(str)  
    res = ngx.decode_base64(res)
    
    if not res then
        res = "invalid base64 str:" .. str 
    end

    return res   
end

local function notifyThirdPartyMonitor(urlList)
    local reqList = {};
    for _, url in ipairs(urlList) do
        local req = {};
        req[1] = const.THIRD_PARTY_MONITOR_URI;
        req[2] = {};
        req[2].method = ngx.HTTP_GET;
        req[2].vars = {};
        req[2].vars[const.NGINX_VAR_URL] = url;

        table.insert(reqList, req);
    end

    local rspList = {ngx.location.capture_multi(reqList)};

    for i, rsp in ipairs(rspList) do
        if rsp.status ~= ngx.HTTP_OK then
            ngx.log(ngx.ERR, "failed to notify " .. urlList[i] .. ", status:" .. rsp.status);
        end
    end
end

local function getDict(id)
    return ngx.shared.sax:get(id)
end

local function setDict(id, value, exptime)
    exptime = exptime or 0
    return ngx.shared.sax:set(id, value, exptime)
end

local function addDict(id, value, exptime)
    exptime = exptime or 0
    return ngx.shared.sax:add(id, value, exptime)
end

local function incrDict(id, step)
    return ngx.shared.sax:incr(id, step)
end

local function flushAllDict()
    ngx.shared.sax:flush_all()
end

local function flushExpiredDict()
    ngx.shared.sax:flush_expired()
end

local function genKeyForQpsCount(id)
    return const.DSP_QPS_COUNT_PREFIX .. id
end

local function genKeyForQpsTotal(id)
    return const.DSP_QPS_TOTAL_PREFIX .. id
end

local function genKeyForQpsLimit(id)
    return const.DSP_QPS_LIMIT_PREFIX .. id
end

local function trim(str)
    local tmp = string.gsub(str, "^%s+", "");
    local tmp = string.gsub(tmp, "%s+$", "");
    return tmp;
end

local function alarm(subject, content)
    local centerList = db.selectCenterInfoAll()
    local localIP = ngx.var.server_addr 
    local flag = false 
    for _, center in ipairs(centerList) do
        if center.ip == localIP then
            flag = true
            break
        end
     end
  
    if flag  then
        os.execute("cd /usr/local/openresty/nginx/src/script/alarm && ./send_alert.pl "
                    ..  " --sv \"搜索频道\" " 
                    ..  "--service \"AD Engine \"" 
                    ..  " --object \"Monitor\""
                    ..  " --subject " .. "\"" .. subject  .. "\""
                    ..  " --content " .. "\""  .. content .. "\"" 
                    ..  " --gmailto \"ad_engine_monitor\""
                    ..  " --gmsgto \"ad_engine_monitor\"")
    else 
        ngx.log(ngx.ERR, "local ip in not in the center  list .")
    end
end

local function generateSign(signkey, url)
   local pad =  string.sub( ngx.hmac_sha1(signkey, url), 1, 16)
   return resty_string.to_hex(pad)
end

local util = {
    trim            = trim,
    split           = split,
    sid             = sid,
    isAllowedForPd  = isAllowedForPd,
    checkAdvertiserType = checkAdvertiserType,
    encryptPrice    = encryptPrice,
    notifyThirdPartyMonitor = notifyThirdPartyMonitor,
    decodeLogStr    = decodeLogStr,

    getDict         = getDict,
    setDict         = setDict,
    addDict         = addDict,
    incrDict        = incrDict,
    flushAllDict    = flushAllDict,
    flushExpiredDict= flushExpiredDict,    

    genKeyForQpsCount   = genKeyForQpsCount,
    genKeyForQpsTotal   = genKeyForQpsTotal,
    genKeyForQpsLimit   = genKeyForQpsLimit,

    alarm              = alarm,
    generateSign       = generateSign 
}

return util

