-- Throttler.lua
-- throttle a function call so that it is only allowed to execute once during
-- the given time frame, e.g. once every second and a half.

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole()
local zebug = Zebug:new(Zebug.INFO)

---@class Throttler
---@field t0 number time of previous execution
---@field isQueued boolean some execution is already waiting in the queue
---@field func function the command to execute
---@field maxFreq number how often are we allowed to execute the function (in seconds, decimals allowed) ex 1.5
---@field noQueueing boolean disables the queue and simply discards any invocations that happen during the maxFreq countdown
---@field id string a unique identifier to ensure the same func doesn't get queued more than once
Throttler = { }

-------------------------------------------------------------------------------
-- class variables - shared between all instances
-------------------------------------------------------------------------------

local div = "Ø"
local counter = 1

-------------------------------------------------------------------------------
-- Overrides
-------------------------------------------------------------------------------

local time = GetTimePreciseSec -- fuck whole second bullshit

-------------------------------------------------------------------------------
-- Methods
-------------------------------------------------------------------------------

---@param func function the command to execute
---@param maxFreq number how often are we allowed to execute the function (in seconds, decimals allowed) ex 1.5
---@param id string a unique identifier to ensure the same func doesn't get queued more than once
---@return Throttler - a new instance of Throttler dedicating to executing the given function no more often than maxFreq
function Throttler:new(func, maxFreq, id, noQueueing)
    ---@type Throttler
    local protoSelf = {
        ufoType = "Throttler",
        func = func,
        maxFreq = maxFreq or 1.0,
        noQueueing = noQueueing,
        id = tostring(id or "CACOPHONY"),
    }

    local zelf = deepcopy(self, protoSelf)
    
    zebug.trace:out(10,div, "I'm the first ID",id)

    return zelf
end

---@return function
function Throttler:asFunc()
    return function(...)
        self:exe(...)
    end
end

---@param maxFreq number how often are we allowed to execute the function (in seconds, decimals allowed) ex 1.5
---@param id string a unique identifier to ensure the same func doesn't get queued more than once
---@param func function the command to execute
---@return function - the same function but now limited to being called no more often than maxFreq AND at most one throttled call will enjoy a queue before exe
function Throttler:throttle(maxFreq, id, func)
    return self:new(func, maxFreq, id):asFunc()
end

---@param maxFreq number how often are we allowed to execute the function (in seconds, decimals allowed) ex 1.5
---@param id string a unique identifier to ensure the same func doesn't get queued more than once
---@param func function the command to execute
---@return function - the same function but now limited to being called no more often than maxFreq AND no queue for delayed calls
function Throttler:throttleAndNoQueue(maxFreq, id, func)
    return self:new(func, maxFreq, id, true):asFunc()
end

-- execute eventually (perhaps immediately) depending on the maxFreq param given to new()
---@param reportedElapsed number (optional) how long since this was last called (useful when the Bliz handlers provide ie, eg OnUpdate always has an "elapsed" param
---@return boolean true if the func was executed immediately.  false if the func was postponed or simply thrown away because it's already in the q
function Throttler:exe(...)
    local elapsed
    local runNow
    local previousTime = self.t0

    if reportedElapsed then -- was used in a previous version. left here in case I figure out the best way to add it back in.
        elapsed = reportedElapsed
    elseif previousTime then
        elapsed = time() - previousTime
    else
        elapsed = self.maxFreq
        runNow = true
    end

    runNow = runNow or (elapsed >= self.maxFreq)

    if runNow then
        zebug.info:out(10,div, "t", tFormat4(time()), "Immediately EXE", self.id, "elapsed",elapsed)
        self:doItNow(...)
        return true
    else
        -- do it later
        -- but have we already queued an execution for later?
        if self.isQueued or self.noQueueing then
            zebug.trace:out(10,div, "Discarding", self.id, "elapsed",elapsed)
        else
            self.isQueued = true
            local runWhen = self.maxFreq - elapsed
            local scheduledAt = time()
            counter = counter + 1
            zebug.info:out(10,div, "t", tFormat4(time()), "Scheduling for later", self.id, "elapsed",elapsed, "runWhen",runWhen, "count", counter)

            -- hopefully this pack/unpack won't impose TOO much of a performance hit.
            -- It happens at most only once within a maxFreq period
            local capturedArgs = {...}
            C_Timer.After(runWhen, function() -- using ... here is fail.  No args are passed from C_Timer.After into the func
                local prolapsed = time() - scheduledAt
                zebug.info:name("delayedExe"):out(15,div, "t", tFormat4(time()), "delayed EXE", self.id, "prolapsed", prolapsed, "count", counter)
                self:doItNow(unpack(capturedArgs))
            end)
        end
    end

    return false
end

function Throttler:doItNow(...)
    self.func(...)
    self.t0 = time() -- reset T0 to NOW!
    self.isQueued = false
end

