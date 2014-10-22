local mysql = require "resty.mysql";

local conf = {
    host = "m3746i.mars.grid.sina.com.cn",
    port = 3746,
    database = "SaxMob",
    user = "SaxMob",
    password = "f3u4w8n7b3h",
    max_packet_size = 1024 * 1024,
    
    timeout = 1000,
    keepalive = 60000,
    size = 10
};

local _M = {};

function _M.query(sql)
    local db, err = mysql:new();
    if not db then
    	return nil, err;
    end
    
    db:set_timeout(conf.timeout);
    
    local ok, err, errno, sqlstate = db:connect{
        host = conf.host,
        port = conf.port,
        database = conf.database,
        user = conf.user,
        password = conf.password,
        max_packet_size = conf.max_packet_size
    };
    if not ok then
        return nil, "failed to connect: " .. err;
    end
    
    local res, err, errno, sqlstate = db:query(sql);
    if not res then
    	return nil, "bad result: " .. err;
    end
    
    db:set_keepalive(conf.keepalive, conf.size);

    return res;
end

return _M; 

