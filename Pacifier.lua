-- Pacifier.lua
-- throttle a function call so that it is only allowed to execute outside of combat

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole()
local zebug = Zebug:new(Zebug.WARN)

---@class Pacifier
---@field id string a unique identifier to ensure the same func doesn't get queued more than once
---@field isWaiting boolean an execution is waiting in the queue
---@field mostRecentFunc function
Pacifier = { }

-------------------------------------------------------------------------------
-- class variables - shared between all instances
-------------------------------------------------------------------------------

local div = "+"
local POLLING_FREQUENCY = 0.125
local queue = {}
local counter = 0
local isPolling = false

-------------------------------------------------------------------------------
-- Methods
-------------------------------------------------------------------------------

---@return function the incoming func that has now been wrapped so that it will be postponed until combat (if any) ends
---@param func function a call that would cause problems if it were to execute during combat
---@param userMsg string|nil names/describes the action.  if provided, will be included in a larger message displayed to the user explaining why the action is being delayed.
function Pacifier:wrap(func, userMsg)
    assert(func, "func arg is nil")

    -- "instance" variables - shared between all invocations of a single pacified method
    local alreadySaidMsg
    local userMsgOriginal = userMsg

    local wrapped = function(...)
        if isInCombatLockdownQuiet(userMsg) then
            zebug.trace:owner(userMsg):out(3, div, "IN COMBAT... queueing.")

            -- if the user spams the action, display the message only the first time
            if userMsg and not alreadySaidMsg then
                alreadySaidMsg = true
                msgUser(L10N.WAITING_UNTIL_COMBAT_ENDS .. userMsg)
            end

            -- put the func call into a queue to be performed only once combat ends
            local packedArgs = {...}
            local callback = function()
                counter = counter + 1
                zebug.info:owner(userMsgOriginal):out(3, div, "combat ended... executing. counter",counter, " alreadySaidMsg", alreadySaidMsg, "userMsgOriginal",userMsgOriginal, "userMsg",userMsg)
                if userMsg and alreadySaidMsg then
                    alreadySaidMsg = false
                    msgUser(L10N.COMBAT_HAS_ENDED_SO_NOW_WE_CAN .. userMsg)
                end
                -- invoke the original, unwrapped function
                func(unpack(packedArgs))
            end

            queue[#queue + 1] = callback
            startAmyPoller(userMsgOriginal)
        else
            -- don't queue. execute immediately
            func(...)
        end
    end

    return wrapped
end

function startAmyPoller(msg)
    if not isPolling then
        isPolling = true
        amyPoller(msg)
    end
end

-- loop until combat ends
function amyPoller(msg)
    if isInCombatLockdownQuiet(msg or "Some combat sensitive action") then
        C_Timer.After(POLLING_FREQUENCY, amyPoller)
    else
        consumeQueue()
    end
end

function consumeQueue()
    if not queue then return end

    -- perform the function calls in the order they were received.
    -- time each function call so they spread evenly over 1 second
    local delay = 1.0 / #queue
    for i, func in ipairs(queue) do
        C_Timer.After(delay * i, function()
            if isInCombatLockdownQuiet("pacifier double-check") then
                if i == 1 then
                    zebug.warn:event("Combat Lockdown"):name("Pacifier"):print("Tried to delay invocation until combat ended but then combat started again.  Discarding", #queue, "delayed calls.")
                end
            else
                func()
            end
        end)
    end

    --queue = {} -- because table.clear(queue) isn't a thing in WoW's lua
    wipe(queue)
    isPolling = false
end
