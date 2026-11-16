local Effects = require("mazrim_regrade_effects/effects")
local Cinema = require("mazrim_regrade_effects/cinema")
local Store = require("mazrim_regrade_effects/workshop_store")
local Workshop = {}

function Workshop.number(value, low, high, integer)
    if type(value) == "string" then
        value = value:match("^%s*([%d.,]+)%s*$")
        value = value and tonumber((value:gsub(",", ".")))
    end
    if type(value) ~= "number" or not (value >= low and value <= high) or (integer and value % 1 ~= 0) then
        return nil
    end
    return value
end

function Workshop.percent(chance)
    if chance == nil then return "—" end
    if chance > 0 and chance < 0.0005 then return "<0.1%" end
    if chance < 1 and chance >= 0.9995 then return ">99.9%" end
    return string.format("%.1f%%", chance * 100)
end

function Workshop.new(api, owner)
    local store = Store.open(api, owner)
    local plan = store.data.planner or {}
    local model = {
        owner = owner,
        studio = Effects.normalizeSettings(store.data.studio),
        planner = {
            chance = Workshop.number(plan.chance, 0, 1),
            attempts = Workshop.number(plan.attempts, 1, 10000, true) or 5,
            confidence = Workshop.number(plan.confidence, 0, 1) or 0.90,
        },
    }
    local savedScene = store.data.studio and store.data.studio.scene
    if savedScene == "timelines" then savedScene = "mimic" end
    if savedScene == nil then savedScene = "random" end
    model.studio.scene = Cinema.normalize(savedScene)

    function model.save()
        return store.save({planner = model.planner, studio = model.studio})
    end

    function model.storageStatus()
        return store.status, store.retryable
    end

    function model.setPace(id)
        for _, pace in ipairs(Effects.paces) do
            if pace.id == id then
                model.studio.pace = id
                return model.save()
            end
        end
        return false
    end

    function model.setScene(id)
        if id ~= Cinema.normalize(id) then return false end
        model.studio.scene = id
        return model.save()
    end

    function model.toggleWeapon(id)
        local option = Effects.weaponOptions[tonumber(id)]
        if not option or option.id ~= id then return false end
        local disabled = model.studio.disabledWeapons
        disabled[id] = not disabled[id] or nil
        return model.save()
    end

    return model
end

return Workshop
