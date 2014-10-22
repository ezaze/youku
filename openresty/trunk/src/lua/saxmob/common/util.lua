local cjson = require("cjson");
local struct = require("struct");
local bit = require("bit");
local const = require("common.const")
local common = require ("common.common")

local function split(str, delim, max_nb)   
    -- Eliminate bad cases...
    if delim == nil then delim = "," end

    if string.find(str, delim) == nil then  
        return { str }  
    end  
    if max_nb == nil or max_nb < 1 then  
        max_nb = 0    -- _no limit   
    end  
    local result = {}  
    local pat = "(.-)" .. delim .. "()"   
    local nb = 0  
    local last_pos   
    for part, pos in string.gfind(str, pat) do  
        nb = nb + 1  
        result[nb] = part   
        last_pos = pos   
        if nb == max_nb then break end  
    end  
    -- Handle the last field   
    if nb ~= max_nb then  
        result[nb + 1] = string.sub(str, last_pos)   
    end  
    return result   
end

--@return {schema = "", host = "", port = "", uri = ""}
local function parse_inet_url(url)
    local ret = {};
    local host;
    local port;
    local uri;
    local args;
    local last;
    
    if type(url) ~= "string" then
        return nil, "arg format error";
    end

    last = string.len(url);
    if string.sub(url, 1, 7) == "http://" then
        host = 8;
        ret.schema = "http";
    elseif string.sub(url, 1, 8) == "https://" then
        host = 9;
        ret.schema = "https";
    else
        host = 1;
        ret.schema = "http";
    end
    
    local port = string.find(url, ":", host, true);
    local uri = string.find(url, "/", host, true);
    local args = string.find(url, "?", host, true);
    
    if args then
        if not uri then
            uri = args;
        end
    end
    
    if uri then
        local sep = "";
        if args and uri == args then
            sep = "/";
        end
        
        ret.uri = sep .. string.sub(url, uri, last);
        last = uri - 1;
        
        if port and uri < port then
            port = nil
        end
    else
        ret.uri = "/";
    end
    
    if port then
        ret.port = tonumber(string.sub(url, port + 1, last));
        
        if not ret.port or ret.port < 1 or ret.port > 65535 then
            return nil, "incorrect port number";
        end
        last = port - 1;
    else
        ret.port = 80;
    end
    
    if last < host then
        return nil, "no host";
    end
    
    ret.host = string.sub(url, host, last);
    
    return ret;
end

local function decode_log_str(str)
    res = ngx.decode_base64(str)
    
    if not res then
        res = "invalid base64 str:" .. str 
    end

    return res   
end

local function get_dict(id)
    return ngx.shared.business:get(id)
end

local function set_dict(id, value,exptime)
    exptime = exptime or 0
    return ngx.shared.business:set(id, value, exptime)
end

local function add_dict(id, value, exptime)
    exptime = exptime or 0
    return ngx.shared.business:add(id, value, exptime)
end

local function incr_dict(id, step)
    return ngx.shared.business:incr(id, step)
end

local function flush_all_dict()
    return ngx.shared.business:flush_all()
end

local function flush_expired_dict()
    return ngx.shared.business:flush_expired()
end


local function gen_key_for_qps_count(id)
    return const.DSP_QPS_COUNT_PREFIX .. id
end

local function gen_key_for_qps_total(id)
    return const.DSP_QPS_TOTAL_PREFIX .. id
end

local function gen_key_for_qps_limit(id)
    return const.DSP_QPS_LIMIT_PREFIX .. id
end


local function alarm(subject, content)
    local local_ip = ngx.var.server_addr
    local master_list = common.select_master_info_all()
    local flag = false;
    for _,  master in ipairs(master_list) do
        if local_ip == master.ip then
            flag = true
        end
    end   
  
    if flag then
       os.execute("cd /usr/local/openresty/nginx/src/script/alarm && ./send_alert.pl " .." --sv \"搜索频道\" " 
                    ..  "--service \"AD Engine \"" 
                    ..  " --object \"Monitor\""
                    ..  " --subject " .. "\"" .. subject  .. "\""
                    ..  " --content " .. "\""  .. content .. "\"" 
                    ..  " --gmailto \"ad_engine_monitor\""
                    ..  " --gmsgto \"ad_engine_monitor\"")
    else
        ngx.log(ngx.ERR, local_ip .. " is not a  master. can not send alarm")
    end
end

local function encrypt_price(iv, e_key, i_key, win_cpm_price)
    local pad = string.sub(ngx.hmac_sha1(e_key, iv), 1, 8); 
    local price = struct.pack(">l", win_cpm_price);
    local enc_price = {}; 
    for i = 1, 8 do
        enc_price[i] = string.char(bit.bxor(string.byte(pad, i), string.byte(price, i)));
    end 
    enc_price = table.concat(enc_price);
    local signature = string.sub(ngx.hmac_sha1(i_key, price .. iv), 1, 4); 
    local msg = ngx.encode_base64(iv .. enc_price .. signature);

    return msg
end

local function unencrypt_price(e_key, i_key, encrypt_str)
    local iv = string.sub(encrypt_str, 1, 16);
    local encrypt_price = string.sub(encrypt_str, 17, 24);
    local signature = string.sub(encrypt_str, 25, 28);
    local pad = string.sub(ngx.hmac_sha1(e_key, iv), 1, 8);

    local price = {};
    for i = 1, 8 do
        price[i] = string.char(bit.bxor(string.byte(pad, i), string.byte(encrypt_price, i)));
    end
    price = table.concat(price);
    local unenc_price = struct.unpack(">l", price);

    if string.sub(ngx.hmac_sha1(i_key, price .. iv), 1, 4) == signature then
        return unenc_price;
    end

    return "";
end

local function list_concator(list, need_quote)
    if not need_quote then return table.concat(list, ",") end

    local temp = {}
    for _, v in ipairs(list) do
        v = ngx.quote_sql_str(v)
        table.insert(temp, v)
    end
    return table.concat(temp, ",")
end


local function column_list_parse(list, is_update)
    if is_update then
        local set_block
        for k, v in pairs (list) do
            if type(v) == "string" then v = ngx.quote_sql_str(v) end 
            if not  set_block then
                set_block = k .. "=" .. v
            else
                set_block = set_block .. "," .. k .. "=" .. v
            end 
        end
        return set_block
    end
    local key_list, value_list = {},{}
    for key, value in pairs(list) do
        table.insert(key_list, key)
        if type(value) == "string" then value = ngx.quote_sql_str(value) end
        table.insert(value_list, value)
    end

    local key = table.concat(key_list, ",")
    local value = table.concat(value_list, ",")
    return key, value
end

local function log(level, ...) 
    ngx.log(level, ...)
end

local ok, new_tab = pcall(require, "table.new");
if not ok then
    new_tab = function(narr, nrec) return {} end
end

local util = {
    DEBUG                   = false,
    log                     = log,
    new_tab                 = new_tab,
    split                   = split,
    parse_inet_url          = parse_inet_url,
    decode_log_str          = decode_log_str,
    get_dict                = get_dict,
    set_dict                = set_dict,
    add_dict                = add_dict,
    incr_dict               = incr_dict,
    flush_all_dict          = flush_all_dict,
    flush_expired_dict      = flush_expired_dict,

    list_concator           = list_concator,
    column_list_parse       = column_list_parse,

    gen_key_for_qps_count           = gen_key_for_qps_count,
    gen_key_for_qps_total           = gen_key_for_qps_total,
    gen_key_for_qps_limit           = gen_key_for_qps_limit,  
    
    encrypt_price           = encrypt_price,
    unencrypt_price         = unencrypt_price,
 

    alarm               = alarm
}

return util
