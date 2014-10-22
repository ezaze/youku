local db        = require "db"
local object    = require "object"
local const     = require "const"
local util      = require "util"
local cjson     = require "cjson"

local adunit = {
    objectName              = const.OBJECT_ADUNIT,
    getInfoDB               = db.selectAdunitInfo,
    getInfoListDB           = db.selectAdunitInfoList,
    getInfoAllDB            = db.selectAdunitInfoAll
}

local function networkInfoCheck(v)
    if v == "" then return ngx.HTTP_OK end

    local list = util.split(v, "|")
    for _, value in ipairs(list) do
        local list2 = util.split(value, ",")
        if #list2 ~= 4 then return ngx.HTTP_BAD_REQUEST end
        local t = tonumber(list2[4])
        if t == nil then return ngx.HTTP_BAD_REQUEST end
    end

    return ngx.HTTP_OK
end

local function nadListCheck (v)
    if v == "" then return ngx.HTTP_OK end
    local status, res = pcall(cjson.decode, v)
    if not status or type(res) ~= "table"  then 
        ngx.log(ngx.ERR, "invalid nadList " .. v)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
    return ngx.HTTP_OK
end

adunit._attr_manage_end = {
    id           = {const.OBJECT_ATTR_UPDATE_INSERT, "string"},
    wdht         = {const.OBJECT_ATTR_INSERT,   "string"},
    location     = {const.OBJECT_ATTR_NONE,     "string"},
    adnum        = {const.OBJECT_ATTR_NONE,     "number"},
    publisher    = {const.OBJECT_ATTR_INSERT,   "number"},
    adtype       = {const.OBJECT_ATTR_NONE,     "string"},
    displaytype  = {const.OBJECT_ATTR_NONE,     "string"},
    rotatenum    = {const.OBJECT_ATTR_INSERT,   "number"},
    gina         = {const.OBJECT_ATTR_NONE,     "string"},
    nad          = {const.OBJECT_ATTR_NONE,     "string", nadListCheck},
    networkinfo  = {const.OBJECT_ATTR_NONE,     "string",   networkInfoCheck},
    status       = {const.OBJECT_ATTR_INSERT,   "number"},
    channel      = {const.OBJECT_ATTR_NONE,     "string"}   
}

local function splitNetwork(v)
    local list = util.split(v, "|")
    local result = {}

    for _, value in ipairs(list) do
        local tmp = util.split(value, ",")
        tmp[4] = tonumber(tmp[4])
        table.insert(result, tmp)
    end

    return result
end

local function splitNadList(v)
    local tab = cjson.decode(v); 
    return tab
end

adunit._attr_mem = {
   id               = {1,   "string",   false},
   wdht             = {2,   "string",   false},
   location         = {3,   "string",   true,   ""},
   adnum            = {4,   "number",   true,   1},
   publisher        = {5,   "number",   false},
   status           = {6,   "number",   false},
   adtype           = {7,   "table",    true,   const.EMPTY_TABLE},
   displaytype      = {8,   "string",   true,   ""},
   gina             = {9,   "string",   true,   ""},
   nad              = {10,  "table",    true,   const.EMPTY_TABLE, splitNadList},
   rotatenum        = {11,  "number",   false},
   networkinfo      = {12,  "table",    true,   const.EMPTY_TABLE, splitNetwork},
   channel          = {13,  "string",  true,  ""}

}

adunit.__index = adunit
setmetatable(adunit, object)

function adunit:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, adunit)
end

function adunit:getSize(id)
    return self:getAttribute(id, 2)
end

function adunit:getDisplayType(id)
    return self:getAttribute(id, 8)
end

function adunit:getLocation(id)
    return self:getAttribute(id, 3)
end

function adunit:getAdNum(id)
    return self:getAttribute(id, 4)
end

function adunit:getAdTypeList(id)
    return self:getAttribute(id, 7)
end

function adunit:getPublisher(id)
    return self:getAttribute(id, 5)
end

function adunit:getRotateNum(id)
    return self:getAttribute(id, 11)
end

function adunit:getGina(id)
    return self:getAttribute(id, 9)
end

function adunit:getNadList(id)
    return self:getAttribute(id, 10)
end

function adunit:getStatus(id)
    return self:getAttribute(id, 6)
end

function adunit:getNetworkList(id)
    return self:getAttribute(id, 12)
end

function adunit:getChannel(id)
    return self:getAttribute(id, 13)
end
return adunit
