local db        = require "db"
local object    = require "object"
local const     = require "const"
local util      = require "util"

local publisher = {
    objectName              = const.OBJECT_PUBLISHER,
    getInfoDB               = db.selectPublisherInfo,
    getInfoListDB           = db.selectPublisherInfoList,
    getInfoAllDB            = db.selectPublisherInfoAll
}

--transfrom  yuan to fen
local function transformDspPrice(v)
    return math.floor(tonumber(v) * 100)
end

publisher._attr_mem = {
    id          = {1,   "number", false},
    resource    = {2,   "number", false},
    dspprice    = {3,   "number", false, 0,  transformDspPrice},
    blackadtype = {4,   "table",  true,  const.EMPTY_TABLE},
    blackterm   = {5,   "table",  true,  const.EMPTY_TABLE},
    blackclickurl = {6, "table",true,  const.EMPTY_TABLE},
    status      = {7,   "number", false}
}

publisher.__index = publisher
setmetatable(publisher, object)

function publisher:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, publisher)
end

function publisher:getLowestPrice(id)
    return self:getAttribute(id, 3)
end

function publisher:getBlackProductTypeList(id)
    return self:getAttribute(id, 4)
end

function publisher:getBlackTermList(id)
    return self:getAttribute(id, 5)
end

function publisher:getBlackClickUrlList(id)
    return self:getAttribute(id, 6)
end

function publisher:getResource(id)
    return self:getAttribute(id, 2)
end

function publisher:getStatus(id)
    return self:getAttribute(id, 7)
end

return publisher
