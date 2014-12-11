local const         = require "const"
local parser        = require "parser"
local util          = require "util"
local db            = require "db"
local dsp           = require "dsp"
local adunit        = require "adunit"
local resource      = require "resource"
local publisher     = require "publisher"
local creative      = require "creative"
local advertiser    = require "advertiser"
local network       = require "network"


local objectTable = {}
objectTable[const.OBJECT_DSP]        = dsp
objectTable[const.OBJECT_ADUNIT]     = adunit
objectTable[const.OBJECT_RESOURCE]   = resource
objectTable[const.OBJECT_PUBLISHER]  = publisher
objectTable[const.OBJECT_CREATIVE]   = creative
objectTable[const.OBJECT_ADVERTISER] = advertiser
objectTable[const.OBJECT_NETWORK]    = network

local function newObject(name)
    return (objectTable[name]):new()
end

local function initObjectInfo()
    util.flushAllDict()

    for _, object in pairs(objectTable) do
        local object = object:new()
        local res = object:cacheInfoSD()
        if res == -1 then
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
    end
end

local function argsParse()
    local objectName = parser.getSaxObjectName()
    local objectId = parser.getSaxObjectId()
    local operate = parser.getSaxOperate()

    return objectName, objectId, operate
end

local function updateObjectInfo()
    local objectName, objectId, operate = argsParse()
    if objectName == "" 
        or not objectTable[objectName] 
        or objectId == ""
    then
        ngx.log(ngx.ERR, "fail in get args :" .. "objectName=" .. objectName , "objectId=" .. objectId ,"operate=" ..  operate ) 
        return ngx.exit(ngx.HTTP_BAD_REQUEST)
    end

    local objectIdList = util.split(objectId)
    local object = (objectTable[objectName]):new()

    if operate == const.SAX_DELETE_OBJECT_OPERATE then
        object:deleteInfoListSD(objectIdList)
    else
        local res = object:updateInfoListSD(objectIdList)
        if res ~= 0 then 
             ngx.log(ngx.ERR,"error update object in SD then ids=" .. objectId )
             return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) 
    
        end
    end

    -- handle virtual object
    object = objectTable[object.virtualObjectName]
    if object then
        object = object:new()
        if operate == const.SAX_DELETE_OBJECT_OPERATE then
            object:deleteInfoListSD(objectIdList)
        else
            local res = object:updateInfoListSD(objectIdList)
            if res ~= 0 then
                ngx.log(ngx.ERR,"fail to handle virtual object") 
                return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR) 
            end
        end
    end
    ngx.log(ngx.INFO,"sucess update  : "  .. "objectName=" .. objectName , "objectId=" .. objectId ,"operate=" ..  operate)
end

local function updateQpsInfo()
    local reqType = parser.getSaxReqType()

    if reqType == const.GET_DSP_QPS_TOTAL then
        local dspIdStr = parser.getSaxDspIds()
        if dspIdStr == "" then
            ngx.log(ngx.ERR, "failed to get dsp id")
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
        local dspIdList = util.split(dspIdStr)

        local dspObj = newObject(const.OBJECT_DSP)
        local qpsTotalList = dspObj:getQpsTotal(dspIdList);
        local qpsTotalStr = table.concat(qpsTotalList, ",");
        ngx.print(qpsTotalStr)

        ngx.log(ngx.INFO, "get qps total, dsp id:" .. dspIdStr .. ", qps total" .. qpsTotalStr)
    elseif reqType == const.SET_DSP_QPS_LIMIT then
        local dspIdStr = parser.getSaxDspIds()
        if dspIdStr == "" then
            ngx.log(ngx.ERR, "failed to get dsp id")
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
        local dspIdList = util.split(dspIdStr)

        local qpsLimitStr = parser.getQpsLimit()
        if qpsLimitStr == "" then
            ngx.log(ngx.ERR, "failed to get dsp id")
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
        local qpsLimitList = util.split(qpsLimitStr)
        
        local dspObj = newObject(const.OBJECT_DSP)
        dspObj:setQpsLimit(dspIdList, qpsLimitList)

        ngx.log(ngx.INFO, "set qps limit, dsp id:" .. dspIdStr .. ", qps limit:" .. qpsLimitStr)
    else
        ngx.log(ngx.ERR, "unknown type:" .. reqType)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
end

local function getSaxAll()
    return db.selectSaxInfoAll()
end

local function getUpdateObjectUrl(sax)
    return "http://" .. sax.ip .. ":" .. sax.port  .. const.SAX_UPDATE_OBJECT_URI
end

local function getUpdateQpsUrl(sax)
    return "http://" .. sax.ip .. ":" .. sax.port  .. const.SAX_UPDATE_QPS_URI
end

local function getObjectId(objectName, dbId)
    local object = (objectTable[objectName]):new()
    return object:getObjectId(dbId)
end

local function objectNameValidityCheck(objectName)
    local object = objectTable[objectName]
    if not object then
        return false, objectName .. " is not a sax object"
    end

    object = object:new()

    return true, nil, object
end

local function objectValidityCheck(objectName, attributeTable, isUpdate)
    local isValid , errInfo, object = objectNameValidityCheck(objectName)
    if not isValid then return false, errInfo end

    return object:attributeValidityCheck(attributeTable, isUpdate)
end

local function getObjectInfo()
    local object = newObject(ngx.var.arg_object)
    local value = object:getDict(ngx.var.arg_id)
    ngx.say(value)
end

local function getQpsInfo()
    local dspObj = newObject(const.OBJECT_DSP)
    local str = dspObj:getQpsInfoStr(ngx.var.arg_id)
    ngx.say(str)
end

local sax = {
    newObject                       = newObject,
    initObjectInfo                  = initObjectInfo,
    updateObjectInfo                = updateObjectInfo,
    updateQpsInfo                   = updateQpsInfo,
    getSaxAll                       = getSaxAll,
    getObjectId                     = getObjectId,
    getUpdateObjectUrl              = getUpdateObjectUrl,
    getUpdateQpsUrl                 = getUpdateQpsUrl,
    objectNameValidityCheck         = objectNameValidityCheck,
    objectValidityCheck             = objectValidityCheck,
    getObjectInfo                   = getObjectInfo,
    getQpsInfo                      = getQpsInfo
}

return sax
