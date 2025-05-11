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
---@field isQueued boolean an execution is waiting in the queue
---@field func function the command to execute
---@field maxFreq number how often are we allowed to execute the function (in seconds, decimals allowed) ex 1.5
---@field id string a unique identifier to ensure the same func doesn't get queued more than once
Throttler = { }

-------------------------------------------------------------------------------
-- class variables - shared between all instances
-------------------------------------------------------------------------------

local div = "œ"
local exeId = 1

-------------------------------------------------------------------------------
-- Methods
-------------------------------------------------------------------------------

---@param func function the command to execute
---@param maxFreq number how often are we allowed to execute the function (in seconds, decimals allowed) ex 1.5
---@param id string a unique identifier to ensure the same func doesn't get queued more than once
---@return Throttler - a new instance of Throttler deadicating to executing the given funtion no more often that maxFreq
function Throttler:new(func, maxFreq, id)
    local zelf = deepcopy(self, {
        func = func,
        maxFreq = maxFreq or 1.0,
        id = tostring(id or "CACOPHONY"),
    })
    
    zebug.trace:ifMe1st(self.id):out(5,div, "I'm the first ID",id)
    
    return zelf
end

function Throttler:asFunc()
    return function(...)
        self:exe(...)
    end
end

-- execute eventually (perhaps immediately) depending on the maxFreq param given to new()
---@param reportedElapsed number (optional) how long since this was last called (useful when the Bliz handlers provide ie, eg OnUpdate always has an "elapsed" param
---@return boolean true if the func was executed immediately.  false if the func was postponed or simply thrown away because it's already in the q
function Throttler:exe(...)
    local elapsed
    local runNow
    local previousTime = self.t0

    if reportedElapsed then
        elapsed = reportedElapsed
    elseif previousTime then
        elapsed = time() - previousTime
    else
        runNow = true
    end

    runNow = runNow or (elapsed >= self.maxFreq)

    if runNow then
        zebug.info:ifMe1st(self.id):out(5,div, "t", time(), "Immediately EXE", self.id, "elapsed",elapsed)
        self:doItNow(...)
        return true
    else
        -- do it later
        -- but have we already queued an execution for later?
        if self.isQueued then
            zebug.trace:ifMe1st(self.id):out(5,div, "t", time(), "Discarding", self.id, "elapsed",elapsed)
        else
            self.isQueued = true
            local runWhen = self.maxFreq - elapsed
            local scheduledAt = time()
            exeId = exeId + 1
            zebug.info:ifMe1st(self.id):out(5,div, "t", time(), "Scheduling for later", self.id, "elapsed",elapsed, "runWhen",runWhen, "xId", exeId)

            -- hopefully this pack/unpack won't impose TOO much of a performance hit.
            -- It happens at most only once within a maxFreq period
            local capturedArgs = {...}
            C_Timer.After(runWhen, function() -- using ... here is fail.  No args are passed from After into the func
                local prolapsed = time() - scheduledAt
                zebug.info:ifMe1st(self.id):name("exe"):out(7,div, "t", time(), "delayed EXE", self.id, "prolapsed", prolapsed, "xId", exeId)
                self:doItNow(unpack(capturedArgs), "delayed")
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

