local mysql = require "common.mysql";

local function get_body_data()
    ngx.req.read_body()
    return ngx.req.get_body_data() or ""; 
end

local function get_arg_value(arg_key)
    local temp = "arg_" .. arg_key;
    local value = ngx.var[temp] or "";

    return ngx.unescape_uri(value);
end

local function select_worker_info_all()
    local sql = "select ip, port from server where type = 's' order by ip, port";
    return mysql.query(sql);
end

local function select_master_info_all()
    local sql = "select ip, port from server where type = 'c' order by ip, port"
    return mysql.query(sql)
end

local common = {
    get_body_data           = get_body_data,
    get_arg_value           = get_arg_value,
    select_worker_info_all  = select_worker_info_all,
    select_master_info_all  = select_master_info_all
};

return common;

