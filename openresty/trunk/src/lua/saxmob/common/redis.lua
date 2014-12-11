local redis = require "resty.redis";
local util = require "common.util";
--[[
    req:  { ids = {},
            infos = {},
            opts = {ip = "", port = "", timeout = "", keepalive = "", size = ""}
          }
    `keepalive`: keepalive set
        false: not set keepalive
        >0: timeout(ms) for keepalive connection
        =0: never timeout
--]]

local _M = {};

function _M.get(req)

    local ids = req.ids;
    local opts = req.opts;

    local red = redis:new();
    red:set_timeout(opts.timeout or 100);

    if util.DEBUG then
        ngx.log(ngx.DEBUG, "get from read slave " .. opts.ip .. ":" .. opts.port);
    end

    local ok, err = red:connect(opts.ip, opts.port);
    if not ok then
        return nil, err;
    end

    red:init_pipeline(#ids);

    for _, id in ipairs(ids) do
        red:get(id);
    end

    local results, err =  red:commit_pipeline();
    red:set_keepalive(opts.keepalive or 60000, opts.size or 5);
    return results, err;
end

function _M.set(req, exprtime)
    local ids = req.ids;
    local infos = req.infos;
    local opts = req.opts;

    local red = redis:new();
    red:set_timeout(opts.timeout or 10000);
    
    local ok, err = red:connect(opts.ip, opts.port);
    if not ok then
        return nil, err;
    end
    
    red:init_pipeline(#ids);
    for i, id in ipairs(ids) do
        red:set(id, infos[i], "EX", exprtime);
    end
    
    local results, err =  red:commit_pipeline();
    red:set_keepalive(opts.keepalive or 60000, opts.size or 5);

    return results, err;
end

function _M.del_all()
    local rds_server = _tdm_c_hash.rds_server;
    local red = redis:new();
    for _, server in ipairs(rds_server) do
        local wr_master = server.wr_master;
        red:set_timeout(10000);
        local ok, err = red:connect(wr_master.ip, wr_master.port);
        if not ok then
            ngx.log(ngx.INFO, err, " delete failure");
        else
            red:flushall();
            red:set_keepalive(60000, 10);
        end

    end
end

return _M;

