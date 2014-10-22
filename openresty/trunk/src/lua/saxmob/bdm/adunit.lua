local const = require "common.const"
local mysql = require "common.mysql"
local cjson = require "cjson"
local util = require "common.util"
local dsp = require "bdm.dsp"
local object = require "bdm.object"

local adunit = {
    object_name = const.OBJECT_ADUNIT,
}

local function  split_url(url_list)
    return util.split(url_list, ",")
end

adunit._attr_manage_end = {
    id                           = {const.OBJECT_ATTR_NEED, "string"} ,
    status                       = {const.OBJECT_ATTR_NONE, "number" },
    type                         = {const.OBJECT_ATTR_NONE, "string"}  ,
    ad_num                       = {const.OBJECT_ATTR_NONE, "number"},
    excluded_creative_type       = {const.OBJECT_ATTR_NONE, "string"},
    excluded_product_type        = {const.OBJECT_ATTR_NONE, "string"},
    excluded_landing_url         = {const.OBJECT_ATTR_NONE, "string"},
    min_price                    = {const.OBJECT_ATTR_NONE, "number"},
    ssp_id                       = {const.OBJECT_ATTR_NONE, "string"}   
}

adunit._attr_mem = {
    id                           = {1, "string", false},
    status                       = {2, "number", true, 1},
    type                         = {3, "string", true, "" },
    ad_num                       = {4, "number", true ,1},
    excluded_creative_type       = {5, "string", true, ""},
    excluded_product_type        = {6, "string", true, ""},
    excluded_landing_url         = {7, "string", true, "" },  
    min_price                    = {8, "number", true, ""},   
    ssp_id                       = {9, "number", true , ""}   
     
} 
adunit.__index = adunit
setmetatable(adunit,object)
 
function adunit:get_info_db(id)
    local sql = "select id ,status, type, ad_num, excluded_creative_type,excluded_product_type, excluded_landing_url ,min_price, ssp_id  from adunit where id=" .. ngx.quote_sql_str(id)
    local rows = mysql.query(sql)
    if rows == nil or #rows ~= 1 then return nil end 
    return rows[1]
end

function adunit:get_info_list_db(ids)
    local ids_str = util.list_concator(ids, true)
    local sql = "select id ,status, type, ad_num, excluded_creative_type,excluded_product_type, excluded_landing_url ,min_price, ssp_id from adunit  where id in " .. "("  .. ids_str .. ")"   
    local rows = mysql.query(sql)
    return rows
end

function adunit:get_info_all_db()
    local sql = "select id ,status, type, ad_num, excluded_creative_type, excluded_product_type, excluded_landing_url ,min_price, ssp_id from adunit"
    local rows, err =  mysql.query(sql)
    if not rows then ngx.log( ngx.ERR,"fail get all info from adunit".. err)end
    return  rows
end 


function adunit:new()
    local temp = {}
    temp.object = {}
    return setmetatable(temp, adunit)
end

function adunit:get_status(id)
    return self:get_attribute(id, "status")
end

function adunit:get_type(id)
    return self:get_attribute(id, "type")
end

function adunit:get_ad_num(id)
    return self:get_attribute(id, "ad_num")
end

function adunit:get_excluded_creative_type(id)
    return self:get_attribute(id, "excluded_creative_type")
end

function adunit:get_excluded_product_type(id)
    return util.split(self:get_attribute(id, "excluded_product_type"),",")
end

function adunit:get_min_price(id)
    return self:get_attribute(id, "min_price")
end

function adunit:get_ssp_id(id)
    return self:get_attribute(id, "ssp_id")
end

function adunit:get_excluded_landing_url(id)
    return util.split(self:get_attribute(id, "excluded_landing_url"),",")
end

function adunit:get_dsp_id_list()
    local dsp_list_str =  util.get_dict(const.DSP_ALL_SD)
    if not dsp_list_str then return  {} end
    local dsp_list_tab = util.split(dsp_list_str)
    return dsp_list_tab
end

return adunit;
