--[[
-- NOTE: this module like abstract class in c++/java, do NOT use it directly!!!!
-- usage please refer to dsp.lua
--]]
local rdsParser     = require "rds.parser"
local cjson         = require "cjson"
local util          = require "util"
local const         = require "const"

local object = {}
object.__index = object

-- shared dict related
local sharedDictPre = {}
sharedDictPre[const.OBJECT_DSP]         = "d"
sharedDictPre[const.OBJECT_ADUNIT]      = "a"
sharedDictPre[const.OBJECT_RESOURCE]    = "r"
sharedDictPre[const.OBJECT_PUBLISHER]   = "p"
sharedDictPre[const.OBJECT_CREATIVE]    = "c"
sharedDictPre[const.OBJECT_ADVERTISER]  = "v"
sharedDictPre[const.OBJECT_NETWORK]     = "n"

function object:setDict(value)
    local id = value[1] -- index of id must be 1
    value = cjson.encode(value)

    local dictPre = sharedDictPre[self.objectName]
    local dictId = dictPre .. id
    local succ, err, forcible = util.setDict(dictId, value)

    if not succ or forcible then
        ngx.log(ngx.ERR, "Failed to update info of " .. self.objectName .. ". id = " .. id)
        return -1
    end

    return 0
end

function object:getDict(id)
    local dictPre = sharedDictPre[self.objectName]
    if not dictPre then
        return nil
    end

    local dictId = dictPre .. id
    return util.getDict(dictId)
end

function object:getInfoSD(id)
    if self.object[id] then
        return self.object[id]
    end

    local jsonStr = self:getDict(id)
    if not jsonStr then
        return nil
    end

    local info = cjson.decode(jsonStr)
    self.object[id] = info
    return info
end

function object:getInfoListSD(idList)
    local result = {}

    for _, id in ipairs(idList) do
        local t = self:getInfoSD(id)
        if t then result[t[1]] = t end
    end

    return result
end

function object:updateInfoSD(id)
    local info = self.getInfoDB(id)
    if info ~= nil then
        return self:setDict(self:transformInfo(info))
    end

end

function object:updateInfoListSD(idList)
    -- optimize for using index searching
    if #idList == 1 then return self:updateInfoSD(idList[1]) end
        
    local infoList = self.getInfoListDB(idList)
    for _, info in ipairs(infoList) do
        local res = self:setDict(self:transformInfo(info))
        if res ~= 0 then return -1 end
    end

    return 0
end

function object:updateInfoAllSD()
    local infoList = self.getInfoAllDB()
    for _, info in ipairs(infoList) do
        local res = self:setDict(self:transformInfo(info))
        if res ~= 0 then return -1 end
    end

    return 0
end

function object:deleteInfoSD(id)
    util.setDict(sharedDictPre[self.objectName] .. id, nil)
end

function object:deleteInfoListSD(idList)
    for _, id in ipairs(idList) do
        self:deleteInfoSD(id)
    end
end

-- cache info into shared dict
function object:cacheInfoSD()
    return self:updateInfoAllSD()
end

function object:getAttribute(id, index)
    if self.object[id] then
        return self.object[id][index]
    end

    local info = self:getInfoSD(id)
    if not info then return nil end

    return info[index]
end

-- treat dbId equals object id, if some objects have specified rule, just override this function
function object:getObjectId(dbId)
    return dbId
end

function object:isValid(id)
    if self.object[id] or self:getInfoSD(id) then return true end

    return false
end

-- transform object info get from db to lua memory struct based on object._attr_mem table
function object:transformInfo(info)
    local result = {}

    for key, val in pairs(info) do
        if self._attr_mem[key] == nil then
            error("attribute: " .. key .. " of " .. self.objectName .. " is not attribute of this object")
        end

        local index = self._attr_mem[key][1]
        local dataType = self._attr_mem[key][2]
        local nullOk = self._attr_mem[key][3]
        local defaultValue = self._attr_mem[key][4]
        local transformFunc = self._attr_mem[key][5]
        
        if val == rdsParser.null or val == nil then
            if not nullOk then
                error("attribute: " .. key .. " of " .. self.objectName .. " is null, that is illegal!")
            else
                info[key] = defaultValue
            end
        elseif val == "" then
            if defaultValue ~= nil then info[key] = defaultValue end
        else
            if transformFunc ~= nil then
                info[key] = transformFunc(val)
            elseif dataType == "table" then
                info[key] = util.split(val)
            elseif dataType == "string" then
                info[key] = tostring(val)          
            elseif dataType == "number" then
                info[key] = tonumber(val)
            end       
        end

        -- last we transform hash-table to list to do fast-search
        result[index] = info[key]
    end
    
    info = nil
    return result
end

function object:attributeValidityCheck(attributeTable, isUpdate)
    local objectAttrTable = self._attr_manage_end
    if not objectAttrTable then return false, self.objectName .. " is a virtual object!" end

    -- First, transfer key of attributeTable to lower-string
    local newAttrTable = {}
    for attrName, attrValue in pairs(attributeTable) do
        local t = string.lower(attrName)
        newAttrTable[t] = attrValue
    end

    for attrName, attrValue in pairs(newAttrTable) do
        local attr = objectAttrTable[attrName]
        -- check the attribute is one attribute of this object or not
        if not attr then
            local errInfo = attrName .. " is not attribute of sax object: " .. self.objectName
            return false, errInfo
        end

        -- check type is valid or not
        if type(attrValue) ~= attr[2] then
            local errInfo = "type of attribute " .. attrName .. " is not consitent with sax object: " .. self.objectName
            return false, errInfo
        end

        -- call specific check function
        local checkFunc = attr[3]
        if checkFunc then
            local res = checkFunc(attrValue)
            if res ~= ngx.HTTP_OK then
                local errInfo = "format of attribute " .. attrName .. " is incorrect"
                return false, errInfo
            end
        end
    end

    if isUpdate then
        for attrName, attrValue in pairs(objectAttrTable) do
            if attrValue[1] == const.OBJECT_ATTR_UPDATE_INSERT and not newAttrTable[attrName] then
                local errInfo = "attribute(that is must) missing when udpate sax object: " .. self.objectName
                return false, errInfo
            end
        end
    else
        for attrName, attrValue in pairs(objectAttrTable) do
            local f = attrValue[1]
            if (f == const.OBJECT_ATTR_UPDATE_INSERT or f == const.OBJECT_ATTR_INSERT) and not newAttrTable[attrName] then
                local errInfo = "attribute(that is must) missing when insert new sax object: " .. self.objectName
                return false, errInfo
            end
        end
    end

    return true
end

return object
