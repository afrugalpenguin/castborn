-- Modules/InterruptTracker.lua
local InterruptTracker = {}
Castborn.InterruptTracker = InterruptTracker

local frame = nil
local lockoutFrame = nil
local testModeActive = false
local attachedIcons = {}  -- { target = button, focus = button }

local defaults = {
    enabled = true,
    width = 100,
    height = 16,
    point = "CENTER",
    x = 0,
    y = -215,
    xPct = 0,
    yPct = -0.199,
    showLockout = true,
    trackTarget = true,
    trackFocus = true,
    attachToCastbars = false,
    showReadyGlow = true,
}

local function CreateInterruptBar()
    local db = CastbornDB.interrupt
    local playerClass = select(2, UnitClass("player"))
    local interruptInfo = Castborn.SpellData and Castborn.SpellData:GetInterrupt(playerClass)

    if not interruptInfo then
        return nil
    end

    -- Don't show if player doesn't know the interrupt spell yet
    if not Castborn:IsSpellKnown(interruptInfo.spellId) then
        return nil
    end

    frame = CreateFrame("Frame", "Castborn_Interrupt", UIParent, "BackdropTemplate")
    frame:SetSize(db.width, db.height)

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)

    -- Status bar
    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetPoint("TOPLEFT", 1, -1)
    frame.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.bar:SetStatusBarTexture(Castborn:GetBarTexture())
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)
    Castborn:RegisterBarFrame(frame.bar)

    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    -- Icon button for Masque compatibility
    local masqueGroup = Castborn.Masque and Castborn.Masque.enabled and Castborn.Masque.groups.interrupts or nil
    local iconButton = Castborn:CreateMasqueButton(frame, nil, db.height, masqueGroup, {
        iconLayer = "BACKGROUND",
    })
    iconButton:SetPoint("LEFT", frame, "LEFT", 0, 0)
    iconButton.icon:SetTexture(GetSpellTexture(interruptInfo.spellId))
    frame.icon = iconButton.icon
    frame.iconButton = iconButton

    if frame.bar then
        frame.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", db.height + 2, -1)
    end

    frame.time = frame:CreateFontString(nil, "OVERLAY")
    frame.time:SetFont(Castborn:GetBarFont(), 10, "OUTLINE")
    Castborn:RegisterFontString(frame.time, 10, "OUTLINE")
    frame.time:SetPoint("CENTER", frame.bar or frame, "CENTER")

    frame.ready = frame:CreateFontString(nil, "OVERLAY")
    frame.ready:SetFont(Castborn:GetBarFont(), 10, "OUTLINE")
    Castborn:RegisterFontString(frame.ready, 10, "OUTLINE")
    frame.ready:SetPoint("CENTER", frame.bar or frame, "CENTER")
    frame.ready:SetText("READY")
    frame.ready:SetTextColor(0.2, 1, 0.2, 1)
    frame.ready:Hide()

    frame.interruptInfo = interruptInfo

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, db, nil, "Interrupt")
    end

    return frame
end

local function CreateLockoutDisplay()
    local db = CastbornDB.interrupt

    lockoutFrame = CreateFrame("Frame", "Castborn_Lockout", UIParent)
    lockoutFrame:SetSize(80, 20)
    lockoutFrame:SetPoint("LEFT", frame or UIParent, "RIGHT", 10, 0)

    lockoutFrame.bg = lockoutFrame:CreateTexture(nil, "BACKGROUND")
    lockoutFrame.bg:SetAllPoints()
    lockoutFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    lockoutFrame.text = lockoutFrame:CreateFontString(nil, "OVERLAY")
    lockoutFrame.text:SetFont(Castborn:GetBarFont(), 10, "OUTLINE")
    Castborn:RegisterFontString(lockoutFrame.text, 10, "OUTLINE")
    lockoutFrame.text:SetPoint("CENTER")

    lockoutFrame.school = nil
    lockoutFrame.expirationTime = 0

    lockoutFrame:Hide()

    return lockoutFrame
end

local function CreateAttachedIcon(unit)
    local castbar = Castborn.castbars and Castborn.castbars[unit]
    if not castbar then return nil end

    local playerClass = select(2, UnitClass("player"))
    local interruptInfo = Castborn.SpellData and Castborn.SpellData:GetInterrupt(playerClass)
    if not interruptInfo then return nil end
    if not Castborn:IsSpellKnown(interruptInfo.spellId) then return nil end

    local castbarCfg = CastbornDB[unit]
    local iconSize = (castbarCfg.height or 16) + 4

    local masqueGroup = Castborn.Masque and Castborn.Masque.enabled and Castborn.Masque.groups.interrupts or nil
    local btn = Castborn:CreateMasqueButton(castbar, nil, iconSize, masqueGroup, {
        texCoord = 0.07,
        clickThrough = true,
    })
    btn:SetPoint("LEFT", castbar, "RIGHT", 4, 0)
    btn.icon:SetTexture(GetSpellTexture(interruptInfo.spellId))

    -- Backdrop matching castbar style
    Castborn:CreateBackdrop(btn, castbarCfg.bgColor, castbarCfg.borderColor)
    btn.icon:ClearAllPoints()
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Glow texture (same pattern as CooldownTracker)
    btn.glowOuter = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    btn.glowOuter:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    btn.glowOuter:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    btn.glowOuter:SetBlendMode("ADD")
    btn.glowOuter:SetPoint("TOPLEFT", -8, 8)
    btn.glowOuter:SetPoint("BOTTOMRIGHT", 8, -8)
    btn.glowOuter:SetVertexColor(1, 0.8, 0.3, 0)
    btn.glow = btn.glowOuter

    btn.interruptInfo = interruptInfo
    btn:Hide()

    return btn
end

function InterruptTracker:UpdateAttachMode()
    local db = CastbornDB.interrupt
    if db.attachToCastbars then
        -- Hide standalone
        if frame then frame:Hide() end
        if lockoutFrame then lockoutFrame:Hide() end
        -- Create attached icons if needed
        for _, unit in ipairs({"target", "focus"}) do
            if not attachedIcons[unit] then
                attachedIcons[unit] = CreateAttachedIcon(unit)
            end
        end
    else
        -- Hide attached icons (keep frames for reuse)
        for _, btn in pairs(attachedIcons) do
            btn:Hide()
        end
    end
end

local function UpdateAttachedIcons()
    local db = CastbornDB.interrupt
    if not db.attachToCastbars then return end
    if testModeActive then return end

    for _, unit in ipairs({"target", "focus"}) do
        local btn = attachedIcons[unit]
        if btn then
            local tracked = (unit == "target" and db.trackTarget ~= false) or
                            (unit == "focus" and db.trackFocus ~= false)
            local castbar = Castborn.castbars and Castborn.castbars[unit]
            local castbarVisible = castbar and castbar:IsShown() and (castbar.casting or castbar.channeling)

            if tracked and castbarVisible then
                btn:Show()
                local start, duration = GetSpellCooldown(btn.interruptInfo.spellId)
                local onCooldown = duration and duration > 1.5
                if onCooldown then
                    btn.cooldown:SetCooldown(start, duration)
                    btn.icon:SetDesaturated(true)
                    if btn.glow then btn.glow:SetAlpha(0) end
                else
                    btn.cooldown:SetCooldown(0, 0)
                    btn.icon:SetDesaturated(false)
                    if db.showReadyGlow and btn.glow then
                        btn.glow:SetAlpha(0.3)
                    elseif btn.glow then
                        btn.glow:SetAlpha(0)
                    end
                end
            else
                btn:Hide()
            end
        end
    end
end

local function OnCombatLogEvent(self, event, ...)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, extraSpellId, extraSpellName, extraSchool = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= UnitGUID("player") then return end

    if subEvent == "SPELL_INTERRUPT" then
        local lockoutDuration = 4

        if lockoutFrame and CastbornDB.interrupt.showLockout then
            local schoolColor = Castborn.SpellData and Castborn.SpellData:GetSchoolColor(extraSchool) or {1, 1, 1, 1}
            lockoutFrame.text:SetText(string.format("Locked %.1fs", lockoutDuration))
            lockoutFrame.text:SetTextColor(unpack(schoolColor))
            lockoutFrame.school = extraSchool
            lockoutFrame.expirationTime = GetTime() + lockoutDuration
            lockoutFrame:Show()
        end
    end
end

-- Check if a unit is casting something interruptible
local function IsUnitCastingInterruptible(unit)
    if not UnitExists(unit) then return false end
    local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    if name and not notInterruptible then return true end
    name, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
    if name and not notInterruptible then return true end
    return false
end

local function UpdateInterruptCooldown()
    -- Don't override test mode display
    if testModeActive then return end

    -- In attach mode, standalone bar is hidden
    if CastbornDB.interrupt.attachToCastbars then
        if frame then frame:Hide() end
        return
    end

    if not frame or not frame.interruptInfo then return end

    local db = CastbornDB.interrupt
    if not db.enabled then
        frame:Hide()
        return
    end

    -- Check for interruptible casts on target/focus
    local targetInterruptible = db.trackTarget ~= false and IsUnitCastingInterruptible("target")
    local focusInterruptible = db.trackFocus ~= false and IsUnitCastingInterruptible("focus")
    local hasInterruptOpportunity = targetInterruptible or focusInterruptible

    -- Only show when in combat or when interrupt is on cooldown
    local start, duration = GetSpellCooldown(frame.interruptInfo.spellId)
    local onCooldown = duration and duration > 1.5
    local inCombat = UnitAffectingCombat("player")

    if not onCooldown and not inCombat and not hasInterruptOpportunity then
        frame:Hide()
        return
    end

    frame:Show()

    if duration and duration > 1.5 then
        local remaining = (start + duration) - GetTime()
        if frame.bar then
            frame.bar:SetMinMaxValues(0, duration)
            frame.bar:SetValue(remaining)
            frame.bar:SetStatusBarColor(0.8, 0.3, 0.3, 1)
        end
        frame.time:SetText(string.format("%.1f", remaining))
        frame.time:Show()
        frame.ready:Hide()
        frame.icon:SetDesaturated(true)
    else
        if frame.bar then
            frame.bar:SetMinMaxValues(0, 1)
            frame.bar:SetValue(1)
            -- Highlight yellow when there's an interrupt opportunity
            if hasInterruptOpportunity then
                frame.bar:SetStatusBarColor(1, 0.8, 0.2, 1)
            else
                frame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
            end
        end
        frame.time:Hide()
        frame.ready:Show()
        frame.icon:SetDesaturated(false)
    end
end

local function UpdateLockout()
    if not lockoutFrame then return end

    if lockoutFrame.expirationTime > GetTime() then
        local remaining = lockoutFrame.expirationTime - GetTime()
        lockoutFrame.text:SetText(string.format("Locked %.1fs", remaining))
    else
        lockoutFrame:Hide()
    end
end

Castborn:RegisterCallback("INIT", function()
    CastbornDB.interrupt = Castborn:MergeDefaults(CastbornDB.interrupt or {}, defaults)
end)

Castborn:RegisterCallback("READY", function()
    CreateInterruptBar()
    CreateLockoutDisplay()
    InterruptTracker:UpdateAttachMode()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", OnCombatLogEvent)

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.05 then
            UpdateInterruptCooldown()
            UpdateAttachedIcons()
            UpdateLockout()
            elapsed = 0
        end
    end)
end)

-- Test mode function
function Castborn:TestInterrupt()
    local db = CastbornDB.interrupt
    testModeActive = true
    -- Show even if disabled for test mode

    -- Create a mockup interrupt bar if player doesn't have one
    if not frame then
        local mockFrame = CreateFrame("Frame", "Castborn_Interrupt_Mock", UIParent, "BackdropTemplate")
        mockFrame:SetSize(db.width, db.height)
        mockFrame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

        mockFrame.bg = mockFrame:CreateTexture(nil, "BACKGROUND")
        mockFrame.bg:SetAllPoints()
        mockFrame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)

        mockFrame.bar = CreateFrame("StatusBar", nil, mockFrame)
        mockFrame.bar:SetPoint("TOPLEFT", db.height + 2, -1)
        mockFrame.bar:SetPoint("BOTTOMRIGHT", -1, 1)
        mockFrame.bar:SetStatusBarTexture(Castborn:GetBarTexture())
        mockFrame.bar:SetMinMaxValues(0, 1)
        mockFrame.bar:SetValue(1)
        mockFrame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
        Castborn:RegisterBarFrame(mockFrame.bar)

        mockFrame.icon = mockFrame:CreateTexture(nil, "ARTWORK")
        mockFrame.icon:SetSize(db.height, db.height)
        mockFrame.icon:SetPoint("LEFT", mockFrame, "LEFT", 0, 0)
        mockFrame.icon:SetTexture("Interface\\Icons\\Spell_Frost_IceShock")
        mockFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        mockFrame.ready = mockFrame:CreateFontString(nil, "OVERLAY")
        mockFrame.ready:SetFont(Castborn:GetBarFont(), 10, "OUTLINE")
        Castborn:RegisterFontString(mockFrame.ready, 10, "OUTLINE")
        mockFrame.ready:SetPoint("CENTER", mockFrame.bar, "CENTER")
        mockFrame.ready:SetText("READY")
        mockFrame.ready:SetTextColor(0.2, 1, 0.2, 1)

        mockFrame.isMockup = true
        frame = mockFrame

        if Castborn.Anchoring then
            Castborn.Anchoring:MakeDraggable(mockFrame, db, nil, "Interrupt")
        end
    end

    if db.attachToCastbars then
        -- In attach mode, hide standalone and show attached icons
        if frame then frame:Hide() end
        for _, unit in ipairs({"target", "focus"}) do
            local btn = attachedIcons[unit]
            if btn then
                btn:Show()
                btn.icon:SetDesaturated(false)
                btn.cooldown:SetCooldown(0, 0)
                if db.showReadyGlow and btn.glow then
                    btn.glow:SetAlpha(0.3)
                elseif btn.glow then
                    btn.glow:SetAlpha(0)
                end
            end
        end
    elseif frame then
        frame:Show()
        if frame.bar then
            frame.bar:SetMinMaxValues(0, 1)
            frame.bar:SetValue(1)
            frame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
        end
        if frame.ready then frame.ready:Show() end
        if frame.time then frame.time:Hide() end
        if frame.icon then frame.icon:SetDesaturated(false) end
    end
end

-- End test mode
function Castborn:EndTestInterrupt()
    testModeActive = false
    if frame then
        frame:Hide()
    end
    for _, btn in pairs(attachedIcons) do
        btn:Hide()
        if btn.glow then btn.glow:SetAlpha(0) end
    end
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Interrupt", function() Castborn:TestInterrupt() end, function() Castborn:EndTestInterrupt() end)
end)

Castborn:RegisterModule("InterruptTracker", InterruptTracker)
