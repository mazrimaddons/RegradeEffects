local Store = {}
local VERSION = 1
local MAX_REVISION = 1000000000
local FILE_PREFIX = "mazrim_regrade_effects/.data/odds_"
local PREVIOUS_PREFIX = "mazrim_regrade_effects/odds_"
local LEGACY_PREFIX = "mazrim_regrade_effects/workshop_"

local function call(object, method, ...)
    local ok, value = pcall(function(...)
        return object[method](object, ...)
    end, ...)
    return ok and value ~= false, value
end

function Store.owner(api)
    local _, name = call(api.Unit, "UnitName", "player")
    if type(name) ~= "string" or #name < 1 or #name > 64 or name:find("[%z\1-\32\127|]") then
        local _, id = call(api.Unit, "GetUnitId", "player")
        if id ~= nil and id ~= false and id ~= 0 then
            _, name = call(api.Unit, "GetUnitNameById", id)
        end
    end
    if type(name) == "string" and #name >= 1 and #name <= 64 and not name:find("[%z\1-\32\127|]") then
        return name:lower()
    end
end

local function valid(record, owner)
    return type(record) == "table" and record.version == VERSION and record.owner == owner
        and type(record.revision) == "number" and record.revision >= 1
        and record.revision <= MAX_REVISION and record.revision % 1 == 0
        and type(record.data) == "table"
        and type(record.data.planner) == "table" and type(record.data.studio) == "table"
end

local function readPair(file, prefix, encoded, owner)
    local paths = {prefix .. encoded .. "_a.lua", prefix .. encoded .. "_b.lua"}
    local pair = {paths = paths, readable = true}
    for index, path in ipairs(paths) do
        local ok, record = call(file, "Read", path)
        pair.readable = pair.readable and ok
        if type(record) == "table" and type(record.version) == "number" and record.version > VERSION then
            pair.newer = true
        elseif valid(record, owner) and (not pair.latest or record.revision > pair.latest.revision) then
            pair.latest, pair.slot = record, index
        end
        if index == 1 then pair.firstOccupied = record ~= nil end
    end
    return pair
end

local function settingsOnly(data)
    local planner, studio = data.planner, data.studio
    return {
        planner = {chance = planner.chance, attempts = planner.attempts, confidence = planner.confidence},
        studio = {pace = studio.pace, scene = studio.scene, disabledWeapons = studio.disabledWeapons},
    }
end

local function sameWeapons(left, right)
    left = type(left) == "table" and left or {}
    right = type(right) == "table" and right or {}
    for id, disabled in pairs(left) do if right[id] ~= disabled then return false end end
    for id, disabled in pairs(right) do if left[id] ~= disabled then return false end end
    return true
end

local function sameSettings(left, right)
    return left.planner.chance == right.planner.chance
        and left.planner.attempts == right.planner.attempts
        and left.planner.confidence == right.planner.confidence
        and left.studio.pace == right.studio.pace
        and left.studio.scene == right.studio.scene
        and sameWeapons(left.studio.disabledWeapons, right.studio.disabledWeapons)
end

function Store.open(api, owner)
    local service = { data = {} }
    if not owner then
        service.status = "Waiting for a character. Changes here are temporary."
        service.save = function() return false end
        return service
    end
    local encoded = owner:gsub(".", function(char) return string.format("%02x", char:byte()) end)
    local primary = readPair(api.File, FILE_PREFIX, encoded, owner)
    local latest, newer, readable = primary.latest, primary.newer, primary.readable
    if not latest and not newer then
        for _, prefix in ipairs({PREVIOUS_PREFIX, LEGACY_PREFIX}) do
            local older = readPair(api.File, prefix, encoded, owner)
            latest, newer = older.latest, older.newer
            readable = readable and older.readable
            if latest or newer then break end
        end
    end
    local revision = latest and latest.revision or 0
    local slot = primary.slot or (primary.firstOccupied and 1 or 2)
    if latest then service.data = settingsOnly(latest.data) end
    if newer then
        service.status = "Saved by a newer Odds Planner. Changes here are temporary."
    elseif not readable then
        service.status = "Could not read planner saves. Changes here are temporary."
    end

    local function commit(data, nextRevision)
        local destination = slot == 1 and 2 or 1
        local path = primary.paths[destination]
        local record = {version = VERSION, owner = owner, revision = nextRevision, data = data}
        local wrote = call(api.File, "Write", path, record)
        local read, stored = call(api.File, "Read", path)
        if not wrote or not read or not valid(stored, owner) or stored.revision ~= nextRevision
            or not sameSettings(stored.data, data) then
            service.status = "Could not save. Use Retry save to try this session's changes again."
            service.retryable = true
            return false
        end
        revision, slot, service.data, service.status = nextRevision, destination, data, nil
        service.retryable = false
        return true
    end

    function service.save(data)
        if newer or not readable or revision >= MAX_REVISION then return false end
        return commit(data, revision + 1)
    end

    -- A manager update carries .data forward. Copy the selected older record
    -- there on first read, leaving the original files available to older builds.
    if latest and not primary.latest and not newer and readable then
        commit(service.data, revision)
    end
    return service
end

return Store
