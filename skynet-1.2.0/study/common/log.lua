--local logger = require("log")
require("common/stringEx")
local command = {}

local LogLevel = {
    all = 1,
    debug = 2,
    trace = 3,
    error = 4,
    fatal = 5,
    none = 6,
}

local LogLevelName = {
    "all",
    "debug",
    "trace",
    "error",
    "fatal",
    "none",
}

local LogModel = {
    screen = 0x01,
    file = 0x02
}

local LogModelValue = LogModel.screen | LogModel.file

function command.screenModel()
    return LogModel.screen
end

function command.fileModel()
    return LogModel.file
end

function command.setModel(model)
    LogModelValue = model
end

local LogLeveValue = LogLevel.debug
local OfficeNo = ""
local StackLevel = 0
local DefaultStackLevel = 3

function command.setOfficeNo(officeNo)
    OfficeNo = officeNo
end

function command.setLevel(level)
    LogLeveValue = level
end

function command.addStackLevel(data)
    if not data then
        data = 1
    end
    StackLevel = StackLevel + data
end

function command.initStackLevel()
    StackLevel = 0
end

function command.allLevel()
    return LogLevel.all
end

function command.debugLevel()
    return LogLevel.debug
end

function command.traceLevel()
    return LogLevel.trace
end

function command.errorLevel()
    return LogLevel.error
end

function command.fatalLevel()
    return LogLevel.fatal
end

function command.noneLevel()
    return LogLevel.none
end

function command.printInfo()
    local info = debug.getinfo(DefaultStackLevel + StackLevel)
    return command.parsePrintInfo(info)
end

function command.parsePrintInfo(info)
    info = info and info or {}
    local path = info.source and info.source or ""
    path = string.sub(path, 2, -1) -- 去掉开头的"@"
    local fileName = string.match(path, "^.*/(.*)$") -- 捕获最后一个 "/" 之前的部分 就是我们最终要的目录部分
    fileName = fileName and fileName or ""
    local line = info.currentline and info.currentline or ""
    local funcName = info.name and info.name or (info.what and info.what or "")
    return fileName, line, funcName
end

function command.getArgvData(...)
    local data = ""
    local dataTable = {...}
    for _,v in ipairs(dataTable) do
        if type(v) == "table" then
            data = data ..tostring(v) .. "  "
        elseif type(v) == "boolean" then
            if v then
                data = data .. "true" .."  "
            else
                data = data .. "false" .."  "
            end
        else
            data = data .. v .."  "
        end
    end
    return data
end

function command.doPrint(fileName, line, funcName, level, space, desc, ...)
    local data = command.format(desc, ...)
    if (LogModelValue & LogModel.screen) > 0 then
        local levelName = LogLevelName[level]
        local date = os.date("%Y-%m-%d %H:%M:%S");
        print(date .. " |" .. string.format("%-25s", fileName .. ":" .. line) .. " |" .. string.format("%-15s", funcName) .. " |" .. string.format("%-5s", levelName) .. " | "  .. string.format("%-15s", OfficeNo) .. " | " .. space .. data)
    end
--[[
    if (LogModelValue & LogModel.file) > 0 then
        logger.setStackLevel(StackLevel + 2)
        logger.Debug(string.format("%-15s", OfficeNo) .. " | " .. space .. data)
        if level == command.errorLevel() then
            logger.Error(string.format("%-15s", OfficeNo) .. " | " .. space .. data)
        end
        if level == command.fatalLevel() then
            logger.Fatal(string.format("%-15s", OfficeNo) .. " | " .. space .. data)
        end
        logger.setStackLevel(-(StackLevel + 2))
    end
    ]]
end

function command.print(level, desc, ...)
    if LogLeveValue <= level then
        local fileName, line, funcName = command.printInfo()
        command.doPrint(fileName, line, funcName, level, "", desc, ...)
    end
    command.initStackLevel()
end

function command.printData(level, desc, ...)
    command.addStackLevel(2)
    command.print(level, desc, ...)
end

function command.all(desc, ...)
    command.printData(LogLevel.all, desc, ...)
end

function command.debug(desc, ...)
    command.printData(LogLevel.debug, desc, ...)
end

function command.trace(desc, ...)
    command.printData(LogLevel.trace,desc, ...)
end

function command.error(desc, ...)
    command.printData(LogLevel.error,desc, ...)
end

function command.fatal(desc, ...)
    command.printData(LogLevel.fatal,desc, ...)
end


function command.split(desc)
    return string.split(desc, ",")
end

function command.format(desc, ...)
    if not desc then
        return ""
    end

    if type(desc) ~= "string" then
        desc = tostring(desc)
    end

    local rValueTable = {...}
    if not string.find(desc, ", ") and #rValueTable == 0 then
        return desc
    end
    local data = ""
    local rDecTable = command.split(desc)
    local rDelimiter = " "
    for i, rK in ipairs(rDecTable) do
        if i == #rDecTable then
            rDelimiter = ""
        end

        local k = string.trim(rK)
        local v = rValueTable[i]
        if type(v) == "table" then
            data = data .. k .. " = " .. tostring(v) .. rDelimiter
        elseif type(v) == "boolean" then
            if v then
                data = data .. k .. " = " .. "true" .. rDelimiter
            else
                data = data .. k .. " = " .. "false" .. rDelimiter
            end
        elseif not v then
            data = data .. k .. " = " .. "nil" .. rDelimiter
        else
            data = data .. k .. " = " .. v .. rDelimiter
        end
    end

    return data
end


function command.doTableToList(tableName, tableData, func, filterFunc)
    local space = command.getSpace()
    local keyTable = {}
    for key, _ in pairs(tableData) do
        table.insert(keyTable, key)
    end
    table.sort(keyTable, function(a,b)
        return a < b
    end)

    for _, key in pairs(keyTable) do
        local value = tableData[key]
        if type(value) ~= "table" then
            local isPrint = true
            --[[
            local rKey = key
            if type(rKey) == "number" then
                rKey = ""
            end

            if filterFunc then
                isPrint = filterFunc(tableName .. rKey)
            end
            ]]
            if isPrint then
                if value then
                    if value == true then
                        command.insertData(space,  key .. " = true")
                    else
                        command.insertData(space, key .. " = " .. value)
                    end
                else
                    command.insertData(space,  key .. " = false")
                end
                if func then
                    func(tableName .. "." .. key, key, value)
                end
            end
        end
    end

    for _, key in pairs(keyTable) do
        local value = tableData[key]
        if type(value) == "table" then
            local rKey = key
            if type(rKey) == "number" then
                rKey = ""
            end

            local isPrint = true
            if filterFunc then
                isPrint = filterFunc(tableName .. "." .. key, key, value)
            end

            command.insertData(space, key)
            command.insertData(space,"{")
            if isPrint then
                command.createSpace()
                command.doTableToList(tableName .. "." .. rKey, value, func, filterFunc)
                command.delSpace()
            else
                command.insertData(space, "    ignore size = " ..#value)
            end
            command.insertData(space, "}")

            if func then
                func(tableName .. "." .. rKey, key, value)
            end
        end
    end
end


local TableDataList = {}
local TableSpaceList = {}

function command.createSpace()
    local rSpace = command.getSpace() .. string.rep(" ", 3, "")
    command.addSpace(rSpace)
    return rSpace
end

function command.addSpace(space)
    table.insert(TableSpaceList, space)
    return space
end

function command.delSpace()
    table.remove(TableSpaceList, #TableSpaceList)
end


function command.getSpace()
    if #TableSpaceList <= 0 then
        return nil
    end
    return TableSpaceList[#TableSpaceList]
end

function command.insertData(space, data)
    table.insert(TableDataList, space .. data)
end

function command.printSub(desc, ...)
    local space = command.getSpace()
    local data = command.format(desc, ...)
    command.insertData(space, data)
end

function command.printSubTable(tableData, filterFunc, func)
    if not command.getSpace() then
        return
    end

    command.subTableToList(tableData, func, filterFunc)
end

function command.printTable(logLevel, tableData, desc, func, filterFunc)
    if LogLeveValue > logLevel then
        command.initStackLevel()
        return
    end
    command.addSpace("")
    command.tableToList(tableData, desc, func, filterFunc)
    command.delSpace()
    if #TableDataList > 0 then
        local fileName, line, funcName = command.printInfo()
        for _, v in ipairs(TableDataList) do
            command.doPrint(fileName, line, funcName, logLevel, "", v)
        end
    end

    TableDataList = {}
    TableSpaceList = {}
    command.initStackLevel()
end

function command.tableToList(tableData, desc, func, filterFunc)
    if desc then
        local space = command.getSpace()
        command.insertData(space, desc)
        command.insertData(space, "{")
        if tableData then
            command.createSpace()
            command.subTableToList(tableData, func, filterFunc)
            command.delSpace()
        end
        command.insertData(space, "}")
    else
        if tableData then
            command.subTableToList(tableData, func, filterFunc)
        end
    end
end

function command.subTableToList(tableData, func, filterFunc)
    if not tableData then
        return
    end

    local space = command.getSpace()
    for _, rTableData in ipairs(tableData) do
        command.insertData(space, rTableData[2])
        command.insertData(space, "{")
        command.createSpace()
        command.doTableToList(rTableData[2], rTableData[1], func, filterFunc)
        command.delSpace()
        command.insertData(space, "}")
    end
end

return command