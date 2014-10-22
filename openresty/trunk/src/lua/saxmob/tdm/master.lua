local common = require "common.common";
local util = require "common.util";
local const = require "common.const";
local redis = require "common.redis";
local http = require "common.http";
local targeting = require "tdm.targeting";
local cjson = require "cjson";

--[[interface 
POST json encode
body:   [
            {udid = "", ...},  //当属性为空时，不传该属性
            {udid = "", ...},
            {udid = "", ...},
        ]
]]

local function _transfer_table(res_rec)
    local attr = targeting.attr_mem;
    local res_arr = util.new_tab(#attr, 0);
    
    if not res_rec["udid"] then
        ngx.log(ngx.ERR, "record have no udid");
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end

    for key, p in pairs(attr) do
        local val = res_rec[key];
        if val and p[2] ~= type(val) then
            ngx.log(ngx.ERR, key, " type non match expected ", p[2],
                            " type but found ", type(val));
            ngx.exit(ngx.HTTP_BAD_REQUEST);
        end
        res_arr[p[1]] = val or "";
    end
    return res_arr;
end

local function _format_data(rows)
    local temp = util.new_tab(12, 0);
    local data = util.new_tab(12, 0);

    for _, row in ipairs(rows) do 
        local rr_peer = _tdm_c_hash:get_consistent_hash_peer(row.udid);
        local ip = rr_peer.wr_master.ip;
        local port = rr_peer.wr_master.port;    
        local key = ip .. port;

        if not temp[key] then
            data[#data + 1] = { ids = {}, infos = {}, 
                                opts = { ip = ip, port = port}
                              };
            temp[key] = #data;
        end

        local ids = data[temp[key]].ids;
        ids[#ids + 1] = row.udid;

        local row_arr, err = _transfer_table(row);
        local infos = data[temp[key]].infos;
        infos[#infos + 1] = cjson.encode(row_arr);
    end

    return data;
end

local function _check_failed(results, ids, failed)

    if not results then
        ngx.log(ngx.ERR, err_str, "failed to update ids: ", table.concat(ids, ","));
        for _, id in ipairs(ids) do
            failed[#failed + 1] = id;
        end
        return;
    end

    for i, res in ipairs(results) do
        if type(res) == "table" then
            if not res[1] then
                ngx.log(ngx.ERR, res[2], "failed to update id: ", ids[i]);
                failed[#failed + 1] = ids[i];
            end
        end
    end
end

local _M = {}
-- [[PUBLIC API]]
function _M.finish()

    --notify worker to update shared dict
    
    local worker_addr, err = common.select_worker_info_all();
    if not worker_addr then
        ngx.log(ngx.ERR, err, ": failed to get worker address");
        return;
    end
    
    local reqs = util.new_tab(#worker_addr, 0);
    
    for _, addr in ipairs(worker_addr) do
        reqs[#reqs + 1] = {
            addr = { host = addr.ip, port = addr.port },                           
            opt  = { path = const.SAXMOB_UPDATE_TD_URI, timeout = 100}
        };
    end

    local rsps = http.req_muti(reqs);
    for i, rsp in ipairs(rsps) do
        if rsp.status ~= 200 then
            ngx.log(ngx.ERR, rsp.status or rsp.body, ": failed to notify worker: ",
                             reqs[i].addr.host .. ":" .. reqs[i].addr.port);
        end
    end
end

function _M.update_redis()
    local st, btime;
    if util.DEBUG then
        ngx.update_time();
        st = ngx.now();
    end

    local info = common.get_body_data();

    if util.DEBUG then
        ngx.update_time();
        btime = ngx.now() - st;
    end

    local status, rows = pcall(cjson.decode, info);
    if not status then
        ngx.log(ngx.ERR, "request body format error " .. rows);
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end

    if util.DEBUG then
        ngx.update_time();
        st = ngx.now();
    end

    local failed = {};
    local thread = {};
    local data = _format_data(rows) 
    for i, t in ipairs(data) do
        thread[i] = ngx.thread.spawn(function(t) return redis.set(t, 24 * 30 * 3600) end, t); 
    end
    for i, td in ipairs(thread) do
        local succ, results = ngx.thread.wait(td);
         
        _check_failed(succ and results, data[i].ids, failed);
    end

    if util.DEBUG then
        ngx.update_time();
        local stime = ngx.now() - st;
        local str = "\n###time-body:" .. string.len(info) .. "### " .. btime .. "\n" ..
                    "###time-redis:" .. #rows .. "### " .. stime .. "\n";
        ngx.log(ngx.DEBUG, str)
    end

    if #failed ~= 0 then
        ngx.print(table.concat(failed, ","));
    end
end

function _M.del_all()
    redis.del_all();

    _M.finish();
end

return _M;
