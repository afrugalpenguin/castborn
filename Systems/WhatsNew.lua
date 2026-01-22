--[[
    Castborn - What's New System
    Shows changelog when users open options after an addon update
]]

local WhatsNew = {}
Castborn.WhatsNew = WhatsNew

local whatsNewFrame = nil

--------------------------------------------------------------------------------
-- Changelog Data (embedded for last several versions)
--------------------------------------------------------------------------------

local changelog = {
    {
        version = "2.7.0",
        features = {
            "Cooldown tracker now auto-merges new default spells when addon updates (no more missing spells after upgrades)",
            "Added \"What's New\" overlay that shows changelog when opening /cb after an addon update",
        },
        fixes = {},
    },
    {
        version = "2.6.12",
        features = {
            "Implemented \"Anchor to Castbar\" for DoT Tracker, Swing Timer, and Proc Tracker",
            "All anchorable modules now properly follow the player castbar when moved",
        },
        fixes = {
            "Fixed /cb reset not resetting Swing Timer and other modules with anchoring",
        },
    },
    {
        version = "2.6.11",
        features = {},
        fixes = {
            "Fixed options sliders sliding vertically instead of horizontally",
            "Improved slider aesthetics with progress fill bar and native WoW thumb",
            "Exclude self-casts from non-player castbars",
        },
    },
}

--------------------------------------------------------------------------------
-- Version Comparison
--------------------------------------------------------------------------------

function WhatsNew:ShouldShow()
    local currentVersion = Castborn.version
    local lastSeen = CastbornDB.lastSeenVersion

    -- Show if no last seen version (new install or first update with this feature)
    -- Or if current version is different from last seen
    return lastSeen == nil or lastSeen ~= currentVersion
end

function WhatsNew:MarkAsSeen()
    CastbornDB.lastSeenVersion = Castborn.version
end

--------------------------------------------------------------------------------
-- UI Creation
--------------------------------------------------------------------------------

local function CreateWhatsNewFrame()
    local frame = CreateFrame("Frame", "CastbornWhatsNewFrame", UIParent, "BackdropTemplate")
    frame:SetSize(450, 380)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(200)

    -- Dark backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.12, 0.98)
    frame:SetBackdropBorderColor(0.4, 0.6, 0.9, 1)

    -- Make it movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -16)
    frame.title:SetText("|cff88ddffWhat's New in Castborn v" .. Castborn.version .. "|r")

    -- Decorative line under title
    frame.titleLine = frame:CreateTexture(nil, "ARTWORK")
    frame.titleLine:SetHeight(1)
    frame.titleLine:SetPoint("TOPLEFT", 20, -42)
    frame.titleLine:SetPoint("TOPRIGHT", -20, -42)
    frame.titleLine:SetColorTexture(0.4, 0.6, 0.9, 0.5)

    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 50)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1) -- Height will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    -- "Got it!" button
    frame.gotItBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.gotItBtn:SetSize(100, 26)
    frame.gotItBtn:SetPoint("BOTTOM", 0, 14)
    frame.gotItBtn:SetText("Got it!")
    frame.gotItBtn:SetScript("OnClick", function()
        WhatsNew:Hide()
    end)

    -- Dim overlay behind the frame
    frame.overlay = CreateFrame("Frame", "CastbornWhatsNewOverlay", UIParent)
    frame.overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.overlay:SetFrameLevel(199)
    frame.overlay:SetAllPoints(UIParent)
    frame.overlay:EnableMouse(true) -- Block clicks to things behind

    frame.overlay.bg = frame.overlay:CreateTexture(nil, "BACKGROUND")
    frame.overlay.bg:SetAllPoints()
    frame.overlay.bg:SetColorTexture(0, 0, 0, 0.7)

    frame.overlay:Hide()

    frame:Hide()
    return frame
end

local function PopulateChangelog(scrollChild)
    -- Clear existing content
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local y = 0
    local contentWidth = scrollChild:GetWidth() - 10

    for i, entry in ipairs(changelog) do
        -- Version header
        local versionHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        versionHeader:SetPoint("TOPLEFT", 0, y)
        versionHeader:SetWidth(contentWidth)
        versionHeader:SetJustifyH("LEFT")

        if i == 1 then
            versionHeader:SetText("|cffFFCC00Version " .. entry.version .. " (Current)|r")
        else
            versionHeader:SetText("|cff888888Version " .. entry.version .. "|r")
        end

        y = y - 20

        -- Features section
        if #entry.features > 0 then
            local featuresLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            featuresLabel:SetPoint("TOPLEFT", 8, y)
            featuresLabel:SetText("|cff88ddffFeatures:|r")
            y = y - 16

            for _, feature in ipairs(entry.features) do
                local bullet = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bullet:SetPoint("TOPLEFT", 16, y)
                bullet:SetWidth(contentWidth - 24)
                bullet:SetJustifyH("LEFT")
                bullet:SetText("|cffcccccc-|r " .. feature)
                bullet:SetSpacing(2)

                -- Calculate height based on text wrapping
                local textHeight = bullet:GetStringHeight()
                y = y - textHeight - 4
            end
        end

        -- Fixes section
        if #entry.fixes > 0 then
            local fixesLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fixesLabel:SetPoint("TOPLEFT", 8, y)
            fixesLabel:SetText("|cff88ff88Fixes:|r")
            y = y - 16

            for _, fix in ipairs(entry.fixes) do
                local bullet = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bullet:SetPoint("TOPLEFT", 16, y)
                bullet:SetWidth(contentWidth - 24)
                bullet:SetJustifyH("LEFT")
                bullet:SetText("|cffcccccc-|r " .. fix)
                bullet:SetSpacing(2)

                -- Calculate height based on text wrapping
                local textHeight = bullet:GetStringHeight()
                y = y - textHeight - 4
            end
        end

        -- Add spacing between versions
        y = y - 12
    end

    -- Set scroll child height
    scrollChild:SetHeight(math.abs(y) + 20)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function WhatsNew:Show()
    if not whatsNewFrame then
        whatsNewFrame = CreateWhatsNewFrame()
    end

    -- Update title with current version
    whatsNewFrame.title:SetText("|cff88ddffWhat's New in Castborn v" .. Castborn.version .. "|r")

    -- Populate changelog content
    PopulateChangelog(whatsNewFrame.scrollChild)

    whatsNewFrame.overlay:Show()
    whatsNewFrame:Show()
end

function WhatsNew:Hide()
    if whatsNewFrame then
        whatsNewFrame:Hide()
        whatsNewFrame.overlay:Hide()
    end

    -- Mark as seen when dismissed
    self:MarkAsSeen()
end

function WhatsNew:IsShown()
    return whatsNewFrame and whatsNewFrame:IsShown()
end

Castborn:RegisterModule("WhatsNew", WhatsNew)
