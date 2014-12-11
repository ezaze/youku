local util = require "common.util";
local redis = require "common.redis";

local function flush_dict()
    if util.DEBUG then
        ngx.log(ngx.DEBUG, "worker: flush sharedict");
    end

    ngx.shared.targeting:flush_all();
end

-- for debug
local function get_targeting_info(id)
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
    local info, err = redis.get(req);
    return info or err;
end

--[[
ngx.timer.at(6000, flush_cached);
]]
local worker = {
    flush_dict  = flush_dict,
    get_targeting_info     = get_targeting_info
}
return worker;
