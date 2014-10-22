local cjson = require("cjson");
local util = require("common.util");
local const = require("common.const");
local http = require("common.http");

local function log_dsp_req(ad_pend_list, dsp_bid_list)
    local ad_req = ngx.ctx.ad_req
    
    local adunit_id_list = {};
    for _, adunit in ipairs(ad_pend_list) do
        table.insert(adunit_id_list, adunit.id);
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_REQ
                      .. ngx.ctx.id .. "\t"
                      .. table.concat(dsp_bid_list, ",") .. "\t"
                      .. table.concat(adunit_id_list, ",") .. "\t"
                      .. ad_req.app.name .. "\t"
                      .. (ad_req.app.category or "")
                      .. ad_req.carrier .. "\t" 
                      .. ad_req.lbs .. "\t"
                      .. ad_req.ua .. "\t" 
                      .. (ad_req.device.platform or "") .. "\t"
                      .. (ad_req.device.os_version or "") .. "\t"
                      .. (ad_req.device.brand or "")  .. "\t" 
                      .. (ad_req.device.model or "")     
                      .. const.LOG_SEPARATOR_DSP_REQ);
end

local function build_bid_req(ad_pend_list, dsp_bid_list)
    local ad_req = ngx.ctx.ad_req;
    local ad_data = ngx.ctx.ad_data;
    local body = {};

    -- generate bid request body 
    body.id = ngx.ctx.id

    -- generate adunit object
    body.imp = {};
    for _, adunit in ipairs(ad_pend_list) do
        local imp = {};
        imp.id = adunit.id;
        imp.bidfloor = ad_data.adunit_obj:get_min_price(adunit.id);
        imp.banner = {}
        imp.banner.type = ad_data.adunit_obj:get_type(adunit.id);
        local size = adunit.size
        if adunit.size ~= "" then
            size = util.split(adunit.size, "*")
            if #size ==  2 then
                imp.banner.w = tonumber(size[1])
                imp.banner.h = tonumber(size[2])
            end
        end
        
        imp.banner.num = ad_data.adunit_obj:get_ad_num(adunit.id)        
        table.insert(body.imp, imp);
    end

    body.at = const.RTB_OPEN_AUCTION

    -- generate app object
    local app = {}

    app.name = ad_req.app.name
    app.cat = ad_req.app.category
    body.app = app

    -- generate device object
    local device = {}
    if ad_req.ip ~= "" then  device.ip = ad_req.ip end
    if ad_req.lbs ~= "" then 
        local lbs = util.split(ad_req.lbs, ",")
        if #lbs == 2 then
            device.lat = tonumber(lbs[1])
            device.lon = tonumber(lbs[2])
         end 
    end

    if ad_req.ua ~= "" then device.ua = ad_req.ua end 
    if ad_req.device.brand and ad_req.device.brand ~= ""  then device.make = ad_req.device.brand end
    if ad_req.device.model and ad_req.device.model ~= "" then  device.model = ad_req.device.model end

    device.os = ad_req.device.platform or 0
    device.osv = device.version or ""
    device.connectiontype = ad_req.carrier
    
    body.device = device

    -- generate user object
    body.user = {};
    body.user[const.USER_ID] = ngx.md5(ad_req.device.udid)
    if ad_req.device.udid ~= "" then 
        body.user[const.DMP_USER_AGE] =  ad_data.targeting_obj:get_age(ad_req.device.udid) or "";
        body.user[const.DMP_USER_GENDER] = ad_data.targeting_obj:get_gender(ad_req.device.udid) or "";
        local interest = ad_data.targeting_obj:get_interest(ad_req.device.udid) or "";
        body.user[const.DMP_USER_INTEREST] = util.split(interest, ",");
        body.user[const.DMP_USER_ZONE] =  ad_data.targeting_obj:get_city(ad_req.device.udid) or "";
        body.user[const.DMP_USER_DEGREE] = ad_data.targeting_obj:get_degree(ad_req.device.udid) or "";
     else
        body.user[const.DMP_USER_AGE] =  ""; 
        body.user[const.DMP_USER_GENDER] = "";  
        body.user[const.DMP_USER_INTEREST] = {};
        body.user[const.DMP_USER_ZONE] =  ""; 
        body.user[const.DMP_USER_DEGREE] = "";         
     end
    body.bcat = ad_data.adunit_obj:get_excluded_product_type(ad_pend_list[1].id)
    body.badv = ad_data.adunit_obj:get_excluded_landing_url(ad_pend_list[1].id)
    
    local json_str = cjson.encode(body);
    -- build bid request
    local bid_req_list = {};
    local dsp_bid_url = "";
    local dsp_bid_timeout = "";
    local dsp_bid_url_split = {};
    local temp = {};
    for _, dsp_id in ipairs(dsp_bid_list) do
        dsp_bid_url = ad_data.dsp_obj:get_bid_url(dsp_id);
        dsp_bid_timeout = ad_data.dsp_obj:get_timeout(dsp_id);
        dsp_bid_url_split = util.parse_inet_url(dsp_bid_url);

        if not dsp_bid_url_split.host or dsp_bid_url_split.host == "" then
            ngx.log(ngx.ERR, "get dsp bid host error dsp id: " .. dsp_id .. " bid url: " .. dsp_bid_url);
        else
            temp = {};
            temp.addr = {};
            temp.addr.host = dsp_bid_url_split.host;
            temp.addr.port = dsp_bid_url_split.port;

            temp.opt = {};
            temp.opt.path = dsp_bid_url_split.uri;
            if dsp_id == const.SINA_DSP_ID then
                temp.opt.path = temp.opt.path .. "?"
                local hashstr = ad_req.device.udid 
                temp.opt.args = {}
                temp.opt.args[const.RTB_REQ_ARG_COOKIE] = hashstr
                temp.opt.args[const.RTB_REQ_ARG_SSP_ID]  = ad_data.ssp_id
                temp.opt.headers = {[const.HASH_STR]=hashstr}
            end    
            temp.opt.method = http.POST;
            temp.opt.timeout = dsp_bid_timeout;
            temp.opt.keepalive = const.RTB_KEEPALIVE_TIME;
            temp.opt.size = const.RTB_CONNECTION_SIZE;
            temp.opt.body = json_str;

            table.insert(bid_req_list, temp);            
        end
    end

    -- log dsp request
    log_dsp_req(ad_pend_list, dsp_bid_list);
    return bid_req_list;
end

local function is_valid_rsp(rsp)
    if rsp.status ~= ngx.HTTP_OK then
        return false;
    else
        return true;
    end
end

local function get_bid_result(bid_rsp)
    local bid_result = cjson.decode(bid_rsp.body);
    if type(bid_result) ~= "table" then
        error("invalid bid response");
    end

    if bid_result.id ~= ngx.ctx.id then
        error("invalid field id");
    end
    
    if bid_result.cm ~= 0 and bid_result ~= 1 then
        error("invalid field cm")
    end

    if type(bid_result.bid) ~= "table" then
        error("invalid field bid");
    end

        
    if bid_result.bid then    
        for _, ad_content in ipairs(bid_result.bid) do
            if type(ad_content.id) ~= "string" then
                error("invalid field bid.id");
            end

            if type(ad_content.price) ~= "number" then
                error("invalid field price");
            end

            if type(ad_content.ad) ~= "table" then
                error("invalid field ad");
            end
            for _, ad in ipairs(ad_content.ad) do
                if type(ad.markup) ~= "string" then
                    error("invalid field markup type:" .. type(ad.markup))
                end            
                if type(ad.id) ~= "string" then
                    error("invalid field ad id");
                end
            end
         end
    end

    return bid_result;
end

local function log_dsp_rsp(dsp_id, ad_content)
    local ad_data = ngx.ctx.ad_data;

    local creative_id_list = {};
    for i, ad in ipairs(ad_content.ad) do
        creative_id_list[i] = ad.id;
    end

    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_RSP
                      .. ngx.ctx.id .. "\t"
                      .. dsp_id .. "\t"
                      .. ad_content.id .. "\t"
                      .. ad_content.price .. "\t" 
                      .. table.concat(creative_id_list, ",")
                      .. const.LOG_SEPARATOR_DSP_RSP);
end

local function log_dsp_null(dsp_id)
    ngx.log(ngx.DEBUG, const.LOG_SEPARATOR_DSP_NULL
                      .. ngx.ctx.id .. "\t"
                      .. dsp_id 
                      .. const.LOG_SEPARATOR_DSP_NULL);
end

local function log_dsp_invalid(dsp_id)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_INVALID 
                      .. ngx.ctx.id .. "\t"
                      .. dsp_id  
                      .. const.LOG_SEPARATOR_DSP_INVALID) ;
end

local function log_dsp_fail(dsp_id, bid_rsp)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_FAIL
                     .. ngx.ctx.id .. "\t"
                     .. dsp_id .. "\t"
                     .. (bid_rsp.status or bid_rsp.body)
                     .. const.LOG_SEPARATOR_DSP_FAIL);
end

local function log_dsp_win(adunit_id, winner)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_WIN
                      .. ngx.ctx.id .. "\t"  
                      .. adunit_id .. "\t"
                      .. winner.dsp_id .. "\t"
                      .. winner.win_cpm_price .. "\t"  
                      .. table.concat(winner.creative_id, ",") .. "\t"
                      .. const.LOG_SEPARATOR_DSP_WIN);
end

local function valid_markup(markup_str)
    local markup = cjson.decode(markup_str)
    if type(markup.src) ~= "table" then
        error("error type markup.src")
    end

    if type(markup.type) ~= "table" then
        error("error type markup.type")
    end

    if type(markup.link)~= "table" then
        error("error type markup.link ")  
    end
    
    if type(markup.view) ~= "table" then
        error("error type markup.view")
    end
    
    if type(markup.click) ~= "table" then
        error("error type markup.click")
    end    

    return markup
    
end 

local function log_dsp_foul(dsp_id, adunit_id, creative_id)
    ngx.log(ngx.INFO, const.LOG_SEPARATOR_DSP_FOUL
        .. ngx.ctx.id .. "\t"
        .. dsp_id .. "\t"
        .. adunit_id .. "\t"
        .. creative_id
        .. const.LOG_SEPARATOR_DSP_FOUL    
                        
    )
end

local function extract_ad_bid(bid_rsp_list, dsp_bid_list)
    local ad_data = ngx.ctx.ad_data;

    -- extract ad bid
    local ad_bid_list = {};

    for i, bid_rsp in ipairs(bid_rsp_list) do
        if is_valid_rsp(bid_rsp) then 
            local status, bid_result = pcall(get_bid_result, bid_rsp);
            if status then
                if bid_result.bid and #bid_result.bid ~= 0 then
                    for _, bid_content in ipairs(bid_result.bid) do
                        if bid_content.price >= ad_data.adunit_obj:get_min_price(bid_content.id) then
                            local temp = {};
                            temp.max_cpm_price = bid_content.price;
                            temp.ad ={}
                            temp.creative_id = {}
                            for _, ad in ipairs (bid_content.ad) do
                                local status, markup = pcall(valid_markup, ad.markup)
                               -- local  markup = cjson.decode(ad.markup)
                                if status  then
                                    table.insert(temp.ad, markup)
                                    table.insert(temp.creative_id, ad.id)
                                else
                                    --add log dsp_null
                                    log_dsp_foul(dsp_bid_list[i], bid_content.id, ad.id) 
                                    ngx.log(ngx.ERR, "markup:" .. ad.id .. "is invalid. detail :" .. markup)    
                                end
                            end
                            
                            if #temp.ad ~= 0 then
                                if not ad_bid_list[bid_content.id] then
                                    ad_bid_list[bid_content.id] ={} 
                                end
                                temp.dsp_id = dsp_bid_list[i];
                                table.insert(ad_bid_list[bid_content.id], temp);
                            end
                        else
                            ngx.log(ngx.INFO, "dsp:"..dsp_bid_list[i] 
                                                    .. " max cpm price:" 
                                                    .. bid_content.price 
                                                    .. "<" .. ad_data.adunit_obj:get_min_price(bid_content.id));
                        end

                        -- log dsp response
                        log_dsp_rsp(dsp_bid_list[i], bid_content);
                    end
                else 
                    log_dsp_null(dsp_bid_list[i])
                end

            else
                ngx.log(ngx.ERR, "bid:" .. ngx.ctx.id
                                 .. ", dsp id:" .. dsp_bid_list[i] 
                                 .. ", " .. bid_result 
                                 .. ":" .. bid_rsp.body);

                log_dsp_invalid(dsp_bid_list[i])
            end
        else
            -- log dsp bid fail
            log_dsp_fail(dsp_bid_list[i], bid_rsp);
        end
    end
    return ad_bid_list;
end

local function cmp_price(a, b)
    return a.max_cpm_price > b.max_cpm_price
end

local function select_winner(bid_info, adunit_id)
    local ad_data = ngx.ctx.ad_data;
    -- sort bid information
    if #bid_info ~= 1 then
        table.sort(bid_info, cmp_price);
    end

    -- select winner
    local second = 0;
    for i = 2, #bid_info do
        if bid_info[i].max_cpm_price ~= bid_info[1].max_cpm_price then
            second = i;
            break;
        end
    end

    local winner = {};
    if second ~= 0 then
        local first = 1;
        if second - 1 ~= 1 then
            first = math.random(1, second - 1);
        end

        winner.dsp_id = bid_info[first].dsp_id;
        winner.creative_id = bid_info[first].creative_id
        winner.win_cpm_price = bid_info[second].max_cpm_price + const.RTB_EXTRA_PRICE;
        winner.ad = bid_info[first].ad;
    else
        local first = 1;
        if #bid_info ~= 1 then
            first = math.random(1, #bid_info);
        end

        winner.dsp_id = bid_info[first].dsp_id;
        winner.creative_id = bid_info[first].creative_id
        winner.win_cpm_price = ad_data.adunit_obj:get_min_price(adunit_id);
        winner.ad = bid_info[first].ad;
    end
        
    return winner;
end

local function generate_click_url(dsp_id, adunit_id, creative_id)
    local ad_req = ngx.ctx.ad_req;
    local ad_data = ngx.ctx.ad_rata;

    local args = {};
    args[const.ARG_MONITOR_TYPE] = const.CLICK_TYPE_DSP;
    local log = ngx.ctx.id .. "\t"
                .. dsp_id .. "\t"
                .. adunit_id .. "\t"
                .. creative_id 
    local t = ngx.encode_base64(log);
    args[const.ARG_MONITOR_T] = t;

    return const.RTB_CLICK_URL .. "?" .. ngx.encode_args(args);
end

local function generate_view_url(dsp_id, adunit_id, win_cpm_price,creative_id)
    local ad_data = ngx.ctx.ad_data;
    local args = {};
    args[const.ARG_MONITOR_TYPE] = const.VIEW_TYPE_DSP;
    local log = ngx.ctx.id .. "\t"
                .. dsp_id .. "\t"
                .. adunit_id .. "\t"
                .. win_cpm_price .. "\t"
                .. creative_id

    local t = ngx.encode_base64(log);
    args[const.ARG_MONITOR_T] = t;

    return const.RTB_VIEW_URL .. "?" .. ngx.encode_args(args);
end

local function add_monitor_arg_p(ad, monitor_type, msg)
    local capture = ngx.re.match(ad[monitor_type][1], [[\?]], "jo");
    if capture then
        notation = "&" 
    else 
        notation = "?" 
    end 
        
    local args = {}
    args[const.SINA_DSP_CLICK_ARG_P] = msg;
    ad[monitor_type][1] = ad[monitor_type][1] .. notation .. ngx.encode_args(args)
end

local function alter_sina_dsp_creative(ad, click_url, view_url, msg)
    table.insert(ad.click, click_url)
    table.insert(ad.view, view_url )
    add_monitor_arg_p(ad, const.MONITOR_TYPE_CLICK, msg)
    add_monitor_arg_p(ad, const.MONITOR_TYPE_VIEW, msg)
end

local function alter_third_party_dsp_creative(ad,click_url, view_url, msg)
    for i, view in ipairs(ad.view) do
        ad.view[i] = ngx.re.gsub(view, const.RTB_MACRO_WIN_PRICE, msg, "jo");
    end 
    table.insert(ad.click, 1, click_url);
    table.insert(ad.view, 1, view_url);
end    

local function fill_ad_for_dsp(adunit_id, winner, ad_creative_list)
    local ad_data = ngx.ctx.ad_data;

    ad_creative_list[adunit_id] = ad_creative_list[adunit_id] or {};
    
    local e_key = ad_data.dsp_obj:get_encryption_key(winner.dsp_id)
    local i_key = ad_data.dsp_obj:get_integrity_key(winner.dsp_id)
    local msg = util.encrypt_price(ngx.ctx.uuid, e_key, i_key, winner.win_cpm_price);
    msg = ngx.escape_uri(msg)
    
    for i, ad in ipairs(winner.ad) do
       
        local click_url =  generate_click_url(winner.dsp_id, adunit_id, winner.creative_id[i]);
        local view_url = generate_view_url(winner.dsp_id, adunit_id, winner.win_cpm_price, winner.creative_id[i]);
        if (winner.dsp_id == const.SINA_DSP_ID) then
            alter_sina_dsp_creative(ad, click_url, view_url, msg)
        else
            alter_third_party_dsp_creative(ad, click_url, view_url, msg)
        end    
    end

    ad_creative_list[adunit_id].ad = winner.ad;
    ad_creative_list[adunit_id].dsp_id = winner.dsp_id;
    ad_creative_list[adunit_id].creative_id = winner.creative_id

end

local function remove_ad_from_pend_list(ad_pend_list, adunit_id)
    for i, adunit in ipairs(ad_pend_list) do
        if adunit.id == adunit_id then
            table.remove(ad_pend_list, i);
            return;
        end
    end
end

local function handle_bid_rsp(bid_rsp_list, ad_pend_list, dsp_bid_list, ad_creative_list)
    -- extract ad bid
    local ad_bid_list = extract_ad_bid(bid_rsp_list, dsp_bid_list);

    -- conduct auction 
    local win_price_list = {};

    for adunit_id, bid_info in pairs(ad_bid_list) do
        -- select winner 
        local winner = select_winner(bid_info, adunit_id);

        log_dsp_win(adunit_id, winner);
        
        -- fill ad creative list
        fill_ad_for_dsp(adunit_id, winner, ad_creative_list)
        -- remove ad unit from pending list
        remove_ad_from_pend_list(ad_pend_list, adunit_id);
    end
end

local function launch_rtb_for_dsp(ad_pend_list, dsp_bid_list, ad_creative_list)
    -- build bid request
    local bid_req_list = build_bid_req(ad_pend_list, dsp_bid_list);
    -- send bid request
    local bid_rsp_list = http.req_muti(bid_req_list);

    -- handle bid response
    handle_bid_rsp(bid_rsp_list, ad_pend_list, dsp_bid_list, ad_creative_list);
end

local rtb = {
    launch_rtb_for_dsp = launch_rtb_for_dsp,
    generate_click_url = generate_click_url,
    generate_view_url = generate_view_url
}
return rtb;
