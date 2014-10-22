--[[
-- center controller
--]]
local util          = require "util"
local db            = require "db"
local cjson         = require "cjson"
local sax           = require "sax"
local parser        = require "parser"
local const         = require "const"

-- parse content
-- return: status, errInfo
local function contentParse(objectName, contentList, isDelete)
    for _, content in ipairs(contentList) do
        local isValid, errInfo = sax.objectNameValidityCheck(objectName)
        if not isValid then return ngx.HTTP_BAD_REQUEST, errInfo end

        local id = content.id
        if not id then return ngx.HTTP_BAD_REQUEST, "id of object missing" end

        local isExist, status, errInfo = db.checkExist(objectName, id)
        if status ~= ngx.HTTP_OK then
            errInfo = "Failed to check info of object(id = " .. id .. ") in db, details: " .. errInfo 
            return status, errInfo
        end

        if not isDelete then
            isValid, errInfo = sax.objectValidityCheck(objectName, content, isExist)
            if not isValid then
                return ngx.HTTP_BAD_REQUEST, "object(id = " .. id .. ") info is invalid, details: " .. errInfo
            end
        end

        -- save flag
        content._isExist = isExist
    end

    if isDelete then
        for _, content in ipairs(contentList) do
            if not content._isExist then return ngx.HTTP_BAD_REQUEST, "object(id = " .. content.id .. ") not exists" end
        end
    end

    return ngx.HTTP_OK
end

local function updateInfoDB(objectName, contentList)
    local status, errInfo = ngx.HTTP_INTERNAL_SERVER_ERROR, nil
    for _, content in ipairs(contentList) do
        local id = content.id
        local isUpdate = content._isExist

        -- clear flag
        content._isExist = nil
        if isUpdate then
            -- do not update vaule of id
            content.id = nil
            status, errInfo = db.updateInfo(objectName, id, content)
            content.id = id
        else
            status, errInfo = db.insertInfo(objectName, content)
        end

        if status ~= ngx.HTTP_OK then
            local str = cjson.encode(content)
            local err = "Error happend when "
            if isUpdate then
                err = err .. "update values : "
            else
                err = err .. "insert values : "
            end
            errInfo = err .. objectName .. " : " .. str .. "." .."  Details : " .. errInfo

            return status, errInfo
        end

        -- use db id to update info in shared dict
        content._saxObjectId = id
    end

    return ngx.HTTP_OK
end

local function deleteInfoDB(objectName, contentList)
    local status, errInfo =  ngx.HTTP_INTERNAL_SERVER_ERROR, nil
    for _, content in ipairs(contentList) do
        local id = content.id

        -- use object id to delete info in shared dict
        content._saxObjectId = sax.getObjectId(objectName, id)

        status, errInfo = db.deleteInfo(objectName, id)
        if status ~= ngx.HTTP_OK then
            errInfo = "Error happened when delete tuple of " .. objectName .. "(id = " .. id  .. ")" ..
                        ". Details: " .. errInfo
            return status, errInfo
        end
     end

     return ngx.HTTP_OK
end

local function notifySax(objectName, contentList, isDelete)
    local idList = {}
    local requestList = {}

    for _, content in ipairs(contentList) do
        table.insert(idList, content._saxObjectId)
    end
    local ids = table.concat(idList, ",")

    -- get all sax info
    local saxList = sax.getSaxAll()
    if #saxList == 0 then
        ngx.log(ngx.WARN, "No sax info in db")
        return ngx.HTTP_OK
    end

    -- construct request
    for _, _sax in ipairs(saxList) do
        local option = {}
        option.method = ngx.HTTP_POST
        option.args = {}
        local saxUrl = sax.getUpdateObjectUrl(_sax) .. "?" .. "name=" .. objectName
      
        if isDelete then saxUrl = saxUrl .. "&operate=" .. const.SAX_DELETE_OBJECT_OPERATE end
        option.args["saxurl"] = saxUrl

        -- id string may be very long..........
        option.body = "id=" .. ids

        table.insert(requestList, {const.CENTER_NOTIFY_SAX_URI, option})
    end

    -- notify all sax
    local responseList = {ngx.location.capture_multi(requestList)}

    -- status check
    local status = ngx.HTTP_OK
    local failedSaxList = {}
    for i, res in ipairs(responseList) do
        if res.status ~= ngx.HTTP_OK then
            status = ngx.HTTP_INTERNAL_SERVER_ERROR
            table.insert(failedSaxList, sax.getUpdateObjectUrl(saxList[i]))
        end
    end

    if status ~= ngx.HTTP_OK then
        local str = table.concat(failedSaxList, ",")
        local errInfo = "Failed to notify sax worker (" .. str .. ") to update " .. objectName .. " info"
        ngx.log(ngx.ERR, errInfo)

        -- send alarm info
        local subject = "Failed to update sax object info"
        pcall(util.alarm, subject, errInfo)
    end

    return status
end

-- return:
-- errInfo, objectName, contentList, isDelete
-- if errInfo is not nil, means this request is invalid request
local function argsParse()
    local info = parser.getCenterUpdateInfo()
    if info == "" then return "Request arg(info) missing" end

    local status, info = pcall(cjson.decode, info)
    if not status then return "request info is an invalid json format string" end
    if type(info) ~= "table" then return "arg(info) should be table format" end

    local objectName = info.name 
    if not objectName or type(objectName) ~= "string" then
        return "Object name missing or invalid format"
    end

    local isDelete = (info.operate == const.SAX_DELETE_OBJECT_OPERATE)

    local contentList= info.content
    if not contentList then return "request content missing" end
    if type(contentList) ~= "table" then return "request content should be table format" end
    if #contentList == 0 then return "request content is empty list" end

    return nil, objectName, contentList, isDelete
end

local function log(objectName, contentList, isDelete)
    local idList = {}
    for _, content in ipairs(contentList) do
        table.insert(idList, content.id)
    end
    local idStr = table.concat(idList, ",")

    local logInfo = "Success to "
    if not isDelete then 
        logInfo = logInfo .. "update "
    else
        logInfo = logInfo .. "delete "
    end

    logInfo = logInfo .. objectName .. " info in database. ID = (" .. idStr .. ")"
    ngx.log(ngx.INFO, logInfo)
end

local function updateObjectInfo()
    local result = {code = "OK"}

    local errInfo, objectName, contentList, isDelete = argsParse()
    if errInfo then
        result.code = "FAIL"
        result.info = errInfo
        ngx.print(cjson.encode(result))

        return ngx.exit(ngx.HTTP_OK)
    end

    -- request info validity check
    local status, errInfo = contentParse(objectName, contentList, isDelete)
    if status ~= ngx.HTTP_OK then
        result.code = "FAIL"
        result.info = errInfo
        ngx.print(cjson.encode(result))

        return ngx.exit(ngx.HTTP_OK)
    end

    -- update object info in db
    if not isDelete then
        status, errInfo = updateInfoDB(objectName, contentList)
    else
        status, errInfo = deleteInfoDB(objectName, contentList)
    end
    if status ~= ngx.HTTP_OK then
        result.code = "FAIL"
        result.info = errInfo
        ngx.print(cjson.encode(result))

        return ngx.exit(ngx.HTTP_OK)
    end

    log(objectName, contentList, isDelete)

    ngx.print(cjson.encode(result))
    ngx.eof()

    -- notity all sax to update object info in shared dict
    -- if failed to notify some or all sax, just record log
    notifySax(objectName, contentList, isDelete)

    return ngx.exit(ngx.HTTP_OK)
end

-- get dsp qps info from db
local function getDspQpsInfoDB()
    local dsp = sax.newObject(const.OBJECT_DSP)
    local rows = dsp:getInfoAllDB()

    local dspList = {}
    for _, row in ipairs(rows) do
        if row.status == 1 and row.qps > 0 then
            table.insert(dspList, {id = row.id, qps = row.qps, total = {}, limit = {}})
        end
    end

    return dspList 
end

-- get sax server address 
local function getSaxServerAddr()
    local saxList = sax.getSaxAll()
    
    local ipList = {}
    for _, _sax in ipairs(saxList) do
        table.insert(ipList, _sax.ip)
    end
    ngx.log(ngx.INFO, "sax:" .. table.concat(ipList, ","))

    return saxList
end

-- get qps total form sax
local function getQpsTotalFromSax(dspList, saxList)
    local dspIdList = {}
    for _, dsp in pairs(dspList) do
        table.insert(dspIdList, dsp.id)
    end
    local dspIdStr = table.concat(dspIdList, ",")

    local reqList = {}
    for _, _sax in ipairs(saxList) do
        local option = {}
        option.method = ngx.HTTP_GET
        option.args = {}
        option.args["saxurl"] = sax.getUpdateQpsUrl(_sax) .. "?"
                                .. "type=" .. const.GET_DSP_QPS_TOTAL .. "&"
                                .. "dspids=" .. dspIdStr

        table.insert(reqList, {const.CENTER_RESET_QPS_URI, option})
    end

    local rspList = {ngx.location.capture_multi(reqList)}

    local flag = false
    local ipList = {}
    for i, rsp in ipairs(rspList) do
        if rsp.status ~= ngx.HTTP_OK then
            table.insert(ipList, saxList[i].ip)

            for j, dsp in ipairs(dspList) do
                table.insert(dsp.total, 0)
            end
        else
            local qpsTotalList = util.split(rsp.body)

            for j, dsp in ipairs(dspList) do
                table.insert(dsp.total, tonumber(qpsTotalList[j]) or 0)
            end
        end
    end

    if flag then
        local log = table.concat(ipList, ",")
        ngx.log(ngx.ERR, "failed to get qps total from sax worker: " .. log)
        pcall(util.alarm, "failed to get qps total from sax worker", log)
    end
end

-- reallocate qps limit
local function reallocQpsLimit(dspList)
    for _, dsp in ipairs(dspList) do
        local total = 0
        for _, v in ipairs(dsp.total) do
            total = total + v
        end

        local used = 0
        if total == 0 then
            local limit = math.floor(dsp.qps / #dsp.total)

            for _, v in ipairs(dsp.total) do
                table.insert(dsp.limit, limit)
                used = used + limit
            end
        else
            local quota = math.floor(dsp.qps * 0.9)
            local avg = math.floor(dsp.qps * 0.1 / #dsp.total)

            for _, v in ipairs(dsp.total) do
                local limit =  math.floor(quota * (v / total)) + avg
                table.insert(dsp.limit, limit)
                used = used + limit
            end
        end
        
        local i = math.random(1, #dsp.total)
        dsp.limit[i] = dsp.limit[i] + (dsp.qps - used)

        ngx.log(ngx.INFO, "dsp:" .. dsp.id
                          .. ", qps:" .. dsp.qps
                          .. ", total:" .. table.concat(dsp.total, ",")
                          .. ", limit:" .. table.concat(dsp.limit, ","))
    end
end

-- set qps limit to sax 
local function setQpsLimitToSax(dspList, saxList)
    local dspIdList = {}
    for _, dsp in ipairs(dspList) do
        table.insert(dspIdList, dsp.id)
    end
    local dspIdStr = table.concat(dspIdList, ",")

    local reqList = {}
    for i, _sax in ipairs(saxList) do
        local qpsLimitList = {}
        for _, dsp in ipairs(dspList) do
            table.insert(qpsLimitList, dsp.limit[i])
        end

        local option = {}
        option.method = ngx.HTTP_GET
        option.args = {}
        option.args["saxurl"] = sax.getUpdateQpsUrl(_sax) .. "?"
                                .. "type=" .. const.SET_DSP_QPS_LIMIT .. "&"
                                .. "dspids=" .. dspIdStr .. "&"
                                .. "qpslimit=" .. table.concat(qpsLimitList, ",") 
        
        table.insert(reqList, {const.CENTER_RESET_QPS_URI, option})
    end

    local rspList = {ngx.location.capture_multi(reqList)}

    local flag = false
    local ipList = {}
    for i, rsp in ipairs(rspList) do
        if rsp.status ~= ngx.HTTP_OK then
            flag = true
            table.insert(ipList, saxList[i].ip)
        end
    end

    if flag then
        local log = table.concat(ipList, ",")
        ngx.log(ngx.ERR, "faild to set qps limit to sax worker: " .. log)
        pcall(util.alarm, "failed to set qps limit to sax worker", log)
    end
end

local function updateQpsInfo()
    ngx.log(ngx.INFO, "----- update qps info begin -----")

    -- get dsp qps info from db 
    local dspList = getDspQpsInfoDB()

    -- get sax server address
    local saxList = getSaxServerAddr()

    if #dspList ~= 0 and #saxList ~= 0 then
        -- get qps total from sax
        getQpsTotalFromSax(dspList, saxList)

        -- reallocate qps limit
        reallocQpsLimit(dspList)

        -- set qps limit to sax
        setQpsLimitToSax(dspList, saxList)
    end

    ngx.log(ngx.INFO, "----- update qps info end -----")
end

local center = {
    updateObjectInfo = updateObjectInfo,
    updateQpsInfo    = updateQpsInfo
}

return center

