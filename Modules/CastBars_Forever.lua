--[[
    Castborn - Forever castbar overrides
    Loaded only by Castborn_Camelot.toc, after Modules/CastBars.lua.
]]
local CB = Castborn

-- Unregistering events on Blizzard's castbar taints it on the Mainline UI, so detach it from
-- the player instead. The Blizzard bar then has no unit to show and stays hidden.
function CB:HideBlizzardCastBar(silent)
    local frame = PlayerCastingBarFrame
    if frame and frame.SetUnit then
        frame:SetUnit(nil)
    end
    if not silent then
        CB:Print("Default Blizzard castbar hidden")
    end
end

-- Restoring needs Blizzard's own setup to run again
function CB:ShowBlizzardCastBar()
    CB:Print("Reload UI to fully restore Blizzard castbar (/reload)")
end
