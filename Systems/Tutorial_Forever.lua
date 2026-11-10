--[[
    Castborn - tutorial text for the Forever build
    Tutorial.lua already skips steps for modules Forever does not load. This file rewrites
    the steps whose text describes something Forever does not have.
    Loaded only by Castborn_Camelot.toc, after Tutorial.lua.
]]

-- Highlighted words in step text, as in Tutorial.lua
local HL = "|cfff0cf7a"

for _, step in ipairs(Castborn.Tutorial.steps) do
    if step.id == "castbar_companions" then
        -- No five-second rule on Forever (mana is a secret value), so only the GCD bar remains
        step.title = "GCD Indicator"
        step.description = "A thin bar under your castbar sweeps across while your global cooldown runs, so you know when your next ability is ready."
        step.tip = "It follows your player castbar unless you detach it."
        step.configKeys = { "gcd" }
    elseif step.id == "interrupt" then
        -- The lockout needs the combat log, which Forever blocks
        step.description = "Your interrupt's cooldown. The bar turns yellow when your target or focus is casting something you can interrupt."
        step.tip = "The bar shows " .. HL .. "READY|r when you can interrupt again."
    elseif step.id == "armour" then
        -- Buffs are only readable out of combat, and there is no Blessing of Sanctuary
        step.description = "An alert when your self-buff is missing, such as Mage Armour or Demon Skin, so you rebuff after dying or zoning.\n\nPaladins get alerts for their chosen " .. HL .. "Blessing|r (Might, Wisdom or Kings), their " .. HL .. "Aura|r, and " .. HL .. "Righteous Fury|r when Improved Righteous Fury is talented (or always, if you choose).\n\nBuffs are checked out of combat, so the reminder holds its state during a fight."
    elseif step.id == "seals" then
        -- Judgement does not consume the seal on Forever
        step.description = "Your active seal, with a sweep for the time it has left.\n\nWhen no seal is up, the icon turns red with a |cffff3333!|r so you can reseal, for example before a pull."
    end
end
