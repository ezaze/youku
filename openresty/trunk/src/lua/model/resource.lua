local db        = require "db"
local object    = require "object"
local const     = require "const"

local resource = {
    objectName              = const.OBJECT_RESOURCE,
    getInfoDB               = db.selectResourceInfo,
    getInfoListDB           = db.selectResourceInfoList,
    getInfoAllDB            = db.selectResourceInfoAll
}

resource._attr_manage_end = {
    id               = {const.OBJECT_ATTR_UPDATE_INSERT, "number"},
    levelname        = {const.OBJECT_ATTR_NONE, "string"},
    flag             = {const.OBJECT_ATTR_NONE, "number"},
    dspwhitelist     = {const.OBJECT_ATTR_NONE, "string"},
    dspprice         = {const.OBJECT_ATTR_NONE, "number"},
    blackadtype      = {const.OBJECT_ATTR_NONE, "string"},
    blackterm        = {const.OBJECT_ATTR_NONE, "string"},
    blackclickurl    = {const.OBJECT_ATTR_NONE, "string"},
    status           = {const.OBJECT_ATTR_INSERT, "number"},
    pdwhitelist      = {const.OBJECT_ATTR_NONE, "string"}
}

resource._attr_mem = {
    id              = {1,   "number",    false},
    flag            = {2,   "number",    true, 1},
    dspwhitelist    = {3,   "table",     true, const.EMPTY_TABLE},
    status          = {4,   "number",    false},
    pdwhitelist     = {5,   "table",    true, const.EMPTY_TABLE},
}

resource.virtualObjectName = const.OBJECT_PUBLISHER

resource.__index = resource
setmetatable(resource, object)

function resource:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, resource)
end

function resource:getFlag(id)
    return self:getAttribute(id, 2)
end

function resource:getWhiteDspList(id)
    return self:getAttribute(id, 3)
end

function resource:getStatus(id)
    return self:getAttribute(id, 4)
end

function resource:getPdWhiteList(id)
    return self:getAttribute(id, 5)
end 

return resource;   
