-- Wiz's ClickTips core: saved settings, events and /clicktips.
-- Read-only: nothing here touches a secure frame, so it is safe in combat.

local ADDON, ns = ...
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "?"

function ns.Print(msg)
    print("|cff66ccffClickTips:|r " .. tostring(msg))
end

-- Saved account-wide (DaylightClickTipsDB).
ns.DEFAULTS = {
    enabled = true,       -- add the click lines to unit frame tooltips
    amounts = true,       -- heal / absorb amounts from each spell's description
    cost = true,          -- mana cost
    casts = false,        -- how many casts your current mana pays for ("x12")
    icons = true,         -- the spell's icon at the start of its line
    rank = true,          -- "(Rank 3)" after the name
    short = false,        -- "L:" instead of "Left:"
    header = true,        -- the "Clicks" heading over the lines
    hideDefaults = true,  -- hide DaylightUI's default Target / Unit menu clicks
    holdOnly = false,     -- lines only while Shift, Ctrl or Alt is held
    hideCombat = false,   -- no lines in combat
    allMods = false,      -- every modifier's clicks at once, grouped (no need to hold keys)
    allNumbers = false,   -- ...with heal amounts, cost and casts left too (off: shorter lines)
    -- Which frames get the lines
    showParty = true, showRaid = true, showPets = true,
    showPlayer = true, showTarget = true, showFocus = true, showOther = true,
    showEnemies = false,  -- also on frames whose unit is an enemy (your enemy target)
    -- Colors { r, g, b }
    colReady = { 1, 1, 1 },
    colRange = { 1, 0.5, 0.1 },
    colNoMana = { 1, 0.2, 0.2 },
    colCooldown = { 1, 0.2, 0.2 },
    colInvalid = { 0.6, 0.6, 0.6 },
    colAmount = { 0.25, 0.88, 0.25 },
    colCost = { 0.37, 0.66, 1 },
    colHeld = { 0.3, 0.9, 0.3 },   -- the held modifier's group name (Show all modifiers)
}

local function copy(v)
    if type(v) ~= "table" then return v end
    return { v[1], v[2], v[3] }
end
ns.Copy = copy

-- Events --------------------------------------------------------------------
local frame, handlers = CreateFrame("Frame"), {}
function ns.OnEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(frame.RegisterEvent, frame, event)   -- an event this client lacks is skipped
    end
    table.insert(handlers[event], fn)
end
frame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        local ok, err = pcall(fn, event, ...)
        if not ok then ns.Print(event .. ": " .. tostring(err)) end
    end
end)

ns.OnEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    if type(DaylightClickTipsDB) ~= "table" then DaylightClickTipsDB = {} end
    local db = DaylightClickTipsDB
    for k, v in pairs(ns.DEFAULTS) do
        if db[k] == nil or type(db[k]) ~= type(v) then db[k] = copy(v) end
    end
    ns.db = db
end)

-- Settings ------------------------------------------------------------------
-- Changes one setting and tells DaylightUI, so its options window (/dui)
-- redraws the row. Switches save true/false, colors { r, g, b }.
function ns.Set(key, value)
    if not ns.db then return end
    if type(ns.DEFAULTS[key]) == "table" then
        if type(value) ~= "table" then return end
        ns.db[key] = { tonumber(value[1] or value.r) or 1, tonumber(value[2] or value.g) or 1, tonumber(value[3] or value.b) or 1 }
    else
        ns.db[key] = value and true or false
    end
    local DUI = DaylightUI
    if DUI and type(DUI.Fire) == "function" then
        pcall(DUI.Fire, "SettingChanged", ADDON, key, ns.db[key])
    end
    if ns.Refresh then ns.Refresh() end
end

-- /clicktips ----------------------------------------------------------------
local function onOff(v) return v and "|cff66dd66on|r" or "|cffff6644off|r" end

local TOGGLES = {
    tip = { "enabled", "click lines in tooltips" },
    amounts = { "amounts", "heal amounts" },
    cost = { "cost", "mana cost" },
    casts = { "casts", "casts left on your mana" },
    icons = { "icons", "spell icons" },
    rank = { "rank", "spell ranks" },
    short = { "short", "short button names" },
    header = { "header", "\"Clicks\" heading" },
    defaults = { "hideDefaults", "hide default Target / Unit menu clicks" },
    hold = { "holdOnly", "only while holding Shift / Ctrl / Alt" },
    combat = { "hideCombat", "hide in combat" },
    all = { "allMods", "all modifiers at once" },
}
local ORDER = { "tip", "amounts", "cost", "casts", "icons", "rank", "short", "header", "defaults", "hold", "combat", "all" }

SLASH_DAYLIGHTCLICKTIPS1 = "/clicktips"
SlashCmdList.DAYLIGHTCLICKTIPS = function(msg)
    msg = strlower(strtrim(msg or ""))
    local db = ns.db
    if not db then return end
    local t = TOGGLES[msg]
    if t then
        ns.Set(t[1], not db[t[1]])
        ns.Print(t[2] .. ": " .. onOff(db[t[1]]))
        return
    end
    ns.Print(ns.version)
    for _, word in ipairs(ORDER) do
        local s = TOGGLES[word]
        print(("  /clicktips %s - %s: %s"):format(word, s[2], onOff(db[s[1]])))
    end
    ns.Print("Frames and colors: /dui, the ClickTips plugin page.")
end
