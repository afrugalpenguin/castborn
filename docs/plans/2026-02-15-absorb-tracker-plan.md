# Absorb Tracker MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an AbsorbTracker module that shows a draining bar with numeric text when Ice Barrier is active on a mage.

**Architecture:** New `Modules/AbsorbTracker.lua` following existing module pattern (SwingTimer as primary reference). Uses COMBAT_LOG_EVENT_UNFILTERED to detect Ice Barrier buff applied/removed, tooltip scanning for initial absorb value, and combat log damage events to track remaining absorb. Bar uses the standard CreateBackdrop + StatusBar pattern with fade animations.

**Tech Stack:** WoW Lua API, Castborn module system, CLEU combat log parsing, GameTooltip scanning.

---

### Task 1: Add Ice Barrier spell data to SpellData.lua

**Files:**
- Modify: `Data/SpellData.lua` (after line 511, before the final `end`-less return)

**Step 1: Add the absorbs data table**

Add a new `absorbs` section to SpellData, keyed by buff spell ID. Each entry has the spell name and duration. We don't need base absorb values since we'll tooltip-scan for the real value.

```lua
-- In Data/SpellData.lua, after the cooldowns/racialCooldowns sections, before the functions:

-- Absorb shields (keyed by buff spell ID)
SpellData.absorbs = {
    -- Mage - Ice Barrier (all ranks)
    [11426] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [13031] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [13032] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [13033] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [27134] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
    [33405] = { name = "Ice Barrier", duration = 60, class = "MAGE" },
}

function SpellData:GetAbsorbInfo(spellId)
    return self.absorbs[spellId]
end
```

**Step 2: Verify no syntax errors**

Run: `luacheck Data/SpellData.lua`
Expected: No new errors (existing warnings are OK)

**Step 3: Commit**

```
git add Data/SpellData.lua
git commit -m "feat(absorb): add Ice Barrier spell data for absorb tracking"
```

---

### Task 2: Create AbsorbTracker module — frame creation

**Files:**
- Create: `Modules/AbsorbTracker.lua`

**Step 1: Create the module file with frame creation**

Reference `Modules/SwingTimer.lua` for the bar pattern. The absorb bar is a single standalone bar (not a container with multiple bars like SwingTimer).

```lua
--[[
    Castborn - Absorb Tracker Module
    Tracks absorb shield remaining amount (Ice Barrier MVP)
]]

local AbsorbTracker = {}
Castborn.AbsorbTracker = AbsorbTracker

local CB = Castborn

-- State
local absorbFrame = nil
local absorbState = {
    active = false,
    spellId = nil,
    spellName = nil,
    maxAbsorb = 0,
    remaining = 0,
    startTime = 0,
    duration = 0,
}
local testModeActive = false
local playerGUID = nil

-- Fade animation helpers
local function FadeIn(frame, duration)
    frame:SetAlpha(0)
    frame:Show()
    local elapsed = 0
    local fadeDuration = duration or 0.3
    frame.fadeFrame = frame.fadeFrame or CreateFrame("Frame")
    frame.fadeFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local progress = math.min(1, elapsed / fadeDuration)
        frame:SetAlpha(progress)
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function FadeOut(frame, duration)
    local startAlpha = frame:GetAlpha()
    local elapsed = 0
    local fadeDuration = duration or 0.3
    frame.fadeFrame = frame.fadeFrame or CreateFrame("Frame")
    frame.fadeFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local progress = math.min(1, elapsed / fadeDuration)
        frame:SetAlpha(startAlpha * (1 - progress))
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            frame:Hide()
            frame:SetAlpha(1)
        end
    end)
end

local function FormatNumber(num)
    if num >= 1000 then
        return string.format("%d,%03d", math.floor(num / 1000), num % 1000)
    end
    return tostring(num)
end

local function CreateAbsorbBar()
    local cfg = CB.db.absorbs

    local frame = CreateFrame("Frame", "Castborn_AbsorbTracker", UIParent)
    frame:SetSize(cfg.width, cfg.barHeight)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(5)

    CB:CreateBackdrop(frame, cfg.bgColor, cfg.borderColor)

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetStatusBarColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], cfg.barColor[4])
    frame.bar = bar

    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(16, cfg.barHeight * 2)
    spark:Hide()
    frame.spark = spark

    -- Left text: spell name
    local label = bar:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\ARIALN.TTF", math.max(8, cfg.barHeight - 6), "OUTLINE")
    label:SetPoint("LEFT", bar, "LEFT", 4, 0)
    label:SetText("")
    frame.label = label

    -- Right text: absorb remaining + timer
    local valueText = bar:CreateFontString(nil, "OVERLAY")
    valueText:SetFont("Fonts\\ARIALN.TTF", math.max(8, cfg.barHeight - 6), "OUTLINE")
    valueText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    frame.valueText = valueText

    -- Make draggable via Anchoring system
    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, CB.db.absorbs, nil, "Absorb Tracker")
    else
        CB:MakeMoveable(frame, "absorbs")
    end
    CB:ApplyPosition(frame, "absorbs")

    frame:Hide()
    return frame
end
```

**Step 2: Verify no syntax errors**

Run: `luacheck Modules/AbsorbTracker.lua`
Expected: Warnings about globals (normal for WoW addon files), no errors

**Step 3: Commit**

```
git add Modules/AbsorbTracker.lua
git commit -m "feat(absorb): create AbsorbTracker module with bar frame"
```

---

### Task 3: Add tooltip scanning and combat log detection

**Files:**
- Modify: `Modules/AbsorbTracker.lua`

**Step 1: Add tooltip scanning function**

This scans the player's buff tooltip to extract the absorb amount. Must be appended after `CreateAbsorbBar()` and before the INIT/READY callbacks.

```lua
-- Tooltip scanning for absorb amount
local scanTooltip = CreateFrame("GameTooltip", "CastbornAbsorbScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function ScanAbsorbTooltip(spellId)
    scanTooltip:ClearLines()
    scanTooltip:SetSpellByID(spellId)
    for i = 1, scanTooltip:NumLines() do
        local text = _G["CastbornAbsorbScanTooltipTextLeft" .. i]:GetText()
        if text then
            -- Match patterns like "Absorbs 2847 damage" or "absorbs up to 2847 damage"
            local amount = text:match("(%d[%d,]+)%s+damage")
            if amount then
                amount = amount:gsub(",", "")
                return tonumber(amount)
            end
        end
    end
    return nil
end
```

**Step 2: Add the combat log event handler and update loop**

```lua
local function ShowAbsorb(spellId, spellName, absorbAmount, duration)
    absorbState.active = true
    absorbState.spellId = spellId
    absorbState.spellName = spellName
    absorbState.maxAbsorb = absorbAmount
    absorbState.remaining = absorbAmount
    absorbState.startTime = GetTime()
    absorbState.duration = duration

    if absorbFrame then
        absorbFrame.label:SetText(spellName)
        FadeIn(absorbFrame, 0.3)
    end
end

local function HideAbsorb()
    absorbState.active = false
    if absorbFrame and absorbFrame:IsShown() then
        FadeOut(absorbFrame, 0.3)
    end
end

local function UpdateAbsorbBar()
    if not absorbFrame or not absorbState.active then return end
    if not CB.db.absorbs.enabled then absorbFrame:Hide() return end

    local remaining = absorbState.remaining
    local max = absorbState.maxAbsorb

    if max > 0 then
        absorbFrame.bar:SetValue(remaining / max)
        local sparkPos = (remaining / max) * absorbFrame.bar:GetWidth()
        absorbFrame.spark:SetPoint("CENTER", absorbFrame.bar, "LEFT", sparkPos, 0)
        absorbFrame.spark:Show()
    end

    -- Time remaining
    local timeLeft = (absorbState.startTime + absorbState.duration) - GetTime()
    if timeLeft <= 0 then
        HideAbsorb()
        return
    end

    absorbFrame.valueText:SetText(FormatNumber(math.floor(remaining)) .. " | " .. string.format("%.0f", timeLeft) .. "s")
end

local function OnCombatLogEvent()
    local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- Check for absorb buff applied (self-cast)
    if (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH") and sourceGUID == playerGUID and destGUID == playerGUID then
        local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
        local absorbInfo = Castborn.SpellData:GetAbsorbInfo(spellId)
        if absorbInfo then
            local absorbAmount = ScanAbsorbTooltip(spellId)
            if absorbAmount and absorbAmount > 0 then
                ShowAbsorb(spellId, absorbInfo.name, absorbAmount, absorbInfo.duration)
            end
        end
    end

    -- Check for absorb buff removed
    if subevent == "SPELL_AURA_REMOVED" and destGUID == playerGUID then
        local spellId = select(12, CombatLogGetCurrentEventInfo())
        if absorbState.active and absorbState.spellId == spellId then
            HideAbsorb()
        end
    end

    -- Track damage absorbed while shield is active
    if absorbState.active and destGUID == playerGUID then
        if subevent == "SWING_DAMAGE" then
            local absorbed = select(20, CombatLogGetCurrentEventInfo())  -- absorbed is param 20 for SWING_DAMAGE
            if absorbed and absorbed > 0 then
                absorbState.remaining = math.max(0, absorbState.remaining - absorbed)
            end
        elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
            local absorbed = select(23, CombatLogGetCurrentEventInfo())  -- absorbed is param 23 for SPELL_DAMAGE
            if absorbed and absorbed > 0 then
                absorbState.remaining = math.max(0, absorbState.remaining - absorbed)
            end
        end
    end
end
```

**Important note on combat log params:** The `absorbed` field position in `CombatLogGetCurrentEventInfo()` varies by subevent. For TBC Classic CLEU:
- `SWING_DAMAGE`: params are `amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing` starting at param 12
- `SPELL_DAMAGE`: params are `spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing` starting at param 12

So for SWING_DAMAGE, absorbed = select(17) [12+5], and for SPELL_DAMAGE, absorbed = select(20) [12+8]. **These positions need to be verified in-game** — the exact indices can shift between Classic versions. The implementer should add a debug print to verify during testing.

**Step 2: Commit**

```
git add Modules/AbsorbTracker.lua
git commit -m "feat(absorb): add tooltip scanning and combat log detection"
```

---

### Task 4: Add INIT/READY callbacks and module registration

**Files:**
- Modify: `Modules/AbsorbTracker.lua` (append to end of file)

**Step 1: Add the lifecycle callbacks**

```lua
-- Default settings
local defaults = {
    enabled = true,
    width = 250,
    barHeight = 20,
    barColor = {0.4, 0.7, 1.0, 1.0},
    bgColor = {0.1, 0.1, 0.1, 0.8},
    borderColor = {0.3, 0.3, 0.3, 1},
    point = "CENTER",
    xPct = 0,
    yPct = -0.185,
}

CB:RegisterCallback("INIT", function()
    CastbornDB.absorbs = CB:MergeDefaults(CastbornDB.absorbs or {}, defaults)

    -- Only enable for mages by default
    local _, class = UnitClass("player")
    if class ~= "MAGE" then
        -- Don't override if user has explicitly set it
        if CastbornDB.absorbs.enabled == nil then
            CastbornDB.absorbs.enabled = false
        end
    end
end)

CB:RegisterCallback("READY", function()
    local _, class = UnitClass("player")
    if class ~= "MAGE" then return end
    if not CastbornDB.absorbs.enabled then return end

    playerGUID = UnitGUID("player")
    absorbFrame = CreateAbsorbBar()

    -- Event frame for combat log
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        end
    end)

    -- Update loop
    CB:CreateThrottledUpdater(0.05, function()
        if testModeActive then return end
        UpdateAbsorbBar()
    end)

    -- Register with TestManager
    CB.TestManager:Register("AbsorbTracker",
        function() CB:TestAbsorbTracker() end,
        function() CB:EndTestAbsorbTracker() end
    )
end)

-- Test mode functions
function CB:TestAbsorbTracker()
    if not absorbFrame then return end
    testModeActive = true

    absorbFrame.label:SetText("Ice Barrier")
    absorbFrame.bar:SetValue(0.65)
    local sparkPos = 0.65 * absorbFrame.bar:GetWidth()
    absorbFrame.spark:SetPoint("CENTER", absorbFrame.bar, "LEFT", sparkPos, 0)
    absorbFrame.spark:Show()
    absorbFrame.valueText:SetText("1,847 | 42s")
    absorbFrame:SetAlpha(1)
    absorbFrame:Show()
end

function CB:EndTestAbsorbTracker()
    testModeActive = false
    if absorbFrame then absorbFrame:Hide() end
end

CB:RegisterModule("AbsorbTracker", AbsorbTracker)
```

**Step 2: Verify no syntax errors**

Run: `luacheck Modules/AbsorbTracker.lua`
Expected: Warnings about globals only, no errors

**Step 3: Commit**

```
git add Modules/AbsorbTracker.lua
git commit -m "feat(absorb): add lifecycle callbacks and test mode"
```

---

### Task 5: Add to TOC file

**Files:**
- Modify: `Castborn.toc`

**Step 1: Add the module to the TOC**

Add `Modules/AbsorbTracker.lua` after `Modules/TotemTracker.lua` in the TOC file (line 29):

```
Modules/TotemTracker.lua
Modules/AbsorbTracker.lua
```

**Step 2: Commit**

```
git add Castborn.toc
git commit -m "feat(absorb): add AbsorbTracker to TOC"
```

---

### Task 6: Add Options panel section

**Files:**
- Modify: `Systems/Options.lua`

**Step 1: Add category to sidebar**

In the `categories` table (around line 40), add the absorb tracker entry. Insert it after the totems entry (line 51), restricted to MAGE class:

```lua
    { id = "totems", name = "Totems", class = "SHAMAN" },
    { id = "absorbs", name = "Absorbs", class = "MAGE" },
```

**Step 2: Add to BuildModule titles table**

In `Options:BuildModule()` (around line 1230), add to the `titles` table:

```lua
    local titles = {
        gcd = "GCD Indicator",
        fsr = "5 Second Rule",
        swing = "Swing Timer",
        dots = "DoT Tracker",
        multidot = "Multi-DoT Tracker",
        buffs = "Proc Tracker",
        cooldowns = "Cooldown Tracker",
        interrupt = "Interrupt Tracker",
        totems = "Totem Tracker",
        absorbs = "Absorb Tracker",
    }
```

**Step 3: Add width/height slider support**

In the width slider conditional (around line 1253), add `"absorbs"` to the condition:

```lua
    if key == "gcd" or key == "fsr" or key == "swing" or key == "absorbs" then
```

Also add the absorb frame resize callback inside the width slider callback:

```lua
            elseif key == "absorbs" and Castborn.AbsorbTracker then
                local f = _G["Castborn_AbsorbTracker"]
                if f then f:SetWidth(v) end
```

And handle height for absorbs alongside gcd/fsr (around line 1266):

```lua
        if key == "gcd" or key == "fsr" or key == "absorbs" then
```

With a height callback:

```lua
                elseif key == "absorbs" then
                    local f = _G["Castborn_AbsorbTracker"]
                    if f then f:SetHeight(v) end
```

**Step 4: Add module-specific options section**

Add an `elseif` branch for the absorbs key (after the totems section, around line 1530):

```lua
    elseif key == "absorbs" then
        local testBtn = CreateButton(parent, "Test Absorb", 90, function()
            if Castborn.TestAbsorbTracker then Castborn:TestAbsorbTracker() end
        end)
        testBtn:SetPoint("TOPLEFT", 0, y)
```

**Step 5: Commit**

```
git add Systems/Options.lua
git commit -m "feat(absorb): add Absorb Tracker options panel"
```

---

### Task 7: In-game testing and tuning

**Files:**
- Possibly modify: `Modules/AbsorbTracker.lua`

**Step 1: Test in-game with `/cb test`**

- Verify the absorb bar appears in test mode
- Verify it's draggable
- Verify it hides when test mode ends

**Step 2: Test with actual Ice Barrier cast**

- Cast Ice Barrier and verify:
  - Bar appears with fade-in
  - Correct absorb amount shown (tooltip scanned)
  - Duration countdown works
  - Taking damage drains the bar
  - Bar fades out when shield breaks or expires
  - Recasting refreshes correctly

**Step 3: Verify combat log absorbed field positions**

Add temporary debug prints if needed:
```lua
CB:Print("SWING_DAMAGE absorbed param: " .. tostring(select(17, CombatLogGetCurrentEventInfo())))
CB:Print("SPELL_DAMAGE absorbed param: " .. tostring(select(20, CombatLogGetCurrentEventInfo())))
```

Adjust the `select()` indices if they don't match. Remove debug prints once verified.

**Step 4: Tune and commit any fixes**

```
git add Modules/AbsorbTracker.lua
git commit -m "fix(absorb): tune combat log field positions for TBC Classic"
```

---

## Notes for implementer

- **Combat log field positions are the riskiest part.** The `select()` indices for the `absorbed` field in SWING_DAMAGE vs SPELL_DAMAGE events may differ from what's documented. Test in-game and adjust.
- **Tooltip scanning**: `SetSpellByID` may not work for all buff spell IDs in TBC. If it fails, try scanning the player's buff tooltip directly using `scanTooltip:SetUnitBuff("player", buffIndex)` by iterating player buffs.
- **Ice Barrier spell IDs**: The IDs in SpellData (11426, 13031, 13032, 13033, 27134, 33405) should be the buff aura IDs. Verify these are what CLEU reports in SPELL_AURA_APPLIED. If the CLEU reports different IDs, update SpellData accordingly.
