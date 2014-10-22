local const = {
    CENTER_NOTIFY_SAX_URI       = "/center/notifysax",
    CENTER_RESET_QPS_URI        = "/center/resetqps",
    SAX_UPDATE_OBJECT_URI       = "/sax/updateobject",
    SAX_UPDATE_QPS_URI            = "/sax/updateqps",
    SAX_DELETE_OBJECT_OPERATE   = "delete",

    --dsp qps service type  (gettotal setlimit)
    GET_DSP_QPS_TOTAL            = "gettoal",
    SET_DSP_QPS_LIMIT            = "setlimit",

    OBJECT_DSP                  = "dsp",
    OBJECT_RESOURCE             = "resource",
    OBJECT_PUBLISHER            = "publisher",
    OBJECT_ADUNIT               = "adunit",
    OBJECT_CREATIVE             = "creative",
    OBJECT_ADVERTISER           = "advertiser",
    OBJECT_NETWORK              = "network",
    OBJECT_STATUS_VALID         = 1,
    OBJECT_STATUS_INVALID       = 0,
    OBJECT_FLAG_SET             = 1,
    OBJECT_FLAG_CLEAR           = 0,

    -- to check validity of format of json sent by manage end
    OBJECT_ATTR_UPDATE_INSERT   = 2,
    OBJECT_ATTR_INSERT          = 1,
    OBJECT_ATTR_NONE            = 0,

    -- redis key used to do dsp qps control utility
    DSP_QPS_LIMIT_PREFIX        = "dsp:qps:limit:",
    DSP_QPS_COUNT_PREFIX        = "dsp:qps:count:",
    DSP_QPS_TOTAL_PREFIX        = "dsp:qps:total:",
    DSP_QPS_FACTOR              = 1,
    SERVER_TELECOM              = "telecom",
    SERVER_UNICOM               = "unicom",

    -- used to set default value of some object's attributes
    EMPTY_TABLE                 = {},    

    NGINX_VAR_URL               = "url",
    NGINX_VAR_HASH_STR          = "hash_str",

    SINA_QUERY_URI              = "/sina/query",
    WEIBO_QUERY_URI             = "/weibo/query",
    PREVIEW_QUERY_URI           = "/preview/query",
    SINA_QUERY_URL_SINA         = "http://adengine.sina.com.cn/mfp/delivery.do",
    SINA_QUERY_URL_VIDEO        = "http://adengine.sina.com.cn/mfp/delivery.do",
    SINA_QUERY_URL_MOBILE       = "http://adengine.sina.com.cn/mfp/mobdelivery.do",
    SINA_QUERY_URL_WEIBO_IMPRESS = "http://adengine.sina.com.cn/mfp/appdelivery.do",
    SINA_QUERY_URL_WEIBO_CLICK  = "http://adengine.sina.com.cn/mfp/newappclick.do",
    SINA_QUERY_URL_WEIBO_LOG    = "http://adengine.sina.com.cn/mfp/newappimpress.do", 

    SINA_DSP_ID                 = "17",
    SINA_DSP_BID_ARG_HASHCODE   = "hashcode",
    SINA_DSP_BID_ARG_COOKIE     = "cookie",
    SINA_DSP_BID_ARG_VERSION    = "version",
    SINA_DSP_CLICK_ARG_P        = "p",
    SINA_DSP_CREATIVE_STATUS    = 1,
    SINA_DSP_CREATIVE_UNIQUE_ID = 1,
    SINA_DSP_ADVERTISER_ID      = "1",
    SINA_DSP_ADVERTISER_STATUS  = 1,
    SINA_DSP_ADVERTISER_UNIQUE_ID = 1,
    SINA_DSP_ADVERTISER_TYPE    = "111",

    DSP_BID_URI                 = "/dsp/bid",
    DSP_CFM_URI                 = "/dsp/cfm",
    
    RTB_VERSION                 = "1.0",
    RTB_EXTRA_PRICE             = 1,
    RTB_MACRO_CLICK_UNESC       = "%%CLICK_URL_UNESC%%",
    RTB_MACRO_CLICK_ESC         = "%%CLICK_URL_ESC%%",
    RTB_CLICK_URL               = "http://sax.sina.com.cn/click",
    RTB_CLICK_ARG_TYPE          = "type",
    RTB_CLICK_ARG_T             = "t",
    RTB_CLICK_ARG_TARGETING     = "targeting",
    RTB_CLICK_ARG_URL           = "url",
    RTB_CLICK_ARG_SIGN          = "sign", 

    RTB_VIEW_URL                  = "http://sax.sina.com.cn/view",
    RTB_VIEW_ARG_TYPE             = "type",
    RTB_VIEW_ARG_T                = "t",

    RTB_MACRO_WIN_PRICE         = "%%WIN_PRICE%%",
    RTB_CM_FLAG                 = "true",
    RTB_CM_URL                  = "http://sax.sina.com.cn/cm",
    RTB_WAP_CM_URL              = "http://sax.sina.cn/cm",
    RTB_CM_ARG_NID              = "sina_nid",
    RTB_PHASE_BID               = "BID",
    RTB_PHASE_CFM               = "CFM",

    AD_RSP_DEFAULT_HEADER       = "_ssp_ad.callback(",
    AD_RSP_TAIL                 = ")",
    AD_INVALID_RSP              = "\"nodata\"",

    CLICK_TYPE_DSP              = "2",
    CLICK_TYPE_SINA             = "3",
    CLICK_TYPE_VIDEO            = "4",
    CLICK_TYPE_WEIBO            = "5",
    CLICK_TYPE_MOBILE           = "6",
    CLICK_TYPE_NETWORK          = "network",
    CLICK_TYPE_SAXMOB           = "saxmob",

    VIEW_TYPE_DSP               = "2",
    VIEW_TYPE_SINA              = "3",
    VIEW_TYPE_VIDEO             = "4",
    VIEW_TYPE_VIDEO_END         = "5",
    VIEW_TYPE_NONSTD            = "nonstd",
    VIEW_TYPE_NETWORK           = "network",
    VIEW_TYPE_SAXMOB            = "saxmob",

    LOG_SEPARATOR_SINA_IMPRESS  = "$SINA_IMPRESS_LOG$",
    LOG_SEPARATOR_SINA_FAIL     = "$SINA_FAIL_LOG$",
    LOG_SEPARATOR_DSP_REQ       = "$DSP_REQ_LOG$",
    LOG_SEPARATOR_DSP_RSP       = "$DSP_RSP_LOG$",
    LOG_SEPARATOR_DSP_CFM       = "$DSP_CFM_LOG$",
    LOG_SEPARATOR_DSP_FOUL      = "$DSP_FOUL_LOG$",
    LOG_SEPARATOR_DSP_FAIL      = "$DSP_FAIL_LOG$",
    LOG_SEPARATOR_DSP_INVALID   = "$DSP_INVALID_LOG$",
    LOG_SEPARATOR_DSP_NULL      = "$DSP_NULL_LOG$",
    LOG_SEPARATOR_DSP_QPS       = "$DSP_QPS_LOG$",
    LOG_SEPARATOR_NETWORK_IMPRESS = "$NETWORK_IMPRESS_LOG$",
    LOG_SEPARATOR_VIDEO_IMPRESS = "$VIDEO_IMPRESS_LOG$",
    LOG_SEPARATOR_WEIBO_IMPRESS = "$WEIBO_IMPRESS_LOG$",
    LOG_SEPARATOR_MOBILE_IMPRESS = "$MOBILE_IMPRESS_LOG$",
    LOG_SEPARATOR_DSP_CLICK     = "$DSP_CLICK_LOG$",
    LOG_SEPARATOR_SINA_CLICK    = "$SINA_CLICK_LOG$",
    LOG_SEPARATOR_VIDEO_CLICK   = "$VIDEO_CLICK_LOG$",
    LOG_SEPARATOR_WEIBO_CLICK   = "$WEIBO_CLICK_LOG$", 
    LOG_SEPARATOR_MOBILE_CLICK   = "$MOBILE_CLICK_LOG$",
    LOG_SEPARATOR_NETWORK_CLICK  = "$NETWORK_CLICK_LOG$",    
    LOG_SEPARATOR_DSP_TARGETING = "$TARGETING_LOG$",
    LOG_SEPARATOR_DSP_ORIGIN    = "$ORIGIN$",
    LOG_SEPARATOR_SAXMOB_CLICK  = "$SAXMOB_DSP_CLICK_LOG$",

    LOG_SEPARATOR_DSP_VIEW        = "$DSP_VIEW_LOG$",
    LOG_SEPARATOR_SINA_VIEW       = "$SINA_VIEW_LOG$",
    LOG_SEPARATOR_VIDEO_VIEW      = "$VIDEO_VIEW_LOG$",
    LOG_SEPARATOR_VIDEO_END_VIEW  = "$VIDEO_END_LOG$",
    LOG_SEPARATOR_NONSTD_VIEW     = "$NONSTD_VIEW_LOG$",  
    LOG_SEPARATOR_BLOG_VIEW       = "$BLOG_VIEW_LOG$",
    LOG_SEPARATOR_NETWORK_VIEW    = "$NETWORK_VIEW_LOG$",
    LOG_SEPARATOR_SAXMOB_VIEW     = "$SAXMOB_DSP_VIEW_LOG$",

    VIDEO_LENGTH_TYPE_SHORT     = "short",
    VIDEO_LENGTH_TYPE_MEDIUM    = "medium",
    VIDEO_LENGTH_TYPE_LONG      = "long",
    VIDEO_LENGTH_THRESH_SHORT   = 45001,
    VIDEO_LENGTH_THRESH_LONG    = 300000,

    WEIBO_AD_ID_PREFIX          = "SAX_",
    WEIBO_CLICK_RSP_OK          = "OK",
    WEIBO_CLICK_RSP_FAIL        = "FAIL",

    BAIDU_NETWORK_ID            = "6",
    ANMO_NETWORK_ID             = "7",
    PC_PUBLISHER                = 1,
    WAP_PUBLISHER               =2,

    THIRD_PARTY_MONITOR_URI     = "/thirdparty/monitor",

    PREFERRED_DEAL_TYPE          = "dsp_pd",
    AUCTION_TYPE_PREFERRED_DEAL  = 501,
    AUCTION_TYPE_PRIVATE_AUCTION = 502,
    AUCTION_TYPE_OPEN_AUCTION    = 503,

    DSP_ID_IPINYOU = "1",
    DSP_ID_ACXIOM = "28",

    -- cookie matching 
    CM_MATCH_TAG_ARG_SINA_NID = "sina_nid",
    CM_REDIRECT_URL_ARG_SINA_SID = "sina_sid",
    CM_REDIRECT_URL_ARG_ACXIOM_SID = "uid",
    CM_REDIRECT_URL_ARG_SINA_ERROR = "sina_error",
    CM_ERROR_CODE_NO_COOKIE = "1", 

    --preview
    SINA_PREVIEW_URL_SINA       = "http://172.16.235.199:9099/mfp/previewdelivery.do",
    SINA_PREVIEW_URL_VIDEO      = "http://172.16.235.199:9099/mfp/previewdelivery.do",
    SINA_PREVIEW_URL_WAP        = "http://172.16.235.199:9099/mfp/previewdelivery.do",

    NONSTD_CLK_SIGN_KEY         = "49fb1e091e4b119fec4557fe8ac08a6f"
};

return const;

