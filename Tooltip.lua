-- Wiz's ClickTips: click lines on DaylightUI unit tooltips, like HealBot's: while you hover a
-- frame, one line per mouse button saying what that click does with the
-- modifiers you hold right now; press or release Shift/Ctrl/Alt and the
-- lines change. Spells are colored (each color can be changed in /dui):
--   white  ready and in range
--   orange out of range
--   red    not enough mana, or on cooldown
--   grey   invalid target (a heal on an enemy), or can't be cast now
-- and the right side shows the heal amount (from the spell's description),
-- its mana cost, and how many casts your mana pays for.
--
-- Where the bindings come from: the frame itself. We ask the game's own
-- secure-button code (SecureButton_GetModifiedAttribute) what the click
-- would do, so it is exactly what DaylightUI's click-casting set up, with
-- no reading of DaylightUI's internals. Read-only: this never changes a
-- frame, so it is safe in combat.
--
-- Which frames: the ones DaylightUI's public API hands out
-- (API.On("FrameMade")): party, raid, party pets, player/target/focus...
-- Each kind can be switched off. Hooked through the game's tooltip
-- post-call for unit tooltips.

local _, ns = ...

-- { attribute button, long name, short name, attribute suffix }
local BUTTONS = {
    { "LeftButton", "Left", "L", "1" }, { "RightButton", "Right", "R", "2" },
    { "MiddleButton", "Middle", "M", "3" }, { "Button4", "Button 4", "B4", "4" },
    { "Button5", "Button 5", "B5", "5" },
}
local ACTION_TEXT = { target = "Target", togglemenu = "Unit menu", menu = "Unit menu",
                      focus = "Focus", assist = "Assist", macro = "Action bar key" }
-- DaylightUI's own clicks on every frame ("*type1" target, "*type2" menu).
local DEFAULT_ACTION = { target = true, togglemenu = true, menu = true }
local LABEL = { 0.85, 0.75, 0.55 }   -- DaylightUI's tan label color
local MUTED = { 0.7, 0.7, 0.7 }
local GREY = { 0.6, 0.6, 0.6 }

local frames = {}   -- DaylightUI unit frames -> their kind ("party", "raid", "partypet", "unit")
local S = C_Spell or {}   -- missing functions make call() return nil

local function secret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function isOurs(owner)
    return type(owner) == "table" and frames[owner] ~= nil and owner.GetAttribute ~= nil
end

-- A color setting, falling back to the default.
local function col(key)
    local c = ns.db and ns.db[key]
    if type(c) ~= "table" then c = ns.DEFAULTS[key] end
    return c[1], c[2], c[3]
end
local function hexOf(key)
    local r, g, b = col(key)
    return ("ff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end
local function hex(color, text) return "|c" .. color .. text .. "|r" end

-- Is this frame switched on (Show on: party, raid, ...)?
local UNIT_SETTING = { player = "showPlayer", target = "showTarget", focus = "showFocus" }
local KIND_SETTING = { party = "showParty", raid = "showRaid", partypet = "showPets" }
local function frameWanted(owner)
    local key = KIND_SETTING[frames[owner]]
    if not key then key = UNIT_SETTING[owner:GetAttribute("unit")] or "showOther" end
    return ns.db[key] ~= false
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

-- "|T...|t Flash Heal (Rank 3)", icon and rank as set
local function spellText(id)
    local text = call(S.GetSpellName, id) or ("spell " .. id)
    if ns.db.rank then
        local rank = call(S.GetSpellSubtext, id)
        if type(rank) == "string" and rank ~= "" then text = text .. " (" .. rank .. ")" end
    end
    if ns.db.icons then
        local tex = call(S.GetSpellTexture, id)
        if tex and not secret(tex) then text = "|T" .. tex .. ":0|t " .. text end
    end
    return text
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

-- The spell's first cost as a number (mana, for every healer), or nil.
local function costOf(id)
    local costs = call(S.GetSpellPowerCost, id)
    local c = type(costs) == "table" and costs[1]
    if type(c) ~= "table" or secret(c.cost) or type(c.cost) ~= "number" or c.cost <= 0 then return nil end
    return c.cost, c.type
end

-- "x12": how many times your current mana (or the cost's own power) pays for it.
local function castsLeft(n, powerType)
    local have = call(UnitPower, "player", powerType or (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0)
    if type(have) ~= "number" or secret(have) then return nil end
    return "x" .. math.floor(have / n)
end

-- Color key and short note for a spell on a unit. Anything secret is
-- skipped (no color) rather than guessed.
local function state(id, unit)
    local usable, noMana = call(S.IsSpellUsable, id)
    if not secret(noMana) and noMana == true then return "colNoMana", "no mana" end
    local cd = call(S.GetSpellCooldown, id)
    if type(cd) == "table" and not secret(cd) and not secret(cd.startTime) and not secret(cd.duration)
        and type(cd.duration) == "number" and cd.duration > 1.5 then
        local left = (cd.startTime or 0) + cd.duration - GetTime()
        if left > 0 then return "colCooldown", ("cooldown %ds"):format(math.ceil(left)) end
    end
    if unit then
        local r = call(S.IsSpellInRange, id, unit)
        if not secret(r) and r == false then return "colRange", "out of range" end
        -- No range answer at all for a spell that has a range: the game says
        -- the spell can't go on this unit (a heal on an enemy, a shield on
        -- someone it won't take).
        if not secret(r) and r == nil and call(S.SpellHasRange, id) == true and call(UnitExists, unit) == true then
            return "colInvalid", "invalid target"
        end
    end
    if not secret(usable) and usable == false then return "colInvalid", "can't cast now" end
    return "colReady", nil
end

local function inCombat()
    return call(InCombatLockdown) == true or call(UnitAffectingCombat, "player") == true
end

-- What the lines for one frame would say, without touching the tooltip:
-- the header and one row per bound button, plus a short text "signature" of
-- all of it. Comparing signatures tells the ticker whether anything changed.
-- Each row: { left, right, r, g, b, rr, rg, rb } (right may be nil).
local function buildRows(owner)
    local db = ns.db
    if not (db and db.enabled) then return nil, nil, "off" end
    if type(SecureButton_GetModifiedAttribute) ~= "function" then return nil, nil, "none" end
    if not frameWanted(owner) then return nil, nil, "frame off" end
    if db.hideCombat and inCombat() then return nil, nil, "combat" end
    local prefix = type(SecureButton_GetModifierPrefix) == "function" and SecureButton_GetModifierPrefix(owner) or ""
    if db.holdOnly and prefix == "" then return nil, nil, "no modifier" end
    local unit = owner:GetAttribute("unit")
    local rows = {}
    for _, b in ipairs(BUTTONS) do
        local button = b[1]
        local label = db.short and b[3] or b[2]
        local kind = SecureButton_GetModifiedAttribute(owner, "type", button)
        if type(kind) == "string" and kind ~= "" then
            if kind == "spell" then
                local raw = SecureButton_GetModifiedAttribute(owner, "spell", button)
                local id = spellId(raw)
                if id then
                    local colorKey, note = state(id, unit)
                    local r, g, bl = col(colorKey)
                    local right = note
                    if not right then
                        local bits = {}
                        local a = db.amounts and amount(id)
                        if a then bits[#bits + 1] = hex(hexOf("colAmount"), a) end
                        local n, power = costOf(id)
                        if n and db.cost then bits[#bits + 1] = hex(hexOf("colCost"), tostring(n)) end
                        local left = n and db.casts and castsLeft(n, power)
                        if left then bits[#bits + 1] = hex(hexOf("colCost"), left) end
                        right = table.concat(bits, "  ")
                    end
                    rows[#rows + 1] = { label .. ": " .. spellText(id), right, r, g, bl,
                        note and r or MUTED[1], note and g or MUTED[2], note and bl or MUTED[3] }
                else
                    rows[#rows + 1] = { label .. ": " .. tostring(raw), "not in spellbook",
                        GREY[1], GREY[2], GREY[3], GREY[1], GREY[2], GREY[3] }
                end
            else
                -- DaylightUI's default Target / Unit menu come from "*typeN" on
                -- every frame. One set on purpose for this exact click (like
                -- Ctrl+Left = Target) has its own "ctrl-type1", and still shows.
                local own = owner:GetAttribute(prefix .. "type" .. b[4]) ~= nil
                if not (db.hideDefaults and DEFAULT_ACTION[kind] and not own) then
                    rows[#rows + 1] = { label .. ": " .. (ACTION_TEXT[kind] or kind), nil, 0.7, 0.85, 1 }
                end
            end
        end
    end
    local head = db.header and ("Clicks" .. (prefix ~= "" and (" (" .. modText(prefix) .. ")") or "")) or nil
    local sig = { head or "-" }
    for _, row in ipairs(rows) do
        sig[#sig + 1] = ("%s|%s|%.2f%.2f%.2f"):format(row[1], row[2] or "", row[3], row[4], row[5])
    end
    return rows, head, table.concat(sig, "\n")
end

local shownSig, shownOwner   -- what the tooltip shows right now, and for which frame

-- The lines for one frame, added to the tooltip.
local function addLines(tt, owner)
    local rows, head, sig = buildRows(owner)
    shownSig, shownOwner = sig, owner
    if not rows or #rows == 0 then return end
    tt:AddLine(" ")
    if head then tt:AddLine(head, LABEL[1], LABEL[2], LABEL[3]) end
    for _, row in ipairs(rows) do
        if row[2] then tt:AddDoubleLine(unpack(row, 1, 8))
        else tt:AddLine(row[1], row[3], row[4], row[5]) end
    end
    tt:Show()   -- resize to fit the new lines
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

-- Rebuild the tooltip (a setting, a modifier, combat, range or mana changed).
-- Only when our lines would read differently: every refill makes DaylightUI
-- 2.0 rebuild its whole rich unit card, and doing that for nothing flickers.
local function refresh(force)
    if not GameTooltip:IsShown() then return end
    local owner = GameTooltip:GetOwner()
    if not (isOurs(owner) and owner:IsMouseOver()) then return end
    local ok, _, _, sig = pcall(buildRows, owner)
    if not ok then return end
    if force ~= true and owner == shownOwner and sig == shownSig then return end
    local unit = owner:GetAttribute("unit")
    if type(unit) == "string" and call(UnitExists, unit) == true then GameTooltip:SetUnit(unit) end
end
ns.Refresh = function() refresh(true) end
ns.OnEvent("MODIFIER_STATE_CHANGED", refresh)
ns.OnEvent("PLAYER_REGEN_DISABLED", refresh)
ns.OnEvent("PLAYER_REGEN_ENABLED", refresh)
-- Range, mana and cooldowns change while you hover: check twice a second.
C_Timer.NewTicker(0.5, refresh)

-- Collect DaylightUI's frames through its public API.
ns.OnEvent("PLAYER_LOGIN", function()
    local api = DaylightUI and DaylightUI.API
    if not (api and api.major == 1 and api.On) then
        ns.Print("DaylightUI's API wasn't found: no tooltip lines.")
        return
    end
    api.On("FrameMade", function(kind, f, _, isPreview)
        if not isPreview and (kind == "unit" or kind == "party" or kind == "raid" or kind == "partypet") then
            frames[f] = kind
        end
    end, "DaylightClickTips")
end)
