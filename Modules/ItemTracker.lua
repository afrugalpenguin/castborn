-- Modules/ItemTracker.lua
local ItemTracker = {}
Castborn.ItemTracker = ItemTracker

local frame = nil
local itemFrames = {}
local MAX_ITEMS = 20

local defaults = {
    enabled = true,
    iconSize = 36,
    spacing = 4,
    point = "CENTER",
    x = 450,
    y = -300,
    xPct = 0.234,
    yPct = -0.200,
    trackedItems = {},
    growDirection = "LEFT",
    iconsPerRow = 10,
}

-- Calculate x,y offsets for a given visible index with row wrapping
local function CalcIconPosition(visibleIndex, db)
    local size = db.iconSize or 36
    local spacing = db.spacing or 4
    local perRow = db.iconsPerRow or 10
    local col = (visibleIndex - 1) % perRow
    local row = math.floor((visibleIndex - 1) / perRow)
    local x = col * (size + spacing)
    local y = -(row * (size + spacing))
    return x, y
end

local function CreateItemFrame(parent, index)
    local size = CastbornDB.itemtracker.iconSize or 36

    -- Use Button frame for Masque compatibility
    local f = CreateFrame("Button", "Castborn_Item" .. index, parent)
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

    -- Cooldown frame (for item use cooldowns)
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetDrawEdge(true)
    f.cooldown:SetHideCountdownNumbers(false)
    f.cooldown:EnableMouse(false)
    f.Cooldown = f.cooldown  -- Masque alias

    -- Count text (bottom-right, like bag slots)
    f.count = f:CreateFontString(nil, "OVERLAY")
    f.count:SetFont(Castborn:GetBarFont(), 13, "OUTLINE")
    Castborn:RegisterFontString(f.count, 13, "OUTLINE")
    f.count:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Register with Masque if available
    if Castborn.Masque and Castborn.Masque.enabled then
        Castborn.Masque:AddButton("items", f, {
            Icon = f.icon,
            Cooldown = f.cooldown,
            Normal = f.Normal,
        })
    end

    -- Click-through
    f:Disable()
    f:EnableMouse(false)
    f:Hide()
    return f
end

local function CreateContainer()
    local db = CastbornDB.itemtracker

    frame = CreateFrame("Frame", "Castborn_ItemTracker", UIParent)
    local iconsPerRow = db.iconsPerRow or 10
    local numRows = math.ceil(MAX_ITEMS / iconsPerRow)
    frame:SetSize(db.iconSize * iconsPerRow + db.spacing * (iconsPerRow - 1),
                  db.iconSize * numRows + db.spacing * (numRows - 1) + 4)
    frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    for i = 1, MAX_ITEMS do
        itemFrames[i] = CreateItemFrame(frame, i)
    end

    if Castborn.Anchoring then
        Castborn.Anchoring:MakeDraggable(frame, db, nil, "Items")
    end

    frame:Hide()
    return frame
end

-- Item info cache (GetItemInfo may not return on first call)
local itemCache = {}

local function GetCachedItemInfo(itemId)
    if itemCache[itemId] then
        return itemCache[itemId].name, itemCache[itemId].texture
    end
    local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
    if name then
        itemCache[itemId] = { name = name, texture = texture }
        return name, texture
    end
    return nil, nil
end

local testModeActive = false

local function UpdateItems()
    if testModeActive then return end

    local db = CastbornDB.itemtracker
    if not db.enabled or not frame then
        if frame then frame:Hide() end
        return
    end

    local visibleIndex = 0
    for _, item in ipairs(db.trackedItems or {}) do
        if item.enabled ~= false then
            visibleIndex = visibleIndex + 1
            local itemFrame = itemFrames[visibleIndex]
            if not itemFrame then break end

            local name, texture = GetCachedItemInfo(item.itemId)
            if texture then
                itemFrame.icon:SetTexture(texture)

                local itemCount = GetItemCount(item.itemId)
                if itemCount > 0 then
                    itemFrame.count:SetText(itemCount)
                else
                    itemFrame.count:SetText("0")
                end

                -- Check cooldown
                local start, duration, enabled = GetItemCooldown(item.itemId)

                -- Desaturate if on cooldown or out of stock
                if (duration and duration > 1.5) or itemCount == 0 then
                    itemFrame.icon:SetDesaturated(true)
                    if duration and duration > 1.5 then
                        itemFrame.cooldown:SetCooldown(start, duration)
                    else
                        itemFrame.cooldown:Clear()
                    end
                else
                    itemFrame.icon:SetDesaturated(false)
                    itemFrame.cooldown:Clear()
                end

                -- Position with row wrapping
                local size = db.iconSize or 36
                itemFrame:ClearAllPoints()
                itemFrame:SetSize(size, size)

                local colX, rowY = CalcIconPosition(visibleIndex, db)
                if db.growDirection == "LEFT" then
                    itemFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -colX, rowY)
                else
                    itemFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, rowY)
                end

                itemFrame:Show()
            else
                itemFrame:Hide()
                visibleIndex = visibleIndex - 1
            end
        end
    end

    -- Hide remaining frames
    for i = visibleIndex + 1, MAX_ITEMS do
        if itemFrames[i] then
            itemFrames[i]:Hide()
        end
    end

    -- Resize container to fit content
    if visibleIndex > 0 then
        local perRow = db.iconsPerRow or 10
        local size = db.iconSize or 36
        local spacing = db.spacing or 4
        local cols = math.min(visibleIndex, perRow)
        local rows = math.ceil(visibleIndex / perRow)
        frame:SetSize(cols * size + (cols - 1) * spacing,
                      rows * size + (rows - 1) * spacing + 4)
        frame:Show()
        if frame.dragIndicator and CastbornDB.locked ~= false then
            frame.dragIndicator:Hide()
        end
    else
        frame:Hide()
    end
end

Castborn:RegisterCallback("INIT", function()
    CastbornDB.itemtracker = Castborn:MergeDefaults(CastbornDB.itemtracker or {}, defaults)
end)

Castborn:RegisterCallback("READY", function()
    local db = CastbornDB.itemtracker

    CreateContainer()

    local updateFrame = CreateFrame("Frame")
    local elapsed = 0
    updateFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.1 then
            UpdateItems()
            elapsed = 0
        end
    end)
end)

-- Test mode
function Castborn:TestItems()
    local db = CastbornDB.itemtracker
    if not frame then return end

    testModeActive = true
    frame:Show()

    local testItems = {}
    for i, item in ipairs(db.trackedItems or {}) do
        if item.enabled ~= false then
            local _, texture = GetCachedItemInfo(item.itemId)
            if texture then
                table.insert(testItems, { texture = texture, itemId = item.itemId })
            end
        end
        if #testItems >= MAX_ITEMS then break end
    end

    -- Fallback if no items configured
    if #testItems == 0 then
        local fallbacks = {
            { texture = "Interface\\Icons\\INV_Potion_54", count = 5 },
            { texture = "Interface\\Icons\\INV_Potion_131", count = 3 },
            { texture = "Interface\\Icons\\INV_Misc_Bandage_12", count = 10 },
        }
        for _, fb in ipairs(fallbacks) do
            table.insert(testItems, fb)
        end
    end

    local size = db.iconSize or 36
    for i = 1, #testItems do
        local itemFrame = itemFrames[i]
        if itemFrame then
            itemFrame:ClearAllPoints()
            itemFrame:SetSize(size, size)

            local colX, rowY = CalcIconPosition(i, db)
            if db.growDirection == "LEFT" then
                itemFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -colX, rowY)
            else
                itemFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, rowY)
            end

            itemFrame.icon:SetTexture(testItems[i].texture)
            itemFrame.cooldown:Clear()

            -- Show count (real or test)
            local count = testItems[i].count
            if not count and testItems[i].itemId then
                count = GetItemCount(testItems[i].itemId)
            end
            itemFrame.count:SetText(count or "5")

            -- Desaturate second icon as demo
            itemFrame.icon:SetDesaturated(i == 2)
            if i == 2 then
                itemFrame.cooldown:SetCooldown(GetTime() - 5, 30)
            end

            itemFrame:Show()
        end
    end

    -- Hide remaining
    for i = #testItems + 1, MAX_ITEMS do
        if itemFrames[i] then itemFrames[i]:Hide() end
    end
end

function Castborn:EndTestItems()
    testModeActive = false
    if frame then
        for i = 1, MAX_ITEMS do
            if itemFrames[i] then
                itemFrames[i]:Hide()
            end
        end
        frame:Hide()
    end
end

-- Register with TestManager
Castborn:RegisterCallback("READY", function()
    Castborn.TestManager:Register("Items", function() Castborn:TestItems() end, function() Castborn:EndTestItems() end)
end)

Castborn:RegisterModule("ItemTracker", ItemTracker)
