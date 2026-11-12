--[[
    Castborn - resource bars on Forever
    Health and power are secret (mana even out of combat), so nothing here compares,
    adds or divides them. Values go straight into sinks: StatusBar SetMinMaxValues/SetValue
    and FontString SetFormattedText. AbbreviateNumbers accepts secrets (AllowedWhenTainted).
    Percentages come from UnitHealthPercent / UnitPowerPercent, which return 0-1 unless given
    a curve, so CurveConstants.ScaleTo100 scales them for display.
    Loaded only by Castborn_Camelot.toc, after ResourceBars.lua.
]]

local ResourceBars = Castborn.ResourceBars

-- Abbreviated when the client can, otherwise the full number
local function Abbreviate(value)
    if AbbreviateNumbers then return AbbreviateNumbers(value) end
    return value
end

local function PercentCurve()
    return CurveConstants and CurveConstants.ScaleTo100
end

function ResourceBars:SupportsPercent()
    if self.percentFailed then return false end
    return UnitHealthPercent ~= nil and UnitPowerPercent ~= nil and PercentCurve() ~= nil
end

local function ReadPercent(unit, kind)
    if kind == "health" then
        return UnitHealthPercent(unit, true, PercentCurve())
    end
    local powerType = UnitPowerType(unit)
    return UnitPowerPercent(unit, powerType, false, PercentCurve())
end

local function WriteCurrentMax(fontString, current, max)
    fontString:SetFormattedText("%s / %s", Abbreviate(current), Abbreviate(max))
end

function ResourceBars:SetBarValues(bar, current, max)
    bar:SetMinMaxValues(0, max)
    bar:SetValue(current)
end

function ResourceBars:FormatText(fontString, current, max, unit, kind)
    local format = self:GetTextFormat(Castborn.db and Castborn.db.resources)
    if format == "NONE" then
        fontString:SetText("")
    elseif format == "CURRENT" then
        fontString:SetFormattedText("%s", Abbreviate(current))
    elseif format == "PERCENT" or format == "CURRENT_PERCENT" then
        -- Unverified in game: if the client refuses, stop trying and show current / max
        local ok = pcall(function()
            local percent = ReadPercent(unit, kind)
            if format == "PERCENT" then
                fontString:SetFormattedText("%.0f%%", percent)
            else
                fontString:SetFormattedText("%s (%.0f%%)", Abbreviate(current), percent)
            end
        end)
        if not ok then
            self.percentFailed = true
            WriteCurrentMax(fontString, current, max)
        end
    else
        WriteCurrentMax(fontString, current, max)
    end
end

-- Comparing a secret max errors, so the power bar always stays shown
function ResourceBars:ShouldHidePower(max)
    return false
end
