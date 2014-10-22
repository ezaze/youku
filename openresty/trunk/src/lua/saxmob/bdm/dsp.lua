--local qps = require "common.qps"
local util = require "common.util"
local const = require "common.const"
local mysql = require "common.mysql" 
local object = require "bdm.object"
--local worker = require "bdm.worker"

local dsp = {
    object_name = const.OBJECT_DSP,
--    get_info_db = get_info_db,
--    get_info_list_db = get_info_list_db,
--      get_info_all_db = get_info_all_db
 --    get_all_dsp_db = get_all_dsp_db
}

dsp._attr_manage_end = { 
   id               = {const.OBJECT_ATTR_NEED,        "string"},
   status           = {const.OBJECT_ATTR_NEED,        "number"},
   name             = {const.OBJECT_ATTR_NONE,        "string"},
   bid_url          = {const.OBJECT_ATTR_NEED,        "string"},
   qps              = {const.OBJECT_ATTR_NONE,        "number"},
   ekey             = {const.OBJECT_ATTR_NONE,        "string"},
   ikey             = {const.OBJECT_ATTR_NONE,        "string"},
   timeout          = {const.OBJECT_ATTR_NONE,        "number"}, 
}

dsp._attr_mem = { 
   id               = {1,   "number", false},
   name             = {2,   "string", true, "anonymous"},
   status           = {3,    "number",false },
   bid_url          = {4,   "string", false},
   qps              = {5,   "number", true, 0},
   ekey             = {6,   "string", true, ""},
   ikey             = {7,   "string", true, ""},
   timeout          = {8,  "number", false}
}
dsp.__index =  dsp
setmetatable(dsp, object)

function dsp:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, dsp)
end

function dsp:get_status(id)
    return self:get_attribute(id, "status")
end

function dsp:get_bid_url(id)
    return self:get_attribute(id, "bid_url")
end

function dsp:get_qps(id)
    return self:get_attribute(id, "qps")
end

function dsp:get_encryption_key(id)
    return self: get_attribute(id, "ekey")
end
   
function dsp:get_integrity_key(id)
    return self:get_attribute(id, "ikey")
end

function dsp:get_timeout(id)
    return self:get_attribute(id, "timeout")
end

function dsp:get_info_db(id)
    local sql = "select id ,name, status, qps, bid_url, ekey,ikey,timeout from dsp where id=" .. ngx.quote_sql_str(id)
    local rows = mysql.query(sql)
    if rows == nil or #rows ~= 1 then return nil end
    return rows[1]
end

function dsp:get_info_list_db(ids)
    local ids_str = util.list_concator(ids ,true)

    local sql = "select id ,name, status, qps, bid_url,ekey, ikey, timeout from dsp  where id in " .. "("  .. ids_str .. ")"   
    local rows = mysql.query(sql)
    return rows
end

function dsp:get_info_all_db()
    local sql = "select id, name, status ,qps ,bid_url, ekey ,ikey ,timeout from dsp "
    local rows ,err=  mysql.query(sql)
    if not rows then ngx.log(ngx.ERR, "fail to get all info  from dsp" ..err)end
    return  rows
end


function dsp:get_all_dsp_db()
    local sql = "select id from dsp"
    local ids = {}
    local rows = mysql.query(sql)
    if  not rows then
        return nil
    elseif #rows == 1 then
        return rows[1].id
    else
        for _, row in ipairs (rows) do
            table.insert(ids, row.id)
        end
    end        
    return  table.concat(ids, ",")
end

local function incr(key, value, exptime)
    exptime = exptime or 0

    local new_value = util.incr_dict(key, value)
    if new_value then
        return new_value
    end

    local success = util.add_dict(key, value, exptime)
    if success then
        return value
    end

    new_value = util.incr_dict(key, value)
    return new_value
end

-- return:
-- {id1 = {"limit" = , "count" = }, id2 = {}, ...}
-- limit = 0 means no qps limit
function dsp:get_qps_info_list(id_list)
    local result = {}
    for _, id in ipairs(id_list) do
        result[id] = {}

        local key = util.gen_key_for_qps_limit(id)
        local limit = util.get_dict(key)
        if not limit then
            limit = 0
        end
        result[id]["limit"] = limit

        key = util.gen_key_for_qps_count(id)
        result[id]["count"] = incr(key, 1, 1)

        key = util.gen_key_for_qps_total(id)
        incr(key, 1)
    end

    return result
end

function dsp:get_qps_total(dsp_id_list)
    local qps_total_list = {}
    for _, dsp_id in ipairs(dsp_id_list) do
        local key = util.gen_key_for_qps_total(dsp_id)
        local value = util.get_dict(key)
        if not value then
            value = 0
        end

        table.insert(qps_total_list, value)
    end

    return qps_total_list
end

function dsp:set_qps_limit(dsp_id_list, qps_limit_list)
    for i, dsp_id in ipairs(dsp_id_list) do
        local key = util.gen_key_for_qps_limit(dsp_id)
        util.set_dict(key, tonumber(qps_limit_list[i]) or 0, 0)

        key = util.gen_key_for_qps_total(dsp_id)
        util.set_dict(key, 0, 0)

        key = util.gen_key_for_qps_count(dsp_id)
        util.set_dict(key, 0, 1)
    end

    util.flush_expired_dict()
end

function dsp:get_qps_info_str(dsp_id)
    local key = util.gen_key_for_qps_count(dsp_id)
    local count = util.get_dict(key)
    if not count then
        count = 0
    end

    key = util.gen_key_for_qps_limit(dsp_id)
    local limit = util.get_dict(key)
    if not limit then
        limit = 0
    end

    key = util.gen_key_for_qps_total(dsp_id)
    local total = util.get_dict(key)
    if not total then
        total = 0
    end

    return "id:" .. dsp_id
           .. ", count:" .. count
           .. ", limit:" .. limit
           .. ", total:" .. total
end

return dsp;
