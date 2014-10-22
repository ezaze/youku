local http = require "resty.http";

local function query(req)
    local addr = req.addr;
    local opt = req.opt;
	
    local client = http:new();

    client:set_timeout(opt.timeout or 100);

    local ok, err = client:connect(addr.host, addr.port);
    if not ok then
    	return {status = nil, body = err};
    end
    
    local res, err = client:request(opt);
    if res and res.keepalive and opt.keepalive then
        client:set_keepalive(opt.keepalive, opt.size or 10);
    else
        client:close();
    end

    if res then
        return {status = res.status, headers = res.headers, body = res.body};
    else
        return {status = nil, body = err};
    end
end

local _M = {};
_M.GET = "GET";
_M.POST = "POST";

--[[
reqs:
{
    {addr = {host = "", port = ""},
     opt = {method = "",
            path = "",
            args = "",
            headers = "",
            body = "", 
            timeout = "",
            keepalive = "",
            size = ""}
    }

    ...
}

rsps:
{
    {status = "", headers = "", body = ""}, --in case of success
    {status = nil, body = err}, --in case of failure

    ...
}
]]
function _M.req_muti(reqs)
    local threads = {};
    for i, req in ipairs(reqs) do
        threads[i] = ngx.thread.spawn(query, req);
    end

    local rsps = {};
    for i = 1, #threads do
        local ok, rsp = ngx.thread.wait(threads[i]);
        if ok then
            rsps[i] = rsp;
        else
            rsps[i] = {status = nil, body = rsp};
        end
    end

    return rsps;
end

return _M;

