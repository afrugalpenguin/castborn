-- Modules/ProcTracker.lua (formerly BuffTracker)
-- Tracks important proc buffs and short-duration abilities
local ProcTracker = {}
Castborn.ProcTracker = ProcTracker

local frame = nil
local procFrames = {}
local MAX_PROCS = 8

-- Class-specific proc/buff defaults for TBC
local classProcs = {
    MAGE = {
        { spellId = 12536, name = "Clearcasting" },      -- Arcane Concentration
        { spellId = 12042, name = "Arcane Power" },
        { spellId = 12472, name = "Icy Veins" },
        { spellId = 12043, name = "Presence of Mind" },
        { spellId = 29977, name = "Combustion" },
    },
    WARLOCK = {
        { spellId = 17941, name = "Shadow Trance" },     -- Nightfall proc
        { spellId = 34939, name = "Backlash" },
        { spellId = 18095, name = "Nightfall" },
    },
    PRIEST = {
        { spellId = 14751, name = "Inner Focus" },
        { spellId = 15271, name = "Spirit Tap" },
        { spellId = 33151, name = "Surge of Light" },
    },
    DRUID = {
        { spellId = 16870, name = "Clearcasting" },      -- Omen of Clarity
        { spellId = 16886, name = "Nature's Grace" },
        { spellId = 17116, name = "Nature's Swiftness" },
    },
    SHAMAN = {
        { spellId = 16246, name = "Clearcasting" },      -- Elemental Focus
        { spellId = 16188, name = "Nature's Swiftness" },
        { spellId = 16280, name = "Flurry" },
    },
    PALADIN = {
        { spellId = 20050, name = "Vengeance" },          -- Ret talent proc
        { spellId = 20375, name = "Seal of Command" },
        { spellId = 31842, name = "Divine Illumination" },
        { spellId = 20216, name = "Divine Favor" },
    },
    HUNTER = {
        { spellId = 6150, name = "Quick Shots" },
        { spellId = 3045, name = "Rapid Fire" },
        { spellId = 34720, name = "Thrill of the Hunt" },
    },
    WARRIOR = {
        { spellId = 12880, name = "Enrage" },
        { spellId = 12966, name = "Flurry" },
        { spellId = 12292, name = "Death Wish" },
        { spellId = 12328, name = "Sweeping Strikes" },
    },
    ROGUE = {
        { spellId = 13750, name = "Adrenaline Rush" },
        { spellId = 13877, name = "Blade Flurry" },
        { spellId = 5171, name = "Slice and Dice" },
        { spellId = 14177, name = "Cold Blood" },
    },
}

local defaults = {
    enabled = true,
    width = 200,
    iconSize = 28,
    spacing = 4,
    orientation = "HORIZONTAL",
    point = "CENTER",
    x = 0,
    y = -255,
    xPct = 0,
    yPct = -0.237,
    showDuration = true,
    showStacks = true,
    trackedSpells = {},  -- Will be populated with class defaults on first load
    anchored = false,
}

local function CreateProcFrame(parent, index)
    local size = CastbornDB.procs.iconSize or 28

    -- Use Button for Masque compatibility
    local f = CreateFrame("Button", "Castborn_Proc" .. index, parent)
    f:SetSize(size, size)

    -- Icon texture (sublevel 1 to be above Normal texture)
    f.icon = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.Icon = f.icon  -- Masque alias

    -- Normal texture (border) for Masque
    f.Normal = f:CreateTexture(nil, "BORDER")
    f.Normal:SetPoint("TOPLEFT", -1, 1)
    f.Normal:SetPoint("BOTTOMRIGHT", 1, -1)
    f.Normal:SetColorTexture(0.3, 0.3, 0.3, 1)
    f:SetNormalTexture(f.Normal)

    f.duration = f:CreateFontString(nil, "OVERLAY")
    f.duration:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    f.duration:SetPoint("BOTTOM", 0, -2)

    f.stacks = f:CreateFontString(nil, "OVERLAY")
    f.stacks:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    f.stacks:SetPoint("BOTTOMRIGHT", -1, 1)

    f.glow = f:CreateTexture(nil, "OVERLAY")
    f.glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("TOPLEFT", -6, 6)
    f.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    f.glow:SetVertexColor(1, 0.8, 0.2, 0)

    -- Register with Masque if available
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton("procs", f, {
            Icon = f.icon,
            Normal = f.Normal,
        })
    end

    f:Hide()
    return f
end

local function CreateContainer()
    local db = CastbornDB.procs

    frame = CreateFrame("Frame", "Castborn_ProcTracker", UIParent)
    frame:SetSize(db.width, db.iconSize + 4)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    for i = 1, MAX_PROCS do
        procFrames[i] = CreateProcFrame(frame, i)
    end

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, db, function(f)
            CastbornDB.procs = CastbornDB.procs or {}
            CastbornDB.procs.anchored = false
        end, "Procs Tracker")
    end

    -- Apply position only if not anchored
    if not db.anchored or db.anchored == false then
        Castborn:ApplyPosition(frame, "procs")
    end

    frame:Hide()  -- Start hidden, will show when procs are active
    return frame
end

local function UpdateLayout()
    local db = CastbornDB.procs
    local size = db.iconSize or 28
    local spacing = db.spacing or 4
    local isHorizontal = db.orientation == "HORIZONTAL"

    for i, f in ipairs(procFrames) do
        f:ClearAllPoints()
        f:SetSize(size, size)

        if isHorizontal then
            f:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + spacing), 0)
        else
            f:SetPoint("TOP", frame, "TOP", 0, -((i - 1) * (size + spacing)))
        end
    end
end

local function PulseGlow(procFrame)
    local elapsed = 0
    procFrame.glow:SetAlpha(0.7)
    procFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local alpha = math.sin(elapsed * 6) * 0.3 + 0.4
        alpha = math.max(0, math.min(1, alpha))
        procFrame.glow:SetAlpha(alpha)
        if elapsed > 0.75 then
            procFrame:SetScript("OnUpdate", nil)
            procFrame.glow:SetAlpha(0)
        end
    end)
end

local trackedProcs = {}
local testModeActive = false

local function ScanProcs()
    -- Don't override test mode display
    if testModeActive then return end

    local db = CastbornDB.procs
    if not db.enabled or not frame then
        if frame then frame:Hide() end
        return
    end

    local tracked = {}
    for _, spell in ipairs(db.trackedSpells or {}) do
        tracked[spell.spellId] = spell
    end

    local activeProcs = {}
    for i = 1, 40 do
        local name, icon, stacks, _, duration, expirationTime, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end

        if tracked[spellId] then
            table.insert(activeProcs, {
                name = name,
                icon = icon,
                stacks = stacks,
                duration = duration,
                expirationTime = expirationTime,
                spellId = spellId,
                isNew = not trackedProcs[spellId],
            })
        end
    end

    -- Hide frame if no active procs
    if #activeProcs == 0 then
        frame:Hide()
        trackedProcs = {}
        return
    end

    frame:Show()
    -- Hide drag indicator when not in positioning mode
    if frame.dragIndicator and CastbornDB.locked ~= false then
        frame.dragIndicator:Hide()
    end

    local newTracked = {}
    for _, proc in ipairs(activeProcs) do
        newTracked[proc.spellId] = true
    end
    trackedProcs = newTracked

    for i = 1, MAX_PROCS do
        local procFrame = procFrames[i]
        local proc = activeProcs[i]

        if proc then
            procFrame.icon:SetTexture(proc.icon)
            procFrame.expirationTime = proc.expirationTime

            if db.showDuration and proc.expirationTime and proc.expirationTime > 0 then
                local remaining = proc.expirationTime - GetTime()
                if remaining > 0 then
                    procFrame.duration:SetText(string.format("%.1f", remaining))
                else
                    procFrame.duration:SetText("")
                end
            else
                procFrame.duration:SetText("")
                procFrame.expirationTime = nil
            end

            if db.showStacks and proc.stacks and proc.stacks > 1 then
                procFrame.stacks:SetText(proc.stacks)
            else
                procFrame.stacks:SetText("")
            end

            if proc.isNew then
                PulseGlow(procFrame)
            end

            procFrame:Show()
        else
            procFrame:Hide()
            procFrame.expirationTime = nil
        end
    end
end

Castborn:RegisterCallback("INIT", function()
    CastbornDB.procs = Castborn:MergeDefaults(CastbornDB.procs or {}, defaults)

    -- Populate with class-specific procs if trackedSpells is empty
    if #(CastbornDB.procs.trackedSpells or {}) == 0 then
        local _, playerClass = UnitClass("player")
        if classProcs[playerClass] then
            CastbornDB.procs.trackedSpells = classProcs[playerClass]
        end
    end
end)

Castborn:RegisterCallback("READY", function()
    CreateContainer()
    UpdateLayout()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" then
            ScanProcs()
        end
    end)

    -- OnUpdate for smooth duration countdown
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            elapsed = 0
            local db = CastbornDB.procs
            if not db.showDuration then return end

            for i = 1, MAX_PROCS do
                local procFrame = procFrames[i]
                if procFrame:IsShown() and procFrame.expirationTime then
                    local remaining = procFrame.expirationTime - GetTime()
                    if remaining > 0 then
                        procFrame.duration:SetText(string.format("%.1f", remaining))
                    else
                        procFrame.duration:SetText("")
                    end
                end
            end
        end
    end)

    ScanProcs()
end)

-- Test mode function
function Castborn:TestProcs()
    local db = CastbornDB.procs
    if not frame then return end

    testModeActive = true
    frame:Show()

    -- Class-specific test procs
    local _, playerClass = UnitClass("player")
    local testProcs = {}

    if playerClass == "MAGE" then
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", duration = 15, remaining = 12.3 },  -- Clearcasting
            { icon = "Interface\\Icons\\Spell_Nature_Lightning", duration = 15, remaining = 8.1 },  -- Arcane Power
        }
    elseif playerClass == "WARLOCK" then
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Shadow_Twilight", duration = 10, remaining = 7.2 },  -- Shadow Trance
            { icon = "Interface\\Icons\\Spell_Fire_Fire", duration = 8, remaining = 4.5 },  -- Backlash
        }
    elseif playerClass == "PRIEST" then
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Frost_WindWalkOn", duration = 0, remaining = 0 },  -- Inner Focus
            { icon = "Interface\\Icons\\Spell_Shadow_Requiem", duration = 15, remaining = 11.4 },  -- Spirit Tap
        }
    elseif playerClass == "DRUID" then
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", duration = 15, remaining = 9.8 },  -- Clearcasting
            { icon = "Interface\\Icons\\Spell_Nature_NaturesBlessing", duration = 15, remaining = 5.2 },  -- Nature's Grace
        }
    elseif playerClass == "SHAMAN" then
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", duration = 15, remaining = 11.1 },  -- Clearcasting
            { icon = "Interface\\Icons\\Spell_Nature_BloodLust", duration = 10, remaining = 6.7 },  -- Flurry
        }
    elseif playerClass == "WARRIOR" then
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", duration = 12, remaining = 8.3 },  -- Enrage
            { icon = "Interface\\Icons\\Ability_GhoulFrenzy", duration = 15, remaining = 4.1 },  -- Flurry
        }
    elseif playerClass == "ROGUE" then
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", duration = 15, remaining = 10.5 },  -- Adrenaline Rush
            { icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", duration = 15, remaining = 6.9 },  -- Blade Flurry
        }
    elseif playerClass == "PALADIN" then
        testProcs = {
            { icon = "Interface\\Icons\\Ability_Racial_Avatar", duration = 8, remaining = 5.2 },  -- Vengeance
            { icon = "Interface\\Icons\\Spell_Holy_Heal", duration = 0, remaining = 0 },  -- Divine Favor
        }
    elseif playerClass == "HUNTER" then
        testProcs = {
            { icon = "Interface\\Icons\\Ability_Warrior_InnerRage", duration = 12, remaining = 7.8 },  -- Quick Shots
            { icon = "Interface\\Icons\\Ability_Hunter_RunningShot", duration = 15, remaining = 11.3 },  -- Rapid Fire
        }
    else
        testProcs = {
            { icon = "Interface\\Icons\\Spell_Shadow_ManaBurn", duration = 15, remaining = 12.3 },
            { icon = "Interface\\Icons\\Spell_Nature_Lightning", duration = 10, remaining = 5.1 },
        }
    end

    for i, proc in ipairs(testProcs) do
        local procFrame = procFrames[i]
        if procFrame then
            local size = db.iconSize or 28
            local spacing = db.spacing or 4
            procFrame:ClearAllPoints()
            procFrame:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + spacing), 0)
            procFrame:SetSize(size, size)

            procFrame.icon:SetTexture(proc.icon)
            if proc.remaining > 0 then
                procFrame.duration:SetText(string.format("%.1f", proc.remaining))
            else
                procFrame.duration:SetText("")
            end
            procFrame.stacks:SetText("")

            -- Show glow effect
            PulseGlow(procFrame)

            procFrame:Show()
        end
    end

    -- Hide remaining frames
    for i = #testProcs + 1, MAX_PROCS do
        if procFrames[i] then procFrames[i]:Hide() end
    end
end

-- End test mode
function Castborn:EndTestProcs()
    testModeActive = false
    if frame then
        frame:Hide()
        for i = 1, MAX_PROCS do
            if procFrames[i] then procFrames[i]:Hide() end
        end
    end
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Procs", function() Castborn:TestProcs() end, function() Castborn:EndTestProcs() end)

    -- If player castbar already exists and we should be anchored, attach now
    local cfg = CastbornDB.procs
    if cfg and cfg.anchored ~= false and Castborn.Anchoring and frame then
        local playerCastbar = Castborn.castbars and Castborn.castbars.player
        if playerCastbar then
            Castborn.Anchoring:ReattachToCastbar(frame, CastbornDB.procs, "BOTTOM", -2)
        end
    end
end)

-- Listen for player castbar creation
Castborn:RegisterCallback("PLAYER_CASTBAR_READY", function(castbar)
    -- Anchor BELOW the player castbar if configured
    if frame and CastbornDB.procs and CastbornDB.procs.anchored ~= false and Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(frame, CastbornDB.procs, "BOTTOM", -2)
    end
end)

-- Detach Proc tracker from castbar
Castborn:RegisterCallback("DETACH_PROCS", function()
    if not frame then return end
    if Castborn.Anchoring then
        Castborn.Anchoring:DetachFromCastbar(frame, CastbornDB.procs)
    end
    Castborn:Print("Proc Tracker detached from castbar")
end)

-- Reattach Proc tracker to castbar
Castborn:RegisterCallback("REATTACH_PROCS", function()
    if not frame then return end
    if Castborn.Anchoring then
        Castborn.Anchoring:ReattachToCastbar(frame, CastbornDB.procs, "BOTTOM", -2)
    end
    Castborn:Print("Proc Tracker anchored to castbar")
end)

Castborn:RegisterModule("ProcTracker", ProcTracker)
