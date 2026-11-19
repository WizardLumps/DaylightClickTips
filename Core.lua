-- Wiz's ClickTips core: saved settings, events and /clicktips.
-- Read-only: nothing here touches a secure frame, so it is safe in combat.

local ADDON, ns = ...
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "?"

function ns.Print(msg)
    print("|cff66ccffClickTips:|r " .. tostring(msg))
end

-- Saved account-wide (DaylightClickTipsDB).
local DEFAULTS = {
    enabled = true,   -- add the click lines to unit frame tooltips
    amounts = true,   -- heal / absorb amounts from each spell's description
    cost = true,      -- mana cost
}

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
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    ns.db = db
end)

-- Settings ------------------------------------------------------------------
-- Changes one setting and tells DaylightUI, so its options window (/dui)
-- redraws the switch.
function ns.Set(key, value)
    if not ns.db then return end
    ns.db[key] = value and true or false
    local DUI = DaylightUI
    if DUI and type(DUI.Fire) == "function" then
        pcall(DUI.Fire, "SettingChanged", ADDON, key, ns.db[key])
    end
end

-- /clicktips ----------------------------------------------------------------
local function onOff(v) return v and "|cff66dd66on|r" or "|cffff6644off|r" end

local TOGGLES = {
    tip = { "enabled", "click lines in tooltips" },
    amounts = { "amounts", "heal amounts" },
    cost = { "cost", "mana cost" },
}

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
    ns.Print(("%s - tooltip lines %s, amounts %s, cost %s"):format(ns.version,
        onOff(db.enabled), onOff(db.amounts), onOff(db.cost)))
    ns.Print("/clicktips tip | amounts | cost (switch each on or off)")
    ns.Print("Same switches in /dui: Unit Frames > Click-casting, or the ClickTips plugin page.")
end
