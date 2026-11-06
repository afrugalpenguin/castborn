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
    end
end
