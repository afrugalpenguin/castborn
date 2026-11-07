--[[
    Castborn - tutorial text for the Forever build
    Tutorial.lua already skips steps for modules Forever does not load. This file rewrites
    the steps whose text describes something Forever does not have.
    Loaded only by Castborn_Camelot.toc, after Tutorial.lua.
]]

for _, step in ipairs(Castborn.Tutorial.steps) do
    if step.id == "castbar_companions" then
        -- No five-second rule on Forever (mana is a secret value), so only the GCD bar remains
        step.title = "GCD Indicator"
        step.description = "A thin bar under your player castbar sweeps left-to-right while your Global Cooldown is active, helping you time your next ability."
        step.tip = "The bar anchors to your player castbar by default."
        step.configKeys = { "gcd" }
    elseif step.id == "interrupt" then
        -- The lockout needs the combat log, which Forever blocks
        step.description = "Track your interrupt ability's cooldown. The bar turns yellow when your target or focus is casting something you can interrupt."
        step.tip = "Shows when your kick or counterspell is ready."
    elseif step.id == "absorbs" then
        -- Absorbs are not on Forever, so this step covers only the armour reminder
        step.title = "Armour Tracker"
        step.description = "Shows an alert icon when your class buff is missing (e.g. Mage Armour, Demon Skin). A quick reminder to rebuff after dying or zoning.\n\nPaladins get an alert for your chosen |cff88ddffBlessing|r (Might, Wisdom, Kings, or Sanctuary) and for your |cff88ddffAura|r.\n\nBuffs are checked out of combat, so the reminder holds its state during a fight."
        step.tip = "Paladins can choose which blessing to track in Options > Armour."
        step.getFrame = function() return _G["Castborn_ArmorTracker"] end
        step.configKeys = { "armortracker" }
    end
end
