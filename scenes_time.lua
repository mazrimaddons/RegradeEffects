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
local ANVIL_Y, COUNTER_Y = 263, 337
local PLATE_WIDTH, PLATE_HEIGHT = 93, 22
local SEAT_X, SEAT_LIP, ITEM_SIZE = ITEM_X - 10, 5, 34
local GOLD_START, GOLD_CATCH, GOLD_FLOOR = .256, .308, 356
local IMPACT, VERDICT = .22, .68
local GARU_BANNER, GARU_GLOW = .565, .646
local LIFT_AT, APEX_AT, SWING_AT, RECOIL_AT, REST_AT = .112, .171, .184, .233, .33
local LIFT_FRAME, IMPACT_FRAME, REST_FRAME = 14, 34, 47
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

local function hammerFrame(t)
    if t < LIFT_AT or t >= REST_AT then return 0 end
    if t < SWING_AT then
        return math.floor(step(t, LIFT_AT, APEX_AT) * LIFT_FRAME + .5)
    end
    if t < IMPACT then
        local travel = math.floor(step(t, SWING_AT, IMPACT) * (IMPACT_FRAME - LIFT_FRAME) + .5)
        return math.min(IMPACT_FRAME - 1, LIFT_FRAME + travel)
    end
    return IMPACT_FRAME + math.floor(step(t, RECOIL_AT, REST_AT) * (REST_FRAME - IMPACT_FRAME) + .5)
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
    local flicker = .12 + .025 * math.sin(elapsed / 109) + .02 * math.sin(elapsed / 67)
    light(c, 624, 306, 151, 99, flicker, AMBER)
    for i = 1, 7 do
        local age = (elapsed / (1350 + i % 4 * 190) + i * .193) % 1
        local x = 594 + (i * 29) % 59 + age * math.sin(i) * 12
        local y = 315 - age * (45 + i % 5 * 10)
        local size = i % 2 + 2
        center(c, "diamond", x, y, size, size, math.sin(age * PI) * .52, i % 4 == 0 and PALE_GOLD or AMBER)
    end
end

local function blacksmith(c, f, t, broken)
    local theft = f.theft
    if theft and (theft.taken or theft.reaction and theft.reaction > 0) then
        local flinch = theft.reaction or 0
        c.sprite("smithPanic", 105 - 16 * flinch, 116 - 6 * flinch, 173, 227, 1)
        return
    end
    if broken and t >= REST_AT and t < VERDICT then
        local flinch = 1 - ease(t, REST_AT, .55)
        c.sprite("smithPanic", 105 - 17 * flinch, 116 - 7 * flinch, 173, 227, 1)
        return
    end
    if t >= VERDICT and f.succeeded then
        local hop = math.sin(step(t, VERDICT, .87) * PI) * (f.great and 19 or 7)
        local pose = f.great and t < .87 and "smithCheer" or "smithSmile"
        c.sprite(pose, 105, 116 - hop, 173, 227, 1)
        return
    end
    c.sprite("workbenchSwing"..hammerFrame(t), 92, 103, 304, 236, 1)
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

local function fracturedAnvil(c, t)
    local flight = step(t, IMPACT, .385)
    local spread = 3 + 31 * (1 - (1 - flight) ^ 3)
    local hop = math.sin(flight * PI) * 17
    local y = ANVIL_Y - hop
    c.spritePart("workbenchAnvilLeft", ITEM_X - 91 - spread, y + 8 * flight, 100, 74, 0, 0, 1, 1, 1)
    c.spritePart("workbenchAnvilRight", ITEM_X - 9 + spread, y + 11 * flight, 100, 74, 0, 0, 1, 1, 1)

    local age = step(t, IMPACT, .40)
    if age >= 1 then return end
    for i = 1, 11 do
        local direction = i % 2 == 0 and -1 or 1
        local x = ITEM_X + direction * (6 + (51 + i * 7) * age)
        local yChip = ANVIL_Y + i * 3 - (66 + i % 4 * 16) * age + 106 * age ^ 2
        local sprite = i % 2 == 0 and "workbenchAnvilChipA" or "workbenchAnvilChipB"
        center(c, sprite, x, yChip, 5 + i % 5 * 3, 6 + i % 4 * 2, 1 - ease(age, .72, 1))
    end
end

local function furnaceRupture(c, f, t)
    local split = ease(t, IMPACT, .32)
    local floorWidth = 164 + 230 * split
    local floorX = ITEM_X - floorWidth / 2
    c.spritePart("workbenchCrack", floorX, 324, floorWidth, 52, 0, 0, 1, 1, 1)

    local burn = ease(t, .253, .35) * (1 - ease(t, .57, .81))
    local elapsed = f.elapsed or 0
    local pulse = .91 + .09 * math.sin(elapsed / 82)
    c.spritePart("workbenchHeatedCrack", floorX, 324, floorWidth, 52, 0, 0, 1, 1, .18 + burn * pulse * .82)
    if burn <= 0 then return end

    local rise = ease(t, .253, .41)
    local width = 117 + 145 * rise + 3 * math.sin(elapsed / 109)
    local height = (58 + 191 * rise) * (1 - .56 * ease(t, .60, .81))
    local cel = t < .30 and 1 or t < .36 and 2 or t < .64 and 3 or 4
    light(c, SEAT_X, 358 - height * .52, width + 87, height + 35, burn * pulse * .62, AMBER)
    c.spritePart("workbenchFire"..cel, SEAT_X - width / 2, 368 - height, width, height,
        0, 0, 1, 1, math.min(1, burn * 1.38) * pulse)

    for i = 1, 16 do
        local age = (elapsed / (630 + i % 5 * 85) + i * .191) % 1
        local x = SEAT_X + (i % 2 == 0 and -1 or 1) * (23 + i % 5 * 11 + age * 24)
        local y = 359 - age * height
        local alpha = burn * math.sin(age * PI) * .9
        c.line(x - 3, y + 12, x, y, 1, AMBER, alpha * .64)
        center(c, "diamond", x, y, 3 + i % 3, 4 + i % 3, alpha, i % 3 == 0 and PALE_GOLD or GOLD)
    end
end

local function moltenGold(c, f, t)
    if t < GOLD_START then return end
    local elapsed = f.elapsed or 0
    local reach = ease(t, GOLD_START, GOLD_CATCH)
    local lift = ease(t, GOLD_CATCH, .469)
    local settle = ease(t, .58, .83)
    local bob = math.sin(elapsed / 104) * (2.2 + 2.7 * (1 - settle)) * lift
    local x = SEAT_X + math.sin(elapsed / 193) * lift * 6
    local initialCrest = GOLD_FLOOR - 4
    local catch = ITEM_Y + 5 - SEAT_LIP
    local crest = initialCrest - (initialCrest - catch) * reach - 94 * lift + 31 * settle - bob

    local poolWidth = 81 + 222 * ease(t, GOLD_START, .62)
    local poolHeight = 16 + 15 * reach
    c.spritePart("workbenchGoldPool", ITEM_X - poolWidth / 2, GOLD_FLOOR - poolHeight * 24 / 50,
        poolWidth, poolHeight, 0, 0, 1, 1, ease(t, GOLD_START, .284))

    -- The stream's painted surface and root are at rows 20 and 203 of its sprite.
    local height = (GOLD_FLOOR - crest) * 208 / 183
    local width = 46 + 102 * reach - 10 * settle + 9 * lift * math.sin(elapsed / 94)
    local top = crest - height * 20 / 208
    light(c, x, (crest + GOLD_FLOOR) * .5, width + 31, height + 18, reach * .39, AMBER)
    c.spritePart("workbenchGoldStream", x - width / 2, top, width, height, 0, 0, 1, 1, 1)

    local splash = ease(t, .294, .348) * (1 - ease(t, .48, .61))
    if splash > 0 then
        local puff = 32 + 14 * splash
        c.spritePart("workbenchGoldSplash", x - width * .52, crest - puff * 32 / 60,
            width * 1.04, puff, 0, 0, 1, 1, .9 * splash)
    end
    for i = 1, 9 do
        local phase = (elapsed / (395 + i % 4 * 57) + .209 * i) % 1
        local shine = math.sin(PI * phase) * reach
        local dx = (i % 2 == 0 and -1 or 1) * (8 + i % 3 * 4 + 10 * phase)
        local y = GOLD_FLOOR - (GOLD_FLOOR - crest) * phase
        c.line(x + dx - 1, y + 4 + i % 4 * 2, x + dx + 1, y, 1, PALE_GOLD, shine * .78)
        center(c, "diamond", x + dx, y, 2 + i % 3, 3 + i % 3, shine * .82, GOLD)
    end

    if t >= GOLD_CATCH then return x, crest end
end

local function goldFlakes(c, f, t, x, y)
    local elapsed = f.elapsed or 0
    for i = 1, 18 do
        local flight = step(t, .334 + i * .008, .444 + i * .010)
        if flight > 0 then
            local targetX = (i * 17) % 29 - 14
            local targetY = (i * 11) % 29 - 14
            local direction = i % 2 == 0 and -1 or 1
            local px = x + targetX + direction * (1 - flight) * (20 + i % 4 * 7)
            local py = y + targetY + (1 - flight) * 35 - math.sin(flight * PI) * (9 + i % 5 * 4)
            local flicker = .80 + .20 * math.sin(elapsed / (77 + i * 3) + i * 2)
            local size = 2 + i % 4 * .7
            center(c, "diamond", px + .55, py + .8, size + .9, size + .6, flight * .66, BRASS)
            center(c, "diamond", px, py, size, size * (.58 + i % 3 * .17),
                math.min(1, flight * 1.9) * flicker, i % 3 == 0 and PALE_GOLD or GOLD)
        end
    end
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

local garuSwimmers = {
    {start=.28, fromLeft=true, x=272, y=208, width=98, arc=42},
    {start=.31, x=492, y=210, width=100, arc=54},
    {start=.34, fromLeft=true, x=301, y=293, width=73, arc=27},
    {start=.37, x=531, y=281, width=75, arc=42},
    {start=.39, x=383, y=176, width=110, arc=33},
}

local function garuArrival(c, f, t)
    local elapsed = f.elapsed or 0
    for i, fish in ipairs(garuSwimmers) do
        if t > fish.start then
            local swim = ease(t, fish.start, fish.start + .20)
            local flow = elapsed / 153 + i * 1.73
            local width, height = fish.width, fish.width * 104 / 144
            local entry = fish.fromLeft and -width * .55 or 720 + width * .55
            local x = entry + (fish.x - entry) * swim + math.sin(flow * .73) * swim * 5
            local y = fish.y + (1 - swim) * 23 - math.sin(PI * swim) * fish.arc + math.cos(flow) * 6
            local left, right = math.max(0, x - width / 2), math.min(720, x + width / 2)
            if right > left then
                local stroke = math.floor((elapsed + i * 113) / 141) % 2 + 1
                local direction = fish.fromLeft and "Right" or "Left"
                local alpha = ease(t, fish.start, fish.start + .058)
                c.spritePart("workbenchGaru"..direction..stroke, left, y - height / 2, right - left, height,
                    (left - x + width / 2) / width, 0, (right - left) / width, 1, alpha)
            end
        end
    end
end

local function garuBanner(c, t)
    local pop = ease(t, GARU_BANNER, .642)
    if pop <= 0 then return end
    local width = 577 + 65 * pop
    local x, y = (720 - width) / 2, 72 + (1 - pop) * 15 - math.sin(pop * PI) * 5
    c.box(x - 4, y - 4, width + 8, 71, DARK, .98 * pop)
    c.box(x, y, width, 63, {.105, .120, .171}, .98 * pop)
    c.box(x, y, width, 2, GOLD, .96 * pop)
    c.box(x, y + 61, width, 2, GOLD, .96 * pop)
    center(c, "diamond", x + 20, y + 31, 10, 14, pop, TEAL)
    center(c, "diamond", x + width - 20, y + 31, 10, 14, pop, TEAL)
    c.text("The great and mighty Garu", x + 38, y + 2, width - 76, 30, "title", PALE_GOLD, pop, true)
    c.text("has deemed you worthy of this item", x + 38, y + 32, width - 76, 27, "large", IVORY, pop, true)
end

local function garuBlessing(c, f, t, y)
    local power = ease(t, GARU_GLOW, .78)
    if power <= 0 then return end
    local elapsed = f.elapsed or 0
    local pulse = .91 + .09 * math.sin(elapsed / 231)
    light(c, SEAT_X, y, 216, 148, power * pulse * .69, GOLD)
    orbit(c, elapsed, 12, SEAT_X, y, 44 + 18 * power, 19 + 14 * power, power * .84, PALE_GOLD)
    orbit(c, -elapsed * .70, 7, SEAT_X, y, 30, 30, power * .71, TEAL)
end

local finales = {[2]=clockwork, [3]=phoenix, [4]=garuBlessing}

local function workpiece(c, f, t, broken, goldX, goldTop)
    local hot = ease(t, LIFT_AT, IMPACT) * (1 - ease(t, IMPACT, IMPACT + .16))
    local hit = math.sin(step(t, IMPACT, IMPACT + .042) * PI)
    local x, y, forged = ITEM_X, ITEM_Y + 2 * hit, 0
    if broken then
        x = goldX and goldX + (ITEM_X - SEAT_X) or x
        y = goldTop and goldTop + SEAT_LIP + 1 or y + 6 * ease(t, GOLD_START, GOLD_CATCH)
        forged = ease(t, .30, .48)
        hot = math.max(hot, forged * (1 - ease(t, .56, .81)))
    end
    local seat = x - (ITEM_X - SEAT_X)
    local lip = y - SEAT_LIP
    local size = ITEM_SIZE
    local half = size / 2
    local itemY = lip - half
    local finale = f.great and finales[f.celebrationVariant]
    if finale then finale(c, f, t, itemY) end
    local stolen = f.theft and f.theft.taken
    if not stolen then
        local scorch = f.code == 0 and t >= .51
        local tint = (scorch or f.code == 1 and t > .61) and {.77, .66, .59} or nil
        local rim = forged > 0 and PALE_GOLD or BRASS
        if not broken then light(c, ITEM_X, ANVIL_Y - 1, PLATE_WIDTH + 13, 9, .67, DARK) end
        light(c, x, y + 4, PLATE_WIDTH + 35, 53, .09 + hot * .55, AMBER)
        local holder = goldTop and 1 - ease(t, GOLD_CATCH, .365) or 1
        if holder > 0 then
            center(c, "workbenchPlate", x, y + (1 - holder) * 5, PLATE_WIDTH, PLATE_HEIGHT, holder, tint)
        end
        light(c, seat, lip + 1, size + 21, 9, .82, DARK)
        c.box(seat - half - 2, lip - size - 2, size + 4, size + 4, DARK, .96)
        c.box(seat - half - 2, lip - size - 2, size + 4, 1, rim, .65 + forged * .3)
        center(c, "item", seat, itemY, size, size, 1)
        if finale == garuBlessing and t > GARU_GLOW then
            light(c, seat, itemY, size + 28, size + 28, ease(t, GARU_GLOW, .80) * .59, PALE_GOLD)
        end
        if broken and hot > .05 then
            light(c, seat, itemY, size + 33, size + 33, hot * .45, GOLD)
            c.box(seat - half - 2, lip - size, 1, size, AMBER, hot * .78)
            c.box(seat + half + 1, lip - size, 1, size, AMBER, hot * .78)
        end
        if goldTop then goldFlakes(c, f, t, seat, itemY) end
        c.box(seat - half - 4, lip, size + 8, 2, rim, .96)
        if scorch then
            local heat = .9 - .49 * ease(t, .52, .78)
            c.line(371, y - 6, 389, y - 1, 1.2, AMBER, heat)
            c.line(389, y - 1, 383, y + 5, 1, PALE_GOLD, heat * .61)
        end
    end
    if t >= IMPACT and t < IMPACT + .12 then
        local age = step(t, IMPACT, IMPACT + .12)
        local contactY = ITEM_Y - SEAT_LIP - ITEM_SIZE
        light(c, SEAT_X, contactY, broken and 212 or 132, broken and 135 or 90,
            (1 - age) ^ 4 * .96, PALE_GOLD)
        sparks(c, SEAT_X, contactY, age, broken and 27 or 20, AMBER, f.seed)
    end
    if t > .56 then
        if f.succeeded then
            local age = step(t, .56, .94)
            if f.great then
                sparks(c, seat, itemY, age, 26, GOLD, f.seed)
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
    local broken = t >= IMPACT and f.great and (f.celebrationVariant or 1) == 1
    local garu = f.great and f.celebrationVariant == 4
    f.cueAt = IMPACT
    c.sprite("workbenchForge", 0, 0, 720, 460, 1)
    furnace(c, f.elapsed or 0)
    if broken then
        fracturedAnvil(c, t)
    else
        c.spritePart("workbenchAnvil", ITEM_X - 91, ANVIL_Y, 182, COUNTER_Y - ANVIL_Y, 0, 0, 1, 1, 1)
    end
    blacksmith(c, f, t, broken)
    c.spritePart("workbenchForge", 0, COUNTER_Y, 720, 39, 0, COUNTER_Y/460, 1, 39/460, 1)
    local goldX, goldTop
    if broken then
        furnaceRupture(c, f, t)
        goldX, goldTop = moltenGold(c, f, t)
    end
    if garu then garuArrival(c, f, t) end
    materials(c, f)
    workpiece(c, f, t, broken, goldX, goldTop)
    captions(c, f, t)
    if garu then garuBanner(c, t) end
end

local art = {
    workbenchForge={8,8,720,460,"workbench-court.dds"},
    workbenchAnvil={8,4,364,202,"workbench-court-props.dds"},
    workbenchAnvilLeft={8,4,200,202,"workbench-anvil-break.dds"},
    workbenchAnvilRight={216,4,200,202,"workbench-anvil-break.dds"},
    workbenchAnvilChipA={16,214,36,32,"workbench-anvil-break.dds"},
    workbenchAnvilChipB={60,214,30,32,"workbench-anvil-break.dds"},
    workbenchCrack={8,8,440,104,"workbench-forge-crack.dds"},
    workbenchHeatedCrack={8,120,440,104,"workbench-forge-crack.dds"},
    workbenchGoldStream={8,8,116,208,"workbench-molten-gold.dds"},
    workbenchGoldSplash={132,8,116,60,"workbench-molten-gold.dds"},
    workbenchGoldPool={132,80,116,50,"workbench-molten-gold.dds"},
    workbenchArmillary={336,8,304,304,"workbench-court-finals.dds"},
    workbenchPhoenix={664,8,304,304,"workbench-court-finals.dds"},
    workbenchPlate={8,208,186,44,"workbench-court-props.dds"},
    workbenchGaruLeft1={8,8,144,104,"workbench-garu.dds"},
    workbenchGaruLeft2={168,8,144,104,"workbench-garu.dds"},
    workbenchGaruRight1={8,128,144,104,"workbench-garu.dds"},
    workbenchGaruRight2={168,128,144,104,"workbench-garu.dds"},
}
for cel = 1, 4 do
    art["workbenchFire"..cel] = {8 + (cel - 1) * 168, 8, 156, 240, "workbench-forge-fire.dds"}
end
for frame = 0, REST_FRAME do
    art["workbenchSwing"..frame] = {8 + frame % 6 * 320, 8 + math.floor(frame / 6) * 248,
        304, 236, "workbench-court-strike.dds"}
end

return {workbench = {
    label="Workbench", duration=4250, draw=drawWorkbench, art=art,
    celebrationCount=4, celebrationHold={[4]=1800},
}}

