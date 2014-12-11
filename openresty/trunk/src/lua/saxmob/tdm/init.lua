local c_hash = require "tdm.c_hash";

local _M = {}

_M.bx_rds_server = 
{
    sp = 6371, ep = 6382,
    { 
      wr_master = { ip = "10.13.88.123" }, 
      rd_slave =  { ip = {"10.13.88.127"}}
    },
    { 
      wr_master = { ip = "10.13.88.124" },
      rd_slave =  { ip = {"10.13.88.128"} }
    },
    {
      wr_master = { ip = "10.13.88.125" }, 
      rd_slave =  { ip = {"10.13.88.129"} }
    },
    { 
      wr_master = { ip = "10.13.88.126" }, 
      rd_slave =  { ip = {"10.13.88.130"} }
    }
};

_M.sx_rds_server = _M.bx_rds_server;
_M.yf_rds_server = _M.bx_rds_server;

function _M.init_c_hash(idc)
    local rds_server = _M[idc .. "_rds_server"]
    _tdm_c_hash = c_hash.new(rds_server)
    _tdm_c_hash:init_consistent_hash()

end

return _M
