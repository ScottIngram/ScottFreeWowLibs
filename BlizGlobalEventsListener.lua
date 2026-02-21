-- BlizGlobalEventsListener.lua
-- register callbacks for global (non-frame) events

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_SYMBOL_TABLE = ...
ADDON_SYMBOL_TABLE.Wormhole()
local zebug = Zebug:new(Zebug.WARN)

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
function BlizGlobalEventsListener:register(zelf, eventHandlers, handlersForAddonLoadedEvents)
    local dispatcher = function(listenerFrame, eventName, ...)
        if not counter[eventName] then
            counter[eventName] = 1
        else
            counter[eventName] = counter[eventName] + 1
        end

        -- pass along the args provided by the Bliz event as "..."
        eventHandlers[eventName](zelf, eventName, counter[eventName], ...)
    end

    local eventListenerFrame = CreateFrame(FrameType.FRAME, ADDON_NAME.."BlizGlobalEventsListener")
    eventListenerFrame:SetScript(Script.ON_EVENT, dispatcher)

    --
    -- ADDON_LOADED - register handlers for listed addons - each addon will trigger its own ADDON_LOADED event
    --

    local oldHandler = eventHandlers.ADDON_LOADED -- preserve the existing handler (if any) before we create a new handler
    local new_ADDON_LOADED_handler = function(zelf, eventName, count, loadedAddonName)
        --[START CALLBACK]--
        if oldHandler then
            zebug.warn:print("triggering the existing ADDON_LOADED handler", oldHandler)
            oldHandler(zelf)
        end

        if not handlersForAddonLoadedEvents then return end

        -- find a handler for the addon that just triggered the ADDON_LOADED event
        for addonName, handler in pairs(handlersForAddonLoadedEvents) do
            zebug.trace:name("dispatcher"):print("loaded",loadedAddonName, "comparing to",addonName, "handler",handler)
            if addonName == loadedAddonName then
                zebug.info:print("invoking", addonName)
                handler(zelf, addonName)
                handlersForAddonLoadedEvents[addonName] = nil
                break
            end
        end
        --[END CALLBACK]--
    end

    eventHandlers.ADDON_LOADED = new_ADDON_LOADED_handler

    -- handle GENERIC events

    for eventName, _ in pairs(eventHandlers) do
        zebug.info:print("registering ",eventName)
        eventListenerFrame:RegisterEvent(eventName)
    end

end
