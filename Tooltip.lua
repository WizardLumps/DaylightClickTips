-- Wiz's ClickTips: click lines on DaylightUI unit tooltips, like HealBot's: while you hover a
-- frame, one line per mouse button saying what that click does with the
-- modifiers you hold right now; press or release Shift/Ctrl/Alt and the
-- lines change. Spells are colored (HealBot's colors):
--   white  ready and in range
--   orange out of range
--   red    not enough mana, or on cooldown
--   grey   can't be cast right now for another reason
-- and the right side shows the heal amount (from the spell's description)
-- and its mana cost.
--
-- Where the bindings come from: the frame itself. We ask the game's own
-- secure-button code (SecureButton_GetModifiedAttribute) what the click
-- would do, so it is exactly what DaylightUI's click-casting set up, with
-- no reading of DaylightUI's internals. Read-only: this never changes a
-- frame, so it is safe in combat.
--
-- Which frames: the ones DaylightUI's public API hands out
-- (API.On("FrameMade")): party, raid, party pets, player/target/focus...
-- Hooked through the game's tooltip post-call for unit tooltips.

local _, ns = ...

local BUTTONS = {
    { "LeftButton", "Left" }, { "RightButton", "Right" }, { "MiddleButton", "Middle" },
    { "Button4", "Button 4" }, { "Button5", "Button 5" },
}
local ACTION_TEXT = { target = "Target", togglemenu = "Unit menu", menu = "Unit menu",
                      focus = "Focus", assist = "Assist", macro = "Action bar key" }
local LABEL = { 0.85, 0.75, 0.55 }   -- DaylightUI's tan label color
local MUTED = { 0.7, 0.7, 0.7 }

local frames = {}   -- DaylightUI unit frames -> true
local S = C_Spell or {}   -- missing functions make call() return nil

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function isOurs(owner)
    return type(owner) == "table" and frames[owner] == true and owner.GetAttribute ~= nil
end

-- "alt-ctrl-shift-" -> "Shift + Ctrl + Alt"
local function modText(prefix)
    local parts = {}
    if prefix:find("shift%-") then parts[#parts + 1] = "Shift" end
    if prefix:find("ctrl%-") then parts[#parts + 1] = "Ctrl" end
    if prefix:find("alt%-") then parts[#parts + 1] = "Alt" end
    return table.concat(parts, " + ")
end

-- A spell attribute (name = top rank, or a spell id) -> spell id
local function spellId(v)
    if type(v) == "number" then return v end
    if type(v) ~= "string" then return nil end
    local n = tonumber(v)
    if n then return n end
    local info = call(S.GetSpellInfo, v)
    return type(info) == "table" and info.spellID or nil
end

-- "Flash Heal (Rank 3)"
local function spellText(id)
    local name = call(S.GetSpellName, id) or ("spell " .. id)
    local rank = call(S.GetSpellSubtext, id)
    if type(rank) == "string" and rank ~= "" then return name .. " (" .. rank .. ")" end
    return name
end

-- Heal / absorb amount from the description: "Heals ... for 307 to 353" ->
-- "307-353"; "absorbing 48 damage" -> "absorbs 48". Cached per spell id.
-- Reads English descriptions; on other languages the amount is just left out.
local amounts = {}
local function amount(id)
    if amounts[id] ~= nil then return amounts[id] or nil end
    local d = call(S.GetSpellDescription, id)
    if type(d) ~= "string" or d == "" or secret(d) then
        call(S.RequestLoadSpellData, id)   -- ask again next time
        return nil
    end
    local lo, hi = d:match("(%d[%d,]*) to (%d[%d,]*)")
    local text = lo and (lo .. "-" .. hi) or nil
    if not text then
        local ab = d:match("[Aa]bsorb%a* (%d[%d,]*)")
        text = ab and ("absorbs " .. ab) or nil
    end
    amounts[id] = text or false
    return text
end
ns.OnEvent("SPELLS_CHANGED", function() wipe(amounts) end)

-- "125": the spell's first cost (mana, for every healer); the blue color says it.
local function cost(id)
    local costs = call(S.GetSpellPowerCost, id)
    local c = type(costs) == "table" and costs[1]
    if type(c) ~= "table" or secret(c.cost) or type(c.cost) ~= "number" or c.cost <= 0 then return nil end
    return tostring(c.cost)
end

-- Right-side colors: heal amount green, mana cost blue.
local AMOUNT_HEX = "ff40e040"
local COST_HEX = "ff5fa8ff"
local function hex(color, text) return "|c" .. color .. text .. "|r" end

-- Color and short note for a spell on a unit. Anything secret is skipped
-- (no color) rather than guessed.
local function state(id, unit)
    local usable, noMana = call(S.IsSpellUsable, id)
    if noMana == true and not secret(noMana) then return 1, 0.2, 0.2, "no mana" end
    local cd = call(S.GetSpellCooldown, id)
    if type(cd) == "table" and not secret(cd) and not secret(cd.startTime) and not secret(cd.duration)
        and type(cd.duration) == "number" and cd.duration > 1.5 then
        local left = (cd.startTime or 0) + cd.duration - GetTime()
        if left > 0 then return 1, 0.2, 0.2, ("cooldown %ds"):format(math.ceil(left)) end
    end
    if unit then
        local r = call(S.IsSpellInRange, id, unit)
        if r == false and not secret(r) then return 1, 0.5, 0.1, "out of range" end
    end
    if usable == false and not secret(usable) then return 0.6, 0.6, 0.6, "can't cast now" end
    return 1, 1, 1, nil
end

-- The lines for one frame.
local function addLines(tt, owner)
    if not (ns.db and ns.db.enabled) then return end
    if type(SecureButton_GetModifiedAttribute) ~= "function" then return end
    local unit = owner:GetAttribute("unit")
    local prefix = type(SecureButton_GetModifierPrefix) == "function" and SecureButton_GetModifierPrefix(owner) or ""
    local any = false
    for _, b in ipairs(BUTTONS) do
        local button, label = b[1], b[2]
        local kind = SecureButton_GetModifiedAttribute(owner, "type", button)
        if type(kind) == "string" and kind ~= "" then
            if not any then
                any = true
                tt:AddLine(" ")
                local head = "Clicks" .. (prefix ~= "" and (" (" .. modText(prefix) .. ")") or "")
                tt:AddLine(head, LABEL[1], LABEL[2], LABEL[3])
            end
            if kind == "spell" then
                local raw = SecureButton_GetModifiedAttribute(owner, "spell", button)
                local id = spellId(raw)
                if id then
                    local r, g, bl, note = state(id, unit)
                    local right = note
                    if not right then
                        local bits = {}
                        local a = ns.db.amounts and amount(id)
                        local c = ns.db.cost and cost(id)
                        if a then bits[#bits + 1] = hex(AMOUNT_HEX, a) end
                        if c then bits[#bits + 1] = hex(COST_HEX, c) end
                        right = table.concat(bits, "  ")
                    end
                    tt:AddDoubleLine(label .. ": " .. spellText(id), right, r, g, bl,
                        note and r or MUTED[1], note and g or MUTED[2], note and bl or MUTED[3])
                else
                    tt:AddDoubleLine(label .. ": " .. tostring(raw), "not in spellbook", 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
                end
            else
                tt:AddLine(label .. ": " .. (ACTION_TEXT[kind] or kind), 0.7, 0.85, 1)
            end
        end
    end
    if any then tt:Show() end   -- resize to fit the new lines
end

-- Unit tooltips: add our lines when the owner is a DaylightUI frame.
local function onUnitTooltip(tt)
    if tt ~= GameTooltip then return end
    local owner = tt:GetOwner()
    if isOurs(owner) then
        local ok, err = pcall(addLines, tt, owner)
        if not ok then ns.Print("tooltip: " .. tostring(err)) end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnitTooltip)
else
    GameTooltip:HookScript("OnTooltipSetUnit", onUnitTooltip)
end

-- Rebuild the tooltip (modifier pressed, range or mana changed).
local function refresh()
    if not (ns.db and ns.db.enabled) then return end   -- /clicktips tip off: leave the tooltip alone entirely
    if not GameTooltip:IsShown() then return end
    local owner = GameTooltip:GetOwner()
    if not isOurs(owner) then return end
    local unit = owner:GetAttribute("unit")
    if type(unit) == "string" and call(UnitExists, unit) == true then GameTooltip:SetUnit(unit) end
end
ns.OnEvent("MODIFIER_STATE_CHANGED", refresh)
-- Range and cooldowns change while you hover: redraw twice a second.
C_Timer.NewTicker(0.5, function()
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    if owner and isOurs(owner) and owner:IsMouseOver() then refresh() end
end)

-- Collect DaylightUI's frames through its public API.
ns.OnEvent("PLAYER_LOGIN", function()
    local api = DaylightUI and DaylightUI.API
    if not (api and api.major == 1 and api.On) then
        ns.Print("DaylightUI's API wasn't found: no tooltip lines.")
        return
    end
    api.On("FrameMade", function(kind, f, _, isPreview)
        if not isPreview and (kind == "unit" or kind == "party" or kind == "raid" or kind == "partypet") then
            frames[f] = true
        end
    end, "DaylightClickTips")
end)
