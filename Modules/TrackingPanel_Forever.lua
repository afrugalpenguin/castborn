--[[
    Castborn - tracking panel on Forever
    The /cbapi probe (build 1.60.1) found XP and reputation plain in and out of combat, so the
    shared reads and maths stand. Only two things differ:
    - The old reputation globals (GetWatchedFactionInfo, GetNumFactions, GetFactionInfo) are
      missing, so every reputation read (watched, by ID, the picker's list) uses C_Reputation.
    - Blizzard's XP and reputation bars are the StatusTrackingBar containers, which Edit Mode
      manages. Reparenting an Edit Mode system frame risks taint and Edit Mode errors, so they
      are faded and made click-through instead.
    Loaded only by Castborn_Camelot.toc, after TrackingPanel.lua.
]]

local TrackingPanel = Castborn.TrackingPanel

-- Thresholds and standing are absolute, as GetWatchedFactionInfo's are on TBC
local function ToReputation(data)
    if not data or not data.name then return nil end
    return {
        factionID = data.factionID,
        name = data.name,
        reaction = data.reaction,
        min = data.currentReactionThreshold,
        max = data.nextReactionThreshold,
        value = data.currentStanding,
    }
end

function TrackingPanel:ReadWatchedFaction()
    local fn = C_Reputation and C_Reputation.GetWatchedFactionData
    return ToReputation(fn and fn())
end

function TrackingPanel:ReadFactionByID(factionID)
    local fn = C_Reputation and C_Reputation.GetFactionDataByID
    return ToReputation(fn and fn(factionID))
end

-- GetNumFactions and GetFactionInfo are missing too; same rules as on TBC
function TrackingPanel:ReadKnownFactions()
    local list = {}
    if not (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex) then
        return list
    end
    local isActive = C_Reputation.IsFactionActive
    local underInactive = false
    for i = 1, C_Reputation.GetNumFactions() do
        local data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.isHeader then
            underInactive = data.name ~= nil and data.name == FACTION_INACTIVE
        elseif data and data.name and data.factionID and data.factionID ~= 0 and not underInactive
                and not (isActive and not isActive(i)) then
            list[#list + 1] = { id = data.factionID, name = data.name }
        end
    end
    return list
end

function TrackingPanel:GetBlizzardBars()
    return {
        { name = "MainStatusTrackingBarContainer", mode = "alpha" },
        { name = "SecondaryStatusTrackingBarContainer", mode = "alpha" },
    }
end
