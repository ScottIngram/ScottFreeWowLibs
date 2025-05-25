-- Pacifier.lua
-- throttle a function call so that it is only allowed to execute outside of combat

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole()
local zebug = Zebug:new(Zebug.TRACE)

---@class Pacifier
---@field id string a unique identifier to ensure the same func doesn't get queued more than once
---@field isWaiting boolean an execution is waiting in the queue
---@field mostRecentFunc function
Pacifier = { }

-------------------------------------------------------------------------------
-- class variables - shared between all instances
-------------------------------------------------------------------------------

local div = "ß"
local MAX_FREQUENCY = 1 -- second

local queue = {}
-------------------------------------------------------------------------------
-- Methods
-------------------------------------------------------------------------------

function Pacifier:pacify(owner, funcName)
    local func = owner[funcName]
    local callCounter = 0
    local ownersLabel = ((owner.getLabel and owner:getLabel()) or tostring(owner))
    local label = ownersLabel .. "->" .. funcName

    local wrapped
    wrapped = function(a,b,c,d,e)
        -- yeah, sorry about the vararg travesty, but, the above's "..." wouldn't be visible to the C_Timer function() and I don't want to incur the cost of pack/unpack
        if isInCombatLockdownQuiet(label) then
            callCounter = callCounter + 1
            local takeUhNumber = callCounter
            zebug.trace:owner(label):out(3, div, "IN COMBAT... delaying. callCounter",callCounter, "takeUhNumber",takeUhNumber)

            -- FUNC START
            C_Timer.After(MAX_FREQUENCY, function()
                if takeUhNumber == callCounter then
                    -- invoke the original function and pass in the "..." from the "wrapped" call, not the C_Timer call
                    zebug.trace:owner(label):out(3, div, "IN COMBAT... delaying AGAIN. callCounter",callCounter, "takeUhNumber",takeUhNumber)
                    wrapped(a,b,c,d,e)
                else
                    zebug.trace:owner(label):out(3, div, "limbo... DISCARD OLD CALL! callCounter",callCounter, "takeUhNumber",takeUhNumber)
                end
            end)
            -- FUNC END
        else
            zebug.trace:owner(label):out(3, div, "no combat... executing. callCounter",callCounter)
            func(a,b,c,d,e)
        end
    end

    return wrapped
end

---@param id string a unique identifier to ensure the same func doesn't get queued more than once
---@return Pacifier - a new instance of Pacifier dedicated to executing the given funtion but only when combat has stopped
function Pacifier:new(id)
    local self = deepcopy(self, {
        id = tostring(id or "CACOPHONY"),
    })
    
    zebug.trace:ifMe1st(self.id):out(5,div, "I'm the first ID",id)
    
    return self
end

-- delay a function call so that it is only executed outside of combat.
-- any previous function calls are discarded in deference to the most recent.
-- if subsequent requests happen during the same window, ensure only the first one is re-queued.
---@param func function the command to execute once combat has ended
function Pacifier:exe(func, reQueue)
    self.mostRecentFunc = func -- the func included in the most recent invocation replaces any previous one
    local qId = self.id

    if isInCombatLockdownQuiet(qId) then
        if self.isWaiting then
            zebug.trace:out(3, div, "IN COMBAT and also already waiting", qId)
            if reQueue then
                self:exe(self.mostRecentFunc, true)
            end
        else
            zebug.trace:out(3, div, "IN COMBAT so postponing", qId)
            self.isWaiting = true
            C_Timer.After(MAX_FREQUENCY, function()
                zebug.trace:out(3, div, "maybe combat, so trying", qId)
                self:exe(self.mostRecentFunc, true)
                zebug.trace:out(3, div, "maybe combat, so tried ", qId)
            end)
        end
    else
        zebug.trace:out(3, div, "no combat so immediately executing ->", qId)
        self.isWaiting = false
        self.mostRecentFunc()
    end
end
