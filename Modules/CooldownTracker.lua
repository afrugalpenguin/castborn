-- Modules/CooldownTracker.lua
local CooldownTracker = {}
Castborn.CooldownTracker = CooldownTracker

local frame = nil
local cdFrames = {}
local MAX_COOLDOWNS = 8

local defaults = {
    enabled = true,
    iconSize = 36,
    spacing = 4,
    point = "CENTER",
    x = -450,
    y = -300,
    xPct = -0.234,
    yPct = -0.278,
    showTime = true,
    trackedSpells = {},
    anchored = true,
    anchorPosition = "LEFT",  -- LEFT, RIGHT, TOP, BOTTOM
    growDirection = "LEFT",   -- LEFT or RIGHT
    showReadyGlow = true,     -- Animated edge glow when ready
}

local function CreateCooldownFrame(parent, index)
    local size = CastbornDB.cooldowns.iconSize or 32

    -- Use Button frame for Masque compatibility
    local f = CreateFrame("Button", "Castborn_CD" .. index, parent)
    f:SetSize(size, size)

    -- Icon texture
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.Icon = f.icon  -- Masque alias

    -- Normal texture (border) for Masque
    f.Normal = f:CreateTexture(nil, "BORDER")
    f.Normal:SetPoint("TOPLEFT", -1, 1)
    f.Normal:SetPoint("BOTTOMRIGHT", 1, -1)
    f.Normal:SetColorTexture(0.3, 0.3, 0.3, 1)
    f:SetNormalTexture(f.Normal)

    -- Cooldown frame
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetHideCountdownNumbers(false)
    f.Cooldown = f.cooldown  -- Masque alias

    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    f.time:SetPoint("CENTER")

    -- Glow effect using layered textures for soft glow look
    f.glowOuter = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.glowOuter:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.glowOuter:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.glowOuter:SetBlendMode("ADD")
    f.glowOuter:SetPoint("TOPLEFT", -8, 8)
    f.glowOuter:SetPoint("BOTTOMRIGHT", 8, -8)
    f.glowOuter:SetVertexColor(1, 0.8, 0.3, 0)
    f.glow = f.glowOuter  -- Keep reference for existing code


    -- Register with Masque if available
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton("cooldowns", f, {
            Icon = f.icon,
            Cooldown = f.cooldown,
            Normal = f.Normal,
        })
    end

    f:Hide()
    return f
end

local function CreateContainer()
    local db = CastbornDB.cooldowns

    frame = CreateFrame("Frame", "Castborn_CooldownTracker", UIParent)
    frame:SetSize(db.iconSize * MAX_COOLDOWNS + db.spacing * (MAX_COOLDOWNS - 1), db.iconSize + 4)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    for i = 1, MAX_COOLDOWNS do
        cdFrames[i] = CreateCooldownFrame(frame, i)
    end

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, db, nil, "Cooldowns")
    end

    frame:Hide()  -- Start hidden, will show when cooldowns are tracked
    return frame
end

-- Static glow for ready cooldowns
local function StartEdgePulse(cdFrame)
    if cdFrame.edgePulseActive then return end
    cdFrame.edgePulseActive = true
    cdFrame.glow:SetAlpha(0.3)
end

local function StopEdgePulse(cdFrame)
    if not cdFrame.edgePulseActive then return end
    cdFrame.edgePulseActive = false
    cdFrame.glow:SetAlpha(0)
end

local function UpdateLayout()
    local db = CastbornDB.cooldowns
    local size = db.iconSize or 32
    local spacing = db.spacing or 4

    for i, f in ipairs(cdFrames) do
        f:ClearAllPoints()
        f:SetSize(size, size)
        f:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + spacing), 0)
    end
end

local lastCooldownDuration = {}
local testModeActive = false

local function UpdateCooldowns()
    -- Don't override test mode display
    if testModeActive then return end

    local db = CastbornDB.cooldowns
    if not db.enabled or not frame then
        if frame then frame:Hide() end
        return
    end

    local visibleIndex = 0
    for i, spell in ipairs(db.trackedSpells or {}) do
        -- Skip disabled spells
        if spell.enabled == false then
            -- do nothing
        -- Skip spells the player doesn't know
        elseif not Castborn:IsSpellKnown(spell.spellId) then
            -- Hide this frame if it was previously shown
            if cdFrames[i] then cdFrames[i]:Hide() end
        else
            visibleIndex = visibleIndex + 1
            local cdFrame = cdFrames[visibleIndex]
            if not cdFrame then break end

            local start, duration, enabled = GetSpellCooldown(spell.name)
            local icon = GetSpellTexture(spell.name)

            -- Position the frame based on visible index (compact layout)
            local size = db.iconSize or 32
            local spacing = db.spacing or 4
            cdFrame:ClearAllPoints()

            -- Grow direction: LEFT grows rightward from right edge, RIGHT grows leftward from left edge
            if db.growDirection == "LEFT" then
                -- Icons grow to the left (first icon on right, subsequent icons to the left)
                cdFrame:SetPoint("RIGHT", frame, "RIGHT", -((visibleIndex - 1) * (size + spacing)), 0)
            else
                -- Icons grow to the right (default)
                cdFrame:SetPoint("LEFT", frame, "LEFT", (visibleIndex - 1) * (size + spacing), 0)
            end

            if icon then
                cdFrame.icon:SetTexture(icon)

                if duration and duration > 1.5 then
                    cdFrame.cooldown:SetCooldown(start, duration)
                    cdFrame.icon:SetDesaturated(true)
                    cdFrame.glow:SetAlpha(0)
                    -- Track the actual cooldown duration (only if significant)
                    if duration > 3 then
                        lastCooldownDuration[spell.spellId] = duration
                    end
                    -- Stop edge pulse when on cooldown
                    StopEdgePulse(cdFrame)
                else
                    cdFrame.cooldown:Clear()
                    cdFrame.icon:SetDesaturated(false)

                    -- Start edge pulse if enabled and was a real cooldown
                    if db.showReadyGlow ~= false and lastCooldownDuration[spell.spellId] then
                        if not cdFrame.edgePulseActive then
                            StartEdgePulse(cdFrame)
                        end
                    end
                end

                cdFrame:Show()
            else
                cdFrame:Hide()
            end
        end  -- end of enabled/known check
    end

    -- Hide any remaining cooldown frames that aren't being used
    for i = visibleIndex + 1, MAX_COOLDOWNS do
        if cdFrames[i] then
            cdFrames[i]:Hide()
        end
    end

    -- Only show container if there are visible cooldowns
    if visibleIndex > 0 then
        frame:Show()
        -- Hide drag indicator when not in positioning mode
        if frame.dragIndicator and CastbornDB.locked ~= false then
            frame.dragIndicator:Hide()
        end
    else
        frame:Hide()
    end
end

Castborn:RegisterCallback("INIT", function()
    CastbornDB.cooldowns = Castborn:MergeDefaults(CastbornDB.cooldowns or {}, defaults)
end)

Castborn:RegisterCallback("COOLDOWNS_GLOW_OFF", function()
    for i = 1, MAX_COOLDOWNS do
        if cdFrames[i] then
            StopEdgePulse(cdFrames[i])
        end
    end
end)

-- Merge new default spells into existing tracked list (for upgrades)
local function MergeNewDefaults(existingSpells, defaultSpells)
    local existingIds = {}
    for _, spell in ipairs(existingSpells) do
        existingIds[spell.spellId] = true
    end

    local added = 0
    for _, spell in ipairs(defaultSpells) do
        if not existingIds[spell.spellId] then
            table.insert(existingSpells, spell)
            added = added + 1
        end
    end

    return added
end

Castborn:RegisterCallback("READY", function()
    local db = CastbornDB.cooldowns
    local _, class = UnitClass("player")
    local currentVersion = Castborn.version

    -- Check if class changed (need to reload defaults)
    -- Note: if loadedForClass is nil but trackedSpells exists, reload anyway (migration case)
    local classChanged = db.loadedForClass ~= class

    if not db.trackedSpells or #db.trackedSpells == 0 or classChanged then
        -- First time setup or class changed: load all class defaults
        if class and Castborn.SpellData then
            db.trackedSpells = Castborn.SpellData:GetClassCooldowns(class)
            db.defaultsLoaded = currentVersion
            db.loadedForClass = class
        end
    elseif db.defaultsLoaded ~= currentVersion then
        -- Version changed: merge any new default spells
        if class and Castborn.SpellData then
            local defaults = Castborn.SpellData:GetClassCooldowns(class)
            if defaults then
                local added = MergeNewDefaults(db.trackedSpells, defaults)
                if added > 0 then
                    Castborn:Print(added .. " new cooldown(s) added from defaults")
                end
            end
        end
        db.defaultsLoaded = currentVersion
        db.loadedForClass = class
    end

    CreateContainer()
    UpdateLayout()

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            UpdateCooldowns()
            elapsed = 0
        end
    end)

    -- Apply initial anchoring if enabled and castbar exists
    if db.anchored ~= false then
        local castbar = Castborn.castbars and Castborn.castbars.player
        if castbar then
            playerCastbar = castbar
            -- Find the anchor target - prefer the icon frame if it exists
            local anchorTarget = (castbar.iconFrame and castbar.iconFrame:IsShown()) and castbar.iconFrame or castbar

            -- Position to the left of the icon, with icons growing leftward
            frame:ClearAllPoints()
            frame:SetPoint("RIGHT", anchorTarget, "LEFT", -4, 0)
            frame.isAnchored = true
            frame.anchorParent = anchorTarget
        end
    end
end)

-- Anchoring Support
local playerCastbar = nil

Castborn:RegisterCallback("PLAYER_CASTBAR_CREATED", function(castbar)
    playerCastbar = castbar
    local db = CastbornDB.cooldowns

    -- Anchor to the left of the castbar's icon (if it exists) by default
    if frame and db and db.anchored ~= false then
        -- Find the anchor target - prefer the icon frame if it exists
        local anchorTarget = (castbar.iconFrame and castbar.iconFrame:IsShown()) and castbar.iconFrame or castbar

        -- Position to the left of the icon, with icons growing leftward
        frame:ClearAllPoints()
        frame:SetPoint("RIGHT", anchorTarget, "LEFT", -4, 0)
        frame.isAnchored = true
        frame.anchorParent = anchorTarget
    end
end)

-- Detach cooldowns from castbar
Castborn:RegisterCallback("DETACH_COOLDOWNS", function()
    local db = CastbornDB.cooldowns
    db.anchored = false
    if Castborn.Anchoring then
        Castborn.Anchoring:Detach(frame, db)
    end
    Castborn:Print("Cooldowns detached from castbar")
end)

-- Reattach cooldowns to castbar
Castborn:RegisterCallback("REATTACH_COOLDOWNS", function()
    local db = CastbornDB.cooldowns
    db.anchored = true

    -- Try to find playerCastbar if not set
    if not playerCastbar then
        playerCastbar = Castborn.castbars and Castborn.castbars.player
    end

    if playerCastbar then
        -- Find the anchor target - prefer the icon frame if it exists
        local anchorTarget = (playerCastbar.iconFrame and playerCastbar.iconFrame:IsShown()) and playerCastbar.iconFrame or playerCastbar

        -- Position to the left of the icon, with icons growing leftward
        frame:ClearAllPoints()
        frame:SetPoint("RIGHT", anchorTarget, "LEFT", -4, 0)
        frame.isAnchored = true
        frame.anchorParent = anchorTarget
    end
    Castborn:Print("Cooldowns anchored to castbar")
end)

-- Test mode function
function Castborn:TestCooldowns()
    local db = CastbornDB.cooldowns
    if not frame then return end

    testModeActive = true
    frame:Show()

    -- Collect enabled spells
    local testSpells = {}
    for _, spell in ipairs(db.trackedSpells or {}) do
        if spell.enabled ~= false then
            local icon = GetSpellTexture(spell.name)
            if icon then
                table.insert(testSpells, icon)
            end
            if #testSpells >= MAX_COOLDOWNS then break end
        end
    end

    -- Fallback if no spells configured
    if #testSpells == 0 then
        testSpells = {
            "Interface\\Icons\\Spell_Frost_FrostShock",
            "Interface\\Icons\\Spell_Fire_FlameBolt",
            "Interface\\Icons\\Spell_Nature_Lightning",
        }
    end

    for i = 1, #testSpells do
        local cdFrame = cdFrames[i]
        if cdFrame then
            local size = db.iconSize or 36
            local spacing = db.spacing or 4
            cdFrame:ClearAllPoints()
            cdFrame:SetSize(size, size)

            if db.growDirection == "LEFT" then
                cdFrame:SetPoint("RIGHT", frame, "RIGHT", -((i - 1) * (size + spacing)), 0)
            else
                cdFrame:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + spacing), 0)
            end

            cdFrame.icon:SetTexture(testSpells[i])
            cdFrame.icon:SetDesaturated(i == 2)
            cdFrame.cooldown:Clear()
            if i == 2 then
                cdFrame.cooldown:SetCooldown(GetTime() - 5, 30)
                StopEdgePulse(cdFrame)
            else
                if db.showReadyGlow ~= false then
                    StartEdgePulse(cdFrame)
                end
            end
            cdFrame:Show()
        end
    end

    -- Hide remaining frames
    for i = #testSpells + 1, MAX_COOLDOWNS do
        if cdFrames[i] then cdFrames[i]:Hide() end
    end
end

-- End test mode
function Castborn:EndTestCooldowns()
    testModeActive = false
    if frame then
        frame:Hide()
        for i = 1, MAX_COOLDOWNS do
            if cdFrames[i] then
                StopEdgePulse(cdFrames[i])
                cdFrames[i]:Hide()
            end
        end
    end
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Cooldowns", function() Castborn:TestCooldowns() end, function() Castborn:EndTestCooldowns() end)
end)

Castborn:RegisterModule("CooldownTracker", CooldownTracker)
