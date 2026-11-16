local Regrade = require("mazrim_regrade_effects/module")
local Settings = require("mazrim_regrade_effects/standalone_store")

local addon = {
    name = "Mazrim Regrade Effects",
    author = "Mazrim",
    desc = "Regrade cinematics and Odds Planner",
    version = "0.5.13",
}

local PREFIX = "mazrim_regrade_settings_"
local PANEL, BUTTON, ACTIVE = {.10,.075,.058}, {.25,.175,.112}, {.40,.24,.11}
local TEXT, MUTED = {.97,.91,.83}, {.78,.70,.60}
local state
local setSwitch

local function call(object, method, ...)
    local ok, value = pcall(function(...) return object[method](object, ...) end, ...)
    return ok and value ~= false, value
end

local function report(api, message)
    call(api.Log, "Info", "[Regrade Effects] " .. message)
end

local function stopEffects(run)
    run.active = false
    for index = #run.cleanup, 1, -1 do
        local ok, stopped = pcall(run.cleanup[index])
        if not ok or stopped ~= true then return false end
        run.cleanup[index] = nil
    end
    run.context = nil
    return true
end

local function startEffects(run)
    if run.active then return true end
    if not stopEffects(run) then return false end
    local ctx = {
        get = function(key) return run.flags[key] end,
        defer = function(cleanup)
            if type(cleanup) ~= "function" then return false end
            run.cleanup[#run.cleanup + 1] = cleanup
            return true
        end,
        summary = function(message)
            report(run.api, message)
            return true
        end,
        enableCaseOpening = function() return setSwitch(run, "case_opening", true) end,
    }
    run.context = ctx
    local ok, started = pcall(run.definition.onStart, ctx)
    if not ok or started ~= true then
        stopEffects(run)
        return false
    end
    run.active = true
    return true
end

setSwitch = function(run, key, value)
    local previous = run.flags[key]
    local changed = value ~= previous
    if not changed and run.store.data[key] == value then return true end
    run.flags[key] = value
    run.notice = nil
    if changed and key == "enabled" then
        if value and not startEffects(run) then
            run.flags[key] = previous
            run.notice = "Could not start regrade effects."
            return false, run.notice
        end
        if not value and not stopEffects(run) then
            run.notice = "Reload to clear the previous UI."
        end
    elseif changed and run.active then
        local ok, applied = pcall(run.context.setCaseOpening, value)
        if not ok or applied ~= true then
            run.flags[key] = previous
            run.notice = "Could not change case opening."
            return false, run.notice
        end
    end

    local ok, saved = pcall(run.store.save, run.flags)
    if not ok or saved ~= true then
        run.notice = "Could not save. Changes last until reload."
        return false, run.notice
    end
    return true
end

local function disposePanel(run)
    local panel = run.panel
    if not panel then return true end
    panel.visible = false
    if panel.root then call(panel.root, "Show", false) end
    for index = #panel.widgets, 1, -1 do
        local widget = panel.widgets[index]
        call(widget, "ReleaseHandler", "OnClick")
        if not call(run.api.Interface, "Free", widget) then return false end
        panel.widgets[index] = nil
    end
    run.panel = nil
    return true
end

local function requireSuccess(success)
    if not success then error("Regrade settings widget setup failed") end
end

local function makeWidget(run, panel, kind, id, x, y, width, height)
    local parent = panel.root
    local ok, widget
    if kind == "window" then
        ok, widget = call(run.api.Interface, "CreateEmptyWindow", PREFIX .. id, "UIParent")
    else
        ok, widget = call(run.api.Interface, "CreateWidget", kind, PREFIX .. id, parent)
    end
    requireSuccess(ok and widget ~= nil)
    panel.widgets[#panel.widgets + 1] = widget
    local placed
    if parent then placed = call(widget, "AddAnchor", "TOPLEFT", parent, x, y)
    else placed = call(widget, "AddAnchor", "CENTER", "UIParent", 0, 0) end
    requireSuccess(placed and call(widget, "SetExtent", width, height))
    return widget
end

local function fill(widget, color)
    local ok, surface = call(widget, "CreateColorDrawable", color[1], color[2], color[3], 1, "background")
    requireSuccess(ok and surface ~= nil and call(surface, "AddAnchor", "TOPLEFT", widget, 0, 0)
        and call(surface, "AddAnchor", "BOTTOMRIGHT", widget, 0, 0)
        and call(surface, "Show", true))
    return surface
end

local function refreshPanel(run)
    local panel = run.panel
    local message = run.notice or run.store.status or ""
    requireSuccess(call(panel.enabled.node, "SetText", run.flags.enabled and "Regrade effects ON" or "Regrade effects OFF")
        and call(panel.caseOpening.node, "SetText", run.flags.case_opening and "Case opening ON" or "Case opening OFF")
        and call(panel.planner.node, "Enable", run.active)
        and call(panel.status, "SetText", message)
        and call(panel.status, "Show", message ~= "")
        and call(panel.root, "SetExtent", 324, message == "" and 164 or 194))
    local enabledColor = run.flags.enabled and ACTIVE or BUTTON
    local caseColor = run.flags.case_opening and ACTIVE or BUTTON
    call(panel.enabled.surface, "SetColor", enabledColor[1], enabledColor[2], enabledColor[3], 1)
    call(panel.caseOpening.surface, "SetColor", caseColor[1], caseColor[2], caseColor[3], 1)
end

local function createPanel(run, panel)
    panel.root = makeWidget(run, panel, "window", "window", 0, 0, 324, 194)
    requireSuccess(call(panel.root, "Show", false))
    fill(panel.root, PANEL)

    local function label(id, text, x, y, width, height, size, color)
        local node = makeWidget(run, panel, "label", id, x, y, width, height)
        call(node, "EnablePick", false)
        call(node, "Clickable", false)
        call(node.style, "SetAlign", ALIGN.LEFT)
        call(node.style, "SetFontSize", size)
        call(node.style, "SetColor", color[1], color[2], color[3], 1)
        requireSuccess(call(node, "SetText", text) and call(node, "Show", true))
        return node
    end

    local function button(id, text, x, y, width, height, action)
        local node = makeWidget(run, panel, "button", id, x, y, width, height)
        call(node.style, "SetFontSize", 13)
        call(node.style, "SetColor", TEXT[1], TEXT[2], TEXT[3], 1)
        local surface = fill(node, BUTTON)
        requireSuccess(call(node, "SetText", text)
            and call(node, "SetHandler", "OnClick", function(_, mouse)
                if state ~= run or run.panel ~= panel or not panel.visible
                    or (mouse ~= nil and mouse ~= "LeftButton") then return end
                action()
                if panel.visible then refreshPanel(run) end
            end)
            and call(node, "Show", true))
        return {node = node, surface = surface}
    end

    label("title", "Regrade Effects", 12, 6, 216, 27, 17, TEXT)
    button("close", "Close", 244, 8, 68, 25, function()
        panel.visible = false
        call(panel.root, "Show", false)
    end)
    panel.enabled = button("enabled", "", 12, 42, 300, 32, function() setSwitch(run, "enabled", not run.flags.enabled) end)
    panel.caseOpening = button("case_opening", "", 12, 81, 300, 32, function()
        setSwitch(run, "case_opening", not run.flags.case_opening)
    end)
    panel.planner = button("planner", "Open Odds Planner", 12, 120, 300, 32, function()
        if not run.active then return end
        local ok, opened = pcall(run.context.openPlanner)
        if ok and opened == true then
            panel.visible = false
            call(panel.root, "Show", false)
        else
            run.notice = "Could not open the Odds Planner."
        end
    end)
    panel.status = label("status", "", 12, 154, 300, 27, 12, MUTED)
end

function addon.OnLoad()
    if state then return not state.flags.enabled or state.active end
    local ok, api = pcall(require, "api")
    if not ok or type(api) ~= "table" then return false end
    local store = Settings.open(api)
    local run = {
        api = api, store = store, active = false, cleanup = {}, definition = Regrade.definition(api),
        flags = {enabled = store.data.enabled, case_opening = store.data.case_opening},
    }
    state = run
    if not run.flags.enabled or startEffects(run) then return true end
    if not run.context then state = nil end
    report(api, "Could not start regrade effects.")
    return false
end

function addon.OnSettingToggle()
    local run = state
    if not run then return false end
    if run.panel and not run.panel.status and not disposePanel(run) then return false end
    if not run.panel then
        local panel = {widgets = {}}
        run.panel = panel
        local ok = pcall(createPanel, run, panel)
        if not ok then
            disposePanel(run)
            report(run.api, "Could not open Regrade Effects settings.")
            return false
        end
    end
    local ok = pcall(refreshPanel, run)
    if not ok or not call(run.panel.root, "Show", true) then return false end
    run.panel.visible = true
    call(run.panel.root, "Raise")
    return true
end

function addon.OnUnload()
    if not state then return true end
    local stopped = stopEffects(state)
    local disposed = disposePanel(state)
    if not stopped or not disposed then return false end
    state = nil
    return true
end

return addon
