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
        version = "3.1.4",
        features = {
            "Added Summon Water Elemental to Mage cooldown options",
        },
        fixes = {},
    },
    {
        version = "3.1.3",
        features = {},
        fixes = {
            "Improved castbar and GCD state handling during rapid casting/key presses",
        },
    },
    {
        version = "3.1.2",
        features = {},
        fixes = {
            "Fixed castbar getting stuck on screen when opening the world map during a cast",
        },
    },
    {
        version = "3.1.1",
        features = {},
        fixes = {
            "Fixed Ice Barrier (and other multi-rank talent spells) not being tracked by the Cooldown Tracker",
        },
    },
    {
        version = "3.1.0",
        features = {
            "Cooldown Tracker: added Icon Size, Spacing, and Grow Left options",
            "Cooldown Tracker: test mode now shows your actual configured spells",
            "Module options pages now scroll when content overflows",
        },
        fixes = {
            "Fixed missing cooldowns (Ice Barrier, Icy Veins) not appearing in options or tracker",
        },
    },
    {
        version = "3.0.0",
        features = {
            "Cooldown Tracker: per-spell enable/disable checkboxes in options (choose exactly which cooldowns to track)",
        },
        fixes = {
            "Removed unused Min Duration slider from Cooldown Tracker options",
        },
    },
    {
        version = "2.9.0",
        features = {
            "Cooldown icons now show a subtle golden glow when abilities become ready, drawing attention to available cooldowns",
            "Added \"Cooldowns Glow\" toggle under Look & Feel > Effects to enable/disable the ready glow",
        },
        fixes = {
            "Removed Multi-DoT click-to-target feature (TargetUnit is a Blizzard-protected action that cannot be called from addon code in combat)",
        },
    },
    {
        version = "2.8.2",
        features = {},
        fixes = {
            "Improved default positions: DoT tracker now mirrors cooldowns, Multi-DoT next to it",
        },
    },
    {
        version = "2.8.1",
        features = {},
        fixes = {
            "Frames now auto-lock when entering combat (prevents getting stuck in test mode)",
        },
    },
    {
        version = "2.8.0",
        features = {
            "Added \"Changelog\" menu item in options (under Profiles) with scrollable version history",
        },
        fixes = {
            "Multi-DoT Tracker now shows actual debuff durations instead of hardcoded values",
        },
    },
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
    {
        version = "2.6.10",
        features = {},
        fixes = { "Added Fear Ward to Priest cooldown tracking" },
    },
    {
        version = "2.6.9",
        features = {},
        fixes = { "Added Holy Fire to Priest Multi-DoT tracking" },
    },
    {
        version = "2.6.8",
        features = {},
        fixes = { "Added all ranks of Druid DoTs (Moonfire, Insect Swarm, Rake, Rip)" },
    },
    {
        version = "2.6.7",
        features = {},
        fixes = {
            "Added all ranks of Warlock DoTs (Corruption, Immolate, Curse of Agony, Curse of Doom, Unstable Affliction, Siphon Life)",
            "Removed Sunfire (not in TBC)",
        },
    },
    {
        version = "2.6.6",
        features = {},
        fixes = { "Added Vampiric Touch to Priest Multi-DoT tracking" },
    },
    {
        version = "2.6.5",
        features = {},
        fixes = { "Added all ranks of Shadow Word: Pain and Devouring Plague for Priest Multi-DoT tracking" },
    },
    {
        version = "2.6.4",
        features = {},
        fixes = { "Fixed proc tracker icons showing as grey boxes (draw layer issue)" },
    },
    {
        version = "2.6.3",
        features = {},
        fixes = { "Proc tracker duration now updates smoothly every 0.1s instead of only on buff changes" },
    },
    {
        version = "2.6.2",
        features = {},
        fixes = { "Fixed CurseForge changelog display" },
    },
    {
        version = "2.6.1",
        features = { "Added Ice Barrier to Mage default cooldowns" },
        fixes = {},
    },
    {
        version = "2.6.0",
        features = {
            "Added default cooldown tracking for Druid, Shaman, Hunter, Rogue, and Warrior",
            "All 9 classes now have default cooldowns configured",
        },
        fixes = {},
    },
    {
        version = "2.5.1",
        features = {},
        fixes = {
            "Added Ice Block to Mage default cooldowns",
            "Fixed upgrade migration so existing users get new default cooldowns",
        },
    },
    {
        version = "2.5.0",
        features = {
            "Added default cooldown tracking for Mage, Priest, Warlock, and Paladin",
            "Cooldown tracker now automatically shows class-relevant abilities (Cold Snap, Icy Veins, etc.)",
        },
        fixes = {},
    },
    {
        version = "2.4.2",
        features = {},
        fixes = {},
        changes = { "Profiles section now shows \"Coming Soon\" (not yet implemented)" },
    },
    {
        version = "2.4.1",
        features = {},
        fixes = { "Updated Interface version for TBC Anniversary (2.5.5)" },
    },
    {
        version = "2.4.0",
        features = {},
        fixes = {},
        changes = {
            "Removed duplicate \"Enabled\" checkboxes from individual module settings",
            "Module enable/disable toggles now only on General screen to avoid confusion",
        },
    },
    {
        version = "2.3.1",
        features = {},
        fixes = { "Fixed CurseForge showing incorrect version number" },
    },
    {
        version = "2.3.0",
        features = {
            "Player castbar now uses class colors by default",
            "Added \"Look & Feel\" section in options with class colors toggle",
            "Added divider in options menu to separate module settings from appearance/profiles",
        },
        fixes = {},
    },
    {
        version = "2.2.0",
        features = { "Added option to hide default Blizzard cast bar (under Player Castbar settings)" },
        fixes = {},
    },
    {
        version = "2.1.0",
        features = {},
        fixes = {
            "Adjusted default positions for target-of-target and focus castbars to avoid overlap with action bars",
            "Fixed release zip containing lowercase folder name causing addon to fail to load",
        },
    },
    {
        version = "2.0.0",
        features = {
            "Player, target, focus, and target-of-target castbars",
            "GCD indicator",
            "Five Second Rule tracker",
            "Swing timers (mainhand, offhand, ranged)",
            "DoT tracker",
            "Multi-DoT tracker",
            "Cooldown tracker",
            "Proc tracker",
            "Interrupt tracker",
        },
        fixes = {
            "Fixed combat log API for TBC Anniversary (use CombatLogGetCurrentEventInfo)",
            "Fixed options panel sliders not displaying",
            "Multi-DoT tracker now shows with 1+ targets (was 2+)",
            "Multi-DoT tracker hides current target (only shows other targets)",
            "Multi-DoT bar no longer overflows container",
            "Multi-DoT layout: icons first, then mob name",
            "Multi-DoT name positioning is now dynamic based on number of dots",
            "Added Frostbolt slow to tracked spells for Mage",
            "Added C_Timer.After fallback for addon initialization",
        },
    },
}

-- Export changelog for use by Options panel
function WhatsNew:GetChangelog()
    return changelog
end

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
