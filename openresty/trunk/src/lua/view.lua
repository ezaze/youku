local util = require "util"
local const = require "const"
local parser = require "parser"

local function logT(logSeparator, t)
    ngx.log(ngx.INFO, logSeparator,
                      t,
                      logSeparator)
end

local function handleDspView()
    local t = util.decodeLogStr(parser.getViewT());
    logT(const.LOG_SEPARATOR_DSP_VIEW, t);
end

local function handleBlogView(t,articleId, userId)
    articleId = (articleId ~= "") and articleId or "-"
    userId = (userId ~= "") and userId or "-"
    local t_args = util.split(t,"\t")
    local timestamp = t_args[1];
    local t_uuid = t_args[6]
    local blog_t = timestamp .. "\t" .. t_uuid .. "\t" .. userId  .. "\t" .. articleId 
    logT(const.LOG_SEPARATOR_BLOG_VIEW, blog_t)
end

local function handleSinaView()
    local t = util.decodeLogStr(parser.getViewT());
    local articleId = parser.getBlogArticleId()
    local userId = parser.getBlogUserId()

    logT(const.LOG_SEPARATOR_SINA_VIEW, t);
    if articleId ~= "" or userId ~= "" then
        handleBlogView(t, articleId, userId )
    end 
end

local function handleVideoView()
    local t = util.decodeLogStr(parser.getViewT());
    logT(const.LOG_SEPARATOR_VIDEO_VIEW, t);
end

local function handleVideoEndView()
    local t = util.decodeLogStr(parser.getViewT());
    logT(const.LOG_SEPARATOR_VIDEO_END_VIEW, t);
end

local function handleNonStdView()
    local t = util.decodeLogStr(parser.getViewT());
    local cookie = parser.getCookie()
    if cookie == "" then cookie = "-" end
    logT(const.LOG_SEPARATOR_NONSTD_VIEW, t .. "\t" .. cookie)
end

local function handleNetworkView()
    local t = util.decodeLogStr(parser.getViewT())
    logT(const.LOG_SEPARATOR_NETWORK_VIEW, t)
end

local function handleSaxmobView()
    local t =  util.decodeLogStr(parser.getViewT())
    logT(const.LOG_SEPARATOR_SAXMOB_VIEW, t)
end

local function view()
    local viewType = parser.getViewType();
    if viewType == const.VIEW_TYPE_DSP then
        handleDspView();
    elseif viewType == const.VIEW_TYPE_SINA then
        handleSinaView();
    elseif viewType == const.VIEW_TYPE_VIDEO then
        handleVideoView();
    elseif viewType == const.VIEW_TYPE_VIDEO_END then
        handleVideoEndView();
    elseif viewType == const.VIEW_TYPE_NONSTD then
        handleNonStdView();
    elseif viewType == const.VIEW_TYPE_NETWORK then
        handleNetworkView();
    elseif viewType == const.VIEW_TYPE_SAXMOB then
        handleSaxmobView() 
    else
        ngx.log(ngx.ERR, "view type not support type=" .. viewType);
    end

    if viewType ~= const.VIEW_TYPE_SAXMOB then
        ngx.redirect("http://d00.sina.com.cn/a.gif");
    end    
end

local view = {
    view = view
};
return view;
