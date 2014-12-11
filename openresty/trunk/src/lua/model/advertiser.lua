local db        = require "db"
local object    = require "object"
local const     = require "const"

local advertiser = {
    objectName       = const.OBJECT_ADVERTISER,
    getInfoDB        = db.selectAdvertiserInfo,
    getInfoListDB    = db.selectAdvertiserInfoList,
    getInfoAllDB     = db.selectAdvertiserInfoAll
}

advertiser._attr_manage_end = {
    id               = {const.OBJECT_ATTR_UPDATE_INSERT, "number"},
    dspid            = {const.OBJECT_ATTR_INSERT, "number"},
    advertiserid     = {const.OBJECT_ATTR_INSERT, "string"},
    status           = {const.OBJECT_ATTR_INSERT, "number"},
    type             = {const.OBJECT_ATTR_NONE,   "string"}
}

-- id = dspid .. advertiserid
-- uniqueid is db id
advertiser._attr_mem = {
    id              = {1,   "string",   false},
    uniqueid        = {2,   "number",   false},
    dspid           = {3,   "number",   false},
    advertiserid    = {4,   "string",   false},
    status          = {5,   "number",   false},
    type            = {6,   "string",   false}
}

advertiser.__index = advertiser
setmetatable(advertiser, object)

function advertiser:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, advertiser)
end

function advertiser:getStatus(dspId, advertiserId)
    if dspId ==const.SINA_DSP_ID then
        return const.SINA_DSP_ADVERTISER_STATUS
    end
   
    local id = dspId .. advertiserId
    return self:getAttribute(id, 5)
end

function advertiser:getUniqueId(dspId, advertiserId)
    if dspId == const.SINA_DSP_ID  then
        return const.SINA_DSP_ADVERTISER_UNIQUE_ID
    end

    local id = dspId .. advertiserId
    return self:getAttribute(id, 2)
end

-- override some function
function advertiser:isValid(dspId, advertiserId)
    if dspId == const.SINA_DSP_ID then
        return true
    end

    local id = dspId .. advertiserId
    if self.object[id] or self:getInfoSD(id) then return true end
         
    return false
end

function advertiser:getObjectId(dbId)
    local objectInfo = self.getInfoDB(dbId)
    if not objectInfo then return nil end

    return objectInfo.id
end

function advertiser:getType(dspId, advertiserId)
    if dspId == const.SINA_DSP_ID then 
        return const.SINA_DSP_ADVERTISER_TYPE 
    end

    local id = dspId .. advertiserId
    return self:getAttribute(id, 6)
end    

return advertiser
