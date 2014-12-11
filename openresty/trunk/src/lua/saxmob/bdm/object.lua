local cjson  = require "cjson"
local const = require "common.const"
local http = require("common.http");
local util = require("common.util")

local object = {}
object.__index = object

local shared_dict_pre={}
shared_dict_pre[const.OBJECT_ADUNIT]  = "a"
shared_dict_pre[const.OBJECT_DSP]  = "d"
shared_dict_pre[const.OBJECT_SSP]  = "s"

function object:set_dict(value)
    local id = value.id -- index of id must be 1
    value = cjson.encode(value)                                                                                                                                        

    local dict_pre = shared_dict_pre[self.object_name]
    local dict_id = dict_pre .. id   
    local succ, err, forcible = util.set_dict(dict_id, value)                                                                                                            
    if not succ or forcible then       
        ngx.log(ngx.ERR, "Failed to update info of " .. self.object_name .. ". id = " .. id)                                                                            
        return -1
    end

    return 0
end    

function object:get_dict(id) 
    local dict_pre = shared_dict_pre[self.object_name]
    if not dict_pre then
        return nil
    end

    local dict_id = dict_pre .. id 
    return util.get_dict(dict_id)
end

function object:get_attribute(id, attribute)
    if self.object[id] then return self.object[id][attribute] end
    local info = self:get_info_sd(id)
    if not info then return nil end
    return info[attribute]
end

function object:attribute_validity_check(attribute_table )
    local object_attributes = self._attr_manage_end

   
    if not object_attributes then 
        return false,  "no _attr_manage_end table  was found in object " .. self.object_name
    end
    
    for attr_name ,attr_value in pairs(attribute_table) do
     
        local attr = object_attributes[attr_name]
        
        if not attr then
            return false ,  attr_name  .. " is  not a value of " .. self.object_name
        end
        
        if type(attr_value) ~= attr[2] then
            return false,  "type of attribute " .. attr_name .. " is not consitent with sax object: " .. self.object_name
        end
        
        local check_func = attr[3]

        if check_funk then
             local res = check_func(attr_value)
             if not res  then
               return false , "attribute(that is must) missing when udpate sax object: " .. self.object_name
             end
        end
    end

    for attr_name , attr_value in ipairs (object_attributes) do
        if(attr_value[1]) == const.OBJECT_ATTR_NEED and not attribute_table[attr_name] then
            return false, "attribute(that is must) missing when udpate sax object: " .. self.object_name
        end
    end 

    return true 
    
end

function object:trans_form_info(info)
    local result = {}
    for key, value in pairs(info) do
        if self._attr_mem[key] == nil then
            error("attribute: " .. key .. " of " .. self.object_name .. " is null, that is illegal!")
        end

        local index = self._attr_mem[key][1]
        local data_type = self._attr_mem[key][2]
        local null_ok = self._attr_mem[key][3]
        local default_value = self._attr_mem[key][4]
        local trans_form_func = self._attr_mem[key][5]

        if value  == ngx.null or value == nil then
            if not null_ok then 
                error("attribute: " .. key .. " of " .. self.object_name .. " is null, that is illegal!")
            else
                info[key] = default_value
            end
        elseif value == "" then
            if default_value ~= 0 then info[key] =value end
        else
            if trans_form_func ~= nil then
                info[key] = tran_form_func(value)
            elseif dataType == "table" then
                info[key] = util.split(val)
            elseif dataType == "string" then
                info[key] = tostring(value)
            elseif dataType == "number" then 
                info[key] = tonumber(val) 
            end 
        end
        result[key] = info[key] 
    end
    info = nil
    return result
end

function object:update_info_sd(id)
    local info =  self:get_info_db(id)
    if info ~= nil then
        return self:set_dict(self:trans_form_info(info))
    end
end 

function  object:update_info_list_sd(ids)
    if #ids == 1 then return self:update_info_sd(ids[1]) end
    local status = 0 

    local info_list = self:get_info_list_db(ids)
    for _, info in ipairs(info_list) do
         status = self:set_dict(self:trans_form_info(info))
         if status ~= 0 then 
            return status 
         end      
    end
    return status
end

function object:update_info_all_sd()
    local info_list = self:get_info_all_db()
    for _, info in ipairs(info_list) do
        local status = self:set_dict(self:trans_form_info(info))
        if status ~= 0 then   return -1     end
        
    end
    return 0
end

function object:delete_info_sd(id)
    util.set_dict(shared_dict_pre[self.object_name] .. id , nil) 
end
    
function object:delete_info_list_sd(ids)
    for _, id in ipairs(ids) do
        self:delete_info_sd(id)
    end 
end

function object:get_info_sd(id)
    if self.object[id] then
        return self.object[id]
    end 

    local json_str = self:get_dict(id)
    if not json_str then
        return nil 
    end 

    local info = cjson.decode(json_str)
    self.object[id] = info
    return info
end

function object:get_info_list_sd(ids)
    local result = {}

    for _, id in ipairs(ids) do
        local t = self:get_info_sd(id)
        if t then result[t[1]] = t end
    end

    return result
end

function object:is_valid(id)
    if self.object[id] or self:get_info_sd(id) then return true end 

    return false
end

return  object
