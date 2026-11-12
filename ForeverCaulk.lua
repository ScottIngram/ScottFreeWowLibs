-- ForeverCaulk.lua
-- functions etc that exist in Retail but are missing from Forever.
-- this way I don't have to riddle my code with a bunch of shitty if/then checks :-) melt

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_NAMESPACE = ...
ADDON_NAMESPACE.Wormhole() -- Lua voodoo magic that replaces the current Global namespace with the addon's

if isForever() then

    print("ForeverCaulk is here")

    -------------------------------------------------------------------------------
    -- Missing Functions
    -------------------------------------------------------------------------------
    --print("ForeverCaulk 1... GetSpecialization",GetSpecialization)

    GetSpecialization = GetSpecialization or function()
        local className, classFile, classId = UnitClass("player")
        --print("ForeverCaulk.GetSpecialization() className",className, "classId",classId)
        return classId
    end

    --print("ForeverCaulk 2... GetSpecialization",GetSpecialization)

else
    print "Not isForever()"
end
