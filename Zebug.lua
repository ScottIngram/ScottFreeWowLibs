-- Zebug.lua
-- developer utilities for displaying code behavior
--
-- Usage:
-- local zebug = Zebug:new(Zebug.INFO) -- the arg turns on/off different speaking volumes: TRACE, INFO, WARN, ERROR
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
-- During development, you may want to silence some speaking volumes that are not currently of interest, so change the arg to WARN or ERROR
-- When you release your addon and want to silence even more speaking volumes, use NONE
--
-- TODO: zebug:wrapAllMethods(MyClassFoo) - wraps all of a class' methods. the wrapper provides a zebugger pre-populated with its
-- method name, call stack depth (to be used with auto-indentation), etc?
-- and can assign individual methods with custom speaking volumes based on some class config = { getFoo = INFO, setBar = TRACE, default = WARN }

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...

-------------------------------------------------------------------------------
-- Module Loading / Exporting
-------------------------------------------------------------------------------

local RaidMarker = ADDON_SYMBOL_TABLE.RaidMarker -- import from BlizApiEnums
local RaidMarkerTexture = ADDON_SYMBOL_TABLE.RaidMarkerTexture -- import from BlizApiEnums

local tFormat4 = ADDON_SYMBOL_TABLE.tFormat4
local nFormat4 = ADDON_SYMBOL_TABLE.nFormat4
local isString = ADDON_SYMBOL_TABLE.isString
local isFloat = ADDON_SYMBOL_TABLE.isFloat

---@class Zebuggers -- IntelliJ-EmmyLua annotation
---@field error Zebug always shown, highest priority messages
---@field warn Zebug end user visible messages
---@field info Zebug dev dev messages
---@field trace Zebug tedious dev messages
---@field originalLowestAllowedSpeakingVolume ZebugSpeakingVolume set upon creation in new()
---@field sharedData table data that's common to the family of trace/info/warn/error instances
local Zebuggers = {}

---@class ZebugSpeakingVolume -- IntelliJ-EmmyLua annotation
local SPEAKING_VOLUME = {
    ALL_MSGS = 0,
    ALL   = 0,
    TRACE = 2,
    INFO  = 4,
    WARN  = 6,
    ERROR = 8,
    NONE  = 10,
}
local SPEAKING_VOLUMES_NAMES = {
    [SPEAKING_VOLUME.TRACE] = "TRACE",
    [SPEAKING_VOLUME.INFO]  = "INFO ",
    [SPEAKING_VOLUME.WARN]  = "WARN ",
    [SPEAKING_VOLUME.ERROR] = "ERROR",
}

---@class Event
---@field color table Bliz color object
---@field colorOpener string the character sequence required to print in a color
---@field indent number
---@field count number
---@field name string
---@field owner any the class/object responsible for deploying the event
---@field mySpeakingVolume ZebugSpeakingVolume

---@type Event
local Event = {}
local eCounter = {}

---@return Event
---@param mySpeakingVolume ZebugSpeakingVolume a lower volume (such as NONE, TRACE, or INFO) will produce less debugging output. it will SUPERCEDE the volume "foo" of any zebug.foo:event(thisEvent)
function Event:new(owner, name, count, mySpeakingVolume, indent)
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
        mySpeakingVolume = mySpeakingVolume,
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
---@field isZebug boolean
---@field color table
---@field mySpeakingVolume ZebugSpeakingVolume
---@field lowestAllowedSpeakingVolume ZebugSpeakingVolume
---@field indentWidth number
---@field zEvent Event
---@field zEventMsg string
---@field zOwner string
---@field markers table<RaidMarker, boolean>
---@field sharedData table
---@field OUTPUT ZebugSpeakingVolume
---@field LEVEL ZebugSpeakingVolume
---@field TRACE ZebugSpeakingVolume
---@field INFO ZebugSpeakingVolume
---@field WARN ZebugSpeakingVolume
---@field ERROR ZebugSpeakingVolume
---@field NONE ZebugSpeakingVolume
local Zebug = {
    TRACE = SPEAKING_VOLUME.TRACE,
    INFO  = SPEAKING_VOLUME.INFO,
    WARN  = SPEAKING_VOLUME.WARN,
    ERROR = SPEAKING_VOLUME.ERROR,
    NONE  = SPEAKING_VOLUME.NONE,
}

ADDON_SYMBOL_TABLE.Zebug = Zebug

---@type table<string,Zebuggers>
local namedZebuggers = {}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local DEFAULT_ZEBUG = SPEAKING_VOLUME.WARN
local ERR_MSG = "ZEBUGGER SYNTAX ERROR: invoke as zebug.info:func() not zebug.info.func()"
local PREFIX = "<" .. ADDON_NAME .. ">"
local DEFAULT_INDENT_CHAR = "#"
local DEFAULT_INDENT_WIDTH = 0
local MUTE_INSTANCE

local COLORS = { }
COLORS[SPEAKING_VOLUME.TRACE] = GetClassColorObj("WARRIOR")
COLORS[SPEAKING_VOLUME.INFO]  = GetClassColorObj("MONK")
COLORS[SPEAKING_VOLUME.WARN]  = GetClassColorObj("ROGUE")
COLORS[SPEAKING_VOLUME.ERROR] = GetClassColorObj("DEATHKNIGHT")

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
    if colorCount == maxColor then
        colorCount = 1
    else
        colorCount = colorCount + 1
    end
    --print(colorCount, COLORZ[colorCount]:WrapTextInColorCode(CLASSES[colorCount]))
    return COLORZ[colorCount], COLOR_OPENER[colorCount]
end
-------------------------------------------------------------------------------
-- Inner Class - ZebuggersSharedData
-------------------------------------------------------------------------------

---@class ZebuggersSharedData -- IntelliJ-EmmyLua annotation
---@field OUTPUT ZebugSpeakingVolume -- IntelliJ-EmmyLua annotation
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

---@return Zebuggers
function Zebuggers:new()
    return deepcopy(Zebuggers, {})
end

---@param speakingVolume ZebugSpeakingVolume the level at which zebug lines are allowed to produce output.  anything below that level is mute.
function Zebuggers:setLowestAllowedSpeakingVolume(speakingVolume)
    self.trace:setLowestAllowedSpeakingVolume(speakingVolume)
    self.info:setLowestAllowedSpeakingVolume(speakingVolume)
    self.warn:setLowestAllowedSpeakingVolume(speakingVolume)
    self.error:setLowestAllowedSpeakingVolume(speakingVolume)
end

function Zebuggers:setLowestAllowedSpeakingVolumeBackToOriginal()
    self.trace:setLowestAllowedSpeakingVolume(self.originalLowestAllowedSpeakingVolume)
    self.info:setLowestAllowedSpeakingVolume(self.originalLowestAllowedSpeakingVolume)
    self.warn:setLowestAllowedSpeakingVolume(self.originalLowestAllowedSpeakingVolume)
    self.error:setLowestAllowedSpeakingVolume(self.originalLowestAllowedSpeakingVolume)
end

function Zebuggers:getLowestAllowedSpeakingVolume()
    return self.originalLowestAllowedSpeakingVolume
end


-------------------------------------------------------------------------------
-- Class Zebug - Functions / Methods
-------------------------------------------------------------------------------

local function isZebuggerObj(zelf)
    return zelf and zelf.isZebug
end

---@param mySpeakingVolume ZebugSpeakingVolume
---@return Zebug
local function newInstance(mySpeakingVolume, lowestAllowedSpeakingVolume, sharedData)
    ---@type Zebug
    local self = {
        isZebug = true,
        level = mySpeakingVolume,
        color = COLORS[mySpeakingVolume],
        mySpeakingVolume = mySpeakingVolume,
        lowestAllowedSpeakingVolume = lowestAllowedSpeakingVolume,
        indentWidth = 5,
        sharedData = sharedData,
    }
    setmetatable(self, { __index = Zebug })
    return self
end

function Zebug:runEvent(event, runEvent, ...)
    local width = event.indent or 20
    local x = self.markers -- remember these for later
    if not self.methodName then
        self.methodName = "Zebug:runEvent"
    end

    local startTime = GetTimePreciseSec()
    self:event(event, ADDON_SYMBOL_TABLE.START):out(width, "=",ADDON_SYMBOL_TABLE.START, tFormat4(startTime), ...)
    runEvent()
    local endTime = GetTimePreciseSec()
    self.markers = x -- put them back coz they get cleared on every output
    self:event(event, ADDON_SYMBOL_TABLE.END):out(width, "=",ADDON_SYMBOL_TABLE.END, tFormat4(endTime), "elapsed time", nFormat4(endTime-startTime),  ...)
end

---@return Zebuggers -- IntelliJ-EmmyLua annotation
function Zebug:new(lowestAllowedSpeakingVolume)
    if not lowestAllowedSpeakingVolume then
        lowestAllowedSpeakingVolume = DEFAULT_ZEBUG
    end
    local isValidNoiseLevel = type(lowestAllowedSpeakingVolume) == "number"
    assert(isValidNoiseLevel, ADDON_NAME..": Zebugger:newZebugger() Invalid Speaking Volume: '".. tostring(lowestAllowedSpeakingVolume) .."'")

    local sharedData = ZebuggersSharedData:new()
    local zebugger = Zebuggers:new()
    zebugger.originalLowestAllowedSpeakingVolume = lowestAllowedSpeakingVolume
    zebugger.error = newInstance(SPEAKING_VOLUME.ERROR, lowestAllowedSpeakingVolume, sharedData)
    zebugger.warn  = newInstance(SPEAKING_VOLUME.WARN, lowestAllowedSpeakingVolume, sharedData)
    zebugger.info  = newInstance(SPEAKING_VOLUME.INFO, lowestAllowedSpeakingVolume, sharedData)
    zebugger.trace = newInstance(SPEAKING_VOLUME.TRACE, lowestAllowedSpeakingVolume, sharedData)
    setmetatable(zebugger, { __index = zebugger.info }) -- support syntax such as zebug:out() that bahaves as debuf.info:out()

    if not MUTE_INSTANCE then
        local silent = function() return MUTE_INSTANCE end
        MUTE_INSTANCE = newInstance(SPEAKING_VOLUME.TRACE, lowestAllowedSpeakingVolume, sharedData)
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

---@param speakingVolume ZebugSpeakingVolume
function Zebug:setLowestAllowedSpeakingVolume(speakingVolume)
    assert(isZebuggerObj(self), ERR_MSG)
    self.lowestAllowedSpeakingVolume = speakingVolume
end

function isEventObj(e)
    return ADDON_SYMBOL_TABLE.isTable(e) and e.colorOpener
end

function Zebug:isMute()
    assert(isZebuggerObj(self), ERR_MSG)
    local speakingVolume = (isEventObj(self.zEvent) and self.zEvent.mySpeakingVolume) or self.mySpeakingVolume
    return speakingVolume < self.lowestAllowedSpeakingVolume
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
    self.zOwner = getNickName(caller)
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
        -- or obj.ufoType -- anything with a ufoType will have a custom tostring
        or obj.toString and obj:toString()
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
    local speakingVolumeMsg = SPEAKING_VOLUMES_NAMES[self.mySpeakingVolume]

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
        " ",
        eventName and "|r" or "", -- end event color

        owner and "",
        owner,

        self:stopColor(), -- end event color

        self:startColor(), -- start debug level color
        speakingVolumeMsg and " " or "",
        speakingVolumeMsg or "",
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
    self.zOwner = nil
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
        --[[owner]]  self.mySqueakyWheelId or self.zOwner or ""
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
    return ((v==nil)and"nil") or (isString(v) and v) or (isFloat(v) and nFormat4(v)) or tostring(v) -- or
end
