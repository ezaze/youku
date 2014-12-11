local common = require("common.common")
local worker = require ("bdm.worker")
local http = require("common.http")
local const = require("common.const")
local mysql = require("common.mysql")
local util  = require("common.util") 
local cjson = require("cjson")

local function get_update_info()
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    if not args or args == ""  then return "request info is empty" end
    local msg = args.info
    local err ,object_name, content, is_delete

    if not msg or  msg == "" then
        err = "no info in request body"
        return err
    end

    local status, info = pcall(cjson.decode ,msg )
    if not status then
        err = "the request info is not json"
        ngx.log(ngx.ERR, err .. ":" .. info ..":" .. msg )
        return err
    end

    object_name = info.name
    if type(object_name) ~= "string" then
        err = err and err .. "bad type of  object name ;" or "bad type of  object name ;"  
        return err
    end  
 
    local content = info.content

    if type(content) ~= "table" then
        err = err and err .. "bad type of content ;" or "bad type of content ;"
        return err
    end

    if info.operate ==  const.SAX_DELETE_OBJECT_OPERATE then
        is_delete = true
    elseif  info.operate == const.SAX_UPDATE_OBJECT_OPERATE then
        is_delete = false
    else
        err = err and err ..  "operate is not delete or update;" or  "operate is not delete or update;"
    end

    if err ~= nil then
        ngx.log(ngx.ERR, err .. "request body is :" ..  msg ) 
        return err
    end

    return err, object_name, content,is_delete
end


-- check if id exist in db
local function check_is_exist(object_name, id) 
    if type(id) == "string" then
        id = ngx.quote_sql_str(id)
    end 

    local sql = "select count(*) as num from " .. object_name .. " where id = " .. id
    local rows,  err = mysql.query(sql) 
    if not rows then
        return nil , ngx.HTTP_BAD_REQUEST, err ;
    end 
    if not  rows[1].num  or rows[1].num == "0" then
        return false , ngx.HTTP_OK
    end 
    return true, ngx.HTTP_OK
end

local function query_mysql_update(object_name, id, column_list)
    local set_block = util.column_list_parse(column_list, true)

    if type(id)== "string" then id = ngx.quote_sql_str(id) end 
    local sql = "update "  .. object_name .. " set "  .. set_block .. " where id =" .. id
        
    local res, err = mysql.query(sql)        
    if not res then
        return ngx.HTTP_BAD_REQUEST,err
    end 

    return ngx.HTTP_OK
end

local function query_mysql_insert(object_name, column_list)
    local column, value = util.column_list_parse(column_list)
    local sql = "insert into " .. object_name .. "(" .. column .. ")" .. "values" .. "(" .. value .. ")"
    local res, err = mysql.query(sql)

    if  res == nil then
        return  ngx.HTTP_BAD_REQUEST,err
    end

    return ngx.HTTP_OK

end

local function  query_mysql_delete(object_name, id) 
    if type(id) == "string" then
        id = ngx.quote_sql_str(id)
    end 

    local sql = "delete from " .. object_name .. " where id = " .. id        

    local res ,err = mysql.query(sql)

    if not res then
        return ngx.HTTP_BAD_REQUEST, err
    end

    return ngx.HTTP_OK
end

local function content_parse(object_name, content_list, is_delete)
    local is_valid, err_info = worker.object_name_validity_check(object_name)

    if not is_valid then return ngx.HTTP_BAD_REQUEST, err_info end 

    for _, content in ipairs(content_list) do
        local id = content.id
        if not id then return ngx.HTTP_BAD_REQUEST, "id of object missing" end
        local is_exist, status, err_info = check_is_exist(object_name, id)

        if status ~= ngx.HTTP_OK then
            err_info = "Failed to check info of object(id = " .. id .. ") in db, details: " .. err_info
            return status, err_info
        end

        if not is_delete then
            local is_valid, err = worker.object_validity_check(object_name, content, is_exist)
            if not is_valid then
                return ngx.HTTP_BAD_REQUEST, "object(id = " .. id .. ") info is invalid, details: " .. err
            end
        end 
        content._is_exist =  is_exist
    end
    return ngx.HTTP_OK
end

-- get sax server address 
local function get_sax_server_addr()
    local sax_list = worker.get_saxmob_worker_all()    
    local ip_list = {}

    for _, _sax in ipairs(sax_list) do
        table.insert(ip_list, _sax.ip)
    end 

    return sax_list
end

local function update_info_db(object_name, content_list)
    local  status, err = ngx.HTTP_OK, nil
    local ids = {}

    for _, content in ipairs(content_list)do
        local id = content.id
        local is_update = content._is_exist
        content._is_exist = nil
        if is_update then 
            content.id = nil
            status, err = query_mysql_update(object_name, id, content)
            content.id = id
        else
            status, err = query_mysql_insert(object_name, content)
        end

        if status ~= ngx.HTTP_OK then      
            local str = cjson.encode(content)
            if is_update then  
                err =  "Error happend when  update values : " .. object_name .. ":" .. str .. " Detail : "  .. err
            else
                err = "Error happend when insert values : " .. object_name .. ":" .. str .. " Detail : "  .. err
            end
            return status, err     
        end 

        -- use db id to update info in shared dict
        content._sax_object_id = id  
    end
    return status, err
end

local function delete_info_db(object_name, content_list)
    local status, err = ngx.HTTP_OK, nil

    for _, content in ipairs(content_list) do
        local id = content.id
        status, err = query_mysql_delete(object_name, id)
        if status ~= ngx.HTTP_OK then
            err =  "Error happened when delete tuple of" .. object_name .. "(id = " .. id  .. ")" ..  ". Details: " .. err
            return status,  err   
        end
        content._sax_object_id = id
    end

    return status, err
end

local function notify_sax(object_name, content_list, is_delete)  
    local id_list = {}
    local req = {}

    for _, content in ipairs(content_list) do
        table.insert(id_list, content._sax_object_id)
    end

    local ids = table.concat(id_list,",")
        
    local sax_list = worker.get_saxmob_worker_all()
    local post_body = "id=" .. ids 
    local get_args =  {}
    get_args.name = object_name

    if is_delete then
        get_args.operate =const.SAX_DELETE_OBJECT_OPERATE
    end 

    for _,sax in ipairs (sax_list) do
        local temp = {}
        temp.addr = {}
        temp.addr.host = sax.ip
        temp.addr.port = sax.port
        temp.opt = {}
        temp.opt.timeout=10000
        temp.opt.path = const.SAX_UPDATE_OBJECT_URI .. "?"
        temp.opt.method = http.POST
        temp.opt.args = ngx.encode_args(get_args)
        temp.opt.body = post_body;
        table.insert(req, temp)
    end

    local fail_list =  {}
    local notify_rsp_list =  http.req_muti(req)
    local status = ngx.HTTP_OK
    for  i , _rsp in ipairs(notify_rsp_list) do
        if _rsp.status ~= ngx.HTTP_OK then
            ngx.log(ngx.ERR, _rsp.status , " "  , _rsp.body )
            status =  ngx.HTTP_INTERNAL_SERVER_ERROR 
            table.insert(fail_list, worker.get_update_object_url(sax_list[i]))
        end 
        
    end
    
    if status ~= ngx.HTTP_OK then
        local str = table.concat(fail_list, ",")
        local err_info = "Failed to notify saxmob worker(" .. str .. ") to update " .. object_name .. " info." .. "id=" .. ids
        ngx.log(ngx.ERR, err_info)
        -- send alarm info
        subject = "worker failed to update saxmob object info"
        pcall(util.alarm, subject, err_info)
    end 

end

local function log_update_db(object_name, content_list, is_delete)
    local id_list = {}

    for _, content in ipairs(content_list) do
        table.insert(id_list, content.id)
    end

    local id_str = table.concat(id_list, ",")
    local log_info = "Success to "

    if not is_delete then
        log_info = log_info .. "update "
    else
        log_info = log_info .. "delete "
    end

    log_info = log_info .. object_name .. " info in database. ID = (" .. id_str .. ")"
    ngx.log(ngx.INFO, log_info)
end

local function update_object_info()
    local result = {code = "OK"}
    local err, object_name, content_list, is_delete = get_update_info()

    if err then
        result.code = "FAIL"
        result.info = err
        ngx.print(cjson.encode(result)) 
        ngx.exit(ngx.HTTP_OK)
    end

    local status, err_info = content_parse(object_name, content_list) 

    if status ~= ngx.HTTP_OK then 
        result.code = "FAIL"
        result.info = err_info
        ngx.print(cjson.encode(result))
        ngx.exit(ngx.HTTP_OK)        
    end 

    -- update object info in db
    if not is_delete then
        status, err_info = update_info_db(object_name, content_list)
    else
        status,err_info = delete_info_db(object_name, content_list)
    end

    if status ~= ngx.HTTP_OK then 
        result.code = "FAIL"
        result.info = err_info
        ngx.print(cjson.encode(result))
        ngx.exit(ngx.HTTP_OK)    
    end     

    log_update_db(object_name, content_list, is_delete)
    ngx.print(cjson.encode(result))  
    ngx.eof()
    notify_sax(object_name, content_list, is_delete)
    return ngx.exit(ngx.HTTP_OK)             
end


local master = {
    update_object_info = update_object_info,
    update_qps_info = update_qps_info,
    check_is_exist = check_is_exist,
    get_sax_server_addr = get_sax_server_addr
}

return master

