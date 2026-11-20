--[[
    Castborn - tracking panel on Forever
    The /cbapi probe (build 1.60.1) found XP and reputation plain in and out of combat, so the
    shared reads and maths stand. Only two things differ:
    - GetWatchedFactionInfo is missing; the watched faction comes from C_Reputation.
    - Blizzard's XP and reputation bars are the StatusTrackingBar containers, which Edit Mode
      manages. Reparenting an Edit Mode system frame risks taint and Edit Mode errors, so they
      are faded and made click-through instead.
    Loaded only by Castborn_Camelot.toc, after TrackingPanel.lua.
]]

local TrackingPanel = Castborn.TrackingPanel

-- Thresholds and standing are absolute, as GetWatchedFactionInfo's are on TBC
function TrackingPanel:ReadWatchedFaction()
    local data = C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if not data or not data.name then return nil end
    return {
        name = data.name,
        reaction = data.reaction,
        min = data.currentReactionThreshold,
        max = data.nextReactionThreshold,
        value = data.currentStanding,
    }
end

function TrackingPanel:GetBlizzardBars()
    return {
        { name = "MainStatusTrackingBarContainer", mode = "alpha" },
        { name = "SecondaryStatusTrackingBarContainer", mode = "alpha" },
    }
end
