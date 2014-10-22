local object = require "object"
local const = require "const"
local db    = require "db"

local network = {
    objectName = const.OBJECT_NETWORK,
    getInfoDB = db.selectNetworkInfo,
    getInfoListDB = db.selectNetworkInfoList,
    getInfoAllDB = db.selectNetworkInfoAll
}

network._attr_manage_end = {
    id                = {const.OBJECT_ATTR_UPDATE_INSERT, "number"},
    name              = {const.OBJECT_ATTR_NONE,          "string"},
    url               = {const.OBJECT_ATTR_UPDATE_INSERT, "string"},
    status            = {const.OBJECT_ATTR_UPDATE_INSERT, "number"}
} 

network._attr_mem = {
    id           = {1, "number", false},  
    name         = {2, "string", true, ""},
    url          = {3, "string", false},
    status       = {4, "number", false}
}

network.__index = network
setmetatable(network, object)

function network:new()
    local temp ={}
    temp.object = {}
    return  setmetatable(temp, network)
end

function network:getNetworkName(id)
    return self:getAttribute(id, 2)
end

function network:getNetworkUrl(id)
    return self:getAttribute(id, 3)
end

function network:getNetworkStatus(id)
    return self:getAttribute(id, 4)
end


return network
