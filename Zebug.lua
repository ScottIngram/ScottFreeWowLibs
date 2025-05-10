-- Zebug.lua
-- developer utilities for displaying code behavior
--
-- Usage:
-- local zebug = Zebug:new(Zebug.OUTPUT.INFO) -- the arg turns on/off different noise levels: TRACE, INFO, WARN, ERROR
-- zebug.trace:print(arg1,arg2, etc) -- this would be silent considering the "Zebug.OUTPUT.INFO" above.  Otherwise, would display a header and all args as "arg1=arg2, arg3=arg4, " etc.
-- zebug.info:print(arg1,arg2, etc) -- displays the args and sets its priority as "INFO"
-- zebug.warn:print(arg1,arg2, etc) -- displays the args and sets its priority as "WARN"
-- zebug.error:print(arg1,arg2, etc) -- displays the args and sets its priority as "ERROR"
-- zebug:print() -- in the absence of a priority,  "INFO" is the default
-- zebug:line(10) -- behaves as print() but sets the header width to 10
-- zebug:out(10,"*") -- behaves as print() but sets the header width to 10 and the header character to "*"
--
-- You can chain some commands
-- zebug:setMethodName("DoMeNow"):print("foo", bar)
-- During development, you may want to silence some levels that are not currently of interest, so change the arg to WARN or ERROR
-- When you release your addon and want to silence even more levels, use NONE
--
-- TODO: zebug:wrapAllMethods(MyClassFoo) - wraps all of a class' methods. the wrapper provides a zebugger pre-populated with its
-- method name, call stack depth (to be used with auto-indentation), etc?
-- and can assign individual methods with custom noiseLevels based on some class config = { getFoo = INFO, setBar = TRACE, default = WARN }

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...

-------------------------------------------------------------------------------
-- Module Loading / Exporting
-------------------------------------------------------------------------------

local RaidMarker = ADDON_SYMBOL_TABLE.RaidMarker -- import from BlizApiEnums
local RaidMarkerTexture = ADDON_SYMBOL_TABLE.RaidMarkerTexture -- import from BlizApiEnums

---@class Zebuggers -- IntelliJ-EmmyLua annotation
---@field error Zebug always shown, highest priority messages
---@field warn Zebug end user visible messages
---@field info Zebug dev dev messages
---@field trace Zebug tedious dev messages
---@field originalNoiseLevel ZebugLevel set upon creation in new()
---@field sharedData table data that's common to the family of trace/info/warn/error instances
local Zebuggers = {}

---@class ZebugLevel -- IntelliJ-EmmyLua annotation
local LEVEL = {
    ALL_MSGS = 0,
    ALL   = 0,
    TRACE = 2,
    INFO  = 4,
    WARN  = 6,
    ERROR = 8,
    NONE  = 10,
}
local LEVEL_NAMES = {
    [LEVEL.TRACE] = "TRACE",
    [LEVEL.INFO]  = "INFO ",
    [LEVEL.WARN]  = "WARN ",
    [LEVEL.ERROR] = "ERROR",
}

---@class Event
---@field color table Bliz color object
---@field colorOpener string the character sequence required to print in a color
---@field indent number
---@field count number
---@field name string
---@field owner any the class/object responsible for deploying the event
---@field noiseLevel ZebugLevel

---@type Event
local Event = {}
local eCounter = {}

---@return Event
function Event:new(owner, name, count, indent, noiseLevel)
    if not count then
        if not eCounter[name] then
            eCounter[name] = 1
        else
            eCounter[name] = eCounter[name] + 1
        end
        count = eCounter[name]
    end

    local c, co = getNextColor()

    ---@type Event
    local self = {
        owner=owner,
        name=name,
        count=count,
        indent=indent,
        noiseLevel=noiseLevel,
        color = c,
        colorOpener = co,
        getFullName=Event.getFullName,
        toString=Event.toString,
    }

    ADDON_SYMBOL_TABLE.UfoMixIn.installMyToString(self)

    return self
end

function Event:getFullName()
    if not self.fullName then
        self.fullName = ((self.owner and getNickName(self.owner) .." / ") or "") .. self.name .. "_" .. self.count
    end
    return self.fullName
end

function Event:toString()
    return self:getFullName()
end


ADDON_SYMBOL_TABLE.Event = Event

---@class Zebug -- IntelliJ-EmmyLua annotation
---@class Zebug -- IntelliJ-EmmyLua annotation
---@field isZebug boolean
---@field level number
---@field color table
---@field myLevel ZebugLevel
---@field canSpeakOnlyIfThisLevel boolean
---@field indentWidth number
---@field zEvent Event
---@field zEventMsg string
---@field zLabel string
---@field markers table<RaidMarker, boolean>
---@field sharedData table
---@field OUTPUT ZebugLevel
---@field LEVEL ZebugLevel
---@field TRACE ZebugLevel
---@field INFO ZebugLevel
---@field WARN ZebugLevel
---@field ERROR ZebugLevel
---@field NONE ZebugLevel
local Zebug = {
    OUTPUT = LEVEL,
    LEVEL = LEVEL,
    TRACE = LEVEL.TRACE,
    INFO  = LEVEL.INFO,
    WARN  = LEVEL.WARN,
    ERROR = LEVEL.ERROR,
    NONE  = LEVEL.NONE,
}

ADDON_SYMBOL_TABLE.Zebug = Zebug

---@type table<string,Zebuggers>
local namedZebuggers = {}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local DEFAULT_ZEBUG = LEVEL.WARN
local ERR_MSG = "ZEBUGGER SYNTAX ERROR: invoke as zebug.info:func() not zebug.info.func()"
local PREFIX = "<" .. ADDON_NAME .. ">"
local DEFAULT_INDENT_CHAR = "#"
local DEFAULT_INDENT_WIDTH = 0
local MUTE_INSTANCE

local COLORS = { }
COLORS[LEVEL.TRACE] = GetClassColorObj("WARRIOR")
COLORS[LEVEL.INFO]  = GetClassColorObj("MONK")
COLORS[LEVEL.WARN]  = GetClassColorObj("ROGUE")
COLORS[LEVEL.ERROR] = GetClassColorObj("DEATHKNIGHT")

local CLASSES = {"HUNTER", "WARLOCK", --[["PRIEST",]] "PALADIN", "MAGE", "ROGUE", "DRUID", "SHAMAN", "WARRIOR", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"};
local maxColor = #CLASSES
local COLORZ
local COLOR_OPENER
local colorCount = 1
function getNextColor()
    if not COLORZ then
        COLORZ = {}
        COLOR_OPENER = {}
        for i, c in ipairs(CLASSES) do
            COLORZ[i] = GetClassColorObj(c)
            COLOR_OPENER[i] = COLORZ[i]:WrapTextInColorCode(""):sub(1,-3)
            --print(COLORZ[i]:WrapTextInColorCode(c))
        end
    end
    if colorCount > maxColor then
        colorCount = 1
    else
        colorCount = colorCount + 1
    end
    return COLORZ[colorCount], COLOR_OPENER[colorCount]
end
-------------------------------------------------------------------------------
-- Inner Class - ZebuggersSharedData
-------------------------------------------------------------------------------

---@class ZebuggersSharedData -- IntelliJ-EmmyLua annotation
---@field OUTPUT ZebugLevel -- IntelliJ-EmmyLua annotation
---@field squeakyWheelId string the first of any number of unique IDs provided by individual callers
local ZebuggersSharedData = { }

---@return ZebuggersSharedData -- IntelliJ-EmmyLua annotation
function ZebuggersSharedData:new()
    local sharedData = {
        doColors = true,
        indentChar = DEFAULT_INDENT_CHAR,
    }
    setmetatable(sharedData, { __index = ZebuggersSharedData })
    return sharedData
end

-------------------------------------------------------------------------------
-- Class Zebuggers - Functions / Methods
-------------------------------------------------------------------------------

local function deepcopy(src, target)
    local orig_type = type(src)
    local copy
    if orig_type == 'table' then
        copy = target or {}
        for orig_key, orig_value in next, src, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
    else -- number, string, boolean, etc
        copy = src
    end
    return copy
end

function Zebuggers:new()
    return deepcopy(Zebuggers, {})
end

---@param level ZebugLevel the level at which zebug lines are allowed to produce output.  anything below that level is mute.
function Zebuggers:setNoiseLevel(level)
    self.trace:setNoiseLevel(level)
    self.info:setNoiseLevel(level)
    self.warn:setNoiseLevel(level)
    self.error:setNoiseLevel(level)
end

function Zebuggers:setNoiseLevelBackToOriginal()
    self.trace:setNoiseLevel(self.originalNoiseLevel)
    self.info:setNoiseLevel(self.originalNoiseLevel)
    self.warn:setNoiseLevel(self.originalNoiseLevel)
    self.error:setNoiseLevel(self.originalNoiseLevel)
end

-------------------------------------------------------------------------------
-- Class Zebug - Functions / Methods
-------------------------------------------------------------------------------

local function isZebuggerObj(zelf)
    return zelf and zelf.isZebug
end

---@param myLevel ZebugLevel
---@return Zebug
local function newInstance(myLevel, canSpeakOnlyIfThisLevel, sharedData)
    ---@type Zebug
    local self = {
        isZebug = true,
        level = myLevel,
        color = COLORS[myLevel],
        myLevel = myLevel,
        canSpeakOnlyIfThisLevel = canSpeakOnlyIfThisLevel,
        indentWidth = 5,
        sharedData = sharedData,
    }
    setmetatable(self, { __index = Zebug })
    return self
end

function Zebug:runEvent(event, funcToWrap)
    local width = event.indent or 20
    local x = self.markers -- remember these for later
    self:event(event, ADDON_SYMBOL_TABLE.START):out(width, "=",ADDON_SYMBOL_TABLE.START)
    funcToWrap()
    self.markers = x -- put them back coz they get cleared on every output
    self:event(event, ADDON_SYMBOL_TABLE.END):out(width, "=",ADDON_SYMBOL_TABLE.END)
end

---@return Zebuggers -- IntelliJ-EmmyLua annotation
function Zebug:new(canSpeakOnlyIfThisLevel)
    if not canSpeakOnlyIfThisLevel then
        canSpeakOnlyIfThisLevel = DEFAULT_ZEBUG
    end
    local isValidNoiseLevel = type(canSpeakOnlyIfThisLevel) == "number"
    assert(isValidNoiseLevel, ADDON_NAME..": Zebugger:newZebugger() Invalid Noise Level: '".. tostring(canSpeakOnlyIfThisLevel) .."'")

    local sharedData = ZebuggersSharedData:new()
    local zebugger = Zebuggers:new()
    zebugger.originalNoiseLevel = canSpeakOnlyIfThisLevel
    zebugger.error = newInstance(LEVEL.ERROR, canSpeakOnlyIfThisLevel, sharedData)
    zebugger.warn  = newInstance(LEVEL.WARN,  canSpeakOnlyIfThisLevel, sharedData)
    zebugger.info  = newInstance(LEVEL.INFO,  canSpeakOnlyIfThisLevel, sharedData)
    zebugger.trace = newInstance(LEVEL.TRACE, canSpeakOnlyIfThisLevel, sharedData)
    setmetatable(zebugger, { __index = zebugger.info }) -- support syntax such as zebug:out() that bahaves as debuf.info:out()

    if not MUTE_INSTANCE then
        local silent = function() return MUTE_INSTANCE end
        MUTE_INSTANCE = newInstance(LEVEL.TRACE, canSpeakOnlyIfThisLevel, sharedData)
        MUTE_INSTANCE.alert = silent
        MUTE_INSTANCE.dump = silent
        MUTE_INSTANCE.dumpy = silent
        MUTE_INSTANCE.print = silent
        MUTE_INSTANCE.line = silent
    end

    return zebugger
end

function Zebug:newZebuggers(...)
    local d = self:new(...)
    return d.trace, d.info, d.warn, d.error
end

-- lets different classes / files / etc to share a Zebugger.  Helpful for letting a tree of objects to share one ifMe1st() ID
function Zebug:getSharedByName(name, ...)
    if not namedZebuggers[name] then
        namedZebuggers[name] = Zebug:new(...)
    end

    return namedZebuggers[name]
end

---@param level ZebugLevel
function Zebug:setNoiseLevel(level)
    assert(isZebuggerObj(self), ERR_MSG)
    self.canSpeakOnlyIfThisLevel = level
end

function Zebug:isMute()
    assert(isZebuggerObj(self), ERR_MSG)
    return self.myLevel < self.canSpeakOnlyIfThisLevel
end

function Zebug:isActive()
    assert(isZebuggerObj(self), ERR_MSG)
    return not self:isMute()
end

function Zebug:colorize(str)
    if not self.sharedData.doColors then return str end
    return self.color:WrapTextInColorCode(str)
end

function Zebug:startColor()
    if not self.sharedData.doColors then return "" end
    if not self.colorOpener then
        self.colorOpener = self.color:WrapTextInColorCode(""):sub(1,-3)
    end
    return self.colorOpener
end

function Zebug:stopColor()
    if not self.sharedData.doColors then return "" end
    return "|r"
end

-- set a raid marker = STAR
function Zebug:mStar(condition)
    return self:mark(RaidMarker.STAR, condition)
end

function Zebug:mCircle(condition)
    return self:mark(RaidMarker.CIRCLE, condition)
end

function Zebug:mDiamond(condition)
    return self:mark(RaidMarker.DIAMOND, condition)
end

function Zebug:mTriangle(condition)
    return self:mark(RaidMarker.TRIANGLE, condition)
end

function Zebug:mMoon(condition)
    return self:mark(RaidMarker.MOON, condition)
end

function Zebug:mSquare(condition)
    return self:mark(RaidMarker.SQUARE, condition)
end

function Zebug:mCross(condition)
    return self:mark(RaidMarker.CROSS, condition)
end

function Zebug:mSkull(condition)
    return self:mark(RaidMarker.SKULL, condition)
end

-- TODO - others? just various icons?

function Zebug:mark(marker, condition)
    local doIt = true -- in the absence of a boolean conditional, default to YES
    if condition and (type(condition) == "boolean") then
        doIt = condition
    end
    if not self.markers then
        self.markers = {}
    end
    self.markers[marker] = doIt and RaidMarkerTexture[marker]
    return self
end

---@return Zebug -- IntelliJ-EmmyLua annotation
function Zebug:setMethodName(methodName)
    self.methodName = methodName
    return self
end

Zebug.name = Zebug.setMethodName

-- if the arg is false then it silences the rest of the zebug commands on the line
-- usage: zebug.warn:ifThen(true):print("yadda")
---@return Zebug -- IntelliJ-EmmyLua annotation
function Zebug:ifThen(conditional)
    if conditional then
        return self
    else
        return MUTE_INSTANCE
    end
end

---@param event Event
function Zebug:event(event, msg)
    assert(event,"can't set nil event!") -- TODO: replace with event = event or UNKNOWN_EVENT
    --assert(ADDON_SYMBOL_TABLE.isTable(event),"event obj must be a table!")
    --assert(event.getFullName,"provided param is not actually an Event object!")
    self.zEvent = event
    self.zEventMsg = msg
    return self
end

---@param caller any a unique identifier, e.g. self or "ID123"
function Zebug:owner(caller)
    self.zLabel = getNickName(caller)
    return self
end

-- for any given set of values provided for squeakyWheelId
-- the first one is recorded and all others will be silenced.
-- Useful for multiple instances of a class which otherwise
-- would all be very noisy.  This filters out all but one.
-- usage: zebug.warn:ifMe1st(self):print("yadda")
--   or zebug.warn:ifMe1st(self:GetName()):print("yadda")
---@return Zebug -- IntelliJ-EmmyLua annotation
---@param caller any a unique identifier, e.g. self or "ID123"
function Zebug:ifMe1st(caller)
    self.mySqueakyWheelId = getNickName(caller)

    if not self.sharedData.squeakyWheelId then
        -- first one wins
        self.sharedData.squeakyWheelId = self.mySqueakyWheelId
        return self
    end

    if self.sharedData.squeakyWheelId == self.mySqueakyWheelId then
        return self
    else
        return MUTE_INSTANCE
    end
end

function getNickName(obj)
    return obj and (
        (type(obj)=="string" and obj)
        or (obj.getLabel and obj:getLabel())
        or (obj.getName and obj:getName())
        or obj.ufoType
        or tostring(obj)
    ) or "nil"
end

function Zebug:alert(msg)
    UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.0)
    return self
end

---@return Zebug -- IntelliJ-EmmyLua annotation
function Zebug:dump(...)
    return self:dumpy("", ...)
end

local DOWN_ARROW = ".....vvvvvVVVVVvvvvv....."
local UP_ARROW   = "`````^^^^^AAAAA^^^^^`````"

---@return Zebug -- IntelliJ-EmmyLua annotation
function Zebug:dumpy(label, ...)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then return end
    self:out(2,DOWN_ARROW, label, DOWN_ARROW)
    DevTools_Dump(...)
    self:out(2,UP_ARROW, label, UP_ARROW)
    return self
end

---@return Zebug -- IntelliJ-EmmyLua annotation
function Zebug:print(...)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then return end
    --if not self.caller then self.caller = getfenv(2) end

    self:line(self.sharedData.indentWidth, ...)

    self.caller = nil
    return self
end

---@return Zebug
---@param indentWidth number how many characters wide is the header
function Zebug:line(indentWidth, ...)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then return end
    --if not self.caller then self.caller = getfenv(2) end

    self:out(indentWidth, self.sharedData.indentChar, ...)

    self.caller = nil
    return self
end

---@return Zebug
---@param indentWidth number how many characters wide is the header
---@param indentChar string will be used to compose the header
function Zebug:out(indentWidth, indentChar, ...)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then return end
    --if not self.caller then self.caller = getfenv(2) end

    --print("Zebug:out() calledBy-->", debugstack(2,4,0) )
    --print("caller ---> ", self:identifyOutsideCaller() )

    local indent = string.rep(indentChar or DEFAULT_INDENT_CHAR, indentWidth or DEFAULT_INDENT_WIDTH)
    local args = table.pack(...)
    local d = self.sharedData
    --local header = self:OLD_getHeader()

    -- <UFO> {rt1}============================== Ufo/1_PLAYER_ENTERING_WORLDUFO?()~[50] END!
    -- <UFO> {rt1} ============================== Ufo/PLAYER_ENTERING_WORLD_1 UFO()~[50] END!

    local file, method, line, eventName, eMsg, owner = self:getHeader()
    local levelMsg = LEVEL_NAMES[self.myLevel]

    local out = {
        self:colorize(PREFIX),
        " ",

        self.markers and self.markers[RaidMarker.STAR] or "",
        self.markers and self.markers[RaidMarker.CIRCLE] or "",
        self.markers and self.markers[RaidMarker.DIAMOND] or "",
        self.markers and self.markers[RaidMarker.TRIANGLE] or "",
        self.markers and self.markers[RaidMarker.MOON] or "",
        self.markers and self.markers[RaidMarker.SQUARE] or "",
        self.markers and self.markers[RaidMarker.CROSS] or "",
        self.markers and self.markers[RaidMarker.SKULL] or "",
        ADDON_SYMBOL_TABLE.isTableNotEmpty(self.markers) and " " or "",

        eventName and self.zEvent.colorOpener or "", -- start event color
        eventName and "[" or "",
        eventName or "",
        eventName and (eMsg and " <-- " or "") or "",
        eventName and eMsg or "",
        eventName and "] " or "",

        indent,
        " ",
        --header or "",

        file,

        method and ":" or "",
        method,

        line,
        eventName and "|r" or "", -- end event color

        owner and "",
        owner,

        self:stopColor(), -- end event color

        self:startColor(), -- start debug level color
        levelMsg and " " or "",
        levelMsg or "",
        self:stopColor(),  -- end debug level color

        " ",
    }

    -- assemble the remaining args as "label:value, "
    for i=1,args.n do
        local v = args[i]
        local isOdd = i%2 == 1
        if isOdd then
            -- table.insert(out, " .. ")
            table.insert(out, self:asString(v))
        else
            table.insert(out, ": ")
            table.insert(out, self:asString(v))
            if i~= args.n then
                table.insert(out, " .. ")
            end
        end
    end

    print(table.concat(out,""))

    if ADDON_SYMBOL_TABLE.isTableNotEmpty(self.markers) then
        self.markers = nil
    end
    self.caller = nil
    self.zLabel = nil
    self.zEvent = nil
    self.zEventMsg = nil
    self.methodName = nil
    self.mySqueakyWheelId = nil
    return self
end

function table.pack(...)
    return { n = select("#", ...), ... }
end

-- find the name of the non-Zebug function who invoked the Zebug:Method
---@return string file name
---@return number line number
---@return string function name
function Zebug:identifyOutsideCaller()
    -- ask for the stack trace (the list of functions responsible for getting to this point in the code)
    -- skip past the top four (1 = this function, 2 = getLabel, 3 = some other Zebug function, 4 = the first possible non-Zebug function)
    -- start looking at callers 3 layers away and work back until we find something non-Zebug
    local stack = debugstack(4,4,0)
    local originalStack = stack
    local j, line, isZebug, isTail, file, n, funcName
    local count = 1
    while stack do
        _, j = string.find(stack, "\n")
        line = string.sub(stack, 1, j)
        isZebug = string.find(line, "Zebug.lua")
        isTail = string.find(line, "tail call")
        if isZebug or isTail then
            stack = string.sub(stack, j+1)
        else
            -- the stack trace format changed in v11.1
            _,_, file, n, funcName = string.find(line,[=[([%w_]+)%.[^:.]*]:(%d+):%s*in function%s*['<]([^'>]+)['>]]=])
            -- this parsed the pre v11.1 format
            -- _,_, file, n, funcName = string.find(line,'([%w_]+)%.[^"]*"]:(%d+):%s*in function%s*.(.+).');
            if not funcName then
                -- the parser failed so spit out some debugging info
                print("WUT? ", originalStack)
                funcName = ""
            end
            if string.find(funcName, "/") then
                -- this is an anonymous function and funcName only contains file name and line number which we already know
                funcName = nil
            end
            stack = nil
        end

        -- guard against an infinite loop
        count = count + 1
        if count > 10 then
            stack = nil
            print "oops too loops"
        end
    end

    return file, n, funcName
end

---@return Zebug -- IntelliJ-EmmyLua annotation
function Zebug:setIndentChar(indentChar)
    self.sharedData.indentChar = indentChar
    return self
end

function Zebug:getHeader()
    local file, n, funcName = self:identifyOutsideCaller()
    if funcName == "?" then
        funcName = nil
    end
    local methodName = self.methodName or funcName or "<ANON>"

    return
        --[[file]]   file or "",
        --[[method]] methodName and (methodName .."()") or "",
        --[[line]]   (n and "~["..n.."]") or "",
        --[[event]]  (self.zEvent and (self.zEvent.getFullName and self.zEvent:getFullName()) or self.zEvent), --[[eventMsg]] self.zEventMsg,
        --[[owner]]  self.mySqueakyWheelId or self.zLabel or ""
end

local function getName(obj, default)
    assert(isZebuggerObj(self), ERR_MSG)
    if(obj and obj.GetName) then
        return obj:GetName() or default or "UNKNOWN"
    end
    return default or "UNNAMED"
end

function Zebug:messengerForEvent(eventName, msg)
    assert(isZebuggerObj(self), ERR_MSG)
    return function(obj)
        if self:isMute() then return end
        self:print(getName(obj,eventName).." said ".. msg .."! ")
    end
end

function Zebug:makeDummyStubForCallback(obj, eventName, msg)
    assert(isZebuggerObj(self), ERR_MSG)
    self:print("makeDummyStubForCallback for " .. eventName)
    obj:RegisterEvent(eventName);
    obj:SetScript(Script.ON_EVENT, self:messengerForEvent(eventName,msg))

end

function Zebug:run(callback)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then return end
    callback()
end

function Zebug:dumpKeys(object)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then return end
    if not object then
        self:print("NiL")
        return
    end

    local isNumeric = true
    for k,v in pairs(object) do
        if (type(k) ~= "number") then isNumeric = false end
    end
    local keys = {}
    for k, v in pairs(object or {}) do
        local key = isNumeric and k or self:asString(k)
        table.insert(keys,key)
    end
    table.sort(keys)
    for i, k in ipairs(keys) do
        self:print(k.." <-> ".. self:asString(object[k]))
    end
end

function Zebug:asString(v)
    assert(isZebuggerObj(self), ERR_MSG)
    return ((v==nil)and"nil") or ((type(v) == "string") and v) or tostring(v) -- or
end
