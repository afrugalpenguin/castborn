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
        version = "5.5.0",
        features = {
            "Totem Tracker buff-based party check — checks actual buff presence instead of range",
            "Tutorial lockout example in the interrupt tracker step",
            "Performance improvements across multiple modules",
        },
        fixes = {
            "Fixed position keys and IsSpellKnown fallback",
            "Fixed profile switching leaving stale keys",
        },
    },
    {
        version = "5.4.0",
        features = {
            "Totem Tracker solo range indicator — shows a single dot when not grouped",
        },
        fixes = {},
    },
    {
        version = "5.3.0",
        features = {
            "Proc Tracker grow direction — choose Grow Right, Grow Left, or Grow from Centre",
        },
        fixes = {},
    },
    {
        version = "5.2.0",
        features = {
            "Castbar colour pickers — global and per-castbar bar colour options",
            "Per-module background colour pickers for all modules",
            "Frame appearance system — individual background alpha, show/hide borders",
            "Global bar font picker in Look & Feel options with LSM support",
            "Global bar texture picker in Look & Feel options with LSM support",
            "Tutorial consolidated from 19 steps to 13 with interactive checkboxes",
            "Frames are now fully click-through when locked",
        },
        fixes = {
            "Fixed spell icons showing as grey squares without Masque installed",
        },
    },
    {
        version = "4.20.0",
        features = {
            "Full Masque skinning support for all icon-bearing modules — CastBars, Interrupt, DoTs, Totems, Multi-DoT, and Armour Tracker",
            "Each module has its own Masque group for independent skin control",
        },
        fixes = {},
    },
    {
        version = "4.19.0",
        features = {
            "Armour Tracker — shows an alert icon when your armour self-buff is missing (Mage, Warlock, Priest)",
        },
        fixes = {},
    },
    {
        version = "4.18.1",
        features = {},
        fixes = {
            "Fixed Masque skinning for Proc Tracker and Absorb Tracker icons",
        },
    },
    {
        version = "4.18.0",
        features = {
            "Absorb Tracker added to the welcome tutorial",
            "Positioning tutorial now mentions Ctrl+Shift+Click to hide overlapping frames",
        },
        fixes = {},
    },
    {
        version = "4.17.0",
        features = {
            "Ctrl+Shift+Click module headers while unlocked to temporarily hide them for easier positioning",
        },
        fixes = {},
    },
    {
        version = "4.16.1",
        features = {},
        fixes = {
            "Fixed absorb tracker cooldown sweep flickering rapidly when taking damage",
        },
    },
    {
        version = "4.16.0",
        features = {
            "Absorb Tracker supports all TBC absorb spells with multi-icon display",
            "Power Word: Shield from healers tracked on any class",
            "School-specific absorbs show spell-school-coloured borders",
            "Configurable grow direction and spacing for absorb icons",
        },
        fixes = {},
    },
    {
        version = "4.15.1",
        features = {},
        fixes = {
            "Fixed absorb tracker not updating remaining value when taking damage",
        },
    },
    {
        version = "4.15.0",
        features = {
            "New Absorb Tracker for Mages — shows Ice Barrier remaining absorb as a shield icon with radial drain",
            "Shield dims and border shifts blue to red as absorb is consumed",
        },
        fixes = {},
    },
    {
        version = "4.14.0",
        features = {
            "Nameplate indicators now show the DoT spell icon instead of a plain square",
            "Added position dropdown (Top/Bottom/Left/Right) to Nameplate Indicator options",
        },
        fixes = {
            "Fixed water elemental timer briefly renewing on pet despawn",
        },
    },
    {
        version = "4.13.2",
        features = {
            "Arcane Blast stacking debuff tracked in Proc Tracker for Mages",
        },
        fixes = {},
    },
    {
        version = "4.13.1",
        features = {},
        fixes = {
            "Fixed proc icon size slider not working",
        },
    },
    {
        version = "4.13.0",
        features = {
            "Persistent pulsing glow on proc icons for the full buff duration",
            "Icon size slider and glow toggle in Proc Tracker options",
        },
        fixes = {},
    },
    {
        version = "4.12.0",
        features = {
            "Water Elemental pet timer in Proc Tracker for Mages",
        },
        fixes = {},
    },
    {
        version = "4.11.1",
        features = {},
        fixes = {
            "Fixed castbars options page not scrolling to show all sections",
        },
    },
    {
        version = "4.11.0",
        features = {
            "Global background opacity slider in Look & Feel options",
        },
        fixes = {},
    },
    {
        version = "4.10.2",
        features = {},
        fixes = {
            "Sliders now display clean numeric values for decimal step sizes",
        },
    },
    {
        version = "4.10.1",
        features = {},
        fixes = {
            "Castbars options page now scrolls when content overflows",
            "DoT and totem tracker sliders now provide immediate visual feedback",
            "Added bar height and width sliders to DoT and totem tracker options",
            "Multi-dot tracker row text no longer overflows at large row heights",
            "Fixed FSR default width not matching castbar/GCD default width",
        },
    },
    {
        version = "4.10.0",
        features = {
            "Width and height sliders for target, focus, and target-of-target castbars",
            "Width and row height sliders for multi-dot tracker",
        },
        fixes = {},
    },
    {
        version = "4.9.0",
        features = {
            "Trinket cooldown tracking — equipped trinkets with \"Use:\" effects now show above the cooldown tracker",
        },
        fixes = {},
    },
    {
        version = "4.8.1",
        features = {
            "Holy Concentration Clearcasting proc now tracked for Priests",
        },
        fixes = {},
    },
    {
        version = "4.8.0",
        features = {
            "Proc tracker now matches buffs by name as a fallback for rank mismatches",
        },
        fixes = {
            "Fixed Combustion, Vengeance, Seal of Command, Enrage, Flurry, and Slice and Dice procs not appearing",
            "Removed Thrill of the Hunt (not a trackable buff)",
        },
    },
    {
        version = "4.7.4",
        features = {},
        fixes = {
            "Fixed Backlash proc not appearing in proc tracker",
        },
    },
    {
        version = "4.7.3",
        features = {},
        fixes = {
            "Fixed newly added procs not appearing for existing users until settings were reset",
        },
    },
    {
        version = "4.7.2",
        features = {},
        fixes = {
            "Fixed multi-DoT nameplate indicator disappearing after briefly flashing",
        },
    },
    {
        version = "4.7.1",
        features = {
            "Symbol of Hope now tracked in cooldowns for Draenei priests",
        },
        fixes = {},
    },
    {
        version = "4.7.0",
        features = {
            "Gift of the Naaru now tracked in cooldowns for Draenei characters (all classes)",
        },
        fixes = {},
    },
    {
        version = "4.6.3",
        features = {},
        fixes = {
            "Fixed totem tracker showing raid-wide indicators instead of party-only",
        },
    },
    {
        version = "4.6.2",
        features = {},
        fixes = {
            "Fixed Lua error spam when Earth Shield or Water Shield buff was active",
            "Increased max displayed cooldowns from 8 to 12",
        },
    },
    {
        version = "4.6.1",
        features = {},
        fixes = {
            "Added missing interrupts for Druid, Priest, and Hunter",
            "Added missing cooldowns across all classes (defensive, utility, PvP)",
            "Added warlock curses, Deep Wounds, trap/sting DoTs, and rogue utility poisons to DoT tracker",
        },
    },
    {
        version = "4.6.0",
        features = {
            "Enhanced cooldown drag-and-drop: icons follow cursor, smooth real-time repositioning, golden glow on dragged icon",
            "Added missing Shaman cooldowns: Earth Shield, Water Shield, Heroism, Bloodlust",
            "Drag headers now positioned above frames for better visibility",
        },
        fixes = {},
    },
    {
        version = "4.5.0",
        features = {
            "Cooldown icon order is now customizable: drag icons in test mode or use up/down arrows in options",
        },
        fixes = {},
        widget = "cooldown_reorder_demo",
    },
    {
        version = "4.4.0",
        features = {
            "Added 'Show Spell Rank' option for player castbar",
        },
        fixes = {},
    },
    {
        version = "4.3.0",
        features = {
            "Totem Tracker: Party coverage indicator shows who's in range",
        },
        fixes = {},
    },
    {
        version = "4.2.0",
        features = {
            "Added 'Hide Tradeskill Casts' option for player castbar",
        },
        fixes = {},
    },
    {
        version = "4.1.3",
        features = {
            "Added Totem Tracker to onboarding tutorial (Shaman only)",
        },
        fixes = {},
    },
    {
        version = "4.1.2",
        features = {},
        fixes = {
            "Fixed /cb lock not dismissing test mode panel",
        },
    },
    {
        version = "4.1.1",
        features = {},
        fixes = {
            "Totem Tracker now sorts by soonest to expire (most urgent at top)",
        },
    },
    {
        version = "4.1.0",
        features = {
            "Totem Tracker (Shaman): Track active totems with duration bars",
            "Mouseover shows party members NOT in range of beneficial totems",
            "Test mode available for all classes to preview",
        },
        fixes = {
            "Drag indicators now use compact handle (tooltips work while unlocked)",
            "Test mode automatically unlocks frames for positioning",
        },
    },
    {
        version = "4.0.0",
        features = {
            "Profile Management UI: Create, copy, delete, and switch between profiles",
            "Import/Export: Share profiles with other players via encoded strings",
            "Per-character profile selection with shared profile storage",
        },
        fixes = {},
    },
    {
        version = "3.3.1",
        features = {},
        fixes = {
            "DoT Tracker now uses SpellData for colours (internal cleanup)",
            "Fixed modules listening for non-existent PLAYER_CASTBAR_READY event",
        },
    },
    {
        version = "3.3.0",
        features = {
            "Interrupt Tracker: Track Target/Focus highlights bar yellow when interrupt opportunity available",
            "Multi-DoT Tracker: Sort by Time option (sorts targets by urgency)",
        },
        fixes = {
            "Renamed Buff Tracker to Proc Tracker in options",
            "Fixed Proc Tracker Show Timers checkbox not working",
            "Fixed castbar Show Icon/Time/Spell Name/Latency toggles requiring reload",
        },
    },
    {
        version = "3.2.2",
        features = {
            "Multi-DoT nameplate indicator now only shows on the most urgent target (lowest DoT timer)",
        },
        fixes = {
            "Fixed Warlock Shadow Trance (Nightfall) proc not being tracked correctly",
        },
    },
    {
        version = "3.2.1",
        features = {},
        fixes = {
            "Fixed Lua error in Multi-DoT nameplate indicators",
        },
    },
    {
        version = "3.2.0",
        features = {
            "Multi-DoT Tracker: Added nameplate indicators showing DoT timers directly on enemy nameplates",
            "Helps identify which mob needs attention when multiple mobs share the same name",
        },
        fixes = {},
    },
    {
        version = "3.1.6",
        features = {},
        fixes = {
            "Fixed procs and cooldowns not loading correctly when switching between characters of different classes",
        },
    },
    {
        version = "3.1.5",
        features = {},
        fixes = {
            "Hide ToT castbar when target is self-targeting (prevents redundant castbar display)",
        },
    },
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
            "Player castbar now uses class colours by default",
            "Added \"Look & Feel\" section in options with class colours toggle",
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

-- Widget: Animated cooldown reorder demo
local function CreateCooldownReorderDemo(parent, yOffset)
    local demoFrame = CreateFrame("Frame", nil, parent)
    demoFrame:SetSize(140, 44)
    demoFrame:SetPoint("TOPLEFT", 16, yOffset)

    local iconSize = 36
    local spacing = 6
    local iconTextures = {
        "Interface\\Icons\\Spell_Frost_FrostShock",
        "Interface\\Icons\\Spell_Fire_FlameBolt",
        "Interface\\Icons\\Spell_Nature_Lightning",
    }

    local icons = {}
    for i = 1, 3 do
        local icon = CreateFrame("Frame", nil, demoFrame)
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("LEFT", (i - 1) * (iconSize + spacing), 0)

        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetAllPoints()
        icon.tex:SetTexture(iconTextures[i])
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        icon.border = icon:CreateTexture(nil, "BORDER")
        icon.border:SetPoint("TOPLEFT", -1, 1)
        icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
        icon.border:SetColorTexture(0.3, 0.3, 0.3, 1)

        -- Store home positions (offsets from left)
        icon.homeX = (i - 1) * (iconSize + spacing)
        icons[i] = icon
    end

    -- Animation state
    local animElapsed = 0
    local animPhase = "pause"  -- "animate" or "pause"
    local animDuration = 0.5
    local pauseDuration = 2.5

    -- Target positions during animation: icon 3 -> slot 1, icons 1,2 -> shift right
    local function UpdateAnimation(elapsed)
        animElapsed = animElapsed + elapsed

        if animPhase == "pause" then
            if animElapsed >= pauseDuration then
                animElapsed = 0
                animPhase = "animate"
            end
        elseif animPhase == "animate" then
            local t = math.min(animElapsed / animDuration, 1)
            -- Ease in-out
            t = t * t * (3 - 2 * t)

            local step = iconSize + spacing
            -- Icon 3 moves from slot 3 to slot 1
            local icon3TargetX = 0
            local icon3StartX = 2 * step
            icons[3]:ClearAllPoints()
            icons[3]:SetPoint("LEFT", icon3StartX + (icon3TargetX - icon3StartX) * t, 0)

            -- Icon 1 moves from slot 1 to slot 2
            local icon1TargetX = step
            local icon1StartX = 0
            icons[1]:ClearAllPoints()
            icons[1]:SetPoint("LEFT", icon1StartX + (icon1TargetX - icon1StartX) * t, 0)

            -- Icon 2 moves from slot 2 to slot 3
            local icon2TargetX = 2 * step
            local icon2StartX = step
            icons[2]:ClearAllPoints()
            icons[2]:SetPoint("LEFT", icon2StartX + (icon2TargetX - icon2StartX) * t, 0)

            if animElapsed >= animDuration then
                animElapsed = 0
                animPhase = "reset"
            end
        elseif animPhase == "reset" then
            if animElapsed >= 1.0 then
                -- Reset to original positions
                for i = 1, 3 do
                    icons[i]:ClearAllPoints()
                    icons[i]:SetPoint("LEFT", icons[i].homeX, 0)
                end
                animElapsed = 0
                animPhase = "pause"
            end
        end
    end

    demoFrame:SetScript("OnUpdate", function(self, elapsed)
        UpdateAnimation(elapsed)
    end)

    return demoFrame, 52  -- frame and height consumed
end

local widgetBuilders = {
    cooldown_reorder_demo = CreateCooldownReorderDemo,
}

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

        -- Widget (animated demo)
        if entry.widget and widgetBuilders[entry.widget] then
            y = y - 4
            local widgetFrame, widgetHeight = widgetBuilders[entry.widget](scrollChild, y)
            y = y - widgetHeight - 4
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
