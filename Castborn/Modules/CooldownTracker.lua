-- Modules/CooldownTracker.lua
local CooldownTracker = {}
Castborn.CooldownTracker = CooldownTracker

local frame = nil
local cdFrames = {}
local MAX_COOLDOWNS = 12

local trinketFrame = nil
local trinketFrames = {}
local TRINKET_SLOTS = { 13, 14 }

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
    trackTrinkets = true,
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
    if Castborn.Masque and Castborn.Masque.enabled then
        f:SetNormalTexture(f.Normal)
    else
        f.Normal:Hide()
    end

    -- Cooldown frame
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetHideCountdownNumbers(false)
    f.cooldown:EnableMouse(false)
    f.Cooldown = f.cooldown  -- Masque alias

    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    f.time:SetPoint("CENTER")

    -- Charge counter (displayed centered on icon for Earth Shield, Water Shield)
    f.charges = f:CreateFontString(nil, "OVERLAY", nil, 7)
    f.charges:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    f.charges:SetPoint("CENTER", f.icon, "CENTER", 0, 0)
    f.charges:SetTextColor(1, 0.82, 0, 1)  -- Yellow/gold colour
    f.charges:Hide()

    -- Glow effect using layered textures for soft glow look
    f.glowOuter = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.glowOuter:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.glowOuter:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.glowOuter:SetBlendMode("ADD")
    f.glowOuter:SetPoint("TOPLEFT", -8, 8)
    f.glowOuter:SetPoint("BOTTOMRIGHT", 8, -8)
    f.glowOuter:SetVertexColor(1, 0.8, 0.3, 0)
    f.glow = f.glowOuter  -- Keep reference for existing code

    -- Drag shadow effect (hidden by default)
    f.dragShadow = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.dragShadow:SetColorTexture(0, 0, 0, 0.5)
    f.dragShadow:SetPoint("TOPLEFT", 3, -3)
    f.dragShadow:SetPoint("BOTTOMRIGHT", 3, -3)
    f.dragShadow:Hide()

    -- Bright drag glow effect (hidden by default)
    f.dragGlow = f:CreateTexture(nil, "OVERLAY")
    f.dragGlow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.dragGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.dragGlow:SetBlendMode("ADD")
    f.dragGlow:SetPoint("TOPLEFT", -10, 10)
    f.dragGlow:SetPoint("BOTTOMRIGHT", 10, -10)
    f.dragGlow:SetVertexColor(1, 0.8, 0.2, 1)  -- Bright gold
    f.dragGlow:Hide()

    -- Drag cursor overlay icon
    f.dragCursor = f:CreateTexture(nil, "OVERLAY")
    f.dragCursor:SetTexture("Interface\\CURSOR\\Move")
    f.dragCursor:SetSize(20, 20)
    f.dragCursor:SetPoint("TOPLEFT", -4, 4)
    f.dragCursor:SetAlpha(0.9)
    f.dragCursor:Hide()


    -- Register with Masque if available
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton("cooldowns", f, {
            Icon = f.icon,
            Cooldown = f.cooldown,
            Normal = f.Normal,
        })
    end

    -- Click-through (WeakAuras pattern): Disable + EnableMouse(false)
    f:Disable()
    f:EnableMouse(false)
    f:Hide()
    return f
end

local function CreateTrinketFrame(parent, index)
    local size = CastbornDB.cooldowns.iconSize or 32

    local f = CreateFrame("Button", "Castborn_Trinket" .. index, parent)
    f:SetSize(size, size)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.Icon = f.icon

    f.Normal = f:CreateTexture(nil, "BORDER")
    f.Normal:SetPoint("TOPLEFT", -1, 1)
    f.Normal:SetPoint("BOTTOMRIGHT", 1, -1)
    f.Normal:SetColorTexture(0.3, 0.3, 0.3, 1)
    if Castborn.Masque and Castborn.Masque.enabled then
        f:SetNormalTexture(f.Normal)
    else
        f.Normal:Hide()
    end

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetHideCountdownNumbers(false)
    f.Cooldown = f.cooldown

    f.time = f:CreateFontString(nil, "OVERLAY")
    f.time:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    f.time:SetPoint("CENTER")

    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton("cooldowns", f, {
            Icon = f.icon,
            Cooldown = f.cooldown,
            Normal = f.Normal,
        })
    end

    -- Click-through (WeakAuras pattern): Disable + EnableMouse(false)
    f:Disable()
    f:EnableMouse(false)
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

    -- Enhanced insertion marker (4px thick with glow)
    frame.insertMarker = frame:CreateTexture(nil, "OVERLAY")
    frame.insertMarker:SetColorTexture(0.3, 0.8, 1, 0.9)
    frame.insertMarker:SetSize(4, db.iconSize or 36)
    frame.insertMarker:Hide()

    frame.insertMarkerGlow = frame:CreateTexture(nil, "OVERLAY", nil, -1)
    frame.insertMarkerGlow:SetColorTexture(0.3, 0.8, 1, 0.3)
    frame.insertMarkerGlow:SetSize(8, db.iconSize or 36)
    frame.insertMarkerGlow:Hide()

    -- Slot highlight box
    frame.slotHighlight = frame:CreateTexture(nil, "BACKGROUND")
    frame.slotHighlight:SetColorTexture(0.3, 0.8, 1, 0.2)
    frame.slotHighlight:SetSize(db.iconSize or 36, db.iconSize or 36)
    frame.slotHighlight:Hide()

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, db, nil, "Cooldowns")
    end

    frame:Hide()  -- Start hidden, will show when cooldowns are tracked
    return frame
end

local function CreateTrinketContainer()
    local db = CastbornDB.cooldowns
    local size = db.iconSize or 36
    local spacing = db.spacing or 4

    trinketFrame = CreateFrame("Frame", "Castborn_TrinketTracker", frame)
    trinketFrame:SetSize(size * 2 + spacing, size + 4)
    trinketFrame:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, spacing)

    for i = 1, 2 do
        trinketFrames[i] = CreateTrinketFrame(trinketFrame, i)
    end

    trinketFrame:Hide()
end

local function UpdateTrinkets()
    local db = CastbornDB.cooldowns
    if not trinketFrame then return end
    if not db.trackTrinkets then
        trinketFrame:Hide()
        return
    end

    local size = db.iconSize or 36
    local spacing = db.spacing or 4
    local anyVisible = false

    for i, slot in ipairs(TRINKET_SLOTS) do
        local tf = trinketFrames[i]
        if not tf then break end

        local itemId = GetInventoryItemID("player", slot)
        if itemId and GetItemSpell(itemId) then
            local icon = GetInventoryItemTexture("player", slot)
            local start, duration, enabled = GetInventoryItemCooldown("player", slot)

            tf.icon:SetTexture(icon)
            tf:SetSize(size, size)
            tf:ClearAllPoints()
            tf:SetPoint("RIGHT", trinketFrame, "RIGHT", -((i - 1) * (size + spacing)), 0)

            if duration and duration > 1.5 then
                tf.cooldown:SetCooldown(start, duration)
                tf.icon:SetDesaturated(true)
            else
                tf.cooldown:Clear()
                tf.icon:SetDesaturated(false)
            end

            tf:Show()
            anyVisible = true
        else
            tf:Hide()
        end
    end

    if anyVisible then
        trinketFrame:SetSize(size * 2 + spacing, size + 4)
        trinketFrame:Show()
    else
        trinketFrame:Hide()
    end
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

                -- Create charges fontstring if it doesn't exist (for existing frames)
                if not cdFrame.charges then
                    cdFrame.charges = cdFrame:CreateFontString(nil, "OVERLAY", nil, 7)
                    cdFrame.charges:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
                    cdFrame.charges:SetPoint("CENTER", cdFrame.icon, "CENTER", 0, 0)
                    cdFrame.charges:SetTextColor(1, 0.82, 0, 1)  -- Yellow/gold colour
                end

                -- Check for charge-based buffs (Earth Shield, Water Shield)
                local charges = nil
                if spell.spellId == 974 or spell.spellId == 24398 then
                    -- Check if buff is active on player
                    for j = 1, 40 do
                        local name, _, count = UnitBuff("player", j)
                        if not name then break end
                        if name == spell.name then
                            charges = count
                            break
                        end
                    end
                end

                -- Display charges if available
                if charges and charges > 0 then
                    cdFrame.charges:SetText(charges)
                    cdFrame.charges:Show()
                else
                    cdFrame.charges:Hide()
                end

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
    local _, race = UnitRace("player")
    local currentVersion = Castborn.version

    -- Check if class changed (need to reload defaults)
    -- Note: if loadedForClass is nil but trackedSpells exists, reload anyway (migration case)
    local classChanged = db.loadedForClass ~= class

    if not db.trackedSpells or #db.trackedSpells == 0 or classChanged then
        -- First time setup or class changed: load all class defaults
        if class and Castborn.SpellData then
            db.trackedSpells = Castborn.SpellData:GetClassCooldowns(class)
            -- Append racial cooldowns
            if race then
                for _, spell in ipairs(Castborn.SpellData:GetRacialCooldowns(race)) do
                    table.insert(db.trackedSpells, spell)
                end
            end
            db.defaultsLoaded = currentVersion
            db.loadedForClass = class
        end
    elseif db.defaultsLoaded ~= currentVersion then
        -- Version changed: merge any new default spells
        if class and Castborn.SpellData then
            local defaults = Castborn.SpellData:GetClassCooldowns(class)
            local added = 0
            if defaults then
                added = added + MergeNewDefaults(db.trackedSpells, defaults)
            end
            -- Merge racial cooldowns
            if race then
                local racials = Castborn.SpellData:GetRacialCooldowns(race)
                if racials then
                    added = added + MergeNewDefaults(db.trackedSpells, racials)
                end
            end
            if added > 0 then
                Castborn:Print(added .. " new cooldown(s) added from defaults")
            end
        end
        db.defaultsLoaded = currentVersion
        db.loadedForClass = class
    end

    CreateContainer()
    CreateTrinketContainer()
    UpdateLayout()

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            UpdateCooldowns()
            UpdateTrinkets()
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

-- Drag-reorder support for test mode
local visibleToTrackIndex = {}  -- maps visible icon index -> trackedSpells array index
local testSpellCount = 0        -- number of visible test spells

-- Drag state tracking
local dragState = {
    draggingIndex = nil,
    currentTargetSlot = nil,
}

-- Smooth animation for icon repositioning
local function SmoothRepositionIcon(icon, targetSlot, db)
    if not icon or not db then return end

    local size = db.iconSize or 36
    local spacing = db.spacing or 4
    local targetX, targetY

    if db.growDirection == "LEFT" then
        targetX = -((targetSlot - 1) * (size + spacing))
        targetY = 0
    else
        targetX = (targetSlot - 1) * (size + spacing)
        targetY = 0
    end

    icon.targetX = targetX
    icon.targetY = targetY

    if not icon.isAnimating then
        icon.isAnimating = true

        local animFrame = icon.animFrame or CreateFrame("Frame")
        icon.animFrame = animFrame

        animFrame:SetScript("OnUpdate", function(self, elapsed)
            if not icon or not icon:IsShown() then
                icon.isAnimating = false
                animFrame:SetScript("OnUpdate", nil)
                return
            end

            local currentX = select(4, icon:GetPoint()) or 0
            local currentY = select(5, icon:GetPoint()) or 0

            -- Lerp towards target (30% per frame)
            local newX = currentX + (icon.targetX - currentX) * 0.3
            local newY = currentY + (icon.targetY - currentY) * 0.3

            -- Snap if very close
            if math.abs(newX - icon.targetX) < 0.5 then
                newX = icon.targetX
                newY = icon.targetY
                icon.isAnimating = false
                animFrame:SetScript("OnUpdate", nil)
            end

            -- Apply position
            icon:ClearAllPoints()
            if db.growDirection == "LEFT" then
                icon:SetPoint("RIGHT", frame, "RIGHT", newX, newY)
            else
                icon:SetPoint("LEFT", frame, "LEFT", newX, newY)
            end
        end)
    end
end

local function PositionTestIcon(cdFrame, visibleIndex, db)
    local size = db.iconSize or 36
    local spacing = db.spacing or 4
    cdFrame:ClearAllPoints()
    cdFrame:SetSize(size, size)

    if db.growDirection == "LEFT" then
        cdFrame:SetPoint("RIGHT", frame, "RIGHT", -((visibleIndex - 1) * (size + spacing)), 0)
    else
        cdFrame:SetPoint("LEFT", frame, "LEFT", (visibleIndex - 1) * (size + spacing), 0)
    end
end

local function RefreshTestIcons()
    local db = CastbornDB.cooldowns

    -- Rebuild visible spell list from current trackedSpells order
    local testSpells = {}
    visibleToTrackIndex = {}
    for trackIdx, spell in ipairs(db.trackedSpells or {}) do
        if spell.enabled ~= false then
            -- In test mode, show all enabled spells regardless of whether known
            local icon = GetSpellTexture(spell.spellId) or GetSpellTexture(spell.name)

            -- If still no icon, try to get it from spell data
            if not icon and spell.spellId then
                -- For unknown spells, create a placeholder or use spell ID
                icon = "Interface\\Icons\\INV_Misc_QuestionMark"
            end

            if icon then
                table.insert(testSpells, { icon = icon, trackIdx = trackIdx })
                visibleToTrackIndex[#testSpells] = trackIdx
            end
            if #testSpells >= MAX_COOLDOWNS then break end
        end
    end

    -- Fallback if no spells configured
    if #testSpells == 0 then
        local fallbacks = {
            "Interface\\Icons\\Spell_Frost_FrostShock",
            "Interface\\Icons\\Spell_Fire_FlameBolt",
            "Interface\\Icons\\Spell_Nature_Lightning",
        }
        for i, icon in ipairs(fallbacks) do
            table.insert(testSpells, { icon = icon, trackIdx = nil })
        end
    end

    testSpellCount = #testSpells

    for i = 1, #testSpells do
        local cdFrame = cdFrames[i]
        if cdFrame then
            PositionTestIcon(cdFrame, i, db)
            cdFrame.icon:SetTexture(testSpells[i].icon)
            cdFrame.icon:SetDesaturated(i == 2)
            cdFrame.cooldown:Clear()

            -- Create charges fontstring if it doesn't exist (for existing frames)
            if not cdFrame.charges then
                cdFrame.charges = cdFrame:CreateFontString(nil, "OVERLAY", nil, 7)
                cdFrame.charges:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
                cdFrame.charges:SetPoint("CENTER", cdFrame.icon, "CENTER", 0, 0)
                cdFrame.charges:SetTextColor(1, 0.82, 0, 1)  -- Yellow/gold colour
            end

            -- Show example charges for Earth Shield (974) and Water Shield (24398)
            if testSpells[i].trackIdx then
                local spell = db.trackedSpells[testSpells[i].trackIdx]
                if spell and (spell.spellId == 974 or spell.spellId == 24398) then
                    local exampleCharges = spell.spellId == 974 and 6 or 3
                    cdFrame.charges:SetText(exampleCharges)
                    cdFrame.charges:Show()
                else
                    cdFrame.charges:Hide()
                end
            else
                cdFrame.charges:Hide()
            end

            if i == 2 then
                cdFrame.cooldown:SetCooldown(GetTime() - 5, 30)
                StopEdgePulse(cdFrame)
            else
                if db.showReadyGlow ~= false then
                    StartEdgePulse(cdFrame)
                end
            end
            cdFrame.visibleIndex = i
            cdFrame:Show()
        end
    end

    -- Hide remaining frames
    for i = #testSpells + 1, MAX_COOLDOWNS do
        if cdFrames[i] then cdFrames[i]:Hide() end
    end
end

local function SetupDragReorder(cdFrame, visibleIndex)
    local db = CastbornDB.cooldowns
    cdFrame.visibleIndex = visibleIndex

    cdFrame:SetMovable(true)
    cdFrame:Enable()
    cdFrame:EnableMouse(true)
    cdFrame:RegisterForDrag("LeftButton")

    -- Ghost frame (translucent copy at original position)
    if not cdFrame.ghost then
        cdFrame.ghost = frame:CreateTexture(nil, "ARTWORK", nil, -1)
        cdFrame.ghost:SetSize(db.iconSize or 36, db.iconSize or 36)
        cdFrame.ghost:SetAlpha(0.3)
        cdFrame.ghost:SetDesaturated(true)
    end

    cdFrame:SetScript("OnDragStart", function(self)
        if not testModeActive then return end

        -- Store initial cursor and frame positions
        local scale = UIParent:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        self.dragStartCursorX = cursorX / scale
        self.dragStartCursorY = cursorY / scale

        -- Store offset from icon center to cursor
        local centerX, centerY = self:GetCenter()
        self.dragOffsetX = centerX - self.dragStartCursorX
        self.dragOffsetY = centerY - self.dragStartCursorY

        -- Setup ghost at original position
        local size = db.iconSize or 36
        self.ghost:SetTexture(self.icon:GetTexture())
        self.ghost:ClearAllPoints()

        local spacing = db.spacing or 4
        if db.growDirection == "LEFT" then
            self.ghost:SetPoint("RIGHT", frame, "RIGHT", -((self.visibleIndex - 1) * (size + spacing)), 0)
        else
            self.ghost:SetPoint("LEFT", frame, "LEFT", (self.visibleIndex - 1) * (size + spacing), 0)
        end
        self.ghost:SetSize(size, size)
        self.ghost:Show()

        -- Visual enhancements for dragged icon
        self:SetFrameLevel(self:GetFrameLevel() + 10)
        self:SetScale(1.1)
        self:SetAlpha(1.0)  -- Keep fully opaque
        if self.dragShadow then
            self.dragShadow:Show()
        end
        if self.dragGlow then
            self.dragGlow:Show()
        end
        if self.dragCursor then
            self.dragCursor:Show()
        end

        -- Dim all other cooldown icons
        for i = 1, testSpellCount do
            if cdFrames[i] and cdFrames[i] ~= self and cdFrames[i]:IsShown() then
                cdFrames[i]:SetAlpha(0.4)
                cdFrames[i].icon:SetDesaturated(true)
            end
        end

        self.isDragging = true
        dragState.draggingIndex = self.visibleIndex
        dragState.currentTargetSlot = nil
    end)

    cdFrame:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end
        self.isDragging = false

        -- Reset dragged icon appearance
        self:SetScale(1.0)
        self:SetAlpha(1.0)
        self:SetFrameLevel(self:GetFrameLevel() - 10)
        if self.dragShadow then
            self.dragShadow:Hide()
        end
        if self.dragGlow then
            self.dragGlow:Hide()
        end
        if self.dragCursor then
            self.dragCursor:Hide()
        end

        -- Restore all other cooldown icons
        for i = 1, testSpellCount do
            if cdFrames[i] and cdFrames[i] ~= self and cdFrames[i]:IsShown() then
                cdFrames[i]:SetAlpha(1.0)
                -- Only restore saturation if it was ready (not on cooldown)
                if i ~= 2 then  -- Frame 2 is the test cooldown frame
                    cdFrames[i].icon:SetDesaturated(false)
                end
            end
        end

        -- Hide all visual feedback
        if self.ghost then self.ghost:Hide() end
        if frame.insertMarker then frame.insertMarker:Hide() end
        if frame.insertMarkerGlow then frame.insertMarkerGlow:Hide() end
        if frame.slotHighlight then frame.slotHighlight:Hide() end

        -- Stop all animations and calculate final target slot
        local targetSlot = dragState.currentTargetSlot or self.visibleIndex
        targetSlot = math.max(1, math.min(targetSlot, testSpellCount))

        local fromSlot = self.visibleIndex
        if fromSlot ~= targetSlot and visibleToTrackIndex[fromSlot] and visibleToTrackIndex[targetSlot] then
            -- Move the spell in trackedSpells array
            local fromTrack = visibleToTrackIndex[fromSlot]
            local toTrack = visibleToTrackIndex[targetSlot]
            local spell = table.remove(db.trackedSpells, fromTrack)

            -- Recalculate target index after removal
            if toTrack > fromTrack then
                toTrack = toTrack - 1
            end
            table.insert(db.trackedSpells, toTrack, spell)
        end

        -- Reset drag state
        dragState.draggingIndex = nil
        dragState.currentTargetSlot = nil

        -- Stop all animations
        for i = 1, testSpellCount do
            if cdFrames[i] and cdFrames[i].animFrame then
                cdFrames[i].animFrame:SetScript("OnUpdate", nil)
                cdFrames[i].isAnimating = false
            end
        end

        -- Refresh all icons to reflect new order
        RefreshTestIcons()

        -- Re-setup drag handlers with updated indices
        for i = 1, testSpellCount do
            if cdFrames[i] and cdFrames[i]:IsShown() then
                SetupDragReorder(cdFrames[i], i)
            end
        end
    end)

    cdFrame:SetScript("OnUpdate", function(self, elapsed)
        if not self.isDragging then return end

        -- Update icon position to follow cursor
        local scale = UIParent:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        cursorX = cursorX / scale
        cursorY = cursorY / scale

        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            cursorX + self.dragOffsetX,
            cursorY + self.dragOffsetY)

        -- Calculate target slot from cursor position
        local size = db.iconSize or 36
        local spacing = db.spacing or 4
        local step = size + spacing

        local frameLeft = frame:GetLeft()
        local frameRight = frame:GetRight()
        if not frameLeft or not frameRight then return end

        local targetSlot
        if db.growDirection == "LEFT" then
            local offset = frameRight - cursorX
            targetSlot = math.floor(offset / step + 0.5) + 1
        else
            local offset = cursorX - frameLeft
            targetSlot = math.floor(offset / step + 0.5) + 1
        end
        targetSlot = math.max(1, math.min(targetSlot, testSpellCount))

        -- Only update if target slot changed
        if targetSlot ~= dragState.currentTargetSlot then
            dragState.currentTargetSlot = targetSlot

            -- Reposition other icons to show where dragged icon will fit
            for i = 1, testSpellCount do
                local icon = cdFrames[i]
                if i ~= self.visibleIndex and icon and icon:IsShown() then
                    local displaySlot = i

                    -- Calculate where this icon should be in the new layout
                    if self.visibleIndex < i and i <= targetSlot then
                        displaySlot = i - 1
                    elseif self.visibleIndex > i and i >= targetSlot then
                        displaySlot = i + 1
                    end

                    -- Smoothly move to new position
                    SmoothRepositionIcon(icon, displaySlot, db)
                end
            end

            -- Update insertion marker
            if frame.insertMarker then
                frame.insertMarker:ClearAllPoints()
                frame.insertMarker:SetSize(4, size)

                if db.growDirection == "LEFT" then
                    local xOff = -((targetSlot - 1) * step) + size / 2 + 2
                    frame.insertMarker:SetPoint("RIGHT", frame, "RIGHT", xOff, 0)
                else
                    local xOff = (targetSlot - 1) * step - 2
                    frame.insertMarker:SetPoint("LEFT", frame, "LEFT", xOff, 0)
                end
                frame.insertMarker:Show()

                -- Position glow with marker
                if frame.insertMarkerGlow then
                    frame.insertMarkerGlow:ClearAllPoints()
                    frame.insertMarkerGlow:SetSize(8, size)
                    frame.insertMarkerGlow:SetPoint("CENTER", frame.insertMarker, "CENTER", 0, 0)
                    frame.insertMarkerGlow:Show()
                end
            end

            -- Update slot highlight
            if frame.slotHighlight then
                frame.slotHighlight:ClearAllPoints()
                frame.slotHighlight:SetSize(size, size)

                if db.growDirection == "LEFT" then
                    local xOff = -((targetSlot - 1) * step)
                    frame.slotHighlight:SetPoint("RIGHT", frame, "RIGHT", xOff, 0)
                else
                    local xOff = (targetSlot - 1) * step
                    frame.slotHighlight:SetPoint("LEFT", frame, "LEFT", xOff, 0)
                end
                frame.slotHighlight:Show()
            end
        end
    end)
end

-- Test mode function
function Castborn:TestCooldowns()
    local db = CastbornDB.cooldowns
    if not frame then return end

    testModeActive = true
    frame:Show()

    -- Refresh icons from current trackedSpells order
    RefreshTestIcons()

    -- Setup drag reorder on each visible icon
    for i = 1, testSpellCount do
        if cdFrames[i] and cdFrames[i]:IsShown() then
            SetupDragReorder(cdFrames[i], i)
        end
    end

    -- Show sample trinket icons in test mode
    if db.trackTrinkets and trinketFrame then
        local size = db.iconSize or 36
        local spacing = db.spacing or 4
        local testTrinketIcons = {
            "Interface\\Icons\\INV_Trinket_Naxxramas04",
            "Interface\\Icons\\INV_Trinket_Naxxramas03",
        }
        for i = 1, 2 do
            local tf = trinketFrames[i]
            if tf then
                tf.icon:SetTexture(testTrinketIcons[i])
                tf:SetSize(size, size)
                tf:ClearAllPoints()
                tf:SetPoint("RIGHT", trinketFrame, "RIGHT", -((i - 1) * (size + spacing)), 0)
                tf.cooldown:Clear()
                tf.icon:SetDesaturated(i == 1)
                if i == 1 then
                    tf.cooldown:SetCooldown(GetTime() - 10, 120)
                end
                tf:Show()
            end
        end
        trinketFrame:SetSize(size * 2 + spacing, size + 4)
        trinketFrame:Show()
    end
end

-- End test mode
function Castborn:EndTestCooldowns()
    testModeActive = false
    if frame then
        -- Clean up drag state and visual markers
        if frame.insertMarker then frame.insertMarker:Hide() end
        if frame.insertMarkerGlow then frame.insertMarkerGlow:Hide() end
        if frame.slotHighlight then frame.slotHighlight:Hide() end

        for i = 1, MAX_COOLDOWNS do
            if cdFrames[i] then
                StopEdgePulse(cdFrames[i])
                cdFrames[i]:Disable()
                cdFrames[i]:EnableMouse(false)
                cdFrames[i]:SetScript("OnDragStart", nil)
                cdFrames[i]:SetScript("OnDragStop", nil)
                cdFrames[i]:SetScript("OnUpdate", nil)
                cdFrames[i].isDragging = false
                cdFrames[i]:SetAlpha(1.0)
                cdFrames[i]:SetScale(1.0)
                if cdFrames[i].ghost then cdFrames[i].ghost:Hide() end
                if cdFrames[i].dragShadow then cdFrames[i].dragShadow:Hide() end
                if cdFrames[i].dragGlow then cdFrames[i].dragGlow:Hide() end
                if cdFrames[i].dragCursor then cdFrames[i].dragCursor:Hide() end
                if cdFrames[i].charges then cdFrames[i].charges:Hide() end
                if cdFrames[i].animFrame then
                    cdFrames[i].animFrame:SetScript("OnUpdate", nil)
                    cdFrames[i].isAnimating = false
                end
                cdFrames[i]:Hide()
            end
        end
        frame:Hide()
    end
    -- Hide trinket test frames
    if trinketFrame then
        for i = 1, 2 do
            if trinketFrames[i] then trinketFrames[i]:Hide() end
        end
        trinketFrame:Hide()
    end
    visibleToTrackIndex = {}
    testSpellCount = 0
    dragState.draggingIndex = nil
    dragState.currentTargetSlot = nil
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Cooldowns", function() Castborn:TestCooldowns() end, function() Castborn:EndTestCooldowns() end)
end)

Castborn:RegisterModule("CooldownTracker", CooldownTracker)
