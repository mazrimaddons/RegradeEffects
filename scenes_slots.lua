local Blast = require("mazrim_regrade_effects/slots_blast")

local GOLD = {1, 0.76, 0.36}
local CREAM = {1, 0.94, 0.76}
local MUTED = {0.78, 0.67, 0.54}
local BLACK = {0.07, 0.035, 0.028}
local ROSE = {1, 0.44, 0.56}
local ICE = {0.48, 0.84, 1}

local reelX = {162, 300, 438}
local reelTop, reelBottom, payline = 145, 319, 232
local cellHeight = 65
local brakeStart = {0.31, 0.43, 0.56}
local brakeEnd = {0.53, 0.68, 0.82}
local releaseAt = brakeEnd[3]
local fuseMs, blastClearMs = 240, 175
local paylinePairs = {"slotBell", "slotSeven", "slotCoin"}
local otherSymbols = {"slotGem", "slotBar", "slotCrown"}

local symbols = {
    "slotBell", "slotGem", "slotCoin", "slotBar", "slotCrown", "slotSeven",
    "slotCoin", "slotBell", "slotGem", "slotBar", "slotCrown",
}

local outcomes = {
    [0] = {title = "Destroyed", symbol = "slotBomb", color = {1, 0.32, 0.24}},
    [1] = {title = "Downgraded", symbol = "slotArrow", color = {1, 0.59, 0.29}},
    [2] = {title = "Failed", symbol = "slotNull", color = MUTED},
    [3] = {title = "Success", symbol = "slotCrown", color = {0.67, 0.91, 0.58}},
    [4] = {title = "Great success", symbol = "slotSeven", color = GOLD},
}

local function clamp(value)
    return math.max(0, math.min(1, value))
end

local function fraction(value, first, last)
    return clamp((value - first) / (last - first))
end

local function ease(value)
    return value * value * (3 - 2 * value)
end

local function centered(c, sprite, x, y, w, h, alpha, tint)
    c.sprite(sprite, x - w / 2, y - h / 2, w, h, alpha, tint)
end

local function sparkle(c, x, y, size, alpha, tint)
    centered(c, "slotGleam", x, y, size, size, alpha, tint)
end

local function leverPose(elapsed)
    if elapsed < 210 then return ease(fraction(elapsed, 0, 210)) end
    if elapsed < 365 then return 1 end
    if elapsed < 685 then return 1 - ease(fraction(elapsed, 365, 685)) end
    return 0.13 * math.sin(fraction(elapsed, 685, 900) * math.pi)
end

local function freeReel(index, elapsed, seed)
    local active = math.max(0, elapsed - (index - 1) * 55)
    local speed = (16.6 + index * 0.85) / 1000
    local ramp = 235
    local blend = math.min(active, ramp) / ramp
    local travel = speed * (0.5 * ramp * blend * blend + math.max(0, active - ramp))
    return (seed + index * 3) % #symbols + travel, speed * blend
end

local function reelPosition(f, index, elapsed, wait, duration)
    if f.phase ~= "reveal" or f.t < brakeStart[index] then
        return freeReel(index, elapsed, f.seed or 0)
    end

    local brakingTime = duration * (brakeEnd[index] - brakeStart[index])
    local first, velocity = freeReel(index, wait + duration * brakeStart[index], f.seed or 0)
    local landing = math.floor(first + velocity * brakingTime * 0.48 + 0.5)
    local u = fraction(f.t, brakeStart[index], brakeEnd[index])
    if u >= 1 then return landing, 0, landing end

    -- Match the free-spinning velocity at the brake point and arrive at the center with zero velocity.
    local travel = landing - first
    local tangent = velocity * brakingTime
    local distance = tangent * u + (3 * travel - 2 * tangent) * u * u
        + (tangent - 2 * travel) * u * u * u
    local speed = (tangent + 2 * (3 * travel - 2 * tangent) * u
        + 3 * (tangent - 2 * travel) * u * u) / brakingTime
    return first + distance, speed, landing
end

local function reelSymbol(index, ticket, landing, payout)
    if ticket == landing and payout ~= nil then return payout end
    local symbol = symbols[(ticket + index) % #symbols + 1]
    if symbol == payout and landing and math.abs(ticket - landing) == 1 then
        return payout == "slotGem" and "slotBar" or "slotGem"
    end
    return symbol
end

local function drawReel(c, f, index, elapsed, wait, duration, payout, outcome, revealAge)
    local x = reelX[index]
    local position, speed, landing = reelPosition(f, index, elapsed, wait, duration)
    local center = math.floor(position + 0.5)
    local ink = 0.94 - math.min(speed * 10, 0.22)
    c.box(x, reelTop, 120, reelBottom - reelTop, BLACK)
    for ticket = center - 2, center + 2 do
        local y = payline + (position - ticket) * cellHeight
        local bandTop = math.max(reelTop, y - cellHeight / 2 + 1)
        local bandBottom = math.min(reelBottom, y + cellHeight / 2 - 1)
        if bandBottom > bandTop then
            c.box(x + 1, bandTop, 118, bandBottom - bandTop, {0.24, 0.14, 0.09}, 0.7)
            c.box(x + 1, bandTop, 118, 1, {0.56, 0.35, 0.19}, 0.31)
        end

        local w, h = 83, 83 * 112 / 144
        local symbolTop = y - h / 2
        local visibleTop = math.max(reelTop, symbolTop)
        local visibleBottom = math.min(reelBottom, symbolTop + h)
        if visibleBottom > visibleTop then
            local light = ink * (0.57 + 0.43 * (1 - clamp(math.abs(y - payline) / 94)))
            local drawHeight = visibleBottom - visibleTop
            local sy, sh = (visibleTop - symbolTop) / h, drawHeight / h
            local symbolX = x + (120 - w) / 2
            local key = reelSymbol(index, ticket, landing, payout)
            if key then
                c.spritePart(key, symbolX, visibleTop, w, drawHeight, 0, sy, 1, sh, light)
            else
                centered(c, "glow", x + 60, payline, 96, 76, 0.85, BLACK)
            end
        end
    end

    c.spritePart("slotGlass", x, reelTop, 120, reelBottom - reelTop, 0, 0, 1, 1, 0.82)
    local lamp = math.sin(elapsed / 105 - index) * 0.2 + 0.55
    if f.phase == "reveal" then
        local stopAge = (f.t - brakeEnd[index]) * duration
        if stopAge >= 0 then lamp = 0.55 + math.exp(-stopAge / 190) * 0.45 end
    end
    local color = outcome and outcome.color or GOLD
    if outcome and revealAge then lamp = lamp + math.exp(-revealAge / 165) * 0.3 end
    c.box(x + 2, payline, 15, 1, color, clamp(lamp))
    c.box(x + 103, payline, 15, 1, color, clamp(lamp))
    sparkle(c, x - 5, payline, 13, clamp(lamp), color)
    sparkle(c, x + 125, payline, 13, clamp(lamp), color)
end

local function drawBulbs(c, elapsed, outcome, revealAge, variant)
    local jackpot = outcome and outcome == outcomes[4]
    local bulbs = jackpot and 16 or 8
    local color = outcome and outcome.color or GOLD
    for i = 1, bulbs do
        local x = 147 + (426 / (bulbs - 1)) * (i - 1)
        local wave = (math.sin(elapsed / 178 - i * 0.68) + 1) * 0.5
        local strength = 0.18 + wave * 0.34
        local size = 10
        if outcome then
            strength = 0.22 + strength * math.exp(-revealAge / 520)
            if jackpot then
                strength = 0.3 + wave * 0.62
                size = 13 + wave * 7
                if variant == 2 and i % 3 ~= 0 then color = ROSE
                elseif variant == 3 then color = i % 3 == 0 and CREAM or ICE
                else color = GOLD end
            end
        end
        sparkle(c, x, 118, size, strength, color)
        if jackpot then sparkle(c, 720 - x, 331, size, strength, color) end
    end
end

local function drawJackpot(c, elapsed, age, variant, seed)
    local t = clamp(age / 1900)
    local strength = (1 - t * 0.45) * (0.44 + 0.56 * math.exp(-age / 710))
    local accent = variant == 2 and ROSE or variant == 3 and ICE or GOLD
    c.spritePart("glow", 120, 163, 480, 137, 0, 0, 1, 1, strength * 0.57, accent)
    for i, x in ipairs(reelX) do
        local pulse = (0.5 + 0.5 * math.cos(age / 142 - i * 1.36)) ^ 2
        sparkle(c, x + 60, 139, 21 + pulse * 11, (0.36 + pulse * 0.62) * (1 - t * 0.25), accent)
        sparkle(c, x + 60, 322, 17 + pulse * 8, (0.24 + pulse * 0.6) * (1 - t * 0.25), CREAM)
    end
    for i = 1, 28 do
        local lane = i % 5
        local clock = (age / (1070 + lane * 118) + i * 0.137) % 1
        local alpha = math.sin(clock * math.pi) * (1 - clock * 0.24) * (1 - t * 0.3)
        local x, y, size
        if variant == 2 then
            local side = i % 2 == 0 and 1 or -1
            x = 360 + side * (94 + 220 * clock) + math.sin(clock * 8 + i) * 17
            y = 300 - math.sin(clock * math.pi) * (90 + lane * 17) - clock * 107
            size = 9 + lane * 3
            if i % 4 == 0 then centered(c, "slotGem", x, y, size * 1.8, size * 1.8, alpha) end
        elseif variant == 3 then
            local angle = i * (2 * math.pi / 28) + elapsed / (i % 2 == 0 and 680 or -970)
            local radius = 157 + lane * 12 + math.sin(clock * math.pi) * 102
            x, y = 360 + math.cos(angle) * radius, 227 + math.sin(angle) * radius * 0.47
            size = 8 + lane * 4
        else
            local direction = math.sin(i * 2.387 + seed % 11)
            x, y = 360 + direction * (85 + clock * 210), 123 + clock * clock * (153 + lane * 23)
            size = 8 + lane * 3
            if i % 4 == 0 then
                local glint = math.abs(math.cos(clock * 12 + i))
                c.spritePart("slotCoin", x - size / 2, y - size / 2, size * (0.5 + glint), size * 1.15,
                    0, 0, 1, 1, alpha)
            end
        end
        sparkle(c, x, y, size, alpha, i % 3 == 0 and CREAM or accent)
    end
end

local function drawResultEffect(c, outcome, age)
    local movement = clamp(age / 860)
    local flash = (1 - movement) * (1 - movement)
    if outcome == outcomes[1] then
        local y = payline + movement * 65
        centered(c, "glow", 498, y, 138, 52, flash * 0.61, outcome.color)
        sparkle(c, 479, y, 23, flash, outcome.color)
        sparkle(c, 517, y, 23, flash, outcome.color)
    elseif outcome == outcomes[2] then
        centered(c, "glow", 498, payline, 123, 74, flash * 0.34, outcome.color)
    elseif outcome == outcomes[3] then
        c.spritePart("glow", 154, payline - 57, 412, 114, 0, 0, 1, 1, flash * 0.64, outcome.color)
        for i = 1, 9 do
            local x = 173 + (i - 1) * 47
            local y = payline + movement * (i % 2 == 0 and 52 or -52)
            sparkle(c, x, y, 10 + (i % 3) * 4, flash, outcome.color)
        end
    end
end

local function drawItemName(c, name)
    local line, lines = "", {}
    for word in name:gmatch("%S+") do
        local candidate = line == "" and word or line .. " " .. word
        if #candidate > 43 and line ~= "" then
            lines[#lines + 1] = line
            line = word
        else
            line = candidate
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    local lineHeight = math.min(12, 30 / #lines)
    local font = #lines > 2 and math.floor(lineHeight) or "small"
    for i = 1, #lines do
        c.text(lines[i], 222, 394 + (i - 1) * lineHeight, 342, lineHeight + 1, font, MUTED)
    end
end

local function drawResult(c, f, outcome, revealAge, variant)
    local color = outcome and outcome.color or GOLD
    c.box(157, 350, 66, 68, BLACK, 0.89)
    c.box(157, 350, 66, 1, color, 0.74)
    c.box(157, 417, 66, 1, color, 0.46)
    if outcome == outcomes[0] then
        centered(c, "slotCracked", 190, 384, 53, 53, 0.82)
    elseif f.item then
        centered(c, "item", 190, 384, 56, 56, 1)
    else
        centered(c, outcome and outcome.symbol or "slotCrown", 190, 384, 52, 52, 0.9)
    end

    if outcome then
        c.text(f.title or outcome.title, 222, 349, 342, 29, "large", color)
        local grade = f.grade or f.oldGrade
        if outcome == outcomes[0] and f.oldGrade then
            grade = "Was " .. f.oldGrade
        elseif f.grade and f.oldGrade and f.grade ~= f.oldGrade then
            grade = f.oldGrade .. " → " .. f.grade
        end
        if outcome == outcomes[4] and revealAge < 1450 then
            local mark = variant == 2 and "slotGem" or "slotCoin"
            centered(c, mark, 549, 365, 40, 34, 0.9)
        end
        if grade then c.text(grade, 222, 378, 342, 15, "small", CREAM) end
    else
        c.text("Regrading…", 222, 349, 342, 29, "large", CREAM)
        if f.oldGrade then c.text(f.oldGrade, 222, 378, 342, 15, "small", CREAM) end
    end
    drawItemName(c, f.itemName or "Regrade item")
end

local function landingSymbols(code, seed)
    local match = paylinePairs[seed % #paylinePairs + 1]
    if code == 4 then return match, match, match end
    if code == 3 then return match, match, outcomes[3].symbol end
    local offset = math.floor(seed / #paylinePairs)
    local second = otherSymbols[offset % #otherSymbols + 1]
    local third = code == 2 and otherSymbols[(offset + 1) % #otherSymbols + 1] or outcomes[code].symbol
    return match, second, third
end

local function draw(c, f)
    local wait = f.waitMs or 0
    local duration = f.duration or 4250
    local elapsed = f.elapsed or wait + (f.t or 0) * duration
    local confirmed = f.phase == "reveal" and outcomes[f.code] or nil
    local outcome = confirmed and f.t >= releaseAt and confirmed or nil
    local revealAge = outcome and math.max(0, elapsed - wait - releaseAt * duration) or nil
    local variant = f.celebrationVariant or 1
    local seed = f.seed or 0
    local blastAge = outcome == outcomes[0] and revealAge - fuseMs or nil
    local left, middle, right
    if confirmed then left, middle, right = landingSymbols(f.code, seed) end
    if blastAge and blastAge >= 0 then right = false end
    local payouts = {left, middle, right}

    c.box(0, 0, 720, 460, {0.025, 0.014, 0.013})
    c.spritePart("slotPlate", 0, 0, 720, 460, 0, 0, 1, 1, 1)
    c.text("Royal Slots", 125, 59, 450, 47, "title", CREAM)
    for i = 1, 3 do
        drawReel(c, f, i, elapsed, wait, duration, payouts[i], outcome, revealAge)
    end
    drawBulbs(c, elapsed, outcome, revealAge, variant)
    local lever = math.floor(leverPose(elapsed) * 11 + 0.5)
    c.sprite("slotLever" .. lever, 590, 150, 120, 162, 1)
    local pull = lever / 11
    if lever > 0 and elapsed < 685 then
        -- Follow the gloss on the moving knob instead of flashing the fixed socket.
        local gripX = 646 + 27 * pull + 18 * math.sin(math.pi * pull)
        local gripY = 165 + 110 * pull
        sparkle(c, gripX, gripY, 14 + 6 * pull, 0.26 + 0.43 * pull, CREAM)
    end

    if blastAge then
        if blastAge < 0 then
            drawResult(c, f)
            local charge = 1 + blastAge / fuseMs
            sparkle(c, 524, 207, 13 + charge * 16, 0.44 + charge * 0.55, CREAM)
            return
        end
        Blast.draw(c, blastAge, seed)
        if blastAge >= blastClearMs then drawResult(c, f, outcome, revealAge, variant) end
        return
    elseif outcome == outcomes[4] then
        drawJackpot(c, elapsed, revealAge, variant, seed)
    elseif outcome then
        drawResultEffect(c, outcome, revealAge)
    end
    drawResult(c, f, outcome, revealAge, variant)
end

return {slots = {label = "Royal Slots", duration = 4250, draw = draw}}
