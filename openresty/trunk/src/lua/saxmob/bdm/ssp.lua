local util = require "common.util"
local mysql   = require "common.mysql"
local object = require "bdm.object"
local const = require "common.const"
--local worker = require "bdm.worker"

local ssp = {
    object_name = const.OBJECT_SSP, 
    get_info_db = get_info_db,
    get_info_list_db = get_info_list_db,
    get_info_all_db = get_info_all_db
}


ssp._attr_manage_end ={
    id           = {const.OBJECT_ATTR_UPDATE_INSERT, "string"},
    name         = {const.OBJECT_ATTR_NONE, "string"},
    status       = {const.OBJECT_ATTR_NONE, "number"}   
}

ssp._attr_mem ={
    id               = {1,   "string",   false},
    name             = {2,   "string" ,true, ""},
    status           = {3,   "number", true ,1 }   
}

ssp.__index = ssp
setmetatable(ssp, object)

function ssp: new()
    local temp ={}
    temp.object={}
    return setmetatable(temp, ssp)
end

function ssp:get_name(id)
    return self:get_attribute(id, "name")
end

function ssp:get_status(id)
    return self:get_attribute(id, "status")
end

 function ssp:get_info_db(id)
    local sql = "select id ,name,status  from ssp where id=" ..  ngx.quote_sql_str(id)
    local rows = mysql.query(sql)
    if rows == nil or #rows ~= 1 then return nil end
    return rows[1] 
end

function ssp:get_info_list_db(ids)
    local ids_str = util.list_concator(ids, true)
    local sql = "select id ,name, status  from ssp  where id in " .. "("  .. ids_str .. ")"
    local rows, err = mysql.query(sql)
    return rows
end

function ssp: get_info_all_db()
    local sql = "select id ,name ,status from ssp"
    local rows, err = mysql.query(sql)
        if not rows then ngx.log(ngx.ERR, "fail get all info from  ssp :" ..   err) end
    return  rows
end

return ssp;

