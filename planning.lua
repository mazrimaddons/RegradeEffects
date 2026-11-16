local Planning = {}

local MAX_ROLLS = 1000000000
local MAX_SAFE_INTEGER = 9007199254740991

local function numberIn(value, minimum, maximum)
    if type(value) == "number" and value >= minimum and value <= maximum then return value end
end

local function integerIn(value, minimum, maximum)
    value = numberIn(value, minimum, maximum)
    if value and value % 1 == 0 then return value end
end

local function probability(value)
    return numberIn(value, 0, 1)
end

-- Lua 5.1 has no log1p or expm1. Short series keep small positive odds
-- visible when subtracting a nearly unit probability would round to zero.
local function logMiss(chance)
    if chance < 0.0001 then
        return -chance * (1 + chance * (0.5 + chance * (1 / 3 + chance / 4)))
    end
    return math.log(1 - chance)
end

local function atLeastOne(logFailure, attempts)
    local exponent = logFailure * attempts
    if exponent > -0.0001 then
        return -exponent * (1 + exponent * (0.5 + exponent * (1 / 6 + exponent / 24)))
    end
    return 1 - math.exp(exponent)
end

function Planning.odds(chance, attempts, confidence)
    chance = probability(chance)
    attempts = integerIn(attempts, 0, MAX_ROLLS)
    confidence = probability(confidence)
    local result = {chance = chance, attempts = attempts, confidence = confidence}
    if not chance then return result end

    if chance > 0 then
        local expected = 1 / chance
        if expected < math.huge then result.expectedAttempts = expected end
    end
    if attempts then
        if attempts == 0 or chance == 0 then
            result.cumulative = 0
        elseif chance == 1 then
            result.cumulative = 1
        else
            result.cumulative = atLeastOne(logMiss(chance), attempts)
        end
        result.expectedSuccesses = chance * attempts
    end
    if confidence == 0 then
        result.attemptsForConfidence = 0
    elseif confidence and chance == 1 then
        result.attemptsForConfidence = 1
    elseif confidence and confidence < 1 and chance > 0 then
        local goal = logMiss(confidence)
        local logFailure = logMiss(chance)
        local needed = math.ceil(goal / logFailure)
        if needed <= MAX_SAFE_INTEGER then
            -- At exact boundaries the division may have rounded just above an
            -- integer. Compare in log space and let the adjacent integer win.
            if needed > 1 and (needed - 1) * logFailure <= goal then
                needed = needed - 1
            end
            result.attemptsForConfidence = math.max(1, needed)
        end
    end
    return result
end

return Planning
