--[[
    Castborn - Configuration Module
    Slash commands and options
]]

local CB = Castborn

function CB:ResetPositions()
    local positionKeys = {"player", "target", "targettarget", "focus", "dots", "fsr", "swing", "gcd",
                          "interrupt", "procs", "cooldowns", "multidot"}

    for _, key in ipairs(positionKeys) do
        local def = CB.defaults[key]
        if not def then break end
        if CB.db[key] then
            CB.db[key].point = def.point
            CB.db[key].xPct = def.xPct
            CB.db[key].yPct = def.yPct
            if Castborn.Anchoring then
                CB.db[key].x, CB.db[key].y = Castborn.Anchoring:PercentToPixel(def.xPct, def.yPct)
            end
            if def.width then CB.db[key].width = def.width end
            if def.height then CB.db[key].height = def.height end
            if def.barHeight then CB.db[key].barHeight = def.barHeight end
            if def.iconSize then CB.db[key].iconSize = def.iconSize end
            if def.anchored ~= nil then CB.db[key].anchored = def.anchored end
        end
    end
    -- Apply positions and sizes to frames
    if CB.castbars then
        for k, bar in pairs(CB.castbars) do
            if CB.db[k] then
                CB:ApplyPosition(bar, k)
                bar:SetSize(CB.db[k].width, CB.db[k].height)
            end
        end
    end
    if CB.dotTracker then
        if CB.db.dots.anchored then
            Castborn:FireCallback("REATTACH_DOTS")
        else
            CB:ApplyPosition(CB.dotTracker, "dots")
        end
        CB.dotTracker:SetWidth(CB.db.dots.width)
    end
    if CB.fsrFrame then
        if CB.db.fsr.anchored then
            Castborn:FireCallback("REATTACH_FSR")
        else
            CB:ApplyPosition(CB.fsrFrame, "fsr")
        end
        CB.fsrFrame:SetSize(CB.db.fsr.width, CB.db.fsr.height)
    end
    if CB.swingTimers and CB.swingTimers.container then
        if CB.db.swing.anchored then
            Castborn:FireCallback("REATTACH_SWING")
        else
            CB:ApplyPosition(CB.swingTimers.container, "swing")
        end
    end
    if CB.gcdFrame then
        if CB.db.gcd.anchored then
            -- Re-anchor GCD to castbar
            Castborn:FireCallback("REATTACH_GCD")
        else
            CB:ApplyPosition(CB.gcdFrame, "gcd")
        end
        CB.gcdFrame:SetSize(CB.db.gcd.width, CB.db.gcd.height)
    end
    -- Apply to additional modules
    local interruptFrame = _G["Castborn_Interrupt"]
    if interruptFrame and CB.db.interrupt then
        CB:ApplyPosition(interruptFrame, "interrupt")
    end
    local procFrame = _G["Castborn_ProcTracker"]
    if procFrame and CB.db.procs then
        if CB.db.procs.anchored then
            Castborn:FireCallback("REATTACH_PROCS")
        else
            CB:ApplyPosition(procFrame, "procs")
        end
    end
    local cdFrame = _G["Castborn_CooldownTracker"]
    if cdFrame and CB.db.cooldowns then
        if CB.db.cooldowns.anchored then
            -- Re-anchor cooldowns to castbar
            Castborn:FireCallback("REATTACH_COOLDOWNS")
        else
            CB:ApplyPosition(cdFrame, "cooldowns")
        end
    end
    local multiDotFrame = _G["Castborn_MultiDoTTracker"]
    if multiDotFrame and CB.db.multidot then
        CB:ApplyPosition(multiDotFrame, "multidot")
    end
    CB:Print("All positions reset to defaults")
end

-- Register callback for Options panel reset button
CB:RegisterCallback("RESET_POSITIONS", function()
    CB:ResetPositions()
end)


function CB:ShowTest()
    CB:Print("Showing test bars for 99 seconds (use /cb test again to refresh)")
    local TEST_DURATION = 99

    if CB.castbars and CB.castbars.player then
        local frame = CB.castbars.player
        local cfg = CB.db.player
        frame.casting = true
        frame.channeling = false
        frame.startTime = GetTime()
        frame.endTime = GetTime() + TEST_DURATION
        frame.fadeOut = 0
        frame.bar:SetStatusBarColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
        if frame.icon then frame.icon:SetTexture("Interface\\Icons\\Spell_Fire_FireBolt02") end
        if frame.spellText then frame.spellText:SetText("Test Spell") end
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(0)
        frame:SetAlpha(1)
        frame:Show()
    end

    if CB.castbars and CB.castbars.target then
        local frame = CB.castbars.target
        local cfg = CB.db.target
        frame.casting = true
        frame.channeling = false
        frame.startTime = GetTime()
        frame.endTime = GetTime() + TEST_DURATION
        frame.fadeOut = 0
        frame.bar:SetStatusBarColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
        if frame.icon then frame.icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt") end
        if frame.spellText then frame.spellText:SetText("Enemy Cast") end
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(0)
        frame:SetAlpha(1)
        frame:Show()
    end

    if CB.castbars and CB.castbars.focus then
        local frame = CB.castbars.focus
        local cfg = CB.db.focus
        frame.casting = true
        frame.channeling = false
        frame.startTime = GetTime()
        frame.endTime = GetTime() + TEST_DURATION
        frame.fadeOut = 0
        frame.bar:SetStatusBarColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
        if frame.icon then frame.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning") end
        if frame.spellText then frame.spellText:SetText("Focus Cast") end
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(0)
        frame:SetAlpha(1)
        frame:Show()
    end
end

function CB:HideTestFrames()
    if CB.EndTestCastbars then
        CB:EndTestCastbars()
    elseif CB.castbars then
        for k, frame in pairs(CB.castbars) do
            if frame then
                frame.casting = false
                frame.channeling = false
                frame.fadeOut = 0
                frame:Hide()
            end
        end
    end

    if CB.EndTestSwingTimers then
        CB:EndTestSwingTimers()
    elseif CB.swingTimers and CB.swingTimers.container then
        CB.swingTimers.container:Hide()
    end

    if CB.EndTestGCD then
        CB:EndTestGCD()
    elseif CB.gcdFrame then
        CB.gcdFrame:Hide()
    end

    if CB.EndTestFSR then
        CB:EndTestFSR()
    elseif CB.fsrFrame then
        CB.fsrFrame:Hide()
    end

    if CB.dotTracker then
        CB.dotTracker:Hide()
    end

    local interruptFrame = _G["Castborn_Interrupt"] or _G["Castborn_Interrupt_Mock"]
    if interruptFrame then interruptFrame:Hide() end

    if Castborn.EndTestProcs then Castborn:EndTestProcs() end
    if Castborn.EndTestCooldowns then Castborn:EndTestCooldowns() end
    if Castborn.EndTestMultiDoT then Castborn:EndTestMultiDoT() end
    if Castborn.EndTestInterrupt then Castborn:EndTestInterrupt() end
end

local testModePanel = nil

function CB:ShowTestModePanel()
    if testModePanel then
        testModePanel:Show()
        return
    end

    local panel = CreateFrame("Frame", "CastbornTestModePanel", UIParent, "BackdropTemplate")
    panel:SetSize(160, 90)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -60)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    panel:SetBackdropColor(0.1, 0.1, 0.15, 0.95)
    panel:SetBackdropBorderColor(0.3, 0.5, 0.8, 1)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("|cff88ddffTest Mode|r")

    -- Show Grid button (toggles grid and unlocks frames when showing)
    local gridBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    gridBtn:SetSize(140, 22)
    gridBtn:SetPoint("TOP", 0, -28)
    gridBtn:SetText("Show Grid")
    gridBtn:SetScript("OnClick", function()
        if Castborn.GridPosition then
            if not Castborn.GridPosition.isActive then
                -- Showing grid - also unlock frames
                CastbornDB.locked = false
                if Castborn.Anchoring then
                    Castborn.Anchoring:ShowDragIndicators()
                end
            end
            Castborn.GridPosition:ToggleGrid()
        end
    end)

    -- Done button
    local doneBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    doneBtn:SetSize(140, 22)
    doneBtn:SetPoint("TOP", gridBtn, "BOTTOM", 0, -4)
    doneBtn:SetText("Done")
    doneBtn:SetScript("OnClick", function()
        -- End test mode properly (this handles locking, hiding indicators, etc.)
        CB:EndTestMode()
        -- Hide grid if active
        if Castborn.GridPosition and Castborn.GridPosition.isActive then
            Castborn.GridPosition:HideGrid()
        end
        -- Hide test frames
        if CB.HideTestFrames then CB:HideTestFrames() end
        panel:Hide()
        CB:Print("Test mode ended. Frames locked.")
    end)

    testModePanel = panel
    panel:Show()
end

function CB:HideTestModePanel()
    if testModePanel then
        testModePanel:Hide()
    end
    -- Fallback: hide by global name if local reference failed
    local globalPanel = _G["CastbornTestModePanel"]
    if globalPanel then
        globalPanel:Hide()
    end
end

function CB:InitConfig()
    -- Slash commands are registered in Options.lua
    CB:Print("Type /cb to open options, /cb help for commands")
end
