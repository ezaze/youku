local cjson = require("cjson");
local rtb = require("rtb.rtb");
local common = require("common.common");
local util = require("common.util");
local const = require("common.const");
local dsp = require("bdm.dsp");
local ssp = require("bdm.ssp");
local adunit = require("bdm.adunit");
local targeting = require("tdm.targeting");
local uuid = require("uuid")

local function parse_ad_req()
    ngx.ctx.ad_req = {};
    local ad_req = ngx.ctx.ad_req;

    -- parse ad request body
    local ad_req_body = common.get_body_data();
    
    local status, request_body = pcall(cjson.decode, ad_req_body)
    if not status then
        ngx.log(ngx.ERR, "json decode request body error." .. request_body .. " : " .. ad_req_body);
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end

    -- check SSP protocol version
    if request_body.version ~= const.SAX_SSP_PROTOCOL_VERSION then
        ngx.log(ngx.ERR, "ssp request protocol version error." ..  (request_body.version or "nil"));
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end

    -- check pid
    if not request_body.pid or request_body.pid == "" then
        ngx.log(ngx.ERR, "ssp request pid error.");
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end
    ad_req.pid = request_body.pid;

    --check adunit id
    if not request_body.adunit or not next(request_body.adunit) then
        ngx.log(ngx.ERR, "failed to parse adunit.");
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end

    if not request_body.adunit[1].id or request_body.adunit[1].id == "" then
        ngx.log(ngx.ERR, "ssp request ad unit id error.");
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end
    ad_req.adunit_list = request_body.adunit;

    -- parse carrier
    ad_req.carrier = request_body.carrier or 0;

    -- parse ip
    ad_req.ip = request_body.ip or "";

    -- parse user agent
    ad_req.ua = request_body.ua or "";

    --parse lbs
    ad_req.lbs = request_body.lbs or "";

    -- parse device object
    ad_req.device = request_body.device or {};
    ad_req.device.udid = ad_req.device.udid or "";

    -- parse app object
    ad_req.app = request_body.app or {};
    ad_req.app.name = ad_req.app.name or "";
end

local function get_ad_data()
    local ad_req = ngx.ctx.ad_req;
    
    ngx.ctx.ad_data = {};
    local ad_data = ngx.ctx.ad_data;
    local ad_pend_list = {};
    local dsp_white_list = {};

    -- get ad unit data
    local adunit_obj = adunit:new();
    for _, adunit in ipairs(ad_req.adunit_list) do
        if not adunit_obj:is_valid(adunit.id) then
            ngx.log(ngx.ERR, "failed to get data of ad unit " .. adunit.id);
        else
            if adunit_obj:get_status(adunit.id) == const.OBJECT_STATUS_VALID then
                table.insert(ad_pend_list, adunit);
            end
        end
    end
    ad_data.adunit_obj = adunit_obj;
    
    -- get ssp data
    local ssp_id = adunit_obj:get_ssp_id(ad_req.adunit_list[1].id);

    local ssp_obj = ssp:new();

    if not ssp_id then
        ngx.log(ngx.ERR, "failed to get data of ssp ");
        ad_pend_list = {};
    else
        if not ssp_obj:is_valid(ssp_id) then
            ngx.log(ngx.ERR, "failed to get data of ssp " .. ssp_id);
            ad_pend_list = {};
        else
            if ssp_obj:get_status(ssp_id) == const.OBJECT_STATUS_INVALID then
                ngx.log(ngx.INFO, "ssp:" .. ssp_id .. " is invalid");
                ad_pend_list = {};
            end
        end
    end

    ad_data.ssp_id = ssp_id or "";
    ad_data.ssp_obj = ssp_obj;
   
    -- get dsp data
    local dsp_obj = dsp:new();
    local dsp_id_list = adunit_obj:get_dsp_id_list();

    if not dsp_id_list then
        ngx.log(ngx.ERR, "failed to get data of dsp id list");
    else
        for _, dsp_id in ipairs(dsp_id_list) do
            if not dsp_obj:is_valid(dsp_id) then
                ngx.log(ngx.ERR, "failed to get data of dsp " .. dsp_id);
            else
                if dsp_obj:get_status(dsp_id) == const.OBJECT_STATUS_VALID then
                    table.insert(dsp_white_list, dsp_id);
                end
            end
        end
    end

    ad_data.dsp_obj = dsp_obj;
    ad_data.targeting_obj = targeting:new();

    local adunit_id_list = {};
    for _, adunit in ipairs(ad_req.adunit_list) do
        table.insert(adunit_id_list, adunit.id);
    end
   
    -- generate bid's  id
    ngx.ctx.uuid = uuid.generate("random");  
    ngx.ctx.id =  uuid.unparse(ngx.ctx.uuid);

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_SSP_REQ
                      .. ngx.ctx.id .. "\t"  
                      .. ad_data.ssp_id .. "\t"
                      .. ad_req.pid .. "\t"
                      .. table.concat(adunit_id_list, ",") .. "\t"
                      .. ad_req.ip .. "\t"
                      .. ad_req.device.udid .. "\t"
                      .. ad_req.app.name .. "\t"
                      .. (ad_req.app.category or "" )
                      .. const.LOG_SEPARATOR_SSP_REQ);


    return ad_pend_list, dsp_white_list;
end

local function check_dsp_qps(dsp_white_list, ad_pend_list)
    local ad_data = ngx.ctx.ad_data;
    -- check whether qps threshold of dsp has been reached
    local dsp_bid_list = {};
    local dsp_qps_list = {};

    local qps_list = ad_data.dsp_obj:get_qps_info_list(dsp_white_list);
    for _, dsp_id in ipairs(dsp_white_list) do
        if qps_list[dsp_id].limit > 0 and qps_list[dsp_id].count <= qps_list[dsp_id].limit then
            table.insert(dsp_bid_list, dsp_id);
        else
            table.insert(dsp_qps_list, dsp_id);
        end
    end

    local adunit_id_list = {};
    for _, adunit in ipairs(ad_pend_list) do
        table.insert(adunit_id_list, adunit.id);
    end

    if #dsp_qps_list ~= 0 then
        ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_QPS
                          .. table.concat(adunit_id_list, ",") .. "\t"
                          .. table.concat(dsp_qps_list, ",")
                          .. const.LOG_SEPARATOR_DSP_QPS);
    end

    return dsp_bid_list;
end

local function log_ssp_rsp(log)
    ngx.log(ngx.INFO,   const.LOG_SEPARATOR_SSP_RSP
                        .. ngx.ctx.id .. "\t" 
                        .. ngx.ctx.ad_data.ssp_id .. "\t"
                        .. ngx.ctx.ad_req.pid .. "\t"
                        .. log .. const.LOG_SEPARATOR_SSP_RSP
            )
end

local function build_ad_rsp(ad_creative_list)
    local ad_req = ngx.ctx.ad_req;
    local ad_data = ngx.ctx.ad_data;

    -- build ad response
    local ad_rsp = {};
    ad_rsp.pid = ad_req.pid;
    ad_rsp.version = const.SAX_SSP_PROTOCOL_VERSION;

    ad_rsp.adunit = {};
    local log = {};
    for _, adunit in ipairs(ad_req.adunit_list) do
        local temp = {};
        temp.id = adunit.id;
    
        if not ad_creative_list[adunit.id] then
            temp.ad = {}
        else
            temp.ad = ad_creative_list[adunit.id].ad
            log_ssp_rsp(adunit.id .. "\t".. (ad_creative_list[adunit.id].dsp_id or "") .. "\t" .. table.concat(ad_creative_list[adunit.id].creative_id, "," )  )
        end
        table.insert(ad_rsp.adunit, temp);
    end

    return cjson.encode(ad_rsp);
end

local function impress()
    -- parse ad request
    parse_ad_req();
    
    -- get ad data
    local ad_pend_list, dsp_white_list = get_ad_data();

    local ad_creative_list = {};
        
    -- launch real time bidding for dsp
    if #ad_pend_list ~= 0 and #dsp_white_list ~= 0 then
        local dsp_bid_list = check_dsp_qps(dsp_white_list, ad_pend_list);

        if #dsp_bid_list ~= 0 then
            rtb.launch_rtb_for_dsp(ad_pend_list, dsp_bid_list, ad_creative_list);
        end
    else
        ngx.log(ngx.ERR, "ad_pend_list or dsp_white_list number is 0," 
                          .. "ad_pend_list:" .. #ad_pend_list 
                          .. ", dsp_white_list:" .. #dsp_white_list); 
    end

    -- build ad response
    local ad_rsp = build_ad_rsp(ad_creative_list);

    -- send ad response
    ngx.print(ad_rsp);
end

local impress = {
    impress = impress
};
return impress;
