local const = require "const";
local pairs = pairs;
local ipairs = ipairs;
local insert = table.insert;
local concat = table.concat;

local _M = {}

local function logDspReq(bid, adPendList, dspId)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_REQ,
    bid, "\t",
    dspId , "\t",
    concat(adPendList, ","),
    const.LOG_SEPARATOR_DSP_REQ);
end

local function logDspRsp(bid, dspId, ads)
    local adData = ngx.ctx.adData;

    local adLog = {};
    for _, ad in ipairs(ads.ad) do
        local id = adData.crvObj:getUniqueId(dspId, ad.id);
        if not id then
            id = "invalid"
        end
        local str = "(" .. ad.id .. "," .. id .. ")";

        adLog[#adLog + 1] = str;
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_RSP,
     bid, "\t",
     dspId, "\t",
     ads.id, "\t",
     ads.price, "\t",
     concat(adLog, ","),
     const.LOG_SEPARATOR_DSP_RSP);
end


local function logDspFoul(bid, dspId, adUnitId, creativeId)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_FOUL,
     bid, "\t",
     dspId, "\t",
     adUnitId, "\t",
     creativeId,
     const.LOG_SEPARATOR_DSP_FOUL);
end
local function logDspNull(bid, dspId)
    ngx.log(ngx.DEBUG, const.LOG_SEPARATOR_DSP_NULL,
     bid, "\t",
     dspId,
     const.LOG_SEPARATOR_DSP_NULL);
end

local function logDspInvalid(bid, dspId)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_INVALID,
     bid, "\t",
     dspId,
     const.LOG_SEPARATOR_DSP_INVALID);
end


local function logDspFail(bid, dspId, phase, status)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_FAIL,
     bid, "\t",
     dspId, "\t",
     phase, "\t",
     status,
     const.LOG_SEPARATOR_DSP_FAIL);
end

local function logDspCfm(bid, adUnitId, winner)
    local adReq = ngx.ctx.adReq;
    local adData = ngx.ctx.adData;

    local creativeLog = {};
    for _, creative in ipairs(winner.creative) do
        local str = "(" .. creative.id .. ","
                    .. adData.crvObj:getUniqueId(winner.dspId, creative.id) .. ")";
        insert(creativeLog, str);
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_CFM,
                       bid, "\t",
                       winner.dspId, "\t",
                       adUnitId, "\t",
                       winner.price, "\t",
                       concat(creativeLog, ","),
                       const.LOG_SEPARATOR_DSP_CFM,
                       const.LOG_SEPARATOR_DSP_TARGETING,
                       ((adReq.pageUrl ~= "") and adReq.pageUrl or "-"), "\t",
                       ((adReq.ip ~= "") and adReq.ip or "-"), "\t",
                       ((adReq.cookie ~= "") and adReq.cookie or "-"),
                       const.LOG_SEPARATOR_DSP_TARGETING);
end

local logFunc = {
    request = logDspReq,
    response = logDspRsp,
    foul = logDspFoul,
    null = logDspNull,
    invalid = logDspInvalid,
    fail = logDspFail,
    confirm = logDspCfm
}

function _M.logDsp(logType, ...)
    logFunc[logType](ngx.ctx.bidctx.bid, ...)
end

return _M;
