-- Modules/InterruptTracker.lua
local InterruptTracker = {}
Castborn.InterruptTracker = InterruptTracker

local frame = nil
local lockoutFrame = nil
local testModeActive = false

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
    frame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)

    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(db.height, db.height)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.icon:SetTexture(GetSpellTexture(interruptInfo.spellId))
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    if frame.bar then
        frame.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", db.height + 2, -1)
    end

    frame.time = frame:CreateFontString(nil, "OVERLAY")
    frame.time:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
    frame.time:SetPoint("CENTER", frame.bar or frame, "CENTER")

    frame.ready = frame:CreateFontString(nil, "OVERLAY")
    frame.ready:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
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
    lockoutFrame.text:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
    lockoutFrame.text:SetPoint("CENTER")

    lockoutFrame.school = nil
    lockoutFrame.expirationTime = 0

    lockoutFrame:Hide()

    return lockoutFrame
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

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", OnCombatLogEvent)

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.05 then
            UpdateInterruptCooldown()
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
        mockFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        mockFrame.bar:SetMinMaxValues(0, 1)
        mockFrame.bar:SetValue(1)
        mockFrame.bar:SetStatusBarColor(0.2, 0.8, 0.2, 1)

        mockFrame.icon = mockFrame:CreateTexture(nil, "ARTWORK")
        mockFrame.icon:SetSize(db.height, db.height)
        mockFrame.icon:SetPoint("LEFT", mockFrame, "LEFT", 0, 0)
        mockFrame.icon:SetTexture("Interface\\Icons\\Spell_Frost_IceShock")
        mockFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        mockFrame.ready = mockFrame:CreateFontString(nil, "OVERLAY")
        mockFrame.ready:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
        mockFrame.ready:SetPoint("CENTER", mockFrame.bar, "CENTER")
        mockFrame.ready:SetText("READY")
        mockFrame.ready:SetTextColor(0.2, 1, 0.2, 1)

        mockFrame.isMockup = true
        frame = mockFrame

        if Castborn.Anchoring then
            Castborn.Anchoring:MakeDraggable(mockFrame, db, nil, "Interrupt")
        end
    end

    if frame then
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
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Interrupt", function() Castborn:TestInterrupt() end, function() Castborn:EndTestInterrupt() end)
end)

Castborn:RegisterModule("InterruptTracker", InterruptTracker)
