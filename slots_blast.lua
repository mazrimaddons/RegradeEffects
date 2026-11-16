local Blast = {}

local centerX, centerY = 498, 232
local fullTurn = 2 * math.pi
local scatterStep = 2.399963
local paleGold = {1, 0.87, 0.58}
local hotOrange = {1, 0.49, 0.16}
local deepOrange = {1, 0.24, 0.05}
local soot = {0.11, 0.052, 0.04}

local function easeBetween(value, first, last)
    local t = math.max(0, math.min(1, (value - first) / (last - first)))
    return t * t * (3 - 2 * t)
end

local function stamp(c, viewport, sprite, x, y, w, h, alpha, tint)
    if alpha <= 0 then return end
    local cornerX, cornerY = x - w / 2, y - h / 2
    local left = math.max(viewport.left, cornerX)
    local top = math.max(viewport.top, cornerY)
    local width = math.min(viewport.right, cornerX + w) - left
    local height = math.min(viewport.bottom, cornerY + h) - top
    if width > 0 and height > 0 then
        c.spritePart(sprite, left, top, width, height,
            (left - cornerX) / w, (top - cornerY) / h, width / w, height / h, alpha, tint)
    end
end

local function drawSmoke(c, viewport, age, seedAngle)
    local spread = 1 - math.exp(-age / 0.36)
    local opacity = 0.82 * easeBetween(age, 0.09, 0.36) * (1 - easeBetween(age, 0.81, 1.31))
    for i = 1, 9 do
        local angle = seedAngle + i * scatterStep
        local distance = 100 + 26 * (i % 7)
        local x = centerX + math.cos(angle) * distance * spread
        local y = centerY + (math.sin(angle) * distance * 0.54 - 52) * spread - age * 42
        local size = 105 + 130 * spread + 19 * (i % 5)
        stamp(c, viewport, "slotBlastSmoke", x, y, size, size * 0.83, opacity)
    end
end

local function drawDebris(c, viewport, age, seedAngle)
    local travel = 1 - math.exp(-age / 0.34)
    local opacity = 1 - easeBetween(age, 0.32, 1.18)
    local spread = math.min(1.75, (viewport.right - viewport.left) / 720)
    for i = 1, 13 do
        local angle = seedAngle + i * scatterStep
        local distance = 166 + 34 * ((i * 11) % 10)
        local x = centerX + math.cos(angle) * distance * travel * spread
        local y = centerY + math.sin(angle) * distance * travel * 0.78 + 170 * age * age
        local flip = 0.22 + 0.78 * math.abs(math.cos(age * (9 + i % 6) + i))
        local size = 15 + (i * 13) % 25
        stamp(c, viewport, "slotBlastShard", x, y, size * flip, size, opacity)
    end

    local tailTravel = travel - 0.095 * math.exp(-age / 0.33)
    local sparkFade = 0.94 * (1 - easeBetween(age, 0.27, 1.02))
    if sparkFade <= 0 then return end
    for i = 1, 32 do
        local angle = seedAngle + i * scatterStep + 0.62
        local distance = 178 + 46 * ((i * 13) % 12)
        local dx = math.cos(angle) * distance * spread
        local dy = math.sin(angle) * distance * 0.75
        local fall = age * age * (115 + 20 * (i % 4))
        local x, y = centerX + dx * travel, centerY + dy * travel + fall
        if x > viewport.left and x < viewport.right and y > viewport.top and y < viewport.bottom then
            local tint = i % 3 == 0 and paleGold or hotOrange
            local alpha = sparkFade * (0.63 + 0.37 * math.sin(age * (15 + i % 5) + i) ^ 2)
            local tailX, tailY = centerX + dx * tailTravel, centerY + dy * tailTravel + fall - 9 * age
            tailX = math.max(viewport.left, math.min(viewport.right, tailX))
            tailY = math.max(viewport.top, math.min(viewport.bottom, tailY))
            c.line(tailX, tailY, x, y, 1.1 + 0.4 * (i % 4), tint, 0.84 * alpha)
            if i % 3 == 0 then
                local size = 9 + 4 * (i % 4)
                stamp(c, viewport, "slotGleam", x, y, size, size, alpha, paleGold)
            end
        end
    end
end

function Blast.draw(c, ageMs, seed)
    if ageMs < 0 or ageMs >= 1380 then return end
    local age = ageMs / 1000
    local left, top, width, height = 0, 0, 720, 460
    if c.viewport then left, top, width, height = c.viewport() end
    local viewport = {left = left, top = top, right = left + width, bottom = top + height}
    local farX = math.max(centerX - left, viewport.right - centerX)
    local farY = math.max(centerY - top, viewport.bottom - centerY)
    local reach = math.sqrt(farX * farX + farY * farY)
    local seedAngle = ((seed or 0) % 79) / 79 * fullTurn

    -- A single exposure pulse reaches the viewport corners before the fireball expands.
    local flash = 1 - easeBetween(age, 0, 0.21)
    local darkening = easeBetween(age, 0.12, 0.41) * (1 - easeBetween(age, 0.72, 1.36))
    if flash > 0 then c.box(left, top, width, height, hotOrange, 0.63 * flash) end
    if darkening > 0 then c.box(left, top, width, height, soot, 0.49 * darkening) end
    drawSmoke(c, viewport, age, seedAngle)

    local growth = 1 - math.exp(-age / 0.13)
    local fireSize = 74 + 570 * growth
    local fireFade = 1 - easeBetween(age, 0.14, 0.57)
    stamp(c, viewport, "glow", centerX, centerY, fireSize * 1.45, fireSize, 0.45 * fireFade, deepOrange)
    stamp(c, viewport, "slotBlastFire", centerX, centerY - 21 * growth, fireSize, fireSize * 0.84, fireFade)
    stamp(c, viewport, "glow", centerX, centerY, 184 + 194 * growth, 114 + 112 * growth, 0.70 * flash, paleGold)

    local ringRadius = 30 + reach * easeBetween(age, 0, 0.55)
    local ringSize = ringRadius * 2.5
    local ringFade = easeBetween(age, 0, 0.04) * (1 - easeBetween(age, 0.16, 0.58))
    stamp(c, viewport, "slotBlastRing", centerX, centerY, ringSize, ringSize, ringFade)
    stamp(c, viewport, "slotBlastRing", centerX, centerY, ringSize * 0.79, ringSize * 0.79, 0.38 * ringFade, hotOrange)
    drawDebris(c, viewport, age, seedAngle)
end

return Blast
