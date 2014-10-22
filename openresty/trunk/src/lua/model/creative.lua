local db            = require "db"
local object        = require "object"
local const         = require "const"

local creative = {
    objectName          = const.OBJECT_CREATIVE,
    getInfoDB           = db.selectCreativeInfo,
    getInfoListDB       = db.selectCreativeInfoList,
    getInfoAllDB        = db.selectCreativeInfoAll
}

creative._attr_manage_end = {
   id               = {const.OBJECT_ATTR_UPDATE_INSERT, "number"},
   dspid            = {const.OBJECT_ATTR_INSERT, "number"},
   dspideaid        = {const.OBJECT_ATTR_INSERT, "string"},
   advertiserid     = {const.OBJECT_ATTR_INSERT, "string"},
   onlineurl        = {const.OBJECT_ATTR_NONE, "string"},
   ideatype         = {const.OBJECT_ATTR_NONE, "number"},
   wdht             = {const.OBJECT_ATTR_NONE, "string"},
   status           = {const.OBJECT_ATTR_INSERT, "number"}
}

-- id = dspid .. dspidealid
-- uniqueid is db id
creative._attr_mem = {
    id              = {1,   "string",   false},
    uniqueid        = {2,   "number",   false},
    dspid           = {3,   "number",   false},
    dspideaid       = {4,   "string",   false},
    advertiserid    = {5,   "string",   false},
    status          = {6,   "number",   false}
}

creative.__index = creative
setmetatable(creative, object)


function creative:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, creative)
end

function creative:getAdvertiserId(dspId, creativeId)
    if dspId ==const.SINA_DSP_ID then
        return const.SINA_DSP_ADVERTISER_ID;
    end 

    local id = dspId .. creativeId
    return self:getAttribute(id, 5)
end

function creative:getUniqueId(dspId, creativeId)
    if dspId == const.SINA_DSP_ID then
        return const.SINA_DSP_CREATIVE_UNIQUE_ID;
    end

    local id = dspId .. creativeId
    local status = self:getAttribute(id, 2)

    return status
end

function creative:getStatus(dspId, creativeId)
    if dspId ==const.SINA_DSP_ID then
         return const.SINA_DSP_CREATIVE_STATUS
    end

    local id = dspId .. creativeId
    local status = self:getAttribute(id, 6)

    return status
end

-- override some function
function creative:isValid(dspId, creativeId)
    if dspId == const.SINA_DSP_ID then
         return true
    end

    local id = dspId .. creativeId
    if self.object[id] or self:getInfoSD(id) then return true end

    return false
end

function creative:getObjectId(dbId)
    local objectInfo = self.getInfoDB(dbId)
    if not objectInfo then return nil end

    return objectInfo.id
end

return creative
