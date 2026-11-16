local Effects = {}
local BANNER_DELAY_MS, HOLD_MS, BURST_MS, WAIT_MS = 1000, 1800, 2250, 12000
local PREVIEW_EXTRA_MS = 2000
local FOCUS_DELAY_MS, START_CARD, TILE_COUNT, SPARK_COUNT = 300, 4, 9, 12
local ASSETS = "Addon/mazrim_regrade_effects/assets/"
local CREST_ATLAS, WEAPON_ATLAS = ASSETS .. "case-reel.dds", ASSETS .. "basic-cs-skins-weapons.dds"
local CELL_WIDTH, CELL_HEIGHT, ATLAS_COLUMNS = 256, 160, 4
local PANEL = {0.082, 0.044, 0.034}
local BORDER = {0.45, 0.23, 0.13}
local STAGE = {0.16, 0.095, 0.068}
local TRACK = {0.047, 0.030, 0.026}
local TEXT = {0.99, 0.92, 0.84}
local MUTE = {0.77, 0.63, 0.53}
local COPPER = {0.97, 0.50, 0.24}
local GOLD = {1.00, 0.77, 0.38}
local IRON = {0.58, 0.45, 0.40}
local BROKEN = {0.91, 0.31, 0.24}
local rarities = {
    consumer = {name = "Consumer", color = {176/255, 195/255, 217/255}},
    industrial = {name = "Industrial", color = {94/255, 152/255, 217/255}},
    milspec = {name = "Mil-Spec", color = {75/255, 105/255, 255/255}},
    restricted = {name = "Restricted", color = {136/255, 71/255, 1}},
    classified = {name = "Classified", color = {211/255, 44/255, 230/255}},
    covert = {name = "Covert", color = {235/255, 75/255, 75/255}},
    contraband = {name = "Contraband", color = {228/255, 174/255, 57/255}},
    dragonLore = {name = "Top grade", color = {247/255, 208/255, 118/255}},
}
local rarityOrder = {"consumer", "industrial", "milspec", "restricted", "classified", "covert", "contraband", "dragonLore"}
local neutralCards = {}
for _, key in ipairs(rarityOrder) do
    local rarity = rarities[key]
    rarity.fallback = {name = rarity.name, color = rarity.color, x = 128, y = 192, size = 64}
    neutralCards[#neutralCards + 1] = rarity.fallback
end
-- Atlas order. Dragon Lore has a dedicated landing pool for the highest grades.
local weaponFinishes = {
    {"AK-47", "Fire Serpent", "covert"},
    {"AWP", "Asiimov", "covert"},
    {"M4A4", "Howl", "contraband"},
    {"M4A1-S", "Hyper Beast", "covert"},
    {"Desert Eagle", "Blaze", "restricted"},
    {"USP-S", "Kill Confirmed", "covert"},
    {"Glock-18", "Fade", "restricted"},
    {"P90", "Asiimov", "covert"},
    {"MP7", "Nemesis", "classified"},
    {"Sawed-Off", "The Kraken", "covert"},
    {"SSG 08", "Blood in the Water", "covert"},
    {"MAC-10", "Neon Rider", "covert"},
    {"Galil AR", "Sage Spray", "consumer"},
    {"M4A1-S", "Mud-Spec", "industrial"},
    {"AK-47", "Elite Build", "milspec"},
    {"Glock-18", "Bunsen Burner", "milspec"},
    {"M4A4", "Magnesium", "milspec"},
    {"AWP", "Atheris", "restricted"},
    {"AWP", "Dragon Lore", "dragonLore"},
}
local weapons = {}
Effects.weaponOptions = {}
for i, finish in ipairs(weaponFinishes) do
    local rarity = rarities[finish[3]]
    local id = tostring(i)
    weapons[i] = {name = finish[1], finish = finish[2], color = rarity.color, slot = i, id = id, rarity = rarity}
    Effects.weaponOptions[i] = {id = id, label = finish[1], finish = finish[2]}
end
local greatCard = {name = "Great Success", color = GOLD, x = 128, y = 0}
local brokenCard = {name = "Shattered Blade", color = BROKEN, x = 0, y = 384}
local gradeNames = {
    [0] = "Crude", "Basic", "Grand", "Rare", "Arcane", "Heroic", "Unique",
    "Celestial", "Divine", "Epic", "Legendary", "Mythic",
}
-- Divine and Epic land on Howl. Legendary and Mythic land on Dragon Lore.
local gradeRarities = {
    [0] = rarities.consumer, rarities.consumer, rarities.industrial, rarities.milspec,
    rarities.restricted, rarities.classified, rarities.classified, rarities.covert,
    rarities.contraband, rarities.contraband, rarities.dragonLore, rarities.dragonLore,
}
local pacing = {
    {id = "classic", label = "Classic", settleMs = 2100, speed = 1 / 72},
    {id = "quick", label = "Quick", settleMs = 820, speed = 1 / 52},
    {id = "cinematic", label = "Cinematic", settleMs = 3900, speed = 1 / 85},
}
local paceById = {}
Effects.paces = {}
for _, pace in ipairs(pacing) do
    paceById[pace.id] = pace
    Effects.paces[#Effects.paces + 1] = {id = pace.id, label = pace.label, settleMs = pace.settleMs}
end
local defaultPace = paceById.cinematic

function Effects.normalizeSettings(config)
    config = type(config) == "table" and config or {}
    local pace = config.pace == nil and defaultPace or (paceById[config.pace] or paceById.classic)
    local disabled = config.disabledWeapons
    local filtered = {}
    if type(disabled) == "table" then
        for _, weapon in ipairs(weapons) do
            if disabled[weapon.id] == true then filtered[weapon.id] = true end
        end
    end
    return {pace = pace.id, disabledWeapons = filtered}
end

local function weaponPools(disabled)
    local rolling, byRarity = {}, {}
    for _, weapon in ipairs(weapons) do
        if not disabled[weapon.id] then
            rolling[#rolling + 1] = weapon
            local pool = byRarity[weapon.rarity] or {}
            pool[#pool + 1] = weapon
            byRarity[weapon.rarity] = pool
        end
    end
    return #rolling > 0 and rolling or neutralCards, byRarity
end

local function call(object, method, ...)
    local ok, value, second = pcall(function(...)
        return object[method](object, ...)
    end, ...)
    return ok and value ~= false, value, second
end

local function show(widget, visible)
    return call(widget, "Show", visible) or call(widget, "SetVisible", visible)
end

local function passive(widget)
    local supported = false
    for _, method in ipairs({"EnablePick", "Clickable"}) do
        if type(widget[method]) == "function" then
            if not call(widget, method, false) then return false end
            supported = true
        end
    end
    return supported
end

local function place(widget, parent, x, y, width, height)
    return call(widget, "RemoveAllAnchors")
        and call(widget, "AddAnchor", "TOPLEFT", parent, x, y)
        and call(widget, "SetExtent", width, height)
end

local function ink(widget, color, alpha)
    return call(widget, "SetColor", color[1], color[2], color[3], alpha or 1)
end

local function rectangle(widget, parent, x, y, width, height, color, alpha)
    return place(widget, parent, x, y, width, height) and ink(widget, color, alpha) and show(widget, true)
end

local function visible(window)
    local ok, value = call(window, "IsVisible")
    return ok and value == true
end

local function chanceValue(value)
    if type(value) == "number" and value >= 0 and value <= 1 then return value end
end

local function safeItemName(value, limit)
    if type(value) ~= "string" then return nil end
    value = value:gsub("[%z\1-\31\127|]", " "):match("^%s*(.-)%s*$")
    if #value == 0 then return nil end
    if #value <= limit then return value end
    local cutoff = limit - 3
    while cutoff > 0 do
        local byte = value:byte(cutoff + 1)
        if byte < 128 or byte >= 192 then break end
        cutoff = cutoff - 1
    end
    return value:sub(1, cutoff) .. "..."
end

local function gradeName(grade)
    if type(grade) ~= "number" or not (grade >= 0 and grade <= 99) or grade % 1 ~= 0 then return nil end
    return gradeNames[grade] or ("Grade " .. grade)
end

local function landingCard(r, code, oldGrade)
    if r.great then return greatCard end
    if r.destroyed then return brokenCard end
    local rarity = rarities.milspec
    if r.succeeded or code == 1 then
        local grade = gradeName(r.newGrade) and r.newGrade or oldGrade
        if gradeName(grade) then rarity = gradeRarities[math.min(grade, #gradeRarities)] end
    end
    local pool = r.byRarity[rarity]
    if not pool then return rarity.fallback end
    return pool[(r.seed * 37 + r.landing * 11) % #pool + 1]
end

local function weaponAt(index, seed, pool)
    local stride = #pool % 7 == 0 and 5 or 7
    return pool[(index * stride + seed + math.floor(index / #pool) * 5) % #pool + 1]
end

local function artCoords(card)
    if not card.slot then return card.x, card.y, card.size or 128, card.size or 128 end
    local slot = card.slot - 1
    return slot % ATLAS_COLUMNS * CELL_WIDTH, math.floor(slot / ATLAS_COLUMNS) * CELL_HEIGHT,
        CELL_WIDTH, CELL_HEIGHT
end

local function dimensions(window)
    local ok, width, height = call(window, "GetExtent")
    if not ok or type(width) ~= "number" or type(height) ~= "number" then
        local readWidth, readHeight
        readWidth, width = call(window, "GetWidth")
        readHeight, height = call(window, "GetHeight")
        if not readWidth or not readHeight then return nil end
    end
    if type(width) == "number" and type(height) == "number"
        and width >= 300 and width < math.huge and height >= 150 and height < math.huge then
        return width, height
    end
end

function Effects.new(api, raiseControls, fault)
    local interface = api.Interface
    local view, round, updating
    local configured = defaultPace
    local rolling, byRarity = weaponPools({})
    local self = {}

    function self.configure(config)
        local settings = Effects.normalizeSettings(config)
        configured = paceById[settings.pace]
        rolling, byRarity = weaponPools(settings.disabledWeapons)
        return settings
    end

    local function clock()
        local ok, now = call(api.Time, "GetUiMsec")
        if ok and type(now) == "number" and now >= 0 and now < math.huge then return now end
    end

    function self.hide()
        round = nil
        if not view then return true end
        local hidden = show(view.root, false)
        if view.alarm then hidden = show(view.alarm, false) and hidden end
        if updating and call(view.root, "ReleaseHandler", "OnUpdate") then updating = nil end
        return hidden and not updating
    end

    function self.stop()
        if not view then return true end
        local stopped = self.hide()
        for index = #view.widgets, 1, -1 do
            if not call(interface, "Free", view.widgets[index]) then return false end
            view.widgets[index] = nil
        end
        if not call(interface, "Free", view.root) then return false end
        view, updating = nil, nil
        return stopped
    end

    local function newWidget(kind, name, parent)
        local ok, widget = call(interface, "CreateWidget", kind, "mazrim_regrade_" .. name, parent or view.root)
        if not ok or not widget then return nil end
        view.widgets[#view.widgets + 1] = widget
        if passive(widget) then return widget end
    end

    local function newLabel(name, font, parent)
        local widget = newWidget("label", name, parent)
        if widget and call(widget.style, "SetFontSize", font)
            and call(widget.style, "SetAlign", ALIGN.CENTER) then return widget end
    end

    local function newBox(owner, layer)
        local ok, box = call(owner, "CreateColorDrawable", 1, 1, 1, 1, layer)
        if ok then return box end
    end

    local function newImage(owner, texture, layer)
        local ok, image = call(owner, "CreateImageDrawable", texture, layer)
        if ok then return image end
    end

    local function create()
        local ok, root = call(interface, "CreateEmptyWindow", "mazrim_regrade_overlay", "UIParent")
        if not ok or not root then return false end
        view = {root = root, widgets = {}, cards = {}, sparks = {}}
        if not show(root, false) or not passive(root) then return false end
        view.border = newBox(root, "background")
        view.surface = newBox(root, "background")
        view.heading = newLabel("heading", 21)
        view.detail = newLabel("detail", 12)
        if not (view.border and view.surface and view.heading and view.detail) then return false end
        for i = 1, SPARK_COUNT do
            local spark = newBox(root, "overlay")
            if not spark or not show(spark, false) then return false end
            view.sparks[i] = spark
        end
        return true
    end

    local function createCase()
        local root = view.root
        view.lane = newWidget("emptywidget", "track")
        if not view.lane then return false end
        view.trackBed = newBox(view.lane, "background")
        view.topRail = newBox(view.lane, "background")
        view.bottomRail = newBox(view.lane, "background")
        if not (view.trackBed and view.topRail and view.bottomRail) then return false end
        for i = 1, TILE_COUNT do
            local tile = newWidget("emptywidget", "tile_" .. i, view.lane)
            if not tile then return false end
            local slot = {
                tile = tile,
                backdrop = newBox(tile, "background"),
                strip = newBox(tile, "artwork"),
                weapon = newImage(tile, WEAPON_ATLAS, "artwork"),
                crest = newImage(tile, CREST_ATLAS, "artwork"),
                name = newLabel("tile_label_" .. i, 11, tile),
                finish = newLabel("tile_finish_" .. i, 10, tile),
            }
            if not (slot.backdrop and slot.strip and slot.weapon and slot.crest and slot.name and slot.finish) then
                return false
            end
            view.cards[i] = slot
        end
        view.trim = newWidget("emptywidget", "track_trim", view.lane)
        view.focus = newWidget("emptywidget", "inspection")
        if not (view.trim and view.focus) then return false end
        view.leftShade = newImage(view.trim, CREST_ATLAS, "overlay")
        view.rightShade = newImage(view.trim, CREST_ATLAS, "overlay")
        view.pointer = newBox(view.trim, "overlay")
        view.pointerGlow = newBox(view.trim, "overlay")
        view.pointerTop = newBox(view.trim, "overlay")
        view.pointerBottom = newBox(view.trim, "overlay")
        view.focusFrame = newBox(view.focus, "background")
        view.focusBackdrop = newBox(view.focus, "background")
        view.focusInset = newBox(view.focus, "background")
        view.focusRule = newBox(view.focus, "artwork")
        view.focusWeapon = newImage(view.focus, WEAPON_ATLAS, "artwork")
        view.focusCrest = newImage(view.focus, CREST_ATLAS, "artwork")
        view.focusName = newLabel("inspection_name", 17, view.focus)
        return view.leftShade and view.rightShade and view.pointer and view.pointerGlow and view.pointerTop
            and view.pointerBottom and view.focusFrame and view.focusBackdrop and view.focusInset
            and view.focusRule and view.focusWeapon and view.focusCrest and view.focusName
    end

    local function resultColor(r)
        return r.card and r.card.color or r.great and GOLD or r.succeeded and COPPER or IRON
    end

    local function detailText(r)
        if not r.caseOpening then return "Your regrade result" end
        local prefix = r.preview and "PREVIEW  /  " or ""
        if r.revealed then
            local name = safeItemName(r.itemName, math.floor((r.width - 60) / 7) - #prefix)
            local grade = gradeName(r.newGrade)
            if r.destroyed then grade = nil end
            if name then return prefix .. (grade and (name .. "  /  " .. grade) or name) end
            if grade then return prefix .. grade end
        end
        if r.chance ~= nil then return prefix .. string.format("%.1f%% listed success chance", 100 * r.chance) end
        return prefix .. "Success chance unavailable"
    end

    local function layoutLane(r)
        local width, height = r.width - 32, r.trackHeight
        local center = math.floor(width / 2)
        local shade = math.floor(r.pitch / 2)
        return place(view.lane, view.root, 16, r.trackY, width, height)
            and rectangle(view.trackBed, view.lane, 0, 0, width, height, TRACK)
            and rectangle(view.topRail, view.lane, 0, 0, width, 1, BORDER)
            and rectangle(view.bottomRail, view.lane, 0, height - 1, width, 1, BORDER)
            and place(view.trim, view.lane, 0, 0, width, height)
            and call(view.leftShade, "SetCoords", 128, 256, 64, 8)
            and place(view.leftShade, view.trim, 0, 1, shade, height - 2)
            and call(view.rightShade, "SetCoords", 192, 256, 64, 8)
            and place(view.rightShade, view.trim, width - shade, 1, shade, height - 2)
            and show(view.leftShade, true) and show(view.rightShade, true)
            and rectangle(view.pointerGlow, view.trim, center - 4, 1, 9, height - 2, COPPER, 0.18)
            and rectangle(view.pointer, view.trim, center, 0, 2, height, GOLD)
            and rectangle(view.pointerTop, view.trim, center - 5, 0, 12, 4, GOLD)
            and rectangle(view.pointerBottom, view.trim, center - 5, height - 4, 12, 4, GOLD)
            and show(view.trim, true) and show(view.lane, true) and show(view.focus, false)
    end

    local function layoutFocus(r)
        local focus = view.focus
        local width, height = r.width - 32, r.trackHeight
        local large = height >= 150
        local card = r.card
        local art, other = view.focusCrest, view.focusWeapon
        if card.slot then art, other = other, art end
        local x, y, artW, artH = artCoords(card)
        local ratio = artW / artH
        local maxW = math.min(width - 58, r.great and 230 or 500)
        local maxH = math.max(28, height - (r.great and 24 or large and 36 or 27))
        local drawW = math.floor(math.min(maxW, maxH * ratio))
        local drawH = math.floor(drawW / ratio)
        local drawX = math.floor((width - drawW) / 2)
        local drawY = math.floor((height - drawH - (r.great and 0 or 20)) / 2)
        local label = card.finish and (card.name .. "  |  " .. card.finish) or card.name
        return show(view.lane, false)
            and place(focus, view.root, 16, r.trackY, width, height)
            and rectangle(view.focusFrame, focus, 0, 0, width, height, BORDER)
            and rectangle(view.focusBackdrop, focus, 1, 1, width - 2, height - 2, TRACK)
            and rectangle(view.focusInset, focus, 8, 8, width - 16, height - 16, STAGE, 0.50)
            and rectangle(view.focusRule, focus, math.floor(width / 5), height - 2, math.floor(width * 0.6), 2,
                resultColor(r))
            and call(art, "SetCoords", x, y, artW, artH)
            and place(art, focus, drawX, drawY, drawW, drawH)
            and show(art, true) and show(other, false)
            and place(view.focusName, focus, 6, height - 25, width - 12, 23)
            and ink(view.focusName.style, TEXT)
            and call(view.focusName, "SetText", label) and show(view.focusName, not r.great)
            and show(focus, true)
    end

    local function layout(r)
        local root = view.root
        local width, height = dimensions(r.window)
        local anchored = width ~= nil
        local x, y = 0, 0
        if not anchored then
            local _, screenWidth = call(interface, "GetScreenWidth")
            local _, screenHeight = call(interface, "GetScreenHeight")
            if type(screenWidth) ~= "number" or type(screenHeight) ~= "number"
                or not (screenWidth >= 440 and screenWidth < math.huge
                    and screenHeight >= 280 and screenHeight < math.huge) then return false end
            width, height = math.min(700, screenWidth - 28), r.caseOpening and 268 or 100
            x = math.floor((screenWidth - width) / 2)
            y = math.floor(math.min(screenHeight * 0.14, (screenHeight - height) / 2))
        end
        if r.width == width and r.height == height and r.anchorX == x and r.anchorY == y
            and r.anchored == anchored and r.lastFocus == r.focused and r.lastReveal == r.revealed then
            return true
        end
        r.width, r.height, r.anchorX, r.anchorY, r.anchored = width, height, x, y, anchored
        r.lastFocus, r.lastReveal = r.focused, r.revealed
        r.pitch = math.min(175, math.floor((width - 32) / 3.8))
        r.tileWidth = r.pitch - 4
        r.trackHeight = math.floor(math.min(r.focused and 320 or 140, height - 65))
        r.trackY = math.floor((height - r.trackHeight) / 2)
        local titleY = r.caseOpening and r.trackY - 36 or 19
        local detailY = r.caseOpening and r.trackY + r.trackHeight + 5 or 58
        if not place(root, anchored and r.window or "UIParent", x, y, width, height)
            or not rectangle(view.border, root, 0, 0, width, height, BORDER)
            or not rectangle(view.surface, root, 1, 1, width - 2, height - 2, PANEL)
            or not place(view.heading, root, 16, titleY, width - 32, 31)
            or not ink(view.heading.style, r.revealed and resultColor(r) or TEXT)
            or not call(view.heading, "SetText", r.revealed and r.result or "Opening Regrade Case")
            or not place(view.detail, root, 16, detailY, width - 32, 23)
            or not ink(view.detail.style, MUTE)
            or not call(view.detail, "SetText", detailText(r))
            or not show(view.heading, true) or not show(view.detail, true) then return false end
        if r.caseOpening then
            if r.focused then return layoutFocus(r) end
            return layoutLane(r)
        end
        if view.lane then return show(view.lane, false) and show(view.focus, false) end
        return true
    end

    local function paintCard(r, card, entry, x)
        local left, right = math.max(0, x), math.min(r.width - 32, x + r.tileWidth)
        local width = right - left
        if width <= 0 then return show(card.tile, false) end
        local height = r.trackHeight - 2
        if not place(card.tile, view.lane, left, 1, width, height) then return false end
        local crop = left - x
        if card.entry == entry and card.width == width and card.height == height
            and card.crop == crop and card.fullWidth == r.tileWidth then return show(card.tile, true) end
        card.entry, card.width, card.height = entry, width, height
        card.crop, card.fullWidth = crop, r.tileWidth
        local named = width == r.tileWidth
        local expanded = height >= 104 and r.tileWidth >= 96
        local art, hiddenArt = card.crest, card.weapon
        if entry.slot then art, hiddenArt = hiddenArt, art end
        local artX, artY, artW, artH = artCoords(entry)
        local maxHeight = height - (expanded and 38 or 27)
        local destW = math.floor(math.min(r.tileWidth - 4, maxHeight * artW / artH))
        local destH = math.floor(destW * artH / artW)
        local destX = math.floor((r.tileWidth - destW) / 2)
        local destY = math.floor((maxHeight - destH) / 2) + 3
        local visibleLeft, visibleRight = math.max(destX, crop), math.min(destX + destW, crop + width)
        local paintArt = visibleRight > visibleLeft
        if paintArt then
            local offset = math.floor((visibleLeft - destX) * artW / destW)
            local extent = math.ceil((visibleRight - destX) * artW / destW) - offset
            if not call(art, "SetCoords", artX + offset, artY, extent, artH)
                or not place(art, card.tile, visibleLeft - crop, destY, visibleRight - visibleLeft, destH) then
                return false
            end
        end
        return rectangle(card.backdrop, card.tile, 0, 0, width, height, STAGE,
                entry == greatCard and 0.91 or 0.57)
            and rectangle(card.strip, card.tile, 0, height - 3, width, 3, entry.color)
            and show(art, paintArt) and show(hiddenArt, false)
            and place(card.name, card.tile, 0, height - (expanded and 35 or 23), width, 17)
            and call(card.name, "SetText", entry.name) and ink(card.name.style, entry.slot and TEXT or entry.color)
            and show(card.name, named)
            and place(card.finish, card.tile, 0, height - 20, width, 14)
            and call(card.finish, "SetText", entry.finish or "") and ink(card.finish.style, MUTE)
            and show(card.finish, named and expanded and entry.finish ~= nil)
            and show(card.tile, true)
    end

    local function rollingPosition(r, time)
        return START_CARD + (time - r.started) * r.pace.speed
    end

    local function paintTiles(r, time)
        local position = rollingPosition(r, time)
        if r.landing then
            local duration = r.pace.settleMs
            local remaining = 1 - math.min(1, (time - r.confirmedAt) / duration)
            local distance = r.landing - r.settledFromPosition
            local slope = duration * r.pace.speed / distance
            local progress = 1 + (slope - 3) * remaining ^ 2 + (2 - slope) * remaining ^ 3
            position = r.settledFromPosition + distance * progress
        end
        local first = math.floor(position) - 4
        for offset = 1, TILE_COUNT do
            local index = first + offset - 1
            local card = view.cards[index % TILE_COUNT + 1]
            local x = math.floor((r.width - 32 - r.tileWidth) / 2 + (index - position) * r.pitch)
            local entry = index == r.landing and r.card or weaponAt(index, r.seed, r.rolling)
            if not paintCard(r, card, entry, x) then return false end
        end
        return true
    end

    local function paintSparks(r, age)
        local color = resultColor(r)
        local centerY = r.trackY and r.caseOpening and r.trackY + r.trackHeight / 2 or 43
        for i, spark in ipairs(view.sparks) do
            local t = age / 650
            local active = t >= 0 and t < 1 and r.succeeded
            if active then
                local angle = i * math.pi * 2 / SPARK_COUNT
                local reach = 30 + 120 * (1 - (1 - t) ^ 2)
                local x = math.floor(r.width / 2 + math.cos(angle) * reach)
                local y = math.floor(centerY + math.sin(angle) * reach * 0.24 + t * 8)
                local size = 2 + i % 3
                if not rectangle(spark, view.root, x, y, size * 2, size, color, (1 - t) * 0.90) then
                    return false
                end
            elseif not show(spark, false) then return false end
        end
        return true
    end

    local function coverAlarm()
        -- The native grade result is separate and top-centered, even when the enchanting pane moves.
        if not view.alarm then
            local ok, alarm = call(interface, "CreateEmptyWindow", "mazrim_regrade_alarm_cover", "UIParent")
            if not ok or not alarm then return false end
            view.alarm = alarm
            view.widgets[#view.widgets + 1] = alarm
            if not show(alarm, false) or not passive(alarm)
                or not call(alarm, "AddAnchor", "TOP", "UIParent", 0, 64)
                or not call(alarm, "SetExtent", 510, 326) then return false end
            view.alarmSurface = newBox(alarm, "background")
            if not rectangle(view.alarmSurface, alarm, 0, 0, 510, 326, PANEL) then return false end
        end
        return show(view.alarm, true)
    end

    local function raise()
        if view.alarm and visible(view.alarm) then call(view.alarm, "Raise") end
        local raised = call(view.root, "Raise")
        if raised and raiseControls then pcall(raiseControls) end
        return raised
    end

    local function draw(r, time)
        local landing = r.revealAt and time >= r.revealAt and not r.revealed
        if landing then
            r.revealed = true
            r.shownAt = time
            if r.caseOpening then
                if not r.preview then r.bannerAt = time + BANNER_DELAY_MS end
                r.expires = time + HOLD_MS + (r.preview and PREVIEW_EXTRA_MS or 0)
            end
        end
        if r.caseOpening and r.shownAt and time >= r.shownAt + FOCUS_DELAY_MS then r.focused = true end
        local width, height = r.width, r.height
        if not layout(r) then return false end
        if r.caseOpening and not r.focused and (not r.revealed or landing or r.width ~= width or r.height ~= height) then
            if not paintTiles(r, landing and r.revealAt or time) then return false end
        end
        if r.bannerAt and time >= r.bannerAt then
            if view.alarm and not show(view.alarm, false) then return false end
            r.bannerAt = nil
        end
        if r.shownAt and not r.sparksHidden then
            if not paintSparks(r, time - r.shownAt) then return false end
            r.sparksHidden = time - r.shownAt >= 650
        end
        return true
    end

    local function tick()
        local current = round
        if not current then return end
        local now = clock()
        if not now or now < current.lastFrame
            or (now >= current.expires and (not current.result or current.revealed))
            or (current.window and not visible(current.window))
            or (current.tab and not current.result and not visible(current.tab)) then
            if not self.hide() then fault("Could not close the effect.") end
            return
        end
        if current.raiseNextFrame then
            raise()
            current.raiseNextFrame = nil
        end
        local nextStage = current.bannerAt and now >= current.bannerAt
            or current.revealAt and not current.revealed and now >= current.revealAt
        if not nextStage and now - current.lastFrame < (current.caseOpening and 16 or 33) then return end
        current.lastFrame = now
        local ok, displayed = pcall(draw, current, now)
        if not ok or not displayed then
            self.hide()
            fault("The effect could not be drawn.")
        end
    end

    local function start(r, time)
        if not view and not create() then self.stop(); return false end
        if r.caseOpening and not view.lane and not createCase() then self.stop(); return false end
        if not paintSparks(r, -1) or not draw(r, time) then return false end
        if not updating then
            if not call(view.root, "SetHandler", "OnUpdate", tick) then self.hide(); return false end
            updating = true
        end
        round = r
        r.raiseNextFrame = true
        return show(view.root, true) and raise()
    end

    local function newRound(time, caseOpening, window)
        return {
            caseOpening = caseOpening, window = window, started = time, lastFrame = time,
            seed = math.floor(time) % 101, expires = time + WAIT_MS, pace = configured,
            rolling = rolling, byRarity = byRarity,
        }
    end

    function self.begin(press)
        local time = clock()
        if not time then return false end
        if round and not round.preview and not round.result and time >= round.lastFrame and time < round.expires
            and round.window == press.window and round.tab == press.tab
            and round.itemType == press.itemType and round.grade == press.grade then return true end
        if not self.hide() then return false end
        local r = newRound(time, true, press.window)
        r.tab, r.itemType, r.grade = press.tab, press.itemType, press.grade
        r.chance = chanceValue(press.chance)
        return start(r, time)
    end

    local function finish(result, caseOpening, window, itemType, grade, verifiedChance, preview)
        local time = clock()
        if not time then return false end
        local r = round
        local continuing = not preview and caseOpening and r and not r.preview and not r.result
            and time >= r.lastFrame and time < r.expires and r.window == window
        if not continuing then
            if not self.hide() then return false end
            r = newRound(time, caseOpening, window)
        end
        r.preview = preview
        r.result, r.succeeded = result.title, result.succeeded == true
        r.great = result.great == true and r.succeeded
        r.destroyed = result.code == 0 or result.destroyed == true
        r.itemName, r.newGrade = result.itemName, result.newGrade
        if r.itemType ~= itemType or r.grade ~= grade then r.chance = nil end
        r.chance = chanceValue(verifiedChance) or r.chance
        if not caseOpening then
            r.revealAt, r.expires = time, time + BURST_MS
            return start(r, time)
        end
        r.confirmedAt, r.settledFromPosition = time, rollingPosition(r, time)
        r.landing = math.ceil(r.settledFromPosition + r.pace.settleMs * r.pace.speed / 3)
        r.card = landingCard(r, result.code, grade)
        r.revealAt = time + r.pace.settleMs
        if not continuing and not start(r, time) then return false end
        if not preview and not coverAlarm() then fault("Could not cover the game’s regrade result banner.") end
        r.raiseNextFrame = true
        if not call(view.detail, "SetText", detailText(r)) then return false end
        return draw(r, time) and raise()
    end

    function self.finish(result, caseOpening, window, itemType, grade, verifiedChance)
        return finish(result, caseOpening, window, itemType, grade, verifiedChance)
    end

    function self.isPreviewing()
        return round ~= nil and round.preview == true
    end

    function self.isActive()
        return round ~= nil
    end

    function self.canPreview()
        return not round or self.isPreviewing()
    end

    function self.preview(sample, press)
        if not self.canPreview() then
            return false, "A real regrade reveal is already in progress."
        end
        return finish(sample, true, nil, press.itemType, press.grade, press.chance, true)
    end

    return self
end

return Effects
