local Scenes = {}
local Aguru = require("mazrim_regrade_effects/aguru_cameo")
local TAU = 2 * math.pi
local BLACK = {0.025, 0.018, 0.029}
local STEEL = {0.12, 0.15, 0.19}
local BRONZE = {0.43, 0.27, 0.19}
local BEIGE = {0.92, 0.83, 0.72}
local TEAL = {0.38, 0.86, 0.84}
local RUST = {0.98, 0.34, 0.23}
local GOLD = {1, 0.76, 0.33}
local PALE_GOLD = {1, 0.94, 0.66}
local LILAC = {0.78, 0.49, 0.73}
local ASH = {0.53, 0.40, 0.36}
local PAPER = {0.96, 0.89, 0.78}
local RAIL = {0.33, 0.35, 0.38}
local DRAGON_RED = {0.9, 0.31, 0.19}

local vaultEnding = {
    [0] = "Aguru slipped past the shutters",
    [1] = "The service lift dropped a level",
    [2] = "The inner vault stayed locked",
    [3] = "The item made it out of the vault",
    [4] = "A second vault was hidden behind the first",
}
local mimicEnding = {
    [0] = "Aguru got there first",
    [1] = "It spat the item back chipped",
    [2] = "It spat the item back",
    [3] = "It coughed up a reforged item",
    [4] = "The mimic broke open",
}
local vaultSecrets = {[2] = "The getaway cart arrived right on time", [3] = "The iris guarded a hidden hoard"}
local mimicSecrets = {[2] = "The whole family came out to celebrate", [3] = "The dragon beneath the hoard woke up"}
local colorByOutcome = {
    [0] = RUST, [1] = {0.96, 0.62, 0.39}, [2] = {0.82, 0.69, 0.62}, [3] = TEAL, [4] = GOLD,
}

local function clamp(value)
    return math.max(0, math.min(1, value))
end

local function span(value, first, last)
    local p = clamp((value - first) / (last - first))
    return p * p * (3 - 2 * p)
end

local function mix(a, b, progress)
    return a + (b - a) * progress
end

local function short(text, maximum)
    if type(text) ~= "string" or text == "" then return nil end
    if #text <= maximum then return text end
    local length = maximum - 3
    while length > 0 do
        local byte = text:byte(length + 1)
        if byte < 128 or byte >= 192 then break end
        length = length - 1
    end
    return text:sub(1, length) .. "..."
end

local function meta(frame)
    local item = short(frame.itemName, 67)
    local grade = short(frame.grade, 16)
    if item and grade and frame.code ~= 0 then return item .. "  /  " .. grade end
    if item then return item end
    if grade and frame.code ~= 0 then return grade end
end

local function quote(frame)
    if type(frame.chance) == "number" then
        return string.format("%.1f%% listed success chance", frame.chance * 100)
    end
end

local function sparks(c, x, y, age, radius, color, count, seed, gravity)
    if age < 0 or age >= 1 then return end
    for i = 1, count do
        local angle = (i * 0.618 + seed / 29) * TAU
        local spread = (0.4 + (i * 7 % 11) / 15) * radius * age
        local dx, dy = math.cos(angle) * spread, math.sin(angle) * spread
        local px, py = x + dx, y + dy + gravity * age * age
        local length = 0.18 + age * 0.16
        c.line(px - dx * length, py - dy * length, px, py, 1 + i % 3, color, (1 - age) * 0.85)
    end
end

local function glint(c, x, y, size, alpha, cross)
    c.sprite("diamond", x - size / 2, y - size / 2, size, size, alpha, GOLD)
    if cross then
        c.line(x - size, y, x + size, y, 1, PALE_GOLD, alpha * 0.8)
        c.line(x, y - size, x, y + size, 1, PALE_GOLD, alpha * 0.8)
    end
end

local function shimmers(c, time, fade, seed, count, bottom)
    if fade <= 0 then return end
    for i = 1, count do
        local cycle = (time * (0.25 + (i % 4) * 0.05) + i * 0.137 + seed % 13 * 0.04) % 1
        local x = 35 + (i * 137 + seed * 23) % 650 + math.sin(time * 2 + i) * 10
        local y = 57 + ((i * 97 + seed * 31) % (bottom - 75) + cycle * 54) % (bottom - 75)
        local glow = math.sin(cycle * math.pi) ^ 2
        if glow > 0.13 then
            glint(c, x, y, 2 + (i % 3) + glow * 2, fade * glow * 0.91, i % 5 == 0)
        end
    end
end

local function frameEdge(c, color)
    c.box(0, 0, 720, 38, BLACK)
    c.box(0, 420, 720, 40, BLACK)
    c.box(19, 37, 682, 1, color, 0.65)
    c.box(19, 420, 682, 1, color, 0.65)
    c.box(19, 39, 1, 380, color, 0.33)
    c.box(700, 39, 1, 380, color, 0.33)
end

local function vaultRoom(c, time, alert)
    c.box(0, 0, 720, 460, BLACK)
    c.box(23, 55, 674, 326, STEEL, 0.40)
    c.box(107, 79, 506, 297, BLACK)
    c.box(109, 81, 502, 3, BRONZE)
    c.box(109, 373, 502, 3, BRONZE)
    c.box(107, 83, 4, 291, BRONZE, 0.73)
    c.box(609, 83, 4, 291, BRONZE, 0.73)
    local light = alert and RUST or TEAL
    local flicker = 0.54 + 0.28 * math.sin(time * (alert and 16 or 3.8))
    for i = 1, 2 do
        local side = i == 1 and 1 or -1
        local x = i == 1 and 30 or 631
        c.box(x, 77, 59, 291, STEEL, 0.62)
        c.box(x + 7, 89, 45, 273, BLACK)
        c.box(x + 12, 117, 35, 32, STEEL)
        c.box(x + 14, 119, 31, 2, light, flicker)
        for row = 1, 3 do
            c.box(x + 16, 126 + row * 4, 22 - row * 3, 1, light, 0.48)
        end
        c.line(x + (side == 1 and 13 or 44), 175, x + (side == 1 and 55 or 2), 354, 2, BRONZE, 0.40)
        c.sprite("glow", x - 6, 67, 70, 116, 0.28 * flicker, light)
    end
    for i = 1, 4 do
        local start = i * 190 - 112
        c.line(start, 419, mix(116, 604, (i - 1) / 3), 375, 2, BRONZE, 0.55)
    end
    c.box(135, 387, 450, 1, BRONZE, 0.30)
    c.box(85, 401, 550, 1, BRONZE, 0.37)
end

local function inspectionDock(c, frame, power)
    local hover = math.sin(frame.elapsed * 0.004) * 5
    for i = 1, 2 do
        local x = i == 1 and 135 or 492
        c.box(x, 224, 92, 67, STEEL, power * 0.8)
        c.box(x + 5, 229, 82, 57, BLACK, power * 0.85)
        c.box(x + 6, 234, 80, 49, BRONZE, power * 0.26)
        c.line(x + 11, 278, x + 81, 237, 2, BRONZE, power * 0.65)
        c.line(x + 11, 237, x + 81, 278, 2, BRONZE, power * 0.65)
        c.box(x + 40, 247, 12, 17, STEEL, power)
        c.sprite("diamond", x + 42, 250, 8, 9, power * 0.7, TEAL)
    end
    c.box(249, 142, 222, 146, STEEL, power * 0.71)
    c.box(254, 147, 212, 134, BLACK, power * 0.82)
    c.box(254, 147, 212, 1, TEAL, 0.5 * power)
    c.box(249, 281, 222, 7, BRONZE, power)
    c.box(307, 262, 106, 8, STEEL, power)
    c.box(314, 262, 92, 1, TEAL, power * 0.62)
    c.sprite("glow", 282, 153, 156, 130, 0.36 * power, TEAL)
    c.sprite("item", 305, 151 + hover, 110, 110, power)
    local scan = 257 + frame.elapsed % 1600 / 1600 * 206
    c.box(scan, 148, 2, 132, TEAL, 0.82 * power)
    c.sprite("glow", scan - 29, 148, 60, 132, 0.25 * power, TEAL)
end

local function vaultShutters(c, crush, color)
    local width = 246 * crush
    if width <= 0 then return end
    c.box(114, 101, width, 266, STEEL)
    c.box(606 - width, 101, width, 266, STEEL)
    for i = 1, 7 do
        local y = 106 + 36 * i
        c.box(115, y, width - 1, 3, BLACK)
        c.box(606 - width, y, width - 1, 3, BLACK)
        c.box(115, y + 3, width - 1, 1, color, 0.5)
        c.box(606 - width, y + 3, width - 1, 1, color, 0.5)
    end
    c.box(110 + width, 100, 4, 267, color)
    c.box(606 - width, 100, 4, 267, color)
end

local function treasureBay(c, x, t, delay)
    local opened = span(t, delay, delay + 0.15)
    if opened <= 0 then return end
    c.sprite("glow", x - 22, 138, 151, 166, opened * 0.58, GOLD)
    c.box(x, 180, 106, 100, STEEL, opened)
    c.box(x + 4, 185, 98, 89, BLACK, opened)
    c.box(x + 8, 190 - 26 * opened, 90, 5, GOLD, opened * 0.8)
    c.box(x + 8, 267, 90, 4, GOLD, opened * 0.8)
    c.box(x + 14, 261, 78, 7, BRONZE, opened)
    for i = 1, 4 do
        local height = 8 + (i * 7 % 16)
        c.box(x + 14 + i * 14, 259 - height * opened, 11, height * opened, GOLD, opened * 0.85)
        c.box(x + 14 + i * 14, 259 - height * opened, 11, 1, PALE_GOLD, opened)
    end
end

local function vaultCelebration(c, frame, t, time, open)
    local inner = span(t, 0.44, 0.69)
    local lit = span(t, 0.56, 0.75)
    local lift = span(t, 0.59, 0.87)
    local flash = span(t, 0.56, 0.64) * (1 - span(t, 0.65, 0.78))
    c.sprite("glow", 138, 49, 444, 355, inner * 0.78, GOLD)
    treasureBay(c, 129, t, 0.56)
    treasureBay(c, 485, t, 0.61)
    local doorAlpha = open * (1 - span(t, 0.60, 0.76))
    c.spritePart("vaultdoor", 251 - inner * 134, 107, 109, 218, 0, 0, .5, 1, doorAlpha)
    c.spritePart("vaultdoor", 360 + inner * 134, 107, 109, 218, .5, 0, .5, 1, doorAlpha)
    if lift > 0 then
        local raised = 286 - lift * 23
        c.sprite("glow", 195, 62, 330, 277, lit * (0.5 + flash * 0.42), PALE_GOLD)
        c.box(282, raised, 156, 10, STEEL, lift)
        c.box(288, raised, 144, 2, PALE_GOLD, lift)
        c.box(302, raised + 11, 116, 4, BRONZE, lift)
        local size = mix(58, 143, lift)
        c.sprite("item", 360 - size / 2, raised - size + 2, size, size, lift)
        local crestSize = (52 + 33 * span(t, 0.68, 0.85)) * (1 + flash * 0.19)
        c.sprite("crest", 441 - crestSize / 2, 123 - crestSize / 2, crestSize, crestSize, lit)
    end
    for side = -1, 1, 2 do
        local x = 360 + side * 161
        local phase = (t - (side == -1 and 0.59 or 0.65)) / 0.39
        for i = 1, 12 do
            local age = phase - i * 0.026
            if age > 0 and age < 1 then
                local dx = side * (13 + (i * 11 % 87)) * age
                local y = 247 - (135 + i % 4 * 37) * age + 173 * age * age
                local width = (2 + 6 * math.abs(math.cos(age * 18 + i))) * (1 - age * 0.30)
                c.sprite("diamond", x + dx - width / 2, y, width, 5 + i % 3,
                    (1 - age) * 0.93, i % 3 == 0 and PALE_GOLD or GOLD)
            end
        end
    end
    sparks(c, 360, 209, (t - 0.59) * 2.9, 154, PALE_GOLD, 17, frame.seed, 21)
    shimmers(c, time, lit, frame.seed, 25, 324)
end

local function getawayCart(c, frame, t, time)
    local opened = span(t, 0.38, 0.56)
    local arrival = span(t, 0.48, 0.85)
    local cargo = span(t, 0.69, 0.89)
    c.box(135, 127, 450, 193, BLACK, opened)
    c.sprite("glow", 99, 123, 525, 201, 0.65 * opened, TEAL)
    for i = 1, 15 do
        local x = 80 + i * 34
        c.line(x, 275, x + 14, 313, 4, BRONZE, opened * (i % 2 == 0 and 0.86 or 0.59))
    end
    for _, y in ipairs({282, 305}) do
        c.box(83, y, 555, 5, STEEL, opened)
        c.box(84, y, 553, 1, RAIL, opened)
    end
    for i = 1, 2 do
        local x = i == 1 and 145 or 556
        c.box(x + 2, 165, 4, 112, STEEL, opened)
        c.box(x - 9, 155, 25, 40, STEEL, opened)
        c.box(x - 6, 158, 19, 33, BLACK, opened)
        local light = i == 2 or t > 0.78
        c.sprite("glow", x - 25, 145, 58, 54, opened, light and GOLD or TEAL)
        c.sprite("diamond", x, 170, 8, 8, opened, light and PALE_GOLD or TEAL)
    end
    if arrival <= 0 then return end

    local x = mix(132, 360, arrival)
    for i = 1, 10 do
        local age = (t - 0.53) * 3 - i * 0.05
        if age > 0 and age < 1 then
            local width = 11 + age * 56
            c.sprite("glow", x - 95 - age * 146 - width / 2, 231 - age * 45 - i % 2 * 13,
                width, width, (1 - age) * 0.57, ASH)
        end
    end
    for _, offset in ipairs({-53, 53}) do
        local wheel = x + offset
        local spin = arrival * 27
        c.sprite("vaultdoor", wheel - 19, 263, 38, 38, 0.98)
        for i = 1, 2 do
            local spoke = spin + i * math.pi / 2
            local dx, dy = math.cos(spoke) * 12, math.sin(spoke) * 12
            c.line(wheel - dx, 282 - dy, wheel + dx, 282 + dy, 2, GOLD, 0.72)
        end
    end
    c.box(x - 89, 221, 178, 52, BRONZE)
    c.box(x - 84, 226, 168, 38, STEEL)
    c.box(x - 92, 219, 184, 7, GOLD)
    c.box(x - 74, 258, 148, 2, GOLD, 0.53)
    for i = 1, 5 do
        c.box(x - 78 + i * 24, 233, 2, 22, RAIL, 0.71)
    end
    c.sprite("glow", x + 56, 220, 70, 64, 0.77, GOLD)
    c.sprite("diamond", x + 80, 247, 12, 7, 0.99, PALE_GOLD)
    sparks(c, x - 78, 284, (t - 0.70) * 3.8, 92, GOLD, 14, frame.seed, 17)
    c.sprite("glow", x - 109, 98 - cargo * 26, 218, 187, 0.62 * cargo, GOLD)
    local size = mix(46, 137, cargo)
    c.sprite("item", x - size / 2, 213 - size - cargo * 5 + math.sin(time * 5) * cargo * 5,
        size, size, 0.3 + 0.7 * cargo)
    c.sprite("crest", x + 53, 110, 59, 59, cargo)
end

local function sunLayer(c, cell, x, y, width, height, alpha)
    local sx = (8 + cell % 5 * 400) / 2048
    local sy = (8 + math.floor(cell / 5) * 400) / 2048
    c.spritePart("vaultSun", x - width / 2, y - height / 2, width, height,
        sx, sy, 384 / 2048, 384 / 2048, alpha)
end

local function sealedSun(c, frame, t, time)
    local opened = span(t, 0.42, 0.69)
    if opened <= 0 then return end
    local lit = span(t, 0.61, 0.84)
    local x, y = 360, 187
    c.spritePart("glow", 119, 58, 482, 267, 0, 0, 1, 1, 0.66 * opened, RUST)
    if lit > 0 then
        local shimmer = 0.96 + 0.05 * math.sin(time * 5)
        c.spritePart("glow", 197, 55, 326, 263, 0, 0, 1, 1, 0.72 * lit, GOLD)
        sunLayer(c, 1, x, y, 359 * shimmer, 286 * shimmer, lit * (0.7 + 0.2 * math.sin(time * 6)))
    end
    local hoard = span(t, 0.56, 0.72)
    local pileSize = mix(125, 154, hoard)
    c.sprite("vaultHoard", x - pileSize / 2, y - pileSize / 2 + 5, pileSize, pileSize, hoard)

    local frameIndex = opened * 22
    local blade = math.floor(frameIndex)
    local nextAlpha = opened * (frameIndex - blade)
    -- Keep overlapping blades at the same opacity as the two frames blend.
    sunLayer(c, 2 + blade, x, y, 238, 210, (opened - nextAlpha) / (1 - nextAlpha))
    if nextAlpha > 0 then sunLayer(c, 3 + blade, x, y, 238, 210, nextAlpha) end
    sunLayer(c, 0, x, y, 238, 210, opened)
    if lit <= 0 then return end

    local claim = span(t, 0.70, 0.87)
    local size = mix(52, 100, claim)
    local itemY = y - 33 * claim - 5 * math.sin(claim * math.pi)
    c.sprite("item", x - size / 2, itemY - size / 2, size, size, claim)
    shimmers(c, time, lit * 0.8, frame.seed, 20, 316)
end

local function vault(c, frame)
    local time = frame.elapsed / 1000
    if frame.phase == "waiting" then
        vaultRoom(c, time, false)
        c.sprite("vaultdoor", 149, 78, 233, 233, 0.25)
        inspectionDock(c, frame, 1)
        c.box(115, 105, 490, 25, BLACK, 0.94)
        c.text("VAULT SECURITY FEED", 120, 105, 480, 25, "small", TEAL)
        c.text("Scanning the item", 125, 310, 470, 30, "body", BEIGE)
        frameEdge(c, BRONZE)
        c.text("Vault Heist", 20, 3, 680, 33, "large", BEIGE)
        c.text(quote(frame), 20, 429, 680, 23, "small", BEIGE)
        return
    end

    local t, code = frame.t, frame.code
    local celebration = code == 4 and frame.celebrationVariant
    local color = colorByOutcome[code] or BEIGE
    local breach = span(t, 0.09, 0.29)
    local open = span(t, 0.27, 0.62)
    local extraction = span(t, 0.52, 0.82)
    local final = span(t, 0.70, 0.88)
    vaultRoom(c, time, code == 0 or code == 1 or code == 2)
    if t < 0.20 then inspectionDock(c, frame, 1 - span(t, 0.00, 0.20)) end
    c.sprite("glow", 176, 72, 368, 315, open * 0.65, color)

    if code == 0 then
        local beforeCrush = 1 - span(t, 0.49, 0.58)
        c.sprite("item", 287, 155, 146, 126, beforeCrush * open)
        c.sprite("vaultdoor", 215, 83, 290, 290, breach * (1 - open))
        vaultShutters(c, span(t, 0.38, 0.56), RUST)
        sparks(c, 360, 220, (t - 0.54) * 3, 182, RUST, 15, frame.seed, 85)
        local theft=frame.theft
        if theft then
            local flicker=.32+.24*math.sin(time*37)
            local scan=82+((theft.age/810)%1)*207
            c.spritePart("glow",78,124,564,165,0,0,1,1,.27*flicker,RUST)
            c.line(132,scan,588,scan,1,RUST,flicker)
            c.text(theft.taken and "VAULT BREACHED" or "MOTION DETECTED",468,311,194,17,"small",RUST,.96)
        else
            c.sprite("item", 305, 182, 110, 110, final * 0.44, RUST)
            c.line(314, 276, 403, 185, 2, RUST, final * 0.85)
        end
    elseif code == 1 then
        local drop = span(t, 0.46, 0.77)
        c.box(217, 133, 286, 188, BLACK)
        c.box(225, 138, 270, 166, BRONZE, 0.19)
        local y = 170 + 74 * drop
        c.box(220, y + 61, 280, 8, BRONZE)
        for i = 1, 4 do c.box(248 + i * 43, y + 70, 15, 2, RUST, 0.6) end
        c.sprite("item", 285, y - 42, 150, 110, 0.43 + 0.52 * open)
        c.sprite("vaultdoor", 214 - 153 * open, 83, 290, 290, breach * (1 - extraction))
        sparks(c, 214, y + 50, (t - 0.52) * 3, 108, RUST, 10, frame.seed, 56)
    elseif code == 2 then
        c.sprite("vaultdoor", 215, 83, 290, 290, breach)
        c.box(270, 143, 180, 153, BLACK, final * 0.90)
        c.sprite("item", 314, 156, 92, 92, final * 0.82)
        c.box(278, 288, 164, 2, RUST, final)
        c.text("ACCESS DENIED", 277, 252, 166, 30, "body", RUST, final)
    else
        c.box(171, 99, 378, 261, BLACK)
        if celebration ~= 3 then c.box(173, 101, 374, 257, color, 0.17 * open) end
        if celebration == 2 then
            getawayCart(c, frame, t, time)
        elseif celebration == 3 then
            sealedSun(c, frame, t, time)
        elseif code == 4 then
            vaultCelebration(c, frame, t, time, open)
        else
            local size = 119 + extraction * 74
            local y = 149 - extraction * 10
            c.sprite("item", 360 - size / 2, y, size, size, open)
            c.box(258, y + size * 0.78, 204, 2, TEAL, extraction)
        end
        c.sprite("vaultdoor", 215 - 194 * open, 83, 290, 290, breach * (1 - extraction))
    end

    if t < 0.49 then
        local strike = span(t, 0.07, 0.24) * (1 - span(t, 0.35, 0.48))
        local x = 501 - 139 * strike + math.sin(time * 88) * 2
        c.sprite("vaultdrill", x, 164, 189, 106, 0.28 + strike * 0.72)
        local flame = ((t * 19) % 1) * 0.79
        sparks(c, x + 1, 217, flame, 91 * strike, GOLD, 12, frame.seed, 42)
    end
    frameEdge(c, code == 4 and t >= 0.62 and GOLD or BRONZE)
    c.text("Vault Heist", 20, 3, 680, 33, "large", BEIGE)
    if final > 0 then
        c.box(111, 337, 498, 75, BLACK, final * 0.95)
        c.box(111, 337, 498, 2, color, final)
        c.text(frame.title, 119, 341, 482, 38, "title", color, final)
        c.text(vaultSecrets[celebration] or vaultEnding[code], 118, 381, 484, 24, "small", BEIGE, final)
        c.text(meta(frame), 20, 429, 680, 23, "small", BEIGE, final)
    else
        local status = t < 0.31 and "Drilling the blast lock" or "Checking the inner vault"
        c.text(status, 128, 340, 464, 24, "body", BEIGE)
        c.text(quote(frame), 20, 429, 680, 23, "small", BEIGE)
    end
end

local function mimicRoom(c, time, heat)
    c.sprite("mimicchamber", 0, 0, 720, 460)
    c.spritePart("glow", 143, 58, 434, 279, 0, 0, 1, 1, 0.21 + heat * 0.24, LILAC)
    c.spritePart("glow", 141, 316, 438, 86, 0, 0, 1, 1, .73, BLACK)
    for i = 1, 2 do
        local x = i == 1 and 94 or 626
        local wick = i == 1 and 309 or 320
        local flicker = .82 + .14 * math.sin(time * 9 + i * 6) + .04 * math.sin(time * 17)
        c.sprite("glow", x - 48, wick - 63, 96, 96, flicker * .49, GOLD)
        c.spritePart("diamond", x - 3, wick - 13 * flicker, 6, 13 * flicker, 0, 0, 1, 1, .94, GOLD)
        c.spritePart("diamond", x - 1.5, wick - 6, 3, 6, 0, 0, 1, 1, .86, PALE_GOLD)
    end
end

local function mimicEye(c,x,centerY,width,height,blink,alpha,shift)
    local eyeHeight=height*blink
    local drift=(shift or 0)*width/108*.54
    c.spritePart("mimiceye",x,centerY-eyeHeight/2,width,eyeHeight,0,0,1,1,alpha)
    c.spritePart("mimiciris",x+width*.319+drift,centerY-eyeHeight*.36,width*.362,eyeHeight*.72,0,0,1,1,alpha)
end

local function chest(c, time, jaw, pulse, tint, alpha, rise, lidKick, eyeShift, theft)
    rise, lidKick = rise or 0, lidKick or 0
    local bounce = math.sin(time * 8) * pulse
    local top = 79 - jaw * 42 + bounce - rise - lidKick
    local bottom = 215 + jaw * 38 - bounce - rise
    local throat = 42 + jaw * 85
    c.spritePart("glow", 178, 171 - rise, 364, throat + 38, 0, 0, 1, 1, alpha, BLACK)
    c.sprite("glow", 245, 154 + jaw * 7 - rise, 230, throat + 43, alpha * (0.3 + jaw * 0.37), tint)
    if theft then Aguru.peekMimic(c,theft,bottom+11) end
    c.sprite("mimiclower", 124, bottom, 472, 177, alpha)
    c.sprite("mimicupper", 124, top, 472, 177, alpha)
    local blinkWindow = (time + 0.63) % 2.7
    local blink = blinkWindow > 2.49 and 0.12 + 0.88 * math.abs(blinkWindow - 2.595) / 0.105 or 1
    mimicEye(c,306,top+61,108,50,blink,alpha,eyeShift)
end

-- Three Timelines' gold orbit, centered on the item as it leaves the mimic.
local orbitTints = {{1, 0.43, 0.17}, {0.42, 0.87, 1}, {0.76, 0.53, 1}}
local function mimicOrbit(c, frame, t, x, y)
    local arrival = span(t, 0.58, 0.73)
    local spread = span(t, 0.58, 0.91)
    local tick = frame.elapsed / 480
    local gilding = span(t, 0.63, 0.75)
    c.sprite("glow", x - 270, y - 108, 540, 216, (1 - arrival) * 0.54 + 0.22, GOLD)
    for branch, tint in ipairs(orbitTints) do
        local color = {mix(tint[1], GOLD[1], gilding), mix(tint[2], GOLD[2], gilding),
            mix(tint[3], GOLD[3], gilding)}
        local rx = 74 + spread * (85 + branch * 9)
        local ry = 38 + spread * (28 + branch * 6)
        for i = 1, 8 do
            local angle = (branch - 1) * TAU / 3 + i * math.pi / 12 + tick * 0.35
            local px, py = x + math.cos(angle) * rx, y + math.sin(angle) * ry
            local nextAngle = angle + math.pi / 22
            local opacity = (0.53 + 0.33 * math.sin(tick + i)) * (0.34 + 0.66 * arrival)
            c.line(px, py, x + math.cos(nextAngle) * rx, y + math.sin(nextAngle) * ry, 2.5, color, opacity)
            if i % 4 == 0 then glint(c, px, py, 7, opacity, true) end
        end
    end
    for i = 1, 20 do
        local angle = i * 2.39996 + (frame.seed % 17) * 0.18
        local reach = 48 + spread * (125 + i % 6 * 20)
        local px, py = x + math.cos(angle) * reach, y + math.sin(angle) * reach * 0.46
        local opacity = (0.46 + 0.38 * math.sin(tick * 3 + i)) * (0.36 + arrival * 0.64)
        glint(c, px, py, 3 + i % 5, opacity, i % 5 == 0)
    end
end

local function mimicCelebration(c, frame, t, time)
    local egg = span(t, 0.34, 0.56)
    local shake = span(t, 0.49, 0.58) * (1 - span(t, 0.585, 0.64))
    local cracked = span(t, 0.58, 0.78)
    local bounce = math.sin(cracked * math.pi)
    local size = mix(35, 137, egg)
    local eggX = 360 - size / 2 + math.sin(time * 54) * shake * 10
    local eggY = mix(220, 130, egg)
    local flash = span(t, 0.57, 0.62) * (1 - span(t, 0.64, 0.75))
    local light = span(t, 0.58, 0.76)
    c.sprite("glow", 150, 58, 420, 331, 0.68 * light + 0.31 * flash, GOLD)
    if cracked > 0 then
        local wing = size / 2
        c.spritePart("mimicegg", eggX - cracked * 127, eggY - 26 * bounce + cracked * 77,
            wing, size + 32, 0, 0, 0.5, 1, 1 - cracked)
        c.spritePart("mimicegg", eggX + wing + cracked * 117, eggY - 55 * bounce + cracked * 87,
            wing, size + 32, 0.5, 0, 0.5, 1, 1 - cracked)
        for i = 1, 12 do
            local angle = (i / 12 + frame.seed / 27) * TAU
            local distance = cracked * (105 + i * 9 % 66)
            local x = 360 + math.cos(angle) * distance
            local y = 205 + math.sin(angle) * distance * 0.62 + 38 * cracked * cracked
            glint(c, x, y, 5 + i % 6, (1 - cracked * 0.93) * span(t, 0.58, 0.64), i % 4 == 0)
        end
        local toss = span(t, 0.58, 0.84)
        local itemAir = math.sin(toss * math.pi)
        local itemX = 360 - itemAir * 41
        local itemY = mix(216, 193, toss) - itemAir * 68
        local itemSize = mix(39, 159, toss)
        mimicOrbit(c, frame, t, itemX, itemY)
        c.sprite("item", itemX - itemSize / 2, itemY - itemSize / 2, itemSize, itemSize, span(t, 0.58, 0.64))
        local crest = span(t, 0.64, 0.87)
        local crestY = mix(221, 211, crest) - math.sin(crest * math.pi) * 86
        c.sprite("crest", mix(367, 449, crest), crestY, mix(38, 86, crest), mix(38, 86, crest), crest)
    else
        c.sprite("mimicegg", eggX, eggY, size, size + 32, egg)
    end
    sparks(c, 360, 206, (t - 0.58) * 2.8, 186, PALE_GOLD, 23, frame.seed, 40)
end

local function hatchling(c, x, y, width, jaw, blink, alpha)
    local left = x - width / 2
    local height = width * 0.375
    local upper = y - height - jaw
    local lower = y - height / 3 + jaw * 0.14
    c.sprite("glow", left - 15, y - 18, width + 30, 42, alpha * 0.54, BLACK)
    c.sprite("glow", left + 8, upper + 11, width - 16, height + 12, alpha * 0.82, GOLD)
    c.sprite("mimiclower", left, lower, width, height, alpha)
    c.sprite("mimicupper", left, upper, width, height, alpha)
    mimicEye(c,x-width*.115,upper+height*.34,width*.23,height*.24,blink,alpha)
end

local function mimicFamily(c, frame, t, time)
    local appear = span(t, 0.52, 0.69)
    local pop = span(t, 0.62, 0.79)
    if appear <= 0 then return end
    c.sprite("glow", 92, 87, 536, 264, appear * 0.79, GOLD)
    for i = -1, 1 do
        local spread = span(t, 0.52 + 0.025 * math.abs(i), 0.73)
        local phase = (time * (1.38 + math.abs(i) * 0.27) + 4 * i / 11) % 1
        local hop = math.sin(phase * math.pi) ^ 2
        local x = 360 + i * mix(145, 191, spread)
        local y = mix(305, i == 0 and 303 or 297, spread) - hop * 15
        local blink = phase > 0.88 and 0.34 or 1
        hatchling(c, x, y, i == 0 and 124 or 112, 6 + hop * 11, blink, spread)
        if hop > 0.39 then
            glint(c, x + (12 + math.sin(phase * TAU) * 21) * i, y - 43 - hop * 16, 5 + hop * 6, spread * hop, true)
        end
    end
    local travel = math.sin(pop * math.pi)
    local size = mix(32, 104, pop)
    local y = mix(191, 146, pop) - 44 * travel
    c.sprite("item", 360 - size / 2, y - size / 2, size, size, span(t, 0.63, 0.70))
    c.sprite("crest", 425, y - 24, 54, 54, pop)
    shimmers(c, time, pop, frame.seed + 11, 26, 322)
    sparks(c, 360, 240, (t - 0.63) * 3.3, 148, PALE_GOLD, 18, frame.seed, 31)
end

local function dragonPoint(angle, grow, time)
    local radius = 35 + grow * 169
    local x = 360 + math.cos(angle) * radius
    local y = 222 + math.sin(angle) * (20 + grow * 54) - math.sin(angle * 2 + time * 3) * 12
    return x, y
end

local DRAGON_LINKS = 32
local DRAGON_BACK = {0.70, 0.60, 0.52}

local function dragonAngle(headAngle, link)
    return headAngle - 5.38 * (1 - (1 - link / DRAGON_LINKS) ^ 1.58)
end

local function dragonLink(c, headAngle, link, rise, time, farSide)
    local a = dragonAngle(headAngle, link)
    local x, y = dragonPoint(a, rise, time)
    local nx, ny = dragonPoint(dragonAngle(headAngle, link - 1), rise, time)
    local tx, ty = nx - x, ny - y
    local spacing = math.sqrt(tx * tx + ty * ty)
    local direction = tx >= 0 and 1 or -1
    local scale = 1 - link / DRAGON_LINKS
    local size = math.max((8 + scale * 53) * (0.42 + rise * 0.58), spacing * 1.54)
    local angle = tx == 0 and (ty < 0 and -math.pi / 2 or math.pi / 2)
        or math.atan(ty / tx) + (tx < 0 and math.pi or 0)
    local orientation = math.floor(angle * 16 / TAU + 0.5) % 16
    local tint = farSide and DRAGON_BACK or nil
    if link == 6 or link == 17 then
        local w = size * (link == 6 and 1.72 or 1.59)
        local h = w * 2 / 3
        local hand = direction == 1 and "dragonClawRight" or "dragonClawLeft"
        local lift = math.sin(time * 8 + link) * 3 * rise
        c.sprite(hand, x - w * (direction == 1 and 0.35 or 0.65), y - h * 0.26 - lift,
            w, h, rise * 0.95, tint)
    end
    local mx, my = (x + nx) * 0.5, (y + ny) * 0.5
    c.sprite("dragonCoil" .. orientation, mx - size / 2, my - size / 2, size, size, rise, tint)
end

local function mimicDragon(c, frame, t, time)
    local rise = span(t, 0.47, 0.79)
    if rise <= 0 then return end
    local headAngle = mix(1.4, 4.67, rise) + math.sin(time * 3.2) * 0.23
    local headX, headY = dragonPoint(headAngle, rise, time)
    c.sprite("glow", 140, 78, 440, 278, rise * 0.74, DRAGON_RED)

    -- Layer the links around the item so the coiling body passes behind and in front.
    for pass = 1, 2 do
        local farSide = pass == 1
        for i = DRAGON_LINKS, 1, -1 do
            if (math.sin(dragonAngle(headAngle, i - 0.5)) < 0) == farSide then
                dragonLink(c, headAngle, i, rise, time, farSide)
            end
        end
        if farSide then
            local show = span(t, 0.69, 0.82)
            local size = 46 + show * 90
            c.sprite("glow", 256, 103, 208, 189, show * 0.82, GOLD)
            c.sprite("item", 360 - size / 2, 216 - size / 2, size, size, show)
            c.sprite("crest", 452, 83, 59, 59, show)
        end
    end

    local direction = math.sin(headAngle) > 0 and -1 or 1
    local facing = direction == 1 and "Right" or "Left"
    local headWidth = mix(70, 156, rise)
    local headHeight = headWidth * 2 / 3
    local muzzle = headX + direction * headWidth * 0.43
    local breath = span(t, 0.68, 0.78) * (1 - span(t, 0.85, 0.98))
    local reach = math.max(0, math.min(209, direction == 1 and 694 - muzzle or muzzle - 26))
    if breath > 0.03 and reach > 22 then
        local width = reach * (0.45 + 0.55 * breath) * (0.91 + math.sin(time * 29) * 0.09)
        local height = width * 0.375
        c.sprite("glow", muzzle + direction * width * 0.46 - width / 2, headY - height * 0.7,
            width, height * 1.44, rise * breath * 0.72, DRAGON_RED)
        c.sprite("dragonFlare" .. facing, muzzle - (direction == 1 and width * 0.025 or width * 0.975),
            headY - height * 0.49, width, height, rise * breath)
    end
    c.sprite("glow", headX - 44, headY - 38, 88, 76, rise * 0.49, GOLD)
    local portrait = breath > 0.15 and "dragonRoar" or "dragonHead"
    c.sprite(portrait .. facing, headX - headWidth * (direction == 1 and 0.44 or 0.56),
        headY - headHeight * 0.55, headWidth, headHeight, rise)
    for i = 1, 12 do
        local age = (time * 1.45 + i * 0.084) % 1
        local px = muzzle + direction * (7 + age * reach)
        local py = headY + age * (math.sin(i * 4.7) * 31 + 8)
        local width = 4 + i % 3 * 3
        if px > 22 and px < 698 then glint(c, px, py, width, rise * (1 - age) * (0.3 + breath * 0.63), i % 4 == 0) end
    end
    shimmers(c, time, rise * 0.77, frame.seed + 22, 14, 312)
end

local function mimic(c, frame)
    local time = frame.elapsed / 1000
    if frame.phase == "waiting" then
        mimicRoom(c, time, 0.16)
        local breathe = (math.sin(time * 3.8) + 1) * 0.085
        chest(c, time, 0.20 + breathe, 1.3, LILAC, 1)
        local y = 213 + math.sin(time * 4.8) * 12
        c.sprite("item", 332, y, 57, 57, 0.93)
        c.sprite("glow", 313, y - 18, 96, 92, 0.29, LILAC)
        frameEdge(c, BRONZE)
        c.text("Forge Mimic", 20, 3, 680, 33, "large", BEIGE)
        c.text("The chest is breathing", 20, 383, 680, 24, "small", LILAC)
        c.text(quote(frame), 20, 429, 680, 23, "small", BEIGE)
        return
    end

    local t, code = frame.t, frame.code
    local celebration = code == 4 and frame.celebrationVariant
    local color = colorByOutcome[code] or BEIGE
    local bite = span(t, 0.01, 0.17) * (1 - span(t, 0.18, 0.34))
    local release = span(t, 0.40, 0.60) * (1 - span(t, 0.64, 0.75))
    local finale = span(t, 0.70, 0.86)
    local visibility = 1 - span(t, 0.62, 0.82) * (code == 4 and 1 or 0.66)
    if celebration == 2 then visibility = 1 - span(t, 0.46, 0.63) end
    mimicRoom(c, time, bite + release * 0.35)
    if code == 4 and t >= 0.34 then
        local hop = math.sin(span(t, 0.36, 0.69) * math.pi)
        local kick = span(t, 0.55, 0.65) * 20
        c.sprite("glow", 218, 249, 284, 139, hop * 0.68, GOLD)
        chest(c, time, 0.15 + release * 0.54, release * 6, GOLD, visibility, hop * 29, kick)
    elseif frame.theft then
        local theft=frame.theft
        local eyeShift=mix(0,30,span(theft.age,390,1080))
        chest(c,time,theft.jaw,theft.snap*9,LILAC,1,theft.snap*10,theft.lid,eyeShift,theft)
    else
        chest(c, time, 0.09 + bite * 0.88 + release * 0.49,
            bite * 2 + release * 6, code == 4 and GOLD or LILAC, visibility)
    end
    if t < 0.30 then
        local swallowed = span(t, 0.07, 0.29)
        local size = mix(66, 11, swallowed)
        c.sprite("item", 360 - size / 2, mix(174, 258, swallowed), size, size, 1 - swallowed)
        sparks(c, 361, 243, (t - 0.19) * 6, 67, LILAC, 8, frame.seed, 29)
    elseif celebration == 2 then
        mimicFamily(c, frame, t, time)
    elseif celebration == 3 then
        mimicDragon(c, frame, t, time)
    elseif code == 4 then
        mimicCelebration(c, frame, t, time)
    elseif code == 0 then
        local smoke = span(t, 0.38, 0.58)
        local clear = frame.theft and span(frame.theft.age,100,370) or 0
        local haze = smoke * (1 - finale * 0.59) * (1 - clear * .80) * .68
        for i = 1, 8 do
            local x = 360 + (i - 4.5) * 16 * smoke
            local y = 250 - (i * 17 % 67) * smoke
            local size = 22 + i % 3 * 14 + smoke * 31
            c.sprite("glow", x - size, y - size, size * 2, size * 2, haze, ASH)
        end
        sparks(c, 360, 232, (t - 0.40) * 2.8, 105, RUST, 14, frame.seed, 81)
    else
        local lift = span(t, 0.40, 0.72)
        local air = math.sin(lift * math.pi)
        local size = mix(38, 137, lift)
        local x = 360 + (code == 3 and 0 or 90) * air
        local y = mix(245, 126, lift) - air * 73
        c.sprite("glow", x - 110, y - 24, 220, 220, lift * (code == 3 and 0.71 or 0.47), color)
        c.sprite("item", x - size / 2, y, size, size, lift)
        if code == 1 then
            c.line(x - 18, y + 17, x + 2, y + 49, 2, RUST, lift)
            c.line(x + 2, y + 49, x - 9, y + 67, 2, RUST, lift)
        end
        sparks(c, 361, 245, (t - 0.41) * 3.1, 154, color, 12, frame.seed, 62)
    end
    frameEdge(c, code == 4 and t >= 0.62 and GOLD or BRONZE)
    c.text("Forge Mimic", 20, 3, 680, 33, "large", BEIGE)
    if finale > 0 then
        c.box(111, 337, 498, 75, BLACK, finale * 0.95)
        c.box(111, 337, 498, 2, color, finale)
        c.text(frame.title, 119, 341, 482, 38, "title", color, finale)
        c.text(mimicSecrets[celebration] or mimicEnding[code], 118, 381, 484, 24, "small", BEIGE, finale)
        c.text(meta(frame), 20, 429, 680, 23, "small", PAPER, finale)
    else
        local status = t < 0.32 and "It swallowed the item" or "Something is moving inside"
        c.text(status, 20, 383, 680, 24, "small", LILAC)
        c.text(quote(frame), 20, 429, 680, 23, "small", BEIGE)
    end
end

Scenes.vault = {label = "Vault Heist", duration = 4080, draw = vault}
Scenes.mimic = {label = "Forge Mimic", duration = 3840, draw = mimic}
return Scenes
