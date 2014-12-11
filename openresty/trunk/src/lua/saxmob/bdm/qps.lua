local const = require "common.const"
local common = require "common.common"
local dsp = require "bdm.dsp" 
local master = require "bdm.master"
local http = require "common.http"
local util = require "common.util"

local function update_qps_worker_info()
    local req_type = common.get_arg_value(const.SAX_ARG_REQ_TYPE)

    if req_type == const.GET_DSP_QPS_TOTAL then
       -- local dsp_id_str = parser.get_sax_dsp_ids()
        local dsp_id_str= common.get_arg_value(const.SAX_ARG_DSPIDS)
        if dsp_id_str == "" then
            ngx.log(ngx.ERR, "failed to get dsp id")
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
        local dsp_id_list = util.split(dsp_id_str)

        local dsp_obj = dsp:new()
        local qps_total_list = dsp_obj:get_qps_total(dsp_id_list);
        local qps_total_str = table.concat(qps_total_list, ",");
        ngx.print(qps_total_str)

        ngx.log(ngx.INFO, "get qps total, dsp id:" .. dsp_id_str .. ", qps total" .. qps_total_str)
    elseif req_type == const.SET_DSP_QPS_LIMIT then
        local dsp_id_str = common.get_arg_value(const.SAX_ARG_DSPIDS)
        if dsp_id_str == "" then
            ngx.log(ngx.ERR, "failed to get dsp id")
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end 
        local dsp_id_list = util.split(dsp_id_str)

        local qps_limit_str = common.get_arg_value(const.SAX_ARG_QPS_LIMIT)
        if qps_limit_str == "" then
            ngx.log(ngx.ERR, "failed to get dsp id")
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
        local qps_limit_list = util.split(qps_limit_str)

        local dsp_obj = dsp:new()
        dsp_obj:set_qps_limit(dsp_id_list, qps_limit_list)

        ngx.log(ngx.INFO, "set qps limit, dsp id:" .. dsp_id_str .. ", qps limit:" .. qps_limit_str)
    else
        ngx.log(ngx.ERR, "unknown type:" .. req_type)
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
end

local function get_qps_info()
    local dsp_obj = dsp:new();
    local str = dsp_obj:get_qps_info_str(ngx.var.arg_id)
    ngx.say(str)
end


local function get_update_qps_url(sax)
    return "http://" .. sax.ip .. ":" .. sax.port  .. const.SAX_UPDATE_QPS_URI
end

-- get dsp qps info from db
local function get_dsp_qps_info_db()
    local dsp = dsp:new()
    local rows = dsp:get_info_all_db()

    local dsp_list = {}
    for _, row in ipairs(rows) do
        if row.status == 1 and row.qps > 0 then
            table.insert(dsp_list, {id = row.id, qps = row.qps, total = {}, limit = {}})
        end
    end

    return dsp_list
end

-- get qps total form sax
local function get_qps_total_from_sax(dsp_list, worker_list)
    local dsp_id_list = {}

    for _, dsp in pairs(dsp_list) do
        table.insert(dsp_id_list, dsp.id)
    end 

    local dsp_id_str = table.concat(dsp_id_list, ",")

    local req_list = {}
    for _, worker in ipairs(worker_list) do
        local temp = {}
        temp.addr = {}    
        temp.addr.host = worker.ip
        temp.addr.port = worker.port
        temp.opt ={}
        temp.opt.path = const.SAX_UPDATE_QPS_URI .. "?"
        temp.opt.method = http.GET
        temp.opt.timeout = 10000
        local get_args = {}

        get_args.type = const.GET_DSP_QPS_TOTAL 
        get_args.dspids = dsp_id_str
        temp.opt.args = ngx.encode_args(get_args)
        table.insert(req_list, temp)
       
    end 
         
    local rsp_list =  http.req_muti(req_list); 

    local flag = false
    local ip_list = {}
    for i, rsp in ipairs(rsp_list) do
        if rsp.status ~= ngx.HTTP_OK then
            status = true
            table.insert(ip_list, worker_list[i].ip)

            for j, dsp in ipairs(dsp_list) do
                table.insert(dsp.total, 0)
            end
        else
            local qps_total_list = util.split(rsp.body)

            for j, dsp in ipairs(dsp_list) do
                table.insert(dsp.total, tonumber(qps_total_list[j]) or 0)
            end
        end
    end

    if flag then
        local log = table.concat(ip_list, ",")
        ngx.log(ngx.ERR, "failed to get qps total from saxmob: " .. log)
        pcall(util.alarm, "failed to get qps total from saxmob", log)
    end
end

-- reallocate qps limit
local function realloc_qps_limit(dsp_list)
    for _, dsp in ipairs(dsp_list) do
        local total = 0
        for _, v in ipairs(dsp.total) do
            total = total + v
        end

        local used = 0
        if total == 0 then
            local limit = math.floor(dsp.qps / #dsp.total)

            for _, v in ipairs(dsp.total) do
                table.insert(dsp.limit, limit)
                used = used + limit
            end
        else
            local quota = math.floor(dsp.qps * 0.9)
            local avg = math.floor(dsp.qps * 0.1 / #dsp.total)

            for _, v in ipairs(dsp.total) do
                local limit =  math.floor(quota * (v / total)) + avg
                table.insert(dsp.limit, limit)
                used = used + limit
            end
        end

        local i = math.random(1, #dsp.total)
        dsp.limit[i] = dsp.limit[i] + (dsp.qps - used)

        ngx.log(ngx.INFO, "dsp:" .. dsp.id
                          .. ", qps:" .. dsp.qps
                          .. ", total:" .. table.concat(dsp.total, ",")
                          .. ", limit:" .. table.concat(dsp.limit, ","))
    end
end


local function set_qps_limit_to_sax(dsp_list, worker_list)
    local dsp_id_list = {}
    for _, dsp in ipairs(dsp_list) do
        table.insert(dsp_id_list, dsp.id)
    end
    local dsp_id_str = table.concat(dsp_id_list, ",")

    local req_list = {}
    for i, worker in ipairs(worker_list) do
        local qps_limit_list = {}
        for _, dsp in ipairs(dsp_list) do
            table.insert(qps_limit_list, dsp.limit[i])
        end

        local option = {}
        local temp = {}
        temp.addr = {}
        temp.addr.host = worker.ip
        temp.addr.port = worker.port
        temp.opt = {}
        temp.opt.method = http.GET
        temp.opt.timeout = 10000
        temp.opt.path = const.SAX_UPDATE_QPS_URI .. "?"
        local get_args = {}
        get_args.type =  const.SET_DSP_QPS_LIMIT
        get_args.dspids = dsp_id_str
        get_args.qpslimit = table.concat(qps_limit_list, ",")
        temp.opt.args = ngx.encode_args(get_args)
        table.insert(req_list, temp)
    end
    
    local rsp_list = http.req_muti(req_list)

    local flag = false
    local ip_list = {}
    for i, rsp in ipairs(rsp_list) do
        if rsp.status ~= ngx.HTTP_OK then
            flag = true
            table.insert(ip_list, worker_list[i].ip .. ":" .. worker_list[i].port)
        end
    end

    if flag then
        local log = table.concat(ip_list, ",")
        ngx.log(ngx.ERR, "faild to set qps limit to saxmob: " .. log)
        pcall(util.alarm, "failed to set qps limit to saxmob", log)
    end
end


local function update_qps_master_info()
    ngx.log(ngx.INFO, "----- update qps info begin -----")

    -- get dsp qps info from db 
    local dsp_list = get_dsp_qps_info_db()

    -- get sax server address
    local worker_list = master.get_sax_server_addr()

    if #dsp_list ~= 0 and #worker_list ~= 0 then
        -- get qps total from sax
        get_qps_total_from_sax(dsp_list, worker_list)

        -- reallocate qps limit
        realloc_qps_limit(dsp_list)

        -- set qps limit to sax
        set_qps_limit_to_sax(dsp_list, worker_list)
    end

    ngx.log(ngx.INFO, "----- update qps info end -----")
end


local qps = {
    update_qps_worker_info          = update_qps_worker_info,
    get_qps_info                    = get_qps_info,
    get_update_object               = get_update_object_url,
    get_update_qps_url              = get_update_qps_url,
    get_dsp_qps_info_db             = get_dsp_qps_info_db,
    get_qps_total_from_sx           = get_qps_total_from_sax,
    realloc_qps_limit_to_sax        = relloc_qps_limit_to_sax,
    update_qps_master_info          = update_qps_master_info                   

}

return qps

