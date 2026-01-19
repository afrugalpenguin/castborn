-- Modules/MultiDoTTracker.lua
local MultiDoTTracker = {}
Castborn.MultiDoTTracker = MultiDoTTracker

local frame = nil
local targetFrames = {}
local MAX_TARGETS = 5

local defaults = {
    enabled = true,
    displayMode = "panel",
    width = 220,
    rowHeight = 20,
    point = "CENTER",
    x = 580,
    y = -300,
    xPct = 0.32,
    yPct = -0.278,
    showCyclingIndicator = true,
}

local trackedTargets = {}
local testModeActive = false

local function CreateTargetRow(parent, index)
    local db = CastbornDB.multidot

    local row = CreateFrame("Frame", "Castborn_MultiDoT_Row" .. index, parent)
    row:SetSize(db.width - 4, db.rowHeight)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)

    row.dots = {}
    for i = 1, 6 do
        local dot = CreateFrame("Frame", nil, row)
        dot:SetSize(db.rowHeight - 4, db.rowHeight - 4)
        dot:SetPoint("LEFT", row, "LEFT", 5 + (i - 1) * (db.rowHeight - 2), 0)

        dot.icon = dot:CreateTexture(nil, "ARTWORK")
        dot.icon:SetAllPoints()
        dot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        dot.time = dot:CreateFontString(nil, "OVERLAY")
        dot.time:SetFont("Fonts\\ARIALN.TTF", 8, "OUTLINE")
        dot.time:SetPoint("BOTTOM", 0, -1)

        dot:Hide()
        row.dots[i] = dot
    end

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE")
    row.name:SetPoint("LEFT", row, "LEFT", 5 + 6 * (db.rowHeight - 2), 0)
    row.name:SetJustifyH("LEFT")

    row.urgency = row:CreateTexture(nil, "OVERLAY")
    row.urgency:SetSize(3, db.rowHeight)
    row.urgency:SetPoint("LEFT", 0, 0)
    row.urgency:SetColorTexture(0.2, 0.8, 0.2, 1)

    row:Hide()
    return row
end

local function CreateContainer()
    local db = CastbornDB.multidot

    frame = CreateFrame("Frame", "Castborn_MultiDoTTracker", UIParent, "BackdropTemplate")
    frame:SetSize(db.width, db.rowHeight * MAX_TARGETS + 18)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    frame.header = frame:CreateFontString(nil, "OVERLAY")
    frame.header:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE")
    frame.header:SetPoint("TOPLEFT", 4, -2)
    frame.header:SetText("DoT Targets")
    frame.header:SetTextColor(0.8, 0.8, 0.8, 1)

    for i = 1, MAX_TARGETS do
        local row = CreateTargetRow(frame, i)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -14 - (i - 1) * db.rowHeight)
        targetFrames[i] = row
    end

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, db, nil, "Multi-DoT")
    end

    return frame
end

local function OnCombatLogEvent(self, event, ...)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= UnitGUID("player") then return end

    local dotInfo = Castborn.SpellData and Castborn.SpellData:GetDoTInfo(spellId)
    if not dotInfo then return end

    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
        if not trackedTargets[destGUID] then
            trackedTargets[destGUID] = {
                name = destName,
                guid = destGUID,
                dots = {},
            }
        end

        -- Use duration from SpellData, fallback to 18 seconds
        local duration = dotInfo.duration or 18

        trackedTargets[destGUID].dots[spellId] = {
            expirationTime = GetTime() + duration,
            spellId = spellId,
            name = dotInfo.name,
        }

    elseif subEvent == "SPELL_AURA_REMOVED" then
        if trackedTargets[destGUID] then
            trackedTargets[destGUID].dots[spellId] = nil

            local hasDoTs = false
            for _ in pairs(trackedTargets[destGUID].dots) do
                hasDoTs = true
                break
            end
            if not hasDoTs then
                trackedTargets[destGUID] = nil
            end
        end

    elseif subEvent == "UNIT_DIED" then
        trackedTargets[destGUID] = nil
    end
end

local function ScanTargetDebuffs()
    local targetGUID = UnitGUID("target")
    if not targetGUID or not trackedTargets[targetGUID] then return end

    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime, source, _, _, spellId = UnitDebuff("target", i)
        if not name then break end

        if source == "player" and trackedTargets[targetGUID].dots[spellId] then
            trackedTargets[targetGUID].dots[spellId].expirationTime = expirationTime
        end
    end
end

local function GetUrgencyColor(remaining)
    if remaining <= 3 then
        return 1, 0.2, 0.2, 1
    elseif remaining <= 5 then
        return 1, 0.8, 0.2, 1
    else
        return 0.2, 0.8, 0.2, 1
    end
end

local function GetSortedTargets()
    local sorted = {}
    local currentTargetGUID = UnitGUID("target")

    for guid, data in pairs(trackedTargets) do
        -- Skip current target - that's what the regular DoT tracker is for
        if guid ~= currentTargetGUID then
            local minRemaining = 999
            for spellId, dot in pairs(data.dots) do
                local remaining = dot.expirationTime - GetTime()
                if remaining < minRemaining then
                    minRemaining = remaining
                end
            end

            table.insert(sorted, {
                guid = guid,
                name = data.name,
                dots = data.dots,
                urgency = minRemaining,
            })
        end
    end

    table.sort(sorted, function(a, b)
        return a.urgency < b.urgency
    end)

    return sorted
end

local function UpdateDisplay()
    -- Don't override test mode display
    if testModeActive then return end

    local db = CastbornDB.multidot
    if not db.enabled or not frame then
        if frame then frame:Hide() end
        return
    end

    for guid, data in pairs(trackedTargets) do
        for spellId, dot in pairs(data.dots) do
            if dot.expirationTime <= GetTime() then
                data.dots[spellId] = nil
            end
        end

        local hasDoTs = false
        for _ in pairs(data.dots) do
            hasDoTs = true
            break
        end

        if not hasDoTs then
            trackedTargets[guid] = nil
        end
    end

    ScanTargetDebuffs()

    local sorted = GetSortedTargets()

    if #sorted == 0 then
        frame:Hide()
        return
    end

    frame:Show()

    for i = 1, MAX_TARGETS do
        local row = targetFrames[i]
        local target = sorted[i]

        if target then
            row.name:SetText(target.name or "Unknown")

            row.urgency:SetColorTexture(GetUrgencyColor(target.urgency))

            local dotIndex = 1
            for spellId, dot in pairs(target.dots) do
                local dotFrame = row.dots[dotIndex]
                if dotFrame then
                    local icon = GetSpellTexture(spellId)
                    dotFrame.icon:SetTexture(icon)

                    local remaining = dot.expirationTime - GetTime()
                    if remaining > 0 then
                        dotFrame.time:SetText(string.format("%.0f", remaining))
                        dotFrame.time:SetTextColor(GetUrgencyColor(remaining))
                    else
                        dotFrame.time:SetText("")
                    end

                    dotFrame:Show()
                    dotIndex = dotIndex + 1
                end
            end

            for j = dotIndex, 6 do
                row.dots[j]:Hide()
            end

            -- Position name after the visible dots
            local db = CastbornDB.multidot
            local numDots = dotIndex - 1
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", 5 + numDots * (db.rowHeight - 2) + 2, 0)

            row:Show()
        else
            row:Hide()
        end
    end
end

Castborn:RegisterCallback("INIT", function()
    CastbornDB.multidot = Castborn:MergeDefaults(CastbornDB.multidot or {}, defaults)
end)

Castborn:RegisterCallback("READY", function()
    CreateContainer()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", OnCombatLogEvent)

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            UpdateDisplay()
            elapsed = 0
        end
    end)
end)

-- Test mode function
function Castborn:TestMultiDoT()
    local db = CastbornDB.multidot
    if not frame then return end  -- Show even if disabled for test mode

    testModeActive = true
    frame:Show()

    -- Class-specific test data
    local _, playerClass = UnitClass("player")
    local testTargets = {}

    if playerClass == "MAGE" then
        testTargets = {
            { name = "Mob A", urgency = 2.5, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_FlameBolt", remaining = 2.5 },
                { icon = "Interface\\Icons\\Spell_Nature_Polymorph", remaining = 35.0 },
            }},
            { name = "Mob B", urgency = 5.2, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_FlameBolt", remaining = 5.2 },
            }},
            { name = "Mob C", urgency = 11.0, dots = {
                { icon = "Interface\\Icons\\Spell_Nature_Polymorph", remaining = 42.0 },
            }},
        }
    elseif playerClass == "WARLOCK" then
        testTargets = {
            { name = "Mob A", urgency = 2.5, dots = {
                { icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", remaining = 2.5 },
                { icon = "Interface\\Icons\\Spell_Fire_Immolation", remaining = 8.0 },
            }},
            { name = "Mob B", urgency = 5.2, dots = {
                { icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", remaining = 5.2 },
                { icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", remaining = 12.0 },
            }},
            { name = "Mob C", urgency = 11.0, dots = {
                { icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", remaining = 11.0 },
            }},
        }
    elseif playerClass == "PRIEST" then
        testTargets = {
            { name = "Mob A", urgency = 2.5, dots = {
                { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", remaining = 2.5 },
            }},
            { name = "Mob B", urgency = 8.2, dots = {
                { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", remaining = 8.2 },
                { icon = "Interface\\Icons\\Spell_Shadow_DevouringPlague", remaining = 15.0 },
            }},
            { name = "Mob C", urgency = 14.0, dots = {
                { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", remaining = 14.0 },
            }},
        }
    elseif playerClass == "DRUID" then
        testTargets = {
            { name = "Mob A", urgency = 2.8, dots = {
                { icon = "Interface\\Icons\\Spell_Nature_StarFall", remaining = 2.8 },
                { icon = "Interface\\Icons\\Spell_Nature_InsectSwarm", remaining = 6.0 },
            }},
            { name = "Mob B", urgency = 5.1, dots = {
                { icon = "Interface\\Icons\\Spell_Nature_StarFall", remaining = 5.1 },
            }},
            { name = "Mob C", urgency = 9.0, dots = {
                { icon = "Interface\\Icons\\Ability_Druid_Disembowel", remaining = 9.0 },
            }},
        }
    elseif playerClass == "HUNTER" then
        testTargets = {
            { name = "Mob A", urgency = 3.1, dots = {
                { icon = "Interface\\Icons\\Ability_Hunter_Quickshot", remaining = 3.1 },
            }},
            { name = "Mob B", urgency = 7.5, dots = {
                { icon = "Interface\\Icons\\Ability_Hunter_Quickshot", remaining = 7.5 },
            }},
            { name = "Mob C", urgency = 12.0, dots = {
                { icon = "Interface\\Icons\\Ability_Hunter_Quickshot", remaining = 12.0 },
            }},
        }
    elseif playerClass == "ROGUE" then
        testTargets = {
            { name = "Mob A", urgency = 2.1, dots = {
                { icon = "Interface\\Icons\\Ability_Rogue_Rupture", remaining = 2.1 },
                { icon = "Interface\\Icons\\Ability_Rogue_DualWeild", remaining = 8.0 },
            }},
            { name = "Mob B", urgency = 6.5, dots = {
                { icon = "Interface\\Icons\\Ability_Rogue_Garrote", remaining = 6.5 },
            }},
            { name = "Mob C", urgency = 10.0, dots = {
                { icon = "Interface\\Icons\\Ability_Rogue_Rupture", remaining = 10.0 },
            }},
        }
    elseif playerClass == "WARRIOR" then
        testTargets = {
            { name = "Mob A", urgency = 3.0, dots = {
                { icon = "Interface\\Icons\\Ability_Gouge", remaining = 3.0 },
            }},
            { name = "Mob B", urgency = 7.2, dots = {
                { icon = "Interface\\Icons\\Ability_Gouge", remaining = 7.2 },
            }},
            { name = "Mob C", urgency = 12.0, dots = {
                { icon = "Interface\\Icons\\Ability_Gouge", remaining = 12.0 },
            }},
        }
    elseif playerClass == "SHAMAN" then
        testTargets = {
            { name = "Mob A", urgency = 2.5, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_FlameShock", remaining = 2.5 },
            }},
            { name = "Mob B", urgency = 6.0, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_FlameShock", remaining = 6.0 },
            }},
            { name = "Mob C", urgency = 10.5, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_FlameShock", remaining = 10.5 },
            }},
        }
    else
        -- Default for other classes
        testTargets = {
            { name = "Mob A", urgency = 2.5, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_SoulBurn", remaining = 2.5 },
            }},
            { name = "Mob B", urgency = 5.2, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_SoulBurn", remaining = 5.2 },
            }},
            { name = "Mob C", urgency = 11.0, dots = {
                { icon = "Interface\\Icons\\Spell_Fire_SoulBurn", remaining = 11.0 },
            }},
        }
    end

    for i, target in ipairs(testTargets) do
        local row = targetFrames[i]
        if row then
            row.name:SetText(target.name)

            -- Set urgency color
            local r, g, b = 0.2, 0.8, 0.2
            if target.urgency <= 3 then
                r, g, b = 1, 0.2, 0.2
            elseif target.urgency <= 5 then
                r, g, b = 1, 0.8, 0.2
            end
            row.urgency:SetColorTexture(r, g, b, 1)

            -- Show dots
            for j, dot in ipairs(target.dots) do
                local dotFrame = row.dots[j]
                if dotFrame then
                    dotFrame.icon:SetTexture(dot.icon)
                    dotFrame.time:SetText(string.format("%.0f", dot.remaining))

                    -- Color time based on remaining
                    if dot.remaining <= 3 then
                        dotFrame.time:SetTextColor(1, 0.2, 0.2, 1)
                    elseif dot.remaining <= 5 then
                        dotFrame.time:SetTextColor(1, 0.8, 0.2, 1)
                    else
                        dotFrame.time:SetTextColor(0.2, 0.8, 0.2, 1)
                    end
                    dotFrame:Show()
                end
            end

            -- Hide unused dot frames
            for j = #target.dots + 1, 6 do
                row.dots[j]:Hide()
            end

            row:Show()
        end
    end

    -- Hide unused rows
    for i = #testTargets + 1, MAX_TARGETS do
        if targetFrames[i] then targetFrames[i]:Hide() end
    end
end

-- End test mode
function Castborn:EndTestMultiDoT()
    testModeActive = false
    if frame then
        frame:Hide()
        for i = 1, MAX_TARGETS do
            if targetFrames[i] then targetFrames[i]:Hide() end
        end
    end
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("MultiDoT", function() Castborn:TestMultiDoT() end, function() Castborn:EndTestMultiDoT() end)
end)

Castborn:RegisterModule("MultiDoTTracker", MultiDoTTracker)
