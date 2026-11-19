-- The switches inside DaylightUI's own options window (/dui), through its
-- public plugin API (API.md):
--  * a plugin entry with its own page ("Click tooltips"), and
--  * the same switches as a group on Unit Frames > Click-casting.
-- The rows bring their own get/set, so they read and write this plugin's
-- settings (DaylightClickTipsDB): /clicktips and the options window agree.
-- DaylightUI requires a registered module named after the plugin for a
-- plugin's options group.

local ADDON, ns = ...
local DUI = DaylightUI
local API = DUI and DUI.API
if not (API and API.major == 1 and DUI.RegisterPlugin and DUI.RegisterModule and API.For) then return end

local function toggle(key, label, desc)
    return {
        type = "toggle", label = label, desc = desc,
        get = function() return ns.db ~= nil and ns.db[key] == true end,
        set = function(v) ns.Set(key, v) end,   -- also redraws the switch (Core.lua)
        default = function() return true end,
    }
end

local function items()
    return {
        toggle("enabled", "Click lines in tooltips",
            "Hover a unit frame: the tooltip lists what each mouse button casts with the Shift / Ctrl / Alt you hold, colored by range, mana and cooldown."),
        toggle("amounts", "Heal amounts",
            "The heal or absorb amount from each spell's description, e.g. 307-353."),
        toggle("cost", "Mana cost", "Each spell's mana cost."),
    }
end

local ok, err = pcall(DUI.RegisterPlugin, DUI, ADDON, {
    needs = { 1, 1 },
    short = "ClickTips",
    color = "66ccff",
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
        groups = { { label = "Tooltip", items = items() } },
    } } },
})
if not ok then
    ns.Print("couldn't add a DaylightUI options page: " .. tostring(err))
    return
end

-- The same switches on DaylightUI's Click-casting page. DaylightUI titles a
-- plugin's group "<label> - From <name>", so this reads
-- "Tooltips - From ClickTips".
local me = API.For("ClickTips")
if me and me.AddOptionsGroup then
    pcall(me.AddOptionsGroup, "UnitFrames.clickcast", {
        scope = ADDON,
        label = "Tooltips",
        desc = "Your bindings, shown when you hover a unit frame.",
        items = items(),
    })
end
