-- Systems/Masque.lua
-- Masque library integration for icon skinning

local MasqueSupport = {}
Castborn.Masque = MasqueSupport

-- Check if Masque is available
local MSQ = LibStub and LibStub("Masque", true)
MasqueSupport.enabled = MSQ ~= nil

-- Masque groups for different icon types
MasqueSupport.groups = {}

-- Initialize Masque groups
function MasqueSupport:Init()
    if not MSQ then
        Castborn:Print("Masque not found - icons will use default style")
        return
    end

    -- Create groups for different icon types
    self.groups.castbar = MSQ:Group("Castborn", "Castbar Icons")
    self.groups.cooldowns = MSQ:Group("Castborn", "Cooldown Icons")
    self.groups.buffs = MSQ:Group("Castborn", "Buff/Proc Icons")
    self.groups.dots = MSQ:Group("Castborn", "DoT Icons")
    self.groups.interrupts = MSQ:Group("Castborn", "Interrupt Icons")

    Castborn:Print("Masque support enabled")
end

-- Skin a button/icon frame with Masque
-- buttonData should include: Icon, Cooldown, Normal, Pushed, Highlight, etc.
function MasqueSupport:AddButton(groupName, button, buttonData)
    if not MSQ or not self.groups[groupName] then return end

    local group = self.groups[groupName]
    group:AddButton(button, buttonData)
end

-- Remove a button from Masque group
function MasqueSupport:RemoveButton(groupName, button)
    if not MSQ or not self.groups[groupName] then return end

    local group = self.groups[groupName]
    group:RemoveButton(button)
end

-- Reskin all buttons in a group (call after skin change)
function MasqueSupport:ReSkin(groupName)
    if not MSQ or not self.groups[groupName] then return end

    self.groups[groupName]:ReSkin()
end

-- Reskin all groups
function MasqueSupport:ReSkinAll()
    if not MSQ then return end

    for _, group in pairs(self.groups) do
        group:ReSkin()
    end
end

-- Helper: Create a Masque-compatible icon button
function MasqueSupport:CreateIconButton(parent, size, groupName)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)

    -- Create standard button textures that Masque expects
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.Icon = icon
    button.icon = icon  -- Alias for compatibility

    -- Normal texture (border)
    local normal = button:CreateTexture(nil, "BORDER")
    normal:SetPoint("TOPLEFT", -1, 1)
    normal:SetPoint("BOTTOMRIGHT", 1, -1)
    normal:SetColorTexture(0.3, 0.3, 0.3, 1)
    button.Normal = normal
    button:SetNormalTexture(normal)

    -- Cooldown frame
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(true)
    cooldown:SetHideCountdownNumbers(false)
    button.Cooldown = cooldown
    button.cooldown = cooldown  -- Alias

    -- Register with Masque if available
    if MSQ and self.groups[groupName] then
        self.groups[groupName]:AddButton(button, {
            Icon = icon,
            Cooldown = cooldown,
            Normal = normal,
        })
    end

    return button
end

-- Initialize on READY
Castborn:RegisterCallback("READY", function()
    MasqueSupport:Init()
end)
