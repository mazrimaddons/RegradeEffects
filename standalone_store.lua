local Store = {}

local VERSION = 1
local MAX_REVISION = 1000000000
local paths = {
    "mazrim_regrade_effects/.data/settings_a.lua",
    "mazrim_regrade_effects/.data/settings_b.lua",
}
local HUB_PATH = "mazrim_tools/preferences.lua"
local HUB_MODULE = "mazrim.regrade_effects"

local function fileCall(api, method, ...)
    local ok, result = pcall(function(...)
        return api.File[method](api.File, ...)
    end, ...)
    return ok and result ~= false, result
end

local function validFlags(record)
    return type(record) == "table" and type(record.enabled) == "boolean"
        and type(record.case_opening) == "boolean"
end

local function validSave(record)
    return validFlags(record) and record.version == VERSION and type(record.revision) == "number"
        and record.revision >= 1 and record.revision <= MAX_REVISION and record.revision % 1 == 0
end

local function flags(record)
    return {enabled = record.enabled, case_opening = record.case_opening}
end

local function readSaves(api)
    local latest, slot, newer
    local readable = {}
    for index, path in ipairs(paths) do
        local ok, record = fileCall(api, "Read", path)
        readable[index] = ok
        if ok and type(record) == "table" then
            if type(record.version) == "number" and record.version > VERSION then newer = true end
            if validSave(record) and (not latest or record.revision > latest.revision) then
                latest, slot = record, index
            end
        end
    end
    return latest, slot, readable, newer
end

local function hubFlags(api)
    local ok, legacy = fileCall(api, "Read", HUB_PATH)
    if not ok or type(legacy) ~= "table" or legacy.version ~= 1 or type(legacy.modules) ~= "table" then return end
    local module = legacy.modules[HUB_MODULE]
    if type(module) ~= "table" or type(module.enabled) ~= "boolean" or type(module.values) ~= "table" then return end
    local caseOpening = module.values.case_opening
    if caseOpening == nil then caseOpening = false end  -- the Hub's original default
    if type(caseOpening) ~= "boolean" then return end
    return {enabled = module.enabled, case_opening = caseOpening}
end

local NEWER_NOTICE = "Settings are from a newer version."
local WRITE_NOTICE = "Could not save. Changes last until reload."

function Store.open(api)
    local latest, _, readable, newer = readSaves(api)
    local imported = not latest and not newer and hubFlags(api) or nil
    local service = {data = latest and flags(latest) or imported or {enabled = true, case_opening = true}}
    if newer then
        service.status = NEWER_NOTICE
    elseif not readable[1] and not readable[2] then
        service.status = WRITE_NOTICE
    end

    function service.save(values)
        if not validFlags(values) then return false end
        local previous, slot, available, future = readSaves(api)
        if future then
            service.status = NEWER_NOTICE
            return false
        end
        local destination = (slot == 1 or (slot == nil and not available[1])) and 2 or 1
        local revision = previous and previous.revision or 0
        if not available[destination] or revision == MAX_REVISION then
            service.status = WRITE_NOTICE
            return false
        end

        local saved = flags(values)
        saved.version, saved.revision = VERSION, revision + 1
        local path = paths[destination]
        local wrote = fileCall(api, "Write", path, saved)
        local read, confirmed = fileCall(api, "Read", path)
        if not wrote or not read or not validSave(confirmed) or confirmed.revision ~= saved.revision
            or confirmed.enabled ~= saved.enabled or confirmed.case_opening ~= saved.case_opening then
            service.status = WRITE_NOTICE
            return false
        end

        service.data, service.status = flags(confirmed), nil
        return true
    end

    if imported then service.save(imported) end
    return service
end

return Store
