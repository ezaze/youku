local util = require "common.util";

local _M = util.new_tab(0, 5);
_M._VERSION = "1.0"

local function _consistent_hash_node_point(str)
    return ngx.crc32_long(ngx.md5(str));
end

local function _consistent_hash_find(nodes, point)
    local l = 1;
    local r = #nodes;
    while l < r - 1 do
        local m = l + math.floor((r - l) / 2);
        if point > nodes[m].point then
            l = m + 1;
        else
            r = m;
        end
    end
    
    if point <= nodes[l].point then
        return nodes[l];
    elseif point <= nodes[r].point then
        return nodes[r];
    else 
        return nodes[l];
    end
end

local function _parse_server(rds_server)

    local ret = util.new_tab(#rds_server, 0);
    local sp = rds_server.sp;
    local ep = rds_server.ep;
    for _, server in ipairs(rds_server) do
        local wr_master = server.wr_master;
		local wrs = {}
		for port = sp, ep do
			wrs[#wrs + 1] = {ip = wr_master.ip, port = port};
		end
        
		local rd_slave = server.rd_slave;
        local rds = {};

		local j = 1;
		for port = sp, ep do
        	for i, ip in ipairs(rd_slave.ip) do
				rds[j] = rds[j] or {};
				rds[j][i] = {ip = ip, port = port};
			end
	    	j = j + 1;
		end

        for i = 1, #wrs do
            ret[#ret + 1] = {wr_master = wrs[i], rd_slave = rds[i]};
        end
    end
    return ret;
end

--[[ PUBLIC API ]]--

local mt = { __index = _M }

function _M.new(rds_server, n)
    local obj = util.new_tab(0, 4);
    obj._CONSISTENT_BUCKETS = n or 65536;
    obj.rds_server = _parse_server(rds_server);
     
    return setmetatable(obj, mt);
end


function _M.init_consistent_hash(self)
    if self.init then
        return;
    end
    
    self.buckets = util.new_tab(self._CONSISTENT_BUCKETS, 0);
    local CONSISTENT_BUCKETS = self._CONSISTENT_BUCKETS;
    local buckets = self.buckets;
    local nodes = {};
    
    local rds_server = self.rds_server;
    local real_node = #rds_server;
    local point_per_node = math.floor(CONSISTENT_BUCKETS / real_node);
    
    for _, server in ipairs(rds_server) do
        for j = 1, point_per_node do
            local node = util.new_tab(0, 2);
            local key = server.wr_master.ip .. ":" .. server.wr_master.port .. "-" .. j;
            node.point = _consistent_hash_node_point(key);
            node.rr_peer = { wr_master  = server.wr_master,
                             rd_slave   = server.rd_slave 
                           };
            nodes[#nodes + 1] = node;
        end
    end
    table.sort(nodes, function(a, b) return a.point < b.point end);

    local step = math.floor(0xffffffff / CONSISTENT_BUCKETS);
    for i = 0, CONSISTENT_BUCKETS - 1 do
        buckets[i + 1] = _consistent_hash_find(nodes, i * step);    

        if util.DEBUG then
            ngx.log(ngx.DEBUG, "bucket [", i, "]: ", 
                               buckets[i + 1].rr_peer.wr_master, " ",
                               buckets[i + 1].point);
        end
    end
    self.init = true;
    
end

function _M.get_consistent_hash_peer(self, key)
    if not self.init then
        self:init_consistent_hash();
    end
    
    local buckets = self.buckets;
    local point = ngx.crc32_long(key);
    local node = buckets[point % self._CONSISTENT_BUCKETS + 1];
    return node.rr_peer;
end 

-- for debug
function _M.get_peer(self, key)
    if not self.init then
        self:init_consistent_hash();
    end
    
    local buckets = self.buckets;
    local point = ngx.crc32_long(key);
    local node = buckets[point % self._CONSISTENT_BUCKETS + 1];
    return cjson.encode(node.rr_peer);
end

return _M;
