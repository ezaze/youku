local util          = require "util"
local db            = require "db"
local object        = require "object"
local const         = require "const"
local restyRedis    = require "resty.redis"

-- this is must to all object
local dsp = {
    objectName              = const.OBJECT_DSP,
    getInfoDB               = db.selectDspInfo,
    getInfoListDB           = db.selectDspInfoList,
    getInfoAllDB            = db.selectDspInfoAll
}

-- object arrtribute check info for manage-end request
-- NOTE: key of dsp._attr_manage_end must be consistent with column name in db
-- NOTE: id is just db-id(id column in db)
-- this is must for real object(has info stored in db), and is must not for virtual object(no info in db):
-- list[1] is the attribute type:
--      const.OBJECT_ATTR_UPDATE_INSERT means this attr required both when update or insert this object info into db
--      const.OBJECT_ATTR_INSERT means this attr required only when insert
--      const.OBJECT_ATTR_NONE means this attr is optional both when update or insert

-- list[2] is the value type
-- list[3] is the specific check function for this attribute
dsp._attr_manage_end = {
   id               = {const.OBJECT_ATTR_UPDATE_INSERT, "number"},
   dspname          = {const.OBJECT_ATTR_NONE,          "string"},
   redirecturl      = {const.OBJECT_ATTR_INSERT,        "string"},
   bidurl           = {const.OBJECT_ATTR_INSERT,        "string"},
   notifyurl        = {const.OBJECT_ATTR_NONE,        "string"},
   priority         = {const.OBJECT_ATTR_NONE,          "number"},
   qps              = {const.OBJECT_ATTR_NONE,          "number"},
   encryptionkey    = {const.OBJECT_ATTR_NONE,          "string"},
   integritykey     = {const.OBJECT_ATTR_NONE,          "string"},
   status           = {const.OBJECT_ATTR_INSERT,        "number"},
   signkey             = {const.OJECT_ATTR_NONE,           "string"}
}

-- object data info in lua memory, this is must be for all objects(real&virtual)
-- NOTE: key of dsp._attr_mem must be consistent with selected columns name in db.selectDspInfo
-- NOTE: id is object-id, and may not equals to db-id for some special object(such as creative and advertiser)
-- list[1] is the index of this attribute. NOTE: index of id must be 1
-- list[2] is data type
-- list[3] : true for nil perimitted, false for nil not-permitted
-- list[4] is default value in lua memory if this key is null-value permitted
-- list[5] is function to transform db value to memory value
dsp._attr_mem = {
   id               = {1,   "number", false},
   dspname          = {2,   "string", true, "anonymous"},
   redirecturl      = {3,   "string", false},
   bidurl           = {4,   "string", false},
   notifyurl        = {5,   "string", true, ""},
   priority         = {6,   "number", true, 0},
   qps              = {7,   "number", true, 0},
   encryptionkey    = {8,   "string", true, ""},
   integritykey     = {9,   "string", true, ""},
   status           = {10,  "number", false},
   signkey          = {11,  "string", false } 
}

dsp.__index = dsp
setmetatable(dsp, object)

-- constructor
function dsp:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, dsp)
end

-- specified function
function dsp:getRedirectUrl(id)
    return self:getAttribute(id, 3)
end

function dsp:getRTBUrl(id)
    return self:getAttribute(id, 4)
end

function dsp:getConfirmUrl(id)
    return self:getAttribute(id, 5)
end

function dsp:getPriority(id)
    return self:getAttribute(id, 6)
end

function dsp:getQps(id)
    return self:getAttribute(id, 7)
end

function dsp:getStatus(id)
    return self:getAttribute(id, 10)
end

function dsp:getEncryptionKey(id)
    return self:getAttribute(id, 8)
end

function dsp:getIntegrityKey(id)
    return self:getAttribute(id, 9)
end

function dsp:getSignKey(id)
    return self:getAttribute(id, 10)
end

local function incr(key, value, exptime)
    exptime = exptime or 0

    local newValue = util.incrDict(key, value)
    if newValue then
        return newValue
    end

    local success = util.addDict(key, value, exptime)
    if success then 
        return value
    end
    
    newValue = util.incrDict(key, value)
    return newValue
end

-- return:
-- {id1 = {"limit" = , "count" = }, id2 = {}, ...}
-- limit = 0 means no qps limit
function dsp:getQpsInfoList(idList)
    local result = {}
    for _, id in ipairs(idList) do
        result[id] = {}

        local key = util.genKeyForQpsLimit(id)
        local limit = util.getDict(key)
        if not limit then
            limit = 0
        end
        result[id]["limit"] = limit

        key = util.genKeyForQpsCount(id)
        result[id]["count"] = incr(key, 1, 1)

        key = util.genKeyForQpsTotal(id)
        incr(key, 1)
    end

    return result
end

function dsp:getQpsTotal(dspIdList)
    local qpsTotalList = {}
    for _, dspId in ipairs(dspIdList) do
        local key = util.genKeyForQpsTotal(dspId)
        local value = util.getDict(key)
        if not value then
            value = 0
        end

        table.insert(qpsTotalList, value)
    end

    return qpsTotalList
end

function dsp:setQpsLimit(dspIdList, qpsLimitList)
    for i, dspId in ipairs(dspIdList) do
        local key = util.genKeyForQpsLimit(dspId)
        util.setDict(key, tonumber(qpsLimitList[i]) or 0, 0)

        key = util.genKeyForQpsTotal(dspId)
        util.setDict(key, 0, 0)

        key = util.genKeyForQpsCount(dspId)
        util.setDict(key, 0, 1)
    end

    util.flushExpiredDict()
end

function dsp:getQpsInfoStr(dspId)
    local key = util.genKeyForQpsCount(dspId)
    local count = util.getDict(key)
    if not count then
        count = 0
    end

    key = util.genKeyForQpsLimit(dspId)
    local limit = util.getDict(key)
    if not limit then
        limit = 0
    end

    key = util.genKeyForQpsTotal(dspId)
    local total = util.getDict(key)
    if not total then
        total = 0
    end
    
    return "id:" .. dspId
           .. ", count:" .. count
           .. ", limit:" .. limit
           .. ", total:" .. total
end

return dsp
