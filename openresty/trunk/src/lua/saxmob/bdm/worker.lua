local const = require "common.const";
local dsp = require "bdm.dsp"
local adunit = require "bdm.adunit"
local ssp = require "bdm.ssp" 
local util = require "common.util"
local mysql = require "common.mysql"
local common = require "common.common"

local function get_saxmob_worker_all()
    local sql = "select ip, port from server where type = 's' order by ip, port"
    local rows = mysql.query(sql)
    return rows
end

local object_table = {}
object_table[const.OBJECT_DSP] = dsp
object_table[const.OBJECT_ADUNIT] = adunit
object_table[const.OBJECT_SSP] = ssp

local function  new_object(name)
    return object_table[name]:new()
end

local function object_name_validity_check(name)
    local object =object_table[name]
    if not object then
        return false , name .. "is not a object"
    end
    
    object = object:new()
    return true, nil, object
end

local function object_validity_check(object_name, attribute_table, is_update)
     local is_valid , err_info, object = object_name_validity_check(object_name)
     if not is_valid then return false, err_info end

     return object:attribute_validity_check(attribute_table, is_update)
end


local function set_dsplist_sd()
    
    local dsp_ids = dsp:get_all_dsp_db()
    if dsp_ids == nil then
        ngx.log(ngx.INFO, "no dsp found in db")        
    end
     util.set_dict(const.DSP_ALL_SD, dsp_ids)
end

local function  init_object_info()
    util.flush_all_dict()
    for  _, object in pairs(object_table) do
        local object = object:new()
        local res = object:update_info_all_sd()
        if res == -1 then
             ngx.log(ngx.ERR, "error happend in when initobjct:" .. object.object_name)   
             ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end
        
    end
    set_dsplist_sd()    
end

local function get_update_object_url(sax)
     return "http://" .. sax.ip .. ":" .. sax.port  .. const.SAX_UPDATE_OBJECT_URI
end


local function args_parse()
    ngx.req.read_body()
    local args = ngx.req.get_post_args()


    local ids = args.id
    

    local object_name = common.get_arg_value(const.WORK_ARG_NAME)
    local operate = common.get_arg_value(const.WORK_ARG_OPERATE)

    return object_name, ids, operate
end


local function update_object_info()
    local object_name , idstr, operate = args_parse()
    if not object_name or not object_table[object_name] or not idstr then
        ngx.log(ngx.ERR, "BAD  REUEST " .. object_name .. ",operate =" ..operate .. ",ids=" .. idstr)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
   
    local ids = util.split(idstr)
    local object =  object_table[object_name]:new()
    if operate == const.SAX_DELETE_OBJECT_OPERATE then
        object:delete_info_list_sd(ids)
    else
        local res = object:update_info_list_sd(ids)
        if res ~= 0 then
            ngx.log(ngx.INFO, "fail to  update object:" .. object_name ..", id=" ..idstr)
            return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end    
     end
        
     if object.object_name == const.OBJECT_DSP then
        set_dsplist_sd()
     end

     ngx.log(ngx.INFO, "success to update object:" .. object_name .. ", id=" .. idstr )   
        
end

local function get_object_info()
  --  ngx.log(ngx.INFO, "get obcjt")
    if ngx.var.arg_object == const.DSP_ALL_SD then
        local dsp_list = util.get_dict(const.DSP_ALL_SD)
        ngx.say(tostring(dsp_list))
        ngx.exit(ngx.HTTP_OK)

    end
    local object = new_object(ngx.var.arg_object)
--    ngx.log(ngx.INFO, "get obcjt:" ..  ngx.var.arg_object .. " id:" .. ngx.var.arg_id  )
    local value = object:get_dict(ngx.var.arg_id)
--    ngx.log(ngx.INFO, "object name:" ..object.object_name)
    ngx.say(value)
end

local worker = {
    new_object                      = new_object,
    init_object_info                = init_object_info,
    update_object_info              = update_object_info,
    get_object_id                   = get_object_id,
    get_update_object_url           = get_update_object_url,
    object_name_validity_check      = object_name_validity_check,
    object_validity_check           = object_validity_check,
    get_object_info                 = get_object_info,
    get_saxmob_worker_all           = get_saxmob_worker_all
};


return worker;
