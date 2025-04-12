-- utilities.lua
-- catch-all file for miscellaneous global utility functions

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole() -- Lua voodoo magic that replaces the current Global namespace with the Ufo object

local zebug = Zebug:new(Zebug.OUTPUT.WARN)

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

sprintf = string.format

function registerSlashCmd(cmdName, callbacks)
    _G["SLASH_"..cmdName.."1"] = "/" .. cmdName

    if not callbacks.help then
        local helpFunc = function()
            for name, cmd in pairs(callbacks) do
                if cmd.desc then
                    print("/"..cmdName .. " " .. name.. " - " .. cmd.desc)
                end
            end
        end
        callbacks.help = { fnc = helpFunc }
    end

    SlashCmdList[cmdName] = function(arg)
        if isEmpty(arg) then
            arg = "help"
        end
        local cmd = callbacks[arg]
        if not cmd then
            msgUser(L10N.SLASH_UNKNOWN_COMMAND .. ": \"".. arg .."\"")
        else
            msgUser(arg .."...")
            local func = cmd.fnc
            func()
        end
    end
end

function msgUser(msg, isOptional)
    if isOptional and Config and Config:get("muteLogin") then return end
    if not ADDON_SYMBOL_TABLE.myNameInColor then
        ADDON_SYMBOL_TABLE.myNameInColor = zebug.info:colorize(ADDON_NAME)
    end

    print(ADDON_SYMBOL_TABLE.myNameInColor .. ": " .. msg)
end

function isInCombatLockdown(actionDescription, isQuiet)
    if InCombatLockdown() then
        local msg = actionDescription or "That action"
        local printer = (isQuiet and true) and zebug.info or zebug.warn -- for the time being, make everything "quiet"
        printer:print(msg .. " is not allowed by Blizzard during combat.")
        return true
    else
        return false
    end
end

function isInCombatLockdownQuiet(actionDescription)
    return isInCombatLockdown(actionDescription, true)
end

local exeQ = {}
-- delay a function call so that it is only executed outside of combat
---@param qId string a unique identifier to ensure the same func doesn't get queued more than once
---@param func function the command to execute once combat has ended
function exeOnceNotInCombat(qId, func)

    -- temporarily disable
    --func()
    --if true then return end

    if isInCombatLockdownQuiet(qId) then
        if not exeQ[qId] then
            zebug.trace:line(3,"IN COMBAT so queueing", qId)
            exeQ[qId] = true
            C_Timer.After(1, function()
                zebug.trace:line(3,"maybe combat, so trying", qId)
                exeOnceNotInCombat(qId, func)
                zebug.trace:line(3,"maybe combat, so tried ", qId)
            end)
        else
            zebug.trace:line(3,"IN COMBAT and also already queued", qId)
        end
    else
        zebug.trace:line(3,"no combat so immediately executing ->", qId)
        exeQ[qId] = nil
        func()
    end
end

function safelySetAttribute(zelf, key, value)
    local name = zelf.name or (zelf.getName and zelf:getName()) or (zelf.GetName and zelf:GetName()) or tostring(zelf) or "fucker"
    local qId = name .. tostring(key) .. tostring(value)
    exeOnceNotInCombat(qId, function()
        zelf:SetAttribute(key, value, true) -- the "true" param is used by my custom SetAttribute() to mean "is trusted"
    end)
end

local throttleQ = {}
local throttleT0 = {}

-- throttle a function call so that it is only allowed to execute once during a give time frame, ie once per second and a half
---@param qId string a unique identifier to ensure the same func doesn't get queued more than once
---@param maxFreq number how often are we allowed to execute the function (in seconds, decimals allowed) ex 1.5
---@param func function the command to execute
---@param reportedElapsed number (optional) how long since this was last called (useful when the Bliz handlers provide ie, eg OnUpdate
function throttle(qId, maxFreq, func, reportedElapsed)

    -- temporarily disable
    --func()
    --if true then return end

    if not throttleQ[qId] then
        -- first time call
        throttleQ[qId] = maxFreq
        if not reportedElapsed then
            throttleT0[qId] = time() -- set T0 to NOW!
        end
        -- always do the first call immediately
        zebug.info:line(6,"TIMER FIRST", qId)
        func()
    else
        -- subsequent calls
        local elapsed = reportedElapsed or (time() - (throttleT0[qId] or 0))
        if elapsed >= maxFreq then
            zebug.info:line(6,"TIMER FOLLOWUP", qId, "elapsed",elapsed)
            throttleT0[qId] = time() -- reset T0 to NOW!
            func()
        end
    end
end

function getIdForCurrentToon()
    local name, realm = UnitFullName("player") -- FU Bliz, realm is arbitrarily nil sometimes but not always
    realm = GetRealmName()
    return name.."-"..realm
end

-- I had to create this function to replace lua's strjoin() because
-- lua poops the bed in the strsplit(strjoin(array)) roundtrip whenever the "array" is actually a table because an element was set to nil
function fknJoin(array)
    array = array or {}
    local n = lastIndex(array)
    local omfgDumbAssLanguage = {}
    for i=1,n,1 do
        omfgDumbAssLanguage[i] = array[i] or EMPTY_ELEMENT
    end
    local result = strjoin(DELIMITER,unpack(omfgDumbAssLanguage,1,n)) or ""
    return result
end

-- because lua arrays turn into tables when an element = nil
function lastIndex(table)
    local biggest = 0
    for k,v in pairs(table) do
        if (k > biggest) then
            biggest = k
        end
    end
    return biggest
end

-- ensures then special characters introduced by fknJoin()
function fknSplit(str)
    local omfgDumbassLanguage = { strsplit(DELIMITER, str or "") }
    omfgDumbassLanguage = stripEmptyElements(omfgDumbassLanguage)
    return omfgDumbassLanguage
end

function stripEmptyElements(table)
    for k,v in ipairs(table) do
        if (v == EMPTY_ELEMENT) then
            table[k] = nil
        end
    end
    return table
end

function deepcopy(src, target)
    local orig_type = type(src)
    local copy
    if orig_type == 'table' then
        copy = target or {}
        for orig_key, orig_value in next, src, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        --setmetatable(copy, deepcopy(getmetatable(src)))
    else -- number, string, boolean, etc
        copy = src
    end
    return copy
end

function isNumber(n)
    local isNumber
    local ok = pcall(function() isNumber = tonumber(n) end)
    return isNumber and true or false
end

local next = next

function isTableNotEmpty(table)
    return table and ( next(table) )
end

function isEmptyTable(table)
    return not isTableNotEmpty(table)
end

function isEmpty(s)
    return s == nil or s == ''
end

function exists(s)
    return not isEmpty(s)
end

function tableContainsVal(table, val)
    if not table then return false end
    assert(val ~= nil, "Can't check for nil as an array element")

    for i, v in ipairs(table) do
        if v == val then
            return true
        end
    end

    return false
end

function deleteFromArray(array, killTester)
    local j = 1
    local modified = false

    for i=1,#array do
        if (killTester(array[i])) then
            array[i] = nil
            modified = true
        else
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                array[j] = array[i]
                array[i] = nil
            end
            j = j + 1 -- Increment position of where we'll place the next kept value.
        end
    end

    return modified
end

function moveElementInArray(array, oldPos, newPos)
    if oldPos == newPos then return false end

    zebug.info:line(80)
    -- iterate through the array in whichever direction will encounter the oldPos first and newPos last
    -- ahhh, I feel like I'm writing C code again... flashback to 1994... I'm old :-/
    local forward = oldPos < newPos
    local start = forward and 1 or #array
    local last  = forward and #array or 1
    local inc   = forward and 1 or -1

    local nomad = array[oldPos]
    zebug.info:print("moving",nomad, "from", oldPos, "to",newPos)
    zebug.info:dumpy("ORIGINAL array", array)

    local inMoverMode
    for i=start,last,inc do
        if i == oldPos then
            inMoverMode = true
        elseif i == newPos then
            array[i] = nomad
            zebug.info:dumpy("shifted array", array)
            return true
        end

        if inMoverMode then
            array[i] = array[i + inc]
        end
    end

    return true
end

-- convert data structures into JSON-like strings
-- useful for injecting tables into secure functions because SFs don't allow tables
function serialize(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)

    if name then tmp = tmp .. name .. " = " end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            tmp =  tmp .. serialize(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" or type(val) == "boolean" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

-- convert data structures into lines of Lua variable assignments
-- useful for injecting tables into secure functions because SFs don't allow tables
-- TODO: can I use this instead of the "asLists" solution?  Or would it produce gigantic strings?
function serializeAsAssignments(name, val, isRecurse)
    assert(val, ADDON_NAME..": val is required")
    assert(name, ADDON_NAME..": name is required")

    local tmp
    if isRecurse then
        tmp = ""
    else
        tmp = "local "
    end
    tmp = tmp .. name .. " = "

    local typ = type(val)
    if "table" == typ then
        tmp = tmp .. "{}" .. EOL
        -- trust that if there is an index #1 then all other indices are also numbers.  Otherwise, this will fail.
        local iterFunc = val[1] and ipairs or pairs
        for k, v in iterFunc(val) do
            if type(k) ~= "number" then
                k = string.format("%q", k)
            end
            local nextName = name .. "["..k.."]"
            tmp = tmp .. serializeAsAssignments(nextName, v, true)
        end
    elseif "number" == typ or "boolean" == typ then
        tmp = tmp .. tostring(val) .. EOL
    elseif "string" == typ then
        tmp = tmp .. string.format("%q", val) .. EOL
    else
        tmp = tmp .. QUOTE .. "INVALID" .. QUOTE .. EOL
    end

    return tmp
end

function isClass(firstArg, class)
    assert(class, ADDON_NAME..": nil is not a Class")
    return (firstArg and type(firstArg) == "table" and firstArg.ufoType == class.ufoType)
end

function assertIsFunctionOf(firstArg, class)
    assert(not isClass(firstArg, class), ADDON_NAME..": Um... it's var.foo() not var:foo()")
end

function assertIsMethodOf(firstArg, class)
    assert(isClass(firstArg, class), ADDON_NAME..": Um... it's var:foo() not var.foo()")
end


