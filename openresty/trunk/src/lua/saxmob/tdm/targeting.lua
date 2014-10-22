local cjson = require "cjson";
local redis = require "common.redis";
local util = require "common.util";

local _M = util.new_tab(0, 11);
_M._VERSION = "1.0";

_M.attr_mem = {
    udid            = {1,   "string", false},  --equal imei
    uid             = {2,   "string", true},
    device          = {3,   "string", true},
    age             = {4,   "string", true},
    gender          = {5,   "string", true},
    degree          = {6,   "string", true},
    prov            = {7,   "string", true},
    city            = {8,   "string", true},
    interest        = {9,   "string", true},
    worklbs         = {10,  "string", true},
    homelbs         = {11,  "string", true}
};


local function _set_dict(id, info)
    return ngx.shared.targeting:set(id, info);
end

local function _get_dict(id)
   return ngx.shared.targeting:get(id);
end

local function _set_attr(self, res_arr, id, info)
    local object = self.object;
    object[id] = res_arr;
    
    return _set_dict(id, info);
end

local function _get_attr(self, id, index)
    local object = self.object;
    if object[id] then
        return object[id][index], nil, true;
    end
    
    local info, err = _get_dict(id);
    if not info then
        return nil, err, false;
    end

    local ok, res = pcall(cjson.decode, info);
    if not ok then
        return nil, res, false;
    end
    
    object[id] = res;
    return res[index], nil, true;
end

local function _build_query(id)
    local rr_peer = _tdm_c_hash:get_consistent_hash_peer(id);
    local rd_slave = rr_peer.rd_slave;
    local i;
    if #rd_slave > 1 then
        i = math.random(1, #rd_slave);
    else
        i = 1;
    end
    -- we let timeout option be default
    local req = { ids = {id}, opts = { ip = rd_slave[i].ip, port = rd_slave[i].port } };
    return req;
end

function _get_value(self, id, name)
    if not id or id == "" then
        return nil;
    end

    if not self.object then
        return nil, "is not valid object";
    end

    local value;
    local attr = self.attr_mem;
    if util.DEBUG then
        ngx.log(ngx.DEBUG, "step 1 get value: " .. id .. " " .. name);    
    end

    -- get from cache object and shareddict
    value, err, exist = _get_attr(self, id, attr[name][1]);    
    if value or exist then
        return value;
    end

    if util.DEBUG then
        ngx.log(ngx.DEBUG, "step 2 get redis: " .. id);
    end

    -- sharedict have no key , so we need to query redis
    req = _build_query(id)
    local info, err = redis.get(req)
    if not info then
        ngx.log(ngx.ERR, err);
        self.object[id] = {};
        return nil, err;
    end

    info = info[1]
    if info == ngx.null then
        info = "[]";
    end

    local ok, res_arr = pcall(cjson.decode, info);
    if not ok then
        ngx.log(ngx.ERR, res_arr);
        res_arr = {};
        info = "[]";
    end

    if util.DEBUG then
        ngx.log(ngx.DEBUG, "step 3 set sharedict");
    end

    -- push data to cached object and shareddict
    local succ, err, forcible = _set_attr(self, res_arr, id, info);
    if not succ then
        ngx.log(ngx.WARN, err, " ", forcible, ": set share dict error");
    end

    -- then we return the result
    return res_arr[attr[name][1]];
end

local mt = {__index = _M};
--[[ PUBLIC API ]]

function _M.new()
    local temp = {};
    temp.object = {};
    return setmetatable(temp, mt);
end

function _M.get_value(self, id, name)
    return _get_value(self, id, name);
end

function _M.get_age(self, id)
    return _get_value(self, id, "age");
end

function _M.get_gender(self, id)
    return _get_value(self, id, "gender");
end

function _M.get_degree(self, id)
    return _get_value(self, id, "degree");
end

function _M.get_prov(self, id)
    return _get_value(self, id, "prov");
end

function _M.get_city(self, id)
    return _get_value(self, id, "city");
end

function _M.get_interest(self, id)
    return _get_value(self, id, "interest");
end

function _M.get_worklbs(self, id)
    return _get_value(self, id, "worklbs");
end

function _M.get_homelbs(self, id)
    return _get_value(self, id, "homelbs");
end

return _M;
