-- BlizGlobalEventsListener.lua
-- register callbacks for global (non-frame) events

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole()
local zebug = Zebug:new(Zebug.OUTPUT.WARN)

---@class BlizGlobalEventsListener
BlizGlobalEventsListener = {}

local counter = {}

-------------------------------------------------------------------------------
-- Event Handler Registration
-------------------------------------------------------------------------------

---@param zelf table will act as the "self" object in all eventHandlers
---@param eventHandlers table<string, function> key -> "EVENT_NAME" , value -> handlerCallback
---@param addonLoadedHandlers table<string, function> key -> "OtherAddonName" , value -> funcToCallWhenOtherAddonLoads
-- Note: addons that load before yours will not be handled.  Use C_AddOns.IsAddOnLoaded(addonName) instead
function BlizGlobalEventsListener:register(zelf, eventHandlers, addonLoadedHandlers)
    local dispatcher = function(listenerFrame, eventName, ...)
        if not counter[eventName] then
            counter[eventName] = 1
        else
            counter[eventName] = counter[eventName] + 1
        end

        -- pass the counter as the last arg
        if select("#", ...) == 0 then
            -- no args were passed in from the Bliz event, so don't include "..."
            eventHandlers[eventName](zelf, eventName, counter[eventName])
        else
            -- pass along the args provided by the Bliz event as "..."
            --print("---> eventName",eventName, "counter",counter[eventName])
            eventHandlers[eventName](zelf, ..., eventName, counter[eventName])
        end
    end

    local eventListenerFrame = CreateFrame(FrameType.FRAME, ADDON_NAME.."BlizGlobalEventsListener")
    eventListenerFrame:SetScript(Script.ON_EVENT, dispatcher)

    -- handle the ADDON_LOADED event for specific addons

    local oldHandler = eventHandlers.ADDON_LOADED
    local newHandler = function(zelf, loadedAddonName)
        --[START CALLBACK]--
        if oldHandler then
            zebug.trace:print("triggering the existing ADDON_LOADED handler", oldHandler)
            oldHandler(zelf)
        end

        if not addonLoadedHandlers then return end

        -- find a handler for the addon that just triggered the ADDON_LOADED event
        for addonName, handler in pairs(addonLoadedHandlers) do
            zebug.trace:name("dispatcher"):print("loaded",loadedAddonName, "comparing to",addonName, "handler",handler)
            if addonName == loadedAddonName then
                zebug.info:print("invoking", addonName)
                handler(zelf, addonName)
            end
        end
        --[END CALLBACK]--
    end

    eventHandlers.ADDON_LOADED = newHandler

    -- handle GENERIC events

    for eventName, _ in pairs(eventHandlers) do
        zebug.info:print("registering ",eventName)
        eventListenerFrame:RegisterEvent(eventName)
    end

end
