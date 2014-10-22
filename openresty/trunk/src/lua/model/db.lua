local rdsParser     = require "rds.parser"

local function listConcator(list, needQuote)
    if not needQuote then return table.concat(list, ",") end

    local temp = {}
    for _, v in ipairs(list) do
        v = "'" .. v .. "'"
        table.insert(temp, v)
    end

    return table.concat(temp, ",")
end

local function columnListParse(list, isUpdate)
    if isUpdate then
        local setBlock
        for k, v in pairs(list) do
            if type(v) == "string" then v = ngx.quote_sql_str(v) end
            if not setBlock then
                setBlock = k .. "=" .. v
            else
                setBlock = setBlock .. "," .. k .. "=" .. v
            end
        end

        return setBlock
    end

    local keyList = {}
    local valueList = {}
    for k, v in pairs(list) do
        table.insert(keyList, k)

        if type(v) == "string" then v = ngx.quote_sql_str(v) end
        table.insert(valueList, v)
    end

    local key = table.concat(keyList, ",")
    local value = table.concat(valueList, ",")

    return key, value
end

-- parameters:
-- sql : query sent to mysql
-- isDML : true for insert|update|delete
-- failPeace : ture for just return result even if error happened in this function
--
-- return:
-- tuples, status, errInfo
local function queryMySql(sql, isDML, failPeace)
    local errInfo

    -- query mysql
    local rsp = ngx.location.capture("/mysql",
                                     {method = ngx.HTTP_POST, body = sql})
    if (rsp.status ~= ngx.HTTP_OK or not rsp.body) then
        if not failPeace then
            error("failed to query mysql: " .. sql)
        else
            errInfo = "failed to query mysql: " .. sql
            return nil, rsp.status, errInfo
        end
    end

    -- if isDML, tuple parser is not needed
    if isDML then return nil, rsp.status, errInfo end

    -- parser rds
    local res, err = rdsParser.parse(rsp.body)
    if not res then
        if not failPeace then
            error("failed to parse rds: " .. err)
        else
            errInfo = "failed to parse rds: " .. err
            return nil, ngx.HTTP_INTERNAL_SERVER_ERROR, errInfo
        end
    end

    return res.resultset, rsp.status, errInfo
end

-- selet all dsp info
-- return: {{dsp1}, {dsp2}, ...}
local function selectDspInfoAll()
    local sql = [[
    select id, redirecturl, bidurl, notifyurl, priority, qps, encryptionkey, integritykey, status, signkey
    from dsp
    ]]

    local rows = queryMySql(sql)
    return rows
end

-- select one dsp info with specified id
-- return: {dsp} = {id=, redirecturl=, ...} or nil
local function selectDspInfo(id)
    local sql = [[
    select id, redirecturl, bidurl, notifyurl, priority, qps, encryptionkey, integritykey, status, signkey
    from dsp
    where id =
    ]] .. id

    local rows = queryMySql(sql)
    if rows == nil or #rows ~= 1 then return nil end

    return rows[1]
end

-- select one or more dsp info with id list
-- return {id1 = {dsp1}, id2 = {dsp2}, ...}
local function selectDspInfoList(idList)
    local ids = listConcator(idList)

    local sql = [[
        select id, redirecturl, bidurl, notifyurl, priority, qps, encryptionkey, integritykey, status, signkey
        from dsp
        where id in
    ]] .. " (" .. ids .. ")"

    local rows = queryMySql(sql)

    return rows
end

-- selet all adunit info
-- return :
-- {{adunit1}, {adunit2}, ...}
local function selectAdunitInfoAll()
    local sql = [[
        select id, wdht, location, adnum, publisher, status, adtype, displaytype, rotatenum, gina, nad, networkinfo,channel
        from adunit
    ]]
    local rows = queryMySql(sql)
    
    return rows
end

-- select one adunit info with specified id
-- return:
-- {adunit} = {id=, wdht=, location=, ...} or nil
local function selectAdunitInfo(id)
    local sql = [[
        select id, wdht, location, adnum, publisher, status, adtype, displaytype, rotatenum, gina, nad, networkinfo, channel
        from adunit
        where id =
    ]] .. " '" .. id .. "'"
    local rows = queryMySql(sql)

    if rows == nil or #rows ~= 1 then return nil end

    return rows[1]
end

-- select one or more adunit info with id list
-- return:
-- {{adunit1}, {adunit2}, ...}
local function selectAdunitInfoList(idList)
    local ids = listConcator(idList, true)

    local sql = [[
        select id, wdht, location, adnum, publisher, status, adtype, displaytype, rotatenum, gina, nad, networkinfo, channel
        from adunit
        where id in
    ]] .. " (" .. ids .. ")"
    local rows = queryMySql(sql)

    return rows
end

-- NOTE: no publisher table now, we treat it as extend of resource
-- return:
-- {{publisher1}, {publisher2}, ...}
local function selectPublisherInfoAll()
    -- select basic info
    local sql = "select id, id as resource, dspprice, blackadtype, blackterm, blackclickurl, status from resource"
    local rows = queryMySql(sql)

    return rows
end

-- return:
-- {id = "", resource = "", status = "",.blackadtype = {}, blackterm = {}, blackclickurl = {}}
-- or nil
local function selectPublisherInfo(id)
    -- select basic info
    local sql = [[
        select id, id as resource, dspprice, blackadtype, blackterm, blackclickurl, status
        from resource
        where id =
    ]] .. id
    local rows = queryMySql(sql)

    if rows == nil or #rows ~= 1 then return nil end

    return rows[1]
end

-- return:
-- {{publisher1}, {publisher2}, ...}
local function selectPublisherInfoList(idList)
    local ids = listConcator(idList)

    local sql = [[
        select id, id as resource, dspprice, blackadtype, blackterm, blackclickurl, status
        from resource
        where id in
    ]] .. " (" .. ids .. ")"
    local rows = queryMySql(sql)

    return rows
end

-- return:
-- {{resource1}, {resource2}, ...}
local function selectResourceInfoAll()
    -- select basic info
    local sql = "select id, flag, dspwhitelist, status, pdwhitelist from resource"
    local rows = queryMySql(sql)

    return rows
end

-- return:
-- {id = ", flag = "", status = "", dsp = {}}
-- or nil
local function selectResourceInfo(id)
    -- select basic info
    local sql = [[
        select id, flag, dspwhitelist, status, pdwhitelist
        from resource
        where id =
    ]]  .. id
    local rows = queryMySql(sql)

    if rows == nil or #rows ~= 1 then return nil end

    return rows[1]
end

-- retrun:
-- {{resource1}, {resource2}, ...}
local function selectResourceInfoList(idList)
    local ids = listConcator(idList)

    -- select basic info
    local sql = [[
        select id, flag, dspwhitelist, status, pdwhitelist
        from resource
        where id in
    ]] .. " (" .. ids ..")"
    local rows = queryMySql(sql)

    return rows
end

-- return:
-- {{creative1}, {creative2}, ...}
local function selectCreativeInfoAll()
    local sql = "select id, dspid, dspideaid, advertiserid, status from creative"
    local rows = queryMySql(sql)

    -- when creative loaded into memory, use combination of dspid and dspideaid as object id
    for _, row in ipairs(rows) do
        row.uniqueid = row.id
        row.id = row.dspid .. row.dspideaid
    end

    return rows
end

-- return:
-- {id = "", dspid =, dspideaid =, advertiserid =, status = ""}
local function selectCreativeInfo(id)
    local sql = "select id, dspid, dspideaid, advertiserid, status from creative where id = " .. id
    local rows = queryMySql(sql)

    if rows == nil or #rows ~= 1 then return nil end
    local row = rows[1]
    row.uniqueid = row.id
    row.id = row.dspid .. row.dspideaid

    return row
end

-- return:
-- {id1= {creative1}, id2 = {creative2}, ...} or nil
local function selectCreativeInfoList(idList)
    local ids = listConcator(idList)

    local sql = "select id, dspid, dspideaid, advertiserid, status from creative where id in (" .. ids .. ")"
    local rows = queryMySql(sql)

    for _, row in ipairs(rows) do
        row.uniqueid = row.id
        row.id = row.dspid .. row.dspideaid
    end

    return rows
end

-- return:
-- {{adertiser1}, {adertiser2}, ...}
local function selectAdvertiserInfoAll()
    local sql = "select id, dspid, advertiserid, status, type from advertiser"
    local rows = queryMySql(sql)

    -- when advertiser loaded into memory, use combination of dspid and advertiserid as object id
    for _, row in ipairs(rows) do
        row.uniqueid = row.id
        row.id = row.dspid .. row.advertiserid
    end

    return rows
end

-- return:
-- {id = "", dspid =, advertiserid =, status = ""}
local function selectAdvertiserInfo(id)
    local sql = "select id, dspid, advertiserid, status, type from advertiser where id = " .. id
    local rows = queryMySql(sql)

    if rows == nil or #rows ~= 1 then return nil end
    local row = rows[1]
    row.uniqueid = row.id
    row.id = row.dspid .. row.advertiserid

    return row
end

-- return:
-- {id1= {creative1}, id2 = {creative2}, ...} or nil
local function selectAdvertiserInfoList(idList)
    local ids = listConcator(idList)

    local sql = "select id, dspid, advertiserid, status, type from advertiser where id in (" .. ids .. ")"
    local rows = queryMySql(sql)
    
    for _, row in ipairs(rows) do
        row.uniqueid = row.id
        row.id = row.dspid .. row.advertiserid
    end

    return rows
end

local function selectNetworkInfo(id) 
    local sql = "select id, name, url ,status from network where id =" .. id
    local rows = queryMySql(sql)
    if rows == nil or #rows ~= 1 then  return nil end
    return rows[1]
end

local function selectNetworkInfoList(idList)
    local ids = listConcator(idList)

    local sql = "select id, name, url, status from network where id in (" .. ids .. ")"
    local rows = queryMySql(sql)
    return rows
end

local function selectNetworkInfoAll()
    local sql = "select id, name, url, status from network"
    local rows = queryMySql(sql)
    return rows
end

local function insertInfo(tableName, columnList)
    local columns, values = columnListParse(columnList, false)

    local sql = "insert into " .. tableName .. "(" .. columns .. ") " ..
                "values("  .. values .. ")"

    local _, status, errInfo = queryMySql(sql, true, true)
    if status ~= ngx.HTTP_OK then
        -- TODO
    end

    return status, errInfo
end

local function updateInfo(tableName, id, columnList)
    local setBlock = columnListParse(columnList, true)
    if type(id) == "string" then id = ngx.quote_sql_str(id) end

    local sql = "update " .. tableName ..
                " set " .. setBlock ..
                " where id = " .. id

    local _, status, errInfo = queryMySql(sql, true, true)
    if status ~= ngx.HTTP_OK then
        -- TODO
    end

    return status, errInfo
end

local function deleteInfo(tableName, id)
    if type(id) == "string" then id = ngx.quote_sql_str(id) end
    local sql = "delete from " .. tableName .. " where id = " .. id

    local _, status, errInfo = queryMySql(sql, true, true)
    if status ~= ngx.HTTP_OK then
        -- TODO
    end

    return status, errInfo
end

local function checkExist(tableName, id)
    if type(id) == "string" then id = ngx.quote_sql_str(id) end
    local sql = "select count(*) as num from " .. tableName .. " where id = " .. id

    local rows, status, errInfo = queryMySql(sql, false, true)
    if status ~= ngx.HTTP_OK then return nil, status, errInfo end

    if rows == nil or rows[1].num == 0 then return false, ngx.HTTP_OK end

    return true, ngx.HTTP_OK
end

local function selectSaxInfoAll()
    local sql = "select ip, port from server where type = 's' order by ip, port"
    local rows = queryMySql(sql)
    return rows
end

local function selectCenterInfoAll()
    local sql = "select ip ,type  from server where type = 'c' order by ip"
    local rows = queryMySql(sql)
    return rows
end

local db = {
    selectDspInfoAll            = selectDspInfoAll,
    selectDspInfo               = selectDspInfo,
    selectDspInfoList           = selectDspInfoList,

    selectAdunitInfoAll         = selectAdunitInfoAll,
    selectAdunitInfo            = selectAdunitInfo,
    selectAdunitInfoList        = selectAdunitInfoList,

    selectPublisherInfoAll      = selectPublisherInfoAll,
    selectPublisherInfo         = selectPublisherInfo,
    selectPublisherInfoList     = selectPublisherInfoList,

    selectResourceInfoAll       = selectResourceInfoAll,
    selectResourceInfo          = selectResourceInfo,
    selectResourceInfoList      = selectResourceInfoList,

    selectCreativeInfoAll       = selectCreativeInfoAll,
    selectCreativeInfo          = selectCreativeInfo,
    selectCreativeInfoList      = selectCreativeInfoList,

    selectAdvertiserInfoAll     = selectAdvertiserInfoAll,
    selectAdvertiserInfo        = selectAdvertiserInfo,
    selectAdvertiserInfoList    = selectAdvertiserInfoList,

    selectNetworkInfoAll        = selectNetworkInfoAll,
    selectNetworkInfo           = selectNetworkInfo,
    selectNetworkInfoList       = selectNetworkInfoList,
    insertInfo                  = insertInfo,
    updateInfo                  = updateInfo,
    deleteInfo                  = deleteInfo,

    checkExist                  = checkExist,

    selectSaxInfoAll            = selectSaxInfoAll,
    selectCenterInfoAll         = selectCenterInfoAll
}

return db
