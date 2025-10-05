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
--
-- TODO: use ChatFrame_AddMessage or ChatFrame_AddText for output.  maybe create a Zebug_Chat_Frame?


local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole() -- Lua voodoo magic that replaces the current Global namespace with the Ufo

-------------------------------------------------------------------------------
-- Module Loading / Exporting
-------------------------------------------------------------------------------

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
---@field _king string
---@field dynamicName boolean true if name is a function
---@field owner any the class/object responsible for deploying the event
---@field mySpeakingVolume ZebugSpeakingVolume

---@type Event
Event = {}
local eCounter = {}

---@return Event
---@param mySpeakingVolume ZebugSpeakingVolume a lower volume (such as NONE, TRACE, or INFO) will produce less debugging output. it will SUPERCEDE the volume "foo" of any zebug.foo:event(thisEvent)
function Event:new(owner, name, count, mySpeakingVolume, indent)
    assert(owner, "'owner' param is missing")
    assert(name, "'name' param is missing")
    assert(isString(name) or isFunction(name), "'name' is wrong type. Must be string or func.")

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
        dynamicName=isFunction(name),
        count=count,
        indent=indent,
        mySpeakingVolume = mySpeakingVolume,
        color = c,
        colorOpener = co,
        ufoType="Event",
    }

    setmetatable(self, { __index = Event })
    UfoMixIn.installMyToString(self)

    return self
end

function Event:getFullName()
    if (not self.fullName) or self.dynamicName then
        local name = (((not self.dynamicName) and self.name) or self.name())
        local hasUnderscore = string.find(name, "_")
        local sep = hasUnderscore and "_" or "-"
        self.fullName = ((self.owner and getNickName(self.owner) .." / ") or "") .. name .. sep .. self.count
    end
    return self.fullName
end

function Event:toString()
    return sprintf("<Event %s>", self:getFullName())
end

function Event:king(king)
    self._king = king
end

---@param germ Germ
function Event:muteUnlessKing(germ)
    --assert(self._king, "you haven't set a king so this method call is probably a mistake.")
    local label = (germ.getLabel and germ:getLabel()) or "NoLaBeL"
    --print("e:MUK", "ufoType =(", germ.ufoType, ")", germ, germ:toString(), "label =", label, "- king =",self._king)
    if self._king and (self._king == label) then
        if not self.OLD_mySpeakingVolume then
            self.OLD_mySpeakingVolume = self.mySpeakingVolume
        end
        self.mySpeakingVolume = -10
    end
end

function Event:unMute()
    if not self.OLD_mySpeakingVolume then return end
    self.mySpeakingVolume = self.OLD_mySpeakingVolume
    self.OLD_mySpeakingVolume = nil
end

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
Zebug = {
    MUTE  = -10, -- TODO: fix ambiguity
    TRACE = SPEAKING_VOLUME.TRACE,
    INFO  = SPEAKING_VOLUME.INFO,
    WARN  = SPEAKING_VOLUME.WARN,
    ERROR = SPEAKING_VOLUME.ERROR,
    NONE  = SPEAKING_VOLUME.NONE,
}

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
local IS_MUTE = "IS_MUTE"

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

local function _runEvent(self, showStart, event, callback, ...)
    event = event or self.zEvent
    local funcRestorePreviousGlobalEvent = zebug:setGlobalEvent(event)

    local width = event.indent or 0
    if not self.methodName then
        self.methodName = "callback"
    end

    -- remember these for later
    local methodName = self.methodName
    local markers = self.markers
    local zOwner = self.zOwner

    local startTime = GetTimePreciseSec()
    if showStart then
        _eventStart(self, event):noName():out(width, "=",START, tFormat3(startTime), ...)
    end
    callback(event)
    local endTime = GetTimePreciseSec()

    -- put these back coz they get cleared on every output
    self.markers = markers
    self.methodName = methodName
    self.zOwner = zOwner
    _eventEnd(self, event):noName():out(width, "=",END, tFormat3(endTime), "elapsed time", nFormat3(endTime-startTime),  ...)
    funcRestorePreviousGlobalEvent()
end

---@param callback fun(event:Event) callback to run.  will receive the same event as provided
function Zebug:run(callback, ...)
    _runEvent(self, true, self.zEvent, callback, ...)
end

---@param event Event
---@param callback fun(event:Event) callback to run.  will receive the same event as provided
function Zebug:runTerse(callback, ...)
    _runEvent(self, false, self.zEvent, callback, ...)
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
    return isTable(e) and e.colorOpener
end

function Zebug:isMute()
    assert(isZebuggerObj(self), ERR_MSG)
    if (self.zEvent == IS_MUTE) then
        return true
    end
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

function Zebug:mAll(condition)
    for k, v in pairs(RaidMarkerTexture) do
        --print(k,v)
        self:mark(k, condition)
    end
    for k, v in pairs(MarkTexture) do
        --print(k,v)
        self:mark(k, condition)
    end
    return self
end

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

---@param id RaidMarker | Mark
function Zebug:mark(id, condition)
    local doIt = true -- in the absence of a boolean conditional, default to YES
    if isBoolean(condition) then
        doIt = condition
    end
    if not self.markers then
        self.markers = {}
    end
    self.markers[id] = doIt and ((RaidMarkerTexture[id] or MarkTexture[id]))
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

---@param event string|Event metadata describing the instigating event - good for debugging
function Zebug:event(event)
    event = event or ADDON_SYMBOL_TABLE.eventBridge
    assert(event,"can't set nil event!") -- TODO: replace with event = event or UNKNOWN_EVENT
    --assert(isTable(event),"event obj must be a table!")
    --assert(event.getFullName,"provided param is not actually an Event object!")
    self.zEvent = event
    return self
end

---@param event string|Event metadata describing the instigating event - good for debugging
function Zebug:newEvent(owner, name, count, mySpeakingVolume, indent)
    if self:isMute() then
        -- save CPU cycles when mute
        self.zEvent = IS_MUTE
    else
        self.zEvent = Event:new(owner, name, count, mySpeakingVolume, indent)
    end
    return self
end

function _eventStart(self, event)
    self.zEventMsg = START
    return self:event(event)
end

function _eventEnd(self, event)
    self.zEventMsg = END
    return self:event(event)
end

-- useful when the execution thread passes through code that doesn't explicitly pass the event to the next method()
---@param event string|Event metadata describing the instigating event - good for debugging
---@return function a function that will restore the GlobalEvent to what it was before
function Zebug:setGlobalEvent(event)
    local oldEventBridge = ADDON_SYMBOL_TABLE.eventBridge
    --print("overwriting ADDON_SYMBOL_TABLE.eventBridge = ",ADDON_SYMBOL_TABLE.eventBridge, " and setting it to event -->", event)
    ADDON_SYMBOL_TABLE.eventBridge = event
    return function()
        --print("erasing ADDON_SYMBOL_TABLE.eventBridge = ",ADDON_SYMBOL_TABLE.eventBridge, " and restoring oldEventBridge -->", oldEventBridge)
        ADDON_SYMBOL_TABLE.eventBridge = oldEventBridge
    end
end

---@param caller any a unique identifier, e.g. self or "ID123"
function Zebug:owner(caller)
    if self:isMute() then
        self.zOwner = nil
        return self
    end
    self.zOwner = getNickName(caller)
    return self
end

function Zebug:noName()
    self.suppressMethodName = true
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
        (isString(obj) and obj)
        or (isFunction(obj) and (obj()))
        or obj.toString and obj:toString()
        or (obj.getLabel and obj:getLabel())
        or (obj.getName and obj:getName())
        -- or obj.ufoType -- anything with a ufoType will have a custom tostring
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
    if self:isMute() then
        self:clearLineVars()
        return
    end
    self:out(2,DOWN_ARROW, label, DOWN_ARROW)
    DevTools_Dump(...)
    self:out(2,UP_ARROW, label, UP_ARROW)
    return self
end

---@return Zebug -- IntelliJ-EmmyLua annotation
function Zebug:print(...)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then
        self:clearLineVars()
        return
    end

    self:line(self.sharedData.indentWidth, ...)

    self.caller = nil
    return self
end

---@return Zebug
---@param indentWidth number how many characters wide is the header
function Zebug:line(indentWidth, ...)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then
        self:clearLineVars()
        return
    end

    self:out(indentWidth, self.sharedData.indentChar, ...)

    self.caller = nil
    return self
end

---@return Zebug
---@param indentWidth number how many characters wide is the header
---@param indentChar string will be used to compose the header
function Zebug:out(indentWidth, indentChar, ...)
    assert(isZebuggerObj(self), ERR_MSG)

    if not self.zEvent and ADDON_SYMBOL_TABLE.eventBridge ~= IS_MUTE then
        self.zEvent = ADDON_SYMBOL_TABLE.eventBridge
        --print("zzzeeebbbuuuggg ADDON_SYMBOL_TABLE.eventBridge = ", ADDON_SYMBOL_TABLE.eventBridge)
    end

    if self:isMute() then
        self:clearLineVars()
        return
    end
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
    local shoName = not self.suppressMethodName

    local out1 = {
        self:colorize(PREFIX),
        " ",

        eventName and self.zEvent.colorOpener or "", -- start event color
        eventName and "[" or "",
        eventName or "",
        eventName and (eMsg and " <==== " or "") or "",
        eventName and eMsg or "",
        eventName and "] " or "",
    }

    local outMarkers = self:roundUpAllTheMarkers()

    local out3 = {
        indent,
        " ",
        --header or "",

        --eventName and "|r" or "", -- end event color
        self:stopColor(), -- end event color

        shoName and file or "",
        shoName and method and ":" or "",
        shoName and method or "",

        shoName and line or "",
        shoName and " " or "",

        self:startColor(), -- start debug level color

        owner and "",
        owner,

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
            --table.insert(out, self:asString(v))
            out3[#out3 +1] = self:asString(v)
        else
            out3[#out3 +1] =  ": "
            out3[#out3 +1] =  self:asString(v)
            if i~= args.n then
                out3[#out3 +1] =  " .. "
            end
        end
    end

    if outMarkers then
        print(
                table.concat(out1,""),
                table.concat(outMarkers,""),
                table.concat(out3,"")
        )
    else
        print(
                table.concat(out1,""),
                table.concat(out3,"")
        )
    end

    if isTableNotEmpty(self.markers) then
        self.markers = nil
    end
    self:clearLineVars()
--[[
    self.caller = nil
    self.zOwner = nil
    self.zEvent = nil
    self.zEventMsg = nil
    self.methodName = nil
    self.mySqueakyWheelId = nil
    self.suppressMethodName = nil
]]
    return self
end

function Zebug:clearLineVars()
    self.caller = nil
    self.zOwner = nil
    self.zEvent = nil
    self.zEventMsg = nil
    self.methodName = nil
    self.mySqueakyWheelId = nil
    self.suppressMethodName = nil
end

function Zebug:roundUpAllTheMarkers()
    if not self.markers then return nil end
    local result = {}
    for k, v in pairs(self.markers) do
        --print("icon ",k, "->", v)
        result[#result+1] = v
    end
    result[#result+1] = " "
    return result
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
    local j, line, isZebug, isTail, isEllipsis, file, n, funcName, fileKeep, nKeep
    local count = 1
    while stack or exists(stack) do
        _, j = string.find(stack, "\n")
        line = string.sub(stack, 1, j)
        isZebug = string.find(line, "Zebug.lua")
        isTail = string.find(line, "tail call")
        isEllipsis = string.find(line, "[.][.][.]")
        if isEllipsis then
            stack = nil
        elseif isZebug or isTail then
            stack = string.sub(stack, j+1)
        else
            -- the stack trace format changed in v11.1
            _,_, file, n, funcName = string.find(line,[=[([%w_]+)%.[^:.]*]:(%d+):%s*in function%s*['<]([^'>]+)['>]]=])
            -- this parsed the pre v11.1 format
            -- _,_, file, n, funcName = string.find(line,'([%w_]+)%.[^"]*"]:(%d+):%s*in function%s*.(.+).');
            if not funcName then
                -- the parser failed so spit out some debugging info
                print("WUT? (", stack, ")")
                funcName = ""
            end
            if string.find(funcName, "/") then
                -- this is an anonymous function and funcName only contains file name and line number which we already know
                funcName = nil

                -- the filename and line number are correct
                fileKeep = file
                nKeep = n

                -- and, the correct func name may be found later in the stack, so keep looping.
                stack = string.sub(stack, j+1)
                --print("fileKeep",fileKeep, "nKeep",nKeep, "stack",stack)
            else
                stack = nil
            end
        end

        -- guard against an infinite loop
        count = count + 1
        if count > 10 then
            stack = nil
            print "oops too loops"
        end
    end

    return fileKeep or file, nKeep or n, funcName
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
    local methodName = funcName or self.methodName or "<ANON>"

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
        if self:isMute() then
            self:clearLineVars()
            return
        end
        self:print(getName(obj,eventName).." said ".. msg .."! ")
    end
end

function Zebug:makeDummyStubForCallback(obj, eventName, msg)
    assert(isZebuggerObj(self), ERR_MSG)
    self:print("makeDummyStubForCallback for " .. eventName)
    obj:RegisterEvent(eventName);
    obj:SetScript(Script.ON_EVENT, self:messengerForEvent(eventName,msg))

end

function Zebug:dumpKeys(object)
    assert(isZebuggerObj(self), ERR_MSG)
    if self:isMute() then
        self:clearLineVars()
        return
    end
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
    return ((v==nil)and"nil") or (isString(v) and v) or (isFloat(v) and nFormat3(v)) or tostring(v) -- or
end
