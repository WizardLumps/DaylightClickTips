-- The settings inside DaylightUI's own options window (/dui), through its
-- public plugin API (API.md):
--  * a plugin entry with its own page ("Click tooltips"): every setting, and
--  * the main switches as a group on Unit Frames > Click-casting.
-- The rows bring their own get/set, so they read and write this plugin's
-- settings (DaylightClickTipsDB): /clicktips and the options window agree.
-- DaylightUI requires a registered module named after the plugin for a
-- plugin's options group.

local ADDON, ns = ...
local DUI = DaylightUI
local API = DUI and DUI.API
if not (API and API.major == 1 and DUI.RegisterPlugin and DUI.RegisterModule and API.For) then return end

local function off() return not (ns.db and ns.db.enabled) end

local function toggle(key, label, desc, alwaysOn)
    return {
        type = "toggle", label = label, desc = desc,
        get = function() return ns.db ~= nil and ns.db[key] == true end,
        set = function(v) ns.Set(key, v) end,   -- also redraws the row (Core.lua)
        default = function() return ns.DEFAULTS[key] end,
        disabled = not alwaysOn and off or nil,
    }
end

local function color(key, label, desc)
    return {
        type = "color", label = label, desc = desc,
        get = function() return ns.Copy(ns.db and ns.db[key] or ns.DEFAULTS[key]) end,
        set = function(v) ns.Set(key, v) end,
        default = function() return ns.Copy(ns.DEFAULTS[key]) end,
        disabled = off,
    }
end

local function mainItems()
    return {
        toggle("enabled", "Click lines in tooltips",
            "Hover a unit frame: the tooltip lists what each mouse button casts with the Shift / Ctrl / Alt you hold, colored by range, mana and cooldown.", true),
        toggle("icons", "Spell icons", "Each spell's icon at the start of its line."),
        toggle("amounts", "Heal amounts",
            "The heal or absorb amount from each spell's description, e.g. 307-353."),
        toggle("cost", "Mana cost", "Each spell's mana cost."),
        toggle("casts", "Casts left", "How many times your current mana pays for the spell, e.g. x12."),
    }
end

local function lineItems()
    return {
        toggle("rank", "Spell ranks", "\"(Rank 3)\" after each spell's name."),
        toggle("short", "Short button names", "L, R, M, B4 and B5 instead of Left, Right, Middle, Button 4 and Button 5."),
        toggle("header", "\"Clicks\" heading",
            "The heading over the lines, which also names the Shift / Ctrl / Alt you hold."),
        toggle("hideDefaults", "Hide default clicks",
            "Leave out DaylightUI's standard Left = Target and Right = Unit menu. A click you set yourself for a modifier, like Ctrl + Left = Target, still shows."),
        toggle("holdOnly", "Only while holding a modifier",
            "No lines until you hold Shift, Ctrl or Alt."),
        toggle("hideCombat", "Hide in combat", "No lines while you're in combat."),
    }
end

local function frameItems()
    return {
        toggle("showParty", "Party", "Your party frames."),
        toggle("showRaid", "Raid", "Your raid frames."),
        toggle("showPets", "Party pets", "Your party's pet frames."),
        toggle("showPlayer", "Player", "Your own frame."),
        toggle("showTarget", "Target", "Your target's frame."),
        toggle("showFocus", "Focus", "Your focus's frame."),
        toggle("showOther", "Other frames", "Pet, target of target, arena and the rest."),
        toggle("showEnemies", "Enemies too",
            "Also when the frame's unit is an enemy, like your hostile target. Off: friendly units only, so your target frame shows the lines for friends but not for the mob you're fighting."),
    }
end

local function colorItems()
    return {
        color("colReady", "Ready", "A spell you can cast right now."),
        color("colRange", "Out of range", "The unit is too far away."),
        color("colNoMana", "Not enough mana", "You can't pay for the spell."),
        color("colCooldown", "On cooldown", "The spell is cooling down."),
        color("colInvalid", "Invalid target", "The spell can't go on this unit (a heal on an enemy), or can't be cast right now."),
        color("colAmount", "Heal amount", "The heal or absorb amount on the right."),
        color("colCost", "Mana cost and casts left", "The mana cost and casts left on the right."),
    }
end

local ok, err = pcall(DUI.RegisterPlugin, DUI, ADDON, {
    needs = { 1, 1 },
    short = "ClickTips",
    color = "66ccff",
    -- The sidebar icon: white on transparent, tinted with color.
    icon = "Interface\\AddOns\\" .. ADDON .. "\\Media\\icon-glyph.png",
    blurb = "Your click-cast spells in unit frame tooltips.",
})
if not ok then
    ns.Print("couldn't register with DaylightUI's options: " .. tostring(err))
    return
end

ok, err = pcall(DUI.RegisterModule, DUI, ADDON, {
    plugin = ADDON,
    label = "Click tooltips",
    defaults = {},
    options = { pages = { {
        id = "tooltip", label = "Click tooltips",
        desc = "What each mouse button does, shown in unit frame tooltips.",
        groups = {
            { label = "Tooltip", items = mainItems() },
            { label = "Lines", items = lineItems() },
            { label = "Show on", items = frameItems() },
            { label = "Colors", items = colorItems() },
        },
    } } },
})
if not ok then
    ns.Print("couldn't add a DaylightUI options page: " .. tostring(err))
    return
end

-- The main switches on DaylightUI's Click-casting page. DaylightUI titles a
-- plugin's group "<label> - From <name>", so this reads
-- "Tooltips - From ClickTips". The rest live on the plugin page.
local me = API.For("ClickTips")
if me and me.AddOptionsGroup then
    pcall(me.AddOptionsGroup, "UnitFrames.clickcast", {
        scope = ADDON,
        label = "Tooltips",
        desc = "Your bindings, shown when you hover a unit frame. More settings and colors: the ClickTips plugin page.",
        items = mainItems(),
    })
end
