local const = {
    -- constant for rtb
    SAX_SSP_PROTOCOL_VERSION    = "1.0.1",
    SAX_DSP_PROTOCOL_VERSION    = "1.0.1",
    SAX_PRICE_IKEY              = "879dec2500f547feed8c66c73998eba6",
    SAX_PRICE_EKEY              = "e9dac16fe120ab7a09eb4ae86ac32235",

    DMP_USER_AGE                = "age",
    DMP_USER_GENDER             = "gender",
    DMP_USER_INTEREST           = "interest",
    DMP_USER_ZONE               = "zone",
    DMP_USER_DEGREE             = "degree",
    USER_ID                     = "id",

    LOG_SEPARATOR_DSP_REQ       = "$SAXMOB_DSP_REQ_LOG$",
    LOG_SEPARATOR_DSP_RSP       = "$SAXMOB_DSP_RSP_LOG$",
    LOG_SEPARATOR_DSP_FOUL      = "$SAXMOB_DSP_RSP_FOUL$",
    LOG_SEPARATOR_DSP_NULL      = "$SAXMOB_DSP_NULL_LOG$",
    LOG_SEPARATOR_DSP_INVALID   = "$SAXMOB_DSP_INVALID_LOG$",
    LOG_SEPARATOR_DSP_FAIL      = "$SAXMOB_DSP_FAIL_LOG$",
    LOG_SEPARATOR_SSP_REQ       = "$SAXMOB_SSP_REQ_LOG$",
    LOG_SEPARATOR_SSP_RSP       = "$SAXMOB_SSP_RSP_LOG$",
    LOG_SEPARATOR_DSP_QPS       = "$SAXMOB_DSP_QPS_LOG$",
    LOG_SEPARATOR_DSP_WIN       = "$SAXMOB_DSP_WIN_LOG$",

    RTB_MACRO_WIN_PRICE         = "%%WIN_PRICE%%",
    RTB_KEEPALIVE_TIME          = 60,
    RTB_CONNECTION_SIZE         = 100,
    RTB_EXTRA_PRICE             = 1,

    CLICK_TYPE_DSP              = "saxmob",
    RTB_CLICK_URL               = "http://sax.sina.com.cn/click",
    VIEW_TYPE_DSP               = "saxmob",
    RTB_VIEW_URL                = "http://sax.sina.com.cn/view",

    ARG_MONITOR_TYPE            = "type",
    ARG_CLICK_URL               = "url",
    ARG_MONITOR_T               = "t",
    ARG_WIN_PRICE               = "p",
    MONITOR_TYPE_CLICK          = "click",
    MONITOR_TYPE_VIEW           = "view",

    DSP_ALL_SD                  = "dspall",

    RTB_OPEN_AUCTION            = 502,
    RTB_NO_TEST                 = 0,
    RTB_IS_TEST                 = 1,
    RTB_CARRIER_UNICOM          = "unicom",
    RTB_CARRIER_TELECOM         = "telecom",
    RTB_CARRIER_CMCC            = "cmcc", 
    SINA_DSP_CLICK_ARG_P        = "p",
    SINA_DSP_ID                 = "1",  
    HASH_STR                    = "Hash-Str",
    RTB_REQ_ARG_COOKIE          = "cookie",
    RTB_REQ_ARG_SSP_ID          = "ssp_id",   
    -- constant for bdm
    SAX_UPDATE_OBJECT_URI       = "/business/update",
    SAX_UPDATE_QPS_URI          = "/qps/alloc",
    SAX_DELETE_OBJECT_OPERATE   = "delete",
    SAX_UPDATE_OBJECT_OPERATE   = "update",
    GET_DSP_QPS_TOTAL           = "gettoal",
    SET_DSP_QPS_LIMIT           = "setlimit",
    
    WORK_ARG_NAME               = "name",
    WORK_ARG_OPERATE            = "operate",
    
    DSP_QPS_LIMIT_PREFIX        = "dsp:qps:limit:",
    DSP_QPS_COUNT_PREFIX        = "dsp:qps:count:",
    DSP_QPS_TOTAL_PREFIX        = "dsp:qps:total:",
    DSP_QPS_FACTOR              = 1,

    OBJECT_ADUNIT               = "adunit",
    OBJECT_DSP                  = "dsp",
    OBJECT_SSP                  = "ssp",
    OBJECT_STATUS_VALID         = 1,
    OBJECT_STATUS_INVALID       = 0,

    SAX_ARG_DSPIDS              = "dspids",
    SAX_ARG_REQ_TYPE            = "type",
    SAX_ARG_QPS_LIMIT           = "qpslimit",
    -- constant for tdm
    SAXMOB_UPDATE_TD_URI        = "/targeting/flush"
};

return const;

