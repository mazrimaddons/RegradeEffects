local DARK = {0.045, 0.029, 0.026}
local MUTED = {0.74, 0.68, 0.61}
local IVORY = {0.98, 0.92, 0.81}
local BRASS = {0.73, 0.50, 0.28}
local AMBER = {1, 0.54, 0.24}
local GOLD = {1, 0.78, 0.37}
local PALE_GOLD = {1, 0.94, 0.73}
local STEAM = {0.52, 0.61, 0.63}
local TEAL = {0.50, 0.87, 0.91}
local ITEM_X, ITEM_Y = 388, 258
local ANVIL_Y = 266
local PLATE_WIDTH, PLATE_HEIGHT = 93, 22
local SEAT_X, SEAT_LIP, ITEM_SIZE = ITEM_X - 10, 5, 34
local IMPACT, VERDICT = 0.41, 0.68
local PI = math.pi

local function clamp(x)
    return math.max(0, math.min(1, x))
end

local function step(t, first, last)
    return clamp((t - first) / (last - first))
end

local function ease(t, first, last)
    local p = step(t, first, last)
    return p * p * (3 - 2 * p)
end

local function center(c, sprite, x, y, w, h, opacity, tint)
    c.sprite(sprite, x - w / 2, y - h / 2, w, h, opacity, tint)
end

local function light(c, x, y, w, h, opacity, tint)
    c.spritePart("glow", x - w / 2, y - h / 2, w, h, 0, 0, 1, 1, opacity, tint)
end

local function sparks(c, x, y, age, count, tint, seed, opacity)
    for i = 1, count do
        local angle = i * 2.39996 + (seed or 0) % 17 * .31
        local vx = math.cos(angle) * (42 + i % 6 * 13)
        local vy = 27 + math.abs(math.sin(angle)) * (50 + i % 7 * 9)
        local px = x + vx * age
        local py = y - vy * age + age * age * 73
        local size = i % 4 == 0 and 4 or 2
        local fade = (1 - age) ^ 1.6 * (opacity or 1)
        c.line(px - vx * .045, py + (vy - 136 * age) * .06, px, py, 1, tint, fade * .65)
        center(c, "diamond", px, py, size, size, fade, i % 4 == 0 and PALE_GOLD or tint)
    end
end

local function furnace(c, elapsed)
    local flicker = .11 + .03 * math.sin(elapsed / 109) + .025 * math.sin(elapsed / 67)
    light(c, 80, 226, 302, 252, flicker, AMBER)
    for i = 1, 11 do
        local age = (elapsed / (1350 + i % 4 * 190) + i * .193) % 1
        local x = 38 + (i * 29) % 133 + age * math.sin(i) * 15
        local y = 265 - age * (69 + i % 5 * 14)
        local size = i % 3 + 1
        center(c, "diamond", x, y, size, size, math.sin(age * PI) * .52, i % 4 == 0 and PALE_GOLD or AMBER)
    end
end

local function blacksmith(c, f, t)
    local pose, x, y = "workbenchIdle", 201, 214
    local elapsed = f.elapsed or 0
    local theft = f.theft
    if theft and (theft.taken or theft.reaction and theft.reaction > 0) then
        local flinch = theft.reaction or 0
        pose = "workbenchAlarmed"
        x = x - 11 * flinch
        y = y - 4 * flinch
    elseif t >= VERDICT and f.succeeded then
        pose = "workbenchProud"
        y = y - math.sin(ease(t, VERDICT, .86) * PI) * 5
    elseif t >= .38 and t < .55 then
        pose = "workbenchStrike"
        local reach = ease(t, .375, IMPACT) * (1 - ease(t, .422, .54))
        x = x + 19 + 45 * reach
        y = y - 6
    elseif t >= .31 and t < .38 then
        pose = "workbenchSwing"
        local swing = ease(t, .31, .38)
        x = x - 9 + swing * 25
        y = y - 7 + swing * 2
    elseif t >= .13 and t < .31 then
        pose = "workbenchRaise"
        x = x - 4 - ease(t, .13, .31) * 7
        y = y - ease(t, .13, .31) * 7
    else
        y = y + math.sin(elapsed / 415) * 1.8
    end
    light(c, x, 329, 296, 71, .55, DARK)
    center(c, pose, x, y, 270, 278, 1)
end

local materialSlots = {
    {key = "scroll", label = "Scroll", x = 586, size = 24},
    {key = "charm", label = "Charm", x = 641, size = 24},
}

local function materials(c, f)
    for _, slot in ipairs(materialSlots) do
        if f[slot.key] then
            local x = slot.x
            light(c, x, 298, 61, 39, .23, AMBER)
            c.box(x - 15, 271, 30, 30, DARK, .86)
            c.box(x - 15, 301, 30, 1, BRASS, .75)
            center(c, slot.key, x, 286, slot.size, slot.size, 1)
            c.text(slot.label, x - 25, 305, 50, 19, "small", IVORY)
        end
    end
end

local function orbit(c, elapsed, count, x, y, rx, ry, opacity, tint)
    for i = 1, count do
        local angle = i * 2 * PI / count + elapsed / 420
        local depth = .6 + .4 * math.sin(angle)
        center(c, "diamond", x + math.cos(angle) * rx, y + math.sin(angle) * ry,
            2 + depth * 4, 2 + depth * 4, opacity * depth, tint)
    end
end

local function masterwork(c, f, t, y)
    local rise = ease(t, .56, .82)
    local pulse = 1 + math.sin((f.elapsed or 0) / 205) * .025
    local size = (130 + rise * 61) * pulse
    light(c, SEAT_X, y, 320, 242, rise * .64, GOLD)
    center(c, "workbenchSeal", SEAT_X, y, size, size, rise * .93)
    orbit(c, f.elapsed or 0, 14, SEAT_X, y, 78 + rise * 24, 29 + rise * 28, rise * .88, PALE_GOLD)
end

local function phoenix(c, f, t, y)
    local rise = ease(t, .55, .82)
    local drift = math.sin((f.elapsed or 0) / 170)
    local wings = 148 + 118 * rise
    local w, h = wings + drift * 13 * rise, wings - 6 * drift * rise
    light(c, SEAT_X, y - 44, 340, 255, rise * .66, AMBER)
    c.spritePart("workbenchPhoenix", SEAT_X - w / 2, y - 31 - rise * 32 - h / 2, w, h, 0, 0, 1, 1, rise)
    orbit(c, -(f.elapsed or 0), 18, SEAT_X, y, 92 + rise * 49, 24 + rise * 38, rise * .85, GOLD)
end

local function clockwork(c, f, t, y)
    local rise = ease(t, .56, .83)
    local elapsed = f.elapsed or 0
    local turn = math.sin(elapsed / 320)
    light(c, SEAT_X, y, 302, 224, rise * (.58 + .09 * turn), TEAL)
    local w, h = 185 + 50 * rise + turn * 9, 180 + 38 * rise
    c.spritePart("workbenchArmillary", SEAT_X - w / 2, y - h / 2, w, h, 0, 0, 1, 1, rise)
    orbit(c, elapsed * 1.3, 12, SEAT_X, y, 108 + turn * 8, 36 + rise * 42, rise * .88, TEAL)
    orbit(c, -elapsed * .65, 9, SEAT_X, y, 75, 65, rise * .69, PALE_GOLD)
end

local finales = {masterwork, clockwork, phoenix}

local function workpiece(c, f, t)
    local hot = ease(t, .15, .38) * (1 - ease(t, .65, .96))
    local hit = math.sin(step(t, .37, .51) * PI)
    local y = ITEM_Y + 1.4 * hit
    local lip = y - SEAT_LIP
    local half = ITEM_SIZE / 2
    local itemY = lip - half
    if f.great then
        local finale = finales[f.celebrationVariant] or masterwork
        finale(c, f, t, itemY)
    end
    local stolen = f.theft and f.theft.taken
    if not stolen then
        local scorch = f.code == 0 and t >= .51
        local tint = (scorch or f.code == 1 and t > .61) and {.77, .66, .59} or nil
        light(c, ITEM_X, ANVIL_Y - 1, PLATE_WIDTH + 13, 9, .67, DARK)
        light(c, ITEM_X, y + 4, PLATE_WIDTH + 35, 53, .09 + hot * .55, AMBER)
        center(c, "workbenchPlate", ITEM_X, y, PLATE_WIDTH, PLATE_HEIGHT, 1, tint)
        light(c, SEAT_X, lip + 1, ITEM_SIZE + 21, 9, .82, DARK)
        c.box(SEAT_X - half - 2, lip - ITEM_SIZE - 2, ITEM_SIZE + 4, ITEM_SIZE + 4, DARK, .96)
        c.box(SEAT_X - half - 2, lip - ITEM_SIZE - 2, ITEM_SIZE + 4, 1, BRASS, .65)
        center(c, "item", SEAT_X, itemY, ITEM_SIZE, ITEM_SIZE, 1)
        c.box(SEAT_X - half - 4, lip, ITEM_SIZE + 8, 2, BRASS, .96)
        if scorch then
            local heat = .9 - .49 * ease(t, .52, .78)
            c.line(371, y - 6, 389, y - 1, 1.2, AMBER, heat)
            c.line(389, y - 1, 383, y + 5, 1, PALE_GOLD, heat * .61)
        end
    end
    if t >= IMPACT and t < .66 then
        local age = step(t, IMPACT, .66)
        light(c, ITEM_X - 15, y - 5, 126, 88, (1 - age) ^ 3 * .9, PALE_GOLD)
        sparks(c, ITEM_X - 15, y - 5, age, 20, AMBER, f.seed)
    end
    if t > .56 then
        if f.succeeded then
            local age = step(t, .56, .94)
            if f.great then
                sparks(c, SEAT_X, itemY, age, 26, GOLD, f.seed)
            else
                sparks(c, ITEM_X, y + 2, age, 12, GOLD, f.seed)
            end
        else
            local age = ease(t, .56, .97)
            local alpha = math.sin(PI * age) * (f.code == 2 and .28 or .48)
            for i = 1, 4 do
                light(c, ITEM_X + (i - 2.5) * age * 17, y + 3 - age * i * 16,
                    55 + age * 39, 36 + age * 19, alpha, f.code == 2 and STEAM or DARK)
            end
            if f.code ~= 2 then sparks(c, ITEM_X, y + 4, age, 11, BRASS, f.seed, .71) end
        end
    end
end

local function itemCaption(c, f, detail)
    local name = f.itemName or "Regrade item"
    c.text(name, 28, 420, 664, 22, "body", IVORY)
    if detail then c.text(detail, 28, 442, 664, 16, "small", MUTED) end
end

local function captions(c, f, t)
    c.box(0, 0, 720, 67, DARK, .76)
    c.box(0, 374, 720, 86, DARK, .89)
    c.box(28, 66, 664, 1, BRASS, .55)
    c.box(28, 374, 664, 1, BRASS, .55)
    if t >= VERDICT then
        local alpha = ease(t, VERDICT, .77)
        local color = f.great and PALE_GOLD or f.succeeded and GOLD or IVORY
        c.text(f.title, 28, 15, 664, 43, "hero", color, alpha)
        local grade = f.oldGrade and f.grade and f.oldGrade ~= f.grade and (f.oldGrade .. " → " .. f.grade) or f.grade
        itemCaption(c, f, grade)
    else
        c.text("The Workbench", 28, 20, 664, 37, "title", IVORY)
        local chance = f.chance and string.format("%.1f%% listed success chance", f.chance * 100)
        itemCaption(c, f, chance)
    end
end

local function drawWorkbench(c, f)
    local t = f.phase == "reveal" and clamp(f.t or 0) or 0
    f.cueAt = IMPACT
    c.sprite("workbenchForge", 0, 0, 720, 460, 1)
    furnace(c, f.elapsed or 0)
    blacksmith(c, f, t)
    c.spritePart("workbenchForge", 0, 337, 720, 39, 0, 337/460, 1, 39/460, 1)
    materials(c, f)
    workpiece(c, f, t)
    captions(c, f, t)
end

return {
    workbench = {
        label = "Workbench", duration = 4250, draw = drawWorkbench,
        art = {
            workbenchForge={8,8,1440,920},
            workbenchIdle={8,944,352,424}, workbenchRaise={376,944,352,424},
            workbenchStrike={744,944,352,424}, workbenchProud={1112,944,352,424},
            workbenchSwing={1480,944,352,424},
            workbenchSeal={8,1392,560,560}, workbenchArmillary={584,1392,560,560},
            workbenchPhoenix={1160,1392,560,560},
            workbenchPlate={384,16,624,148,"workbench-props.dds"},
            workbenchAlarmed={8,44,352,424,"workbench-props.dds"},
        },
    },
}

