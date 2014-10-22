local function getCallbackFunc()
    local callbackFunc = ngx.var.arg_callback or "";

    -- filter callbackFunc character not in whiteStr is not valid
    -- whiteStr="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._";
    if string.match(callbackFunc, "^[%w%._]+$") then
        return callbackFunc;
    end
    return "";

end

local function getAdUnitId()
    return ngx.var.arg_adunitid or "";
end

local function getRotateCount()
    return ngx.var.arg_rotate_count or "";
end

local function getReferer()
    return ngx.var.http_referer or "";
end

local function getPageUrl()
    return ngx.var.arg_referral or "";
end

local function getPageKeyword()
    return ngx.var.arg_tgkeywords or "";
end

local function getVideoPageUrl()
    return ngx.var.arg_page_url or ""    
end

local function getPageEntry()
    return ngx.var.arg_tgentry or "";
end

local function getPageTemplate()
    return ngx.var.arg_tgtpl or "";
end

local function getIp()
    local ip = ngx.var.arg_tgip or "";
    if ip == "" then
        return ngx.var.http_x_forwarded_for or "";
    else
        return ip;
    end
end

local function getCookie()
    local cookie = ngx.var.cookie_sinaglobal or "";
    if cookie == "" then
        return ngx.var.cookie_ustat or "";
    else
        return cookie;
    end
end

local function getUserId()
    local cookie_sup = ngx.var.cookie_sup
    local uid = ""
    if cookie_sup ~= nil then        
        cookie_sup = ngx.unescape_uri(cookie_sup)
        local t = ngx.decode_args(cookie_sup)
        uid = t.uid or ""      
    end
    return uid;
end

local function getUserAgent()
    return ngx.var.http_user_agent or "";
end

local function getTimestamp()
    return ngx.var.arg_timestamp or "";
end

local function getPosition()
    return ngx.var.arg_pos or "";
end

local function getLength()
    return ngx.var.arg_v_length or "";
end

local function getSite()
    return ngx.var.arg_site or "";
end

local function getHostname()
    return ngx.var.arg_hostname or "";
end

local function getClient()
    return ngx.var.arg_client or "";
end

local function getVid()
    return ngx.var.arg_vid or "";
end

local function getMovietvid()
    return ngx.var.arg_movietvid or "";
end

local function getSubid()
    return ngx.var.arg_subid or "";
end

local function getSrcid()
    return ngx.var.arg_srcid or "";
end

local function getChannel()
    return ngx.var.arg_v_cha or "";
end

local function getSubject()
    return ngx.var.arg_v_sub or "";
end

local function getSports1()
    return ngx.var.arg_v_sports1 or "";
end

local function getSports2()
    return ngx.var.arg_v_sports2 or "";
end

local function getSports3()
    return ngx.var.arg_v_sports3 or "";
end

local function getSports4()
    return ngx.var.arg_v_sports4 or "";
end

local function getRoom()
    return ngx.var.arg_room or "";
end

local function getLiveId()
    return ngx.var.arg_liveid or "" ;
end

local function getMediaTags()
    return ngx.var.arg_media_tags or "";
end

local function getLiveTags()
    return ngx.var.arg_live_tags or "";
end

local function getDspId()
    return ngx.var.arg_sina_nid or "";
end

local function getSaxObjectName()
    return ngx.var.arg_name or "";
end

local function getSaxObjectId()
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    if not args then return "" end

    return args.id or ""
end

local function getCenterUpdateInfo()
    ngx.req.read_body()
    local args = ngx.req.get_post_args()
    if not args then return "" end

    return args.info or ""
end

local function getSaxOperate()
    return ngx.var.arg_operate or ""
end

local function getClickType()
    return ngx.var.arg_type or "" ;
end 

local function getClickT()
    return ngx.var.arg_t or "" ;
end 

local function  getClickTargeting()
    return ngx.var.arg_targeting or "" ;
end

local function getClickUrl()
    return ngx.var.arg_url or "" ;
end

local function getViewType()
    return ngx.var.arg_type or ""; 
end

local function getViewT()
    return ngx.var.arg_t or "" ;
end

local function getBodyData()
    ngx.req.read_body()
    return ngx.req.get_body_data() or ""; 
end

local function getSaxReqType()
    return ngx.var.arg_type or "";
end

local function getSaxDspIds()
    return ngx.var.arg_dspids or "";
end

local function getQpsLimit()
    return ngx.var.arg_qpslimit or "";
end

local function getPreviewDate()
    return ngx.var.arg_date or "";
end

local function getBlogArticleId()
    return ngx.var.arg_blogArticleId or ""
end

local function getBlogUserId()
    return ngx.var.arg_blogUserId or ""
end

local function getDeId()
    return ngx.var.arg_deid or ""
end

local function getClickSign()
    return ngx.var.arg_sign or ""
end

local parser = {
    getCallbackFunc         = getCallbackFunc,
    getAdUnitId             = getAdUnitId,
    getRotateCount          = getRotateCount,
    getReferer              = getReferer,
    getPageUrl              = getPageUrl,
    getPageKeyword          = getPageKeyword,
    getPageEntry            = getPageEntry,
    getPageTemplate         = getPageTemplate,
    getIp                   = getIp,
    getCookie               = getCookie,
    getUserId               = getUserId,
    getUserAgent            = getUserAgent,
    getTimestamp            = getTimestamp,
    getPosition             = getPosition,
    getLength               = getLength,
    getSite                 = getSite,
    getHostname             = getHostname,
    getClient               = getClient,
    getVid                  = getVid,
    getMovietvid            = getMovietvid,
    getSubid                = getSubid,
    getSrcid                = getSrcid,
    getChannel              = getChannel,
    getSubject              = getSubject,
    getSports1              = getSports1,
    getSports2              = getSports2,
    getSports3              = getSports3,
    getSports4              = getSports4,
    getRoom                 = getRoom,
    getLiveId               = getLiveId,
    getMediaTags            = getMediaTags,
    getLiveTags             = getLiveTags,
    getDspId                = getDspId,
    getSaxObjectName        = getSaxObjectName,
    getSaxObjectId          = getSaxObjectId,
    getSaxOperate           = getSaxOperate,
    getCenterUpdateInfo     = getCenterUpdateInfo,
    getClickType            = getClickType,
    getClickT               = getClickT,
    getClickTargeting       = getClickTargeting,
    getClickUrl             = getClickUrl,
    getViewType             = getViewType,
    getViewT                = getViewT,
    getBodyData             = getBodyData,
    getSaxReqType           = getSaxReqType,
    getSaxDspIds            = getSaxDspIds,
    getQpsLimit             = getQpsLimit,
    getPreviewDate          = getPreviewDate,
    getVideoPageUrl         = getVideoPageUrl,
    getBlogArticleId        = getBlogArticleId,
    getBlogUserId           = getBlogUserId,
    getDeId                 = getDeId,
    getClickSign            = getClickSign
};

return parser;
