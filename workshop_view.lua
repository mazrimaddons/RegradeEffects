local Planning = require("mazrim_regrade_effects/planning")
local Workshop = require("mazrim_regrade_effects/workshop_model")
local View = {}
local PREFIX = "mazrim_regrade_workshop_"
local PACE = {
    { id = "classic", title = "Classic", help = "The original case-opening slowdown." },
    { id = "quick", title = "Quick", help = "A shorter slowdown during regular regrades." },
    { id = "cinematic", title = "Cinematic", help = "A longer slowdown for the full reveal." },
}
local PREVIEW_OUTCOMES = {
    { id = "downgrade", label = "Downgrade" },
    { id = "failure", label = "Fail" },
    { id = "success", label = "Success" },
    { id = "great", label = "Great Success" },
}
local PALETTE = {
    panel = {0.10, 0.075, 0.058}, header = {0.16, 0.11, 0.079}, detail = {0.18, 0.13, 0.096},
    button = {0.25, 0.175, 0.112}, selected = {0.40, 0.24, 0.11}, edge = {0.36, 0.23, 0.14},
    text = {0.97, 0.91, 0.83}, muted = {0.78, 0.70, 0.60}, accent = {1.00, 0.76, 0.43},
    warning = {0.99, 0.71, 0.39},
}

local function call(object, method, ...)
    local ok, value = pcall(function(...) return object[method](object, ...) end, ...)
    return ok and value ~= false, value
end

local function requireSuccess(success)
    if not success then error("Odds Planner widget setup failed") end
    return success
end

local function plain(value)
    if value == nil then return "" end
    return (string.format("%.8f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function percentage(value, originalChance)
    if value == 1 and originalChance and originalChance < 1 then return ">99.9%" end
    return Workshop.percent(value)
end

local function metricNumber(value, precision)
    if value == nil then return "—" end
    if value >= 10000000 then return string.format("%.2g", value) end
    return string.format("%." .. precision .. "f", value)
end

local function shortItemName(value)
    if type(value) ~= "string" or value == "" then return "Selected item" end
    local last = 31
    if #value <= last then return value end
    while last > 1 do
        local char = value:byte(last + 1)
        if not char or char < 128 or char >= 192 then break end
        last = last - 1
    end
    return value:sub(1, last) .. "…"
end

function View.new(api, _presentation, actions)
    local owned, controls, view = {}, {}, {}
    local root, live, visible, moving, notice, boundModel
    local sceneRows=actions.scenes and math.ceil(#actions.scenes/4) or 0
    local width, height = 610, sceneRows>0 and 613+math.max(0,sceneRows-2)*32 or 475
    local content = width - 36
    local _, screenWidth = call(api.Interface, "GetScreenWidth")
    local _, screenHeight = call(api.Interface, "GetScreenHeight")
    screenWidth = Workshop.number(screenWidth, 0, 100000) or (width + 20)
    screenHeight = Workshop.number(screenHeight, 0, 100000) or (height + 20)
    local scale = math.max(0.55, math.min(1, (screenWidth - 16) / width, (screenHeight - 16) / height))
    local pollElapsed = 0

    local function px(value)
        return math.floor(value * scale + 0.5)
    end

    local function color(widget, role)
        local c = PALETTE[role]
        return call(widget, "SetColor", c[1], c[2], c[3], 1)
    end

    local function own(ok, node)
        requireSuccess(ok and node ~= nil)
        owned[#owned + 1] = node
        return node
    end

    local function widget(kind, id, parent, x, y, w, h)
        local node = own(call(api.Interface, "CreateWidget", kind, PREFIX .. id, parent))
        requireSuccess(call(node, "SetExtent", px(w), px(h))
            and call(node, "AddAnchor", "TOPLEFT", parent, px(x), px(y)))
        return node
    end

    local function fill(node, role)
        local ok, box = call(node, "CreateColorDrawable", 0, 0, 0, 1, "background")
        requireSuccess(ok and box ~= nil and color(box, role)
            and call(box, "AddAnchor", "TOPLEFT", node, 0, 0)
            and call(box, "AddAnchor", "BOTTOMRIGHT", node, 0, 0)
            and call(box, "Show", true))
        return box
    end

    local function block(id, parent, x, y, w, h, role)
        local node = widget("emptywidget", id, parent, x, y, w, h)
        call(node, "EnablePick", false)
        call(node, "Clickable", false)
        fill(node, role)
        requireSuccess(call(node, "Show", true))
        return node
    end

    local function text(id, parent, value, x, y, w, h, role, size, align)
        local node = widget("label", id, parent, x, y, w, h)
        call(node, "EnablePick", false)
        call(node, "Clickable", false)
        requireSuccess(call(node.style, "SetAlign", align or ALIGN.LEFT)
            and call(node.style, "SetFontSize", math.max(9, px(size or 13))))
        local function set(value, changedRole)
            return call(node, "SetText", value or "") and color(node.style, changedRole or role or "text")
        end
        requireSuccess(set(value) and call(node, "Show", true))
        return set
    end

    local function run(action)
        if not live or not visible then return end
        local ok, value = pcall(action)
        if not ok then notice = "Could not complete this action." end
        view.refresh()
        return ok and value
    end

    local function button(id, parent, label, x, y, w, h, action)
        local node = widget("button", id, parent, x, y, w, h)
        local surface = fill(node, "button")
        local setCaption = text(id .. "_label", node, label, 3, 0, w - 6, h, "text", 12, ALIGN.CENTER)
        requireSuccess(call(node, "SetText", "") and call(node, "SetHandler", "OnClick", function(_, mouse)
            if mouse == nil or mouse == "LeftButton" then return run(action) end
        end) and call(node, "Show", true))
        return {
            show = function(value) return call(node, "Show", value) end,
            select = function(value)
                return setCaption(label, value and "accent" or "text")
                    and color(surface, value and "selected" or "button")
            end,
        }
    end

    local function edit(id, label, x, w, submit)
        text(id .. "_label", root, label, x, 134, w, 20, "muted", 12)
        local node = widget("x2editbox", id, root, x, 157, w, 28)
        fill(node, "detail")
        requireSuccess(type(node.GetText) == "function" and color(node.style, "text")
            and call(node, "SetText", "") and call(node, "Show", true))
        call(node, "ClearTextOnEnter", false)
        call(node, "SetHandler", "OnEnterPressed", function() return run(submit) end)
        return {
            get = function()
                local _, value = call(node, "GetText")
                return type(value) == "string" and value:sub(1, 60) or ""
            end,
            set = function(value) return call(node, "SetText", value or "") end,
        }
    end

    local function metric(id, label, x, y, w, role)
        local box = block(id .. "_box", root, x, y, w, 56, "detail")
        text(id .. "_label", box, label, 10, 4, w-20, 19, "muted", 12)
        return text(id .. "_value", box, "", 10, 24, w-20, 26, role or "text", 20)
    end

    local function currentQuote()
        local ok, data = pcall(actions.current)
        if ok and type(data) == "table" and Workshop.number(data.chance, 0, 1) then return data end
    end

    local function paintQuote()
        local selected = currentQuote()
        if selected then
            controls.quote.set("Listed success chance  " .. percentage(selected.chance), "accent")
            controls.quote.name(shortItemName(selected.itemName))
        else
            controls.quote.set("Game odds unavailable", "muted")
            controls.quote.name("Slot an item in Regrade to copy its listed odds.")
        end
        controls.copy.select(selected ~= nil)
    end

    local function calculate()
        local chance = Workshop.number(controls.chance.get(), 0, 100)
        local attempts = Workshop.number(controls.attempts.get(), 1, 10000, true)
        local confidence = Workshop.number(controls.confidence.get(), 0, 100)
        if chance == nil or confidence == nil then
            notice = "Enter percentages from 0 to 100."
            return
        end
        if attempts == nil then
            notice = "Use a whole attempt count from 1 to 10,000."
            return
        end
        local model = actions.model()
        model.planner = { chance = chance / 100, attempts = attempts, confidence = confidence / 100 }
        notice = model.save() and "Plan saved." or "Plan updated for this session."
    end

    local function preview(key)
        local started, why = actions.preview(key)
        if not started then notice = why or "Could not start the scene preview." end
    end

    local function paintNumbers(model)
        local plan = model.planner
        if model ~= boundModel then
            boundModel = model
            controls.chance.set(plan.chance and plain(plan.chance * 100) or "")
            controls.attempts.set(tostring(plan.attempts))
            controls.confidence.set(plain(plan.confidence * 100))
        end
        local estimate = Planning.odds(plan.chance, plan.attempts, plan.confidence)
        controls.cumulative(percentage(estimate.cumulative, plan.chance))
        controls.average(metricNumber(estimate.expectedAttempts, 2))
        controls.needed(metricNumber(estimate.attemptsForConfidence, 0))
        local message = "Enter a chance or copy the listed odds from Regrade."
        if estimate.chance ~= nil then
            message = estimate.attemptsForConfidence and
                string.format("%d attempts at %s each", plan.attempts, percentage(plan.chance))
                or "No finite attempt count reaches this target."
        end
        controls.planNote(message)
        for _, row in ipairs(controls.comparisons) do
            row.set(percentage(Planning.odds(plan.chance, row.count).cumulative, plan.chance))
        end
    end

    local function center()
        return call(root, "RemoveAllAnchors") and call(root, "AddAnchor", "CENTER", "UIParent", 0, 0)
    end

    local function finishMove()
        if not moving then return true end
        moving = false
        return call(root, "StopMovingOrSizing")
    end

    function view.refresh()
        if not live or not visible then return true end
        local model = actions.model()
        local storage, retryable
        if type(model.storageStatus) == "function" then storage, retryable = model.storageStatus() end
        controls.retry.show(retryable == true)
        controls.status(storage or notice or "", storage and "warning" or "muted")
        paintQuote()
        paintNumbers(model)
        for i, pace in ipairs(PACE) do
            local selected = model.studio.pace == pace.id
            controls.paceButtons[i].select(selected)
            if selected then controls.paceNote(pace.help) end
        end
        if controls.sceneButtons then
            for i, scene in ipairs(actions.scenes) do controls.sceneButtons[i].select(model.studio.scene==scene.id) end
            if controls.randomScene then controls.randomScene.select(model.studio.scene==actions.randomChoice.id) end
            local voyage = model.studio.scene == "voyage"
            controls.previewGreat.show(not voyage)
            controls.previewDestruction.show(not voyage)
            if controls.previewShipwreck then controls.previewShipwreck.show(voyage) end
            if controls.previewDetour then controls.previewDetour.show(voyage) end
        end
        return true
    end

    function view.show()
        if not live or not root then return false end
        visible = true
        if not view.refresh() or not call(root, "Show", true) then
            visible = false
            return false
        end
        call(root, "Raise")
        return true
    end

    function view.start()
        live = true
        root = own(call(api.Interface, "CreateEmptyWindow", PREFIX .. "window", "UIParent"))
        requireSuccess(call(root, "Show", false) and call(root, "SetExtent", px(width), px(height)) and center())
        fill(root, "panel")
        local titlebar = widget("button", "handle", root, 0, 0, width - 166, 47)
        fill(titlebar, "header")
        requireSuccess(call(titlebar, "SetText", "") and call(titlebar, "Show", true))
        text("title", titlebar, "Odds Planner", 18, 5, width - 200, 36, "text", 22)
        block("header_right", root, width - 166, 0, 166, 47, "header")
        button("center", root, "Center", width - 153, 10, 60, 26, center)
        button("close", root, "Close", width - 85, 10, 67, 26, function()
            finishMove()
            if actions.close then actions.close() end
            if live then visible = false; call(root, "Show", false) end
        end)
        if call(titlebar, "EnableDrag", true) then
            call(titlebar, "RegisterForDrag", "LeftButton")
            call(titlebar, "SetHandler", "OnDragStart", function()
                if live and visible and not moving then moving = call(root, "StartMoving") end
            end)
            call(titlebar, "SetHandler", "OnDragStop", finishMove)
            call(titlebar, "SetHandler", "OnDragEnd", finishMove)
        end

        text("hint", root, "Estimate your odds when each attempt uses the same success chance.",
            18, 52, content, 22, "muted")
        local quote = block("odds_quote", root, 18, 79, content, 43, "detail")
        controls.quote = {
            set = text("odds_quote_text", quote, "", 10, 2, content-152, 20, "accent"),
            name = text("odds_quote_name", quote, "", 10, 21, content-152, 18, "muted", 12),
        }
        controls.copy = button("odds_copy", quote, "Use game odds", content - 132, 7, 122, 28, function()
            local selected = currentQuote()
            if not selected then notice = "Slot a regradeable item to copy its odds."; return end
            controls.chance.set(plain(selected.chance * 100))
            calculate()
        end)
        controls.chance = edit("odds_chance", "Success chance (%)", 18, 144, calculate)
        controls.attempts = edit("odds_attempts", "Attempts", 172, 122, calculate)
        controls.confidence = edit("odds_confidence", "Target confidence (%)", 304, 164, calculate)
        button("odds_calculate", root, "Calculate", 478, 157, 114, 28, calculate)

        local step = 195
        controls.cumulative = metric("odds_cumulative", "At least one success", 18, 199, 184, "accent")
        controls.average = metric("odds_expectation", "Avg. attempts to success", 18 + step, 199, 184)
        controls.needed = metric("odds_needed", "Attempts for target", 18 + 2*step, 199, 184)
        controls.planNote = text("odds_result_note", root, "", 18, 262, content, 21, "muted", 12)
        controls.comparisons = {}
        for i, count in ipairs({1, 5, 10, 25}) do
            controls.comparisons[i] = {count = count, set = metric("odds_compare_" .. i,
                count == 1 and "1 attempt" or (count .. " attempts"), 18+(i-1)*146, 289, 136, "accent")}
        end

        block("pace_rule", root, 18, 360, content, 1, "edge")
        text("pace_title", root, "Reveal speed", 18, 374, 114, 27, "text", 14)
        controls.paceButtons = {}
        for i, pace in ipairs(PACE) do
            local id, title = pace.id, pace.title
            controls.paceButtons[i] = button("pace_" .. id, root, title, 137+(i-1)*118, 374, 110, 28, function()
                local saved = actions.model().setPace(id)
                actions.configure()
                notice = saved and (title .. " speed saved.") or (title .. " speed applied.")
            end)
        end
        controls.paceNote = text("pace_note", root, "", 18, 408, content, 19, "muted", 12)
        if sceneRows > 0 then
            block("scene_rule",root,18,433,content,1,"edge")
            text("scene_title",root,"Reveal scene",18,439,124,25,"text",14)
            local function chooseScene(id,title)
                local saved=actions.model().setScene(id)
                if actions.sceneChanged then actions.sceneChanged() end
                notice=saved and (title.." selected.") or (title.." applied.")
            end
            local random = actions.randomChoice
            if random then
                controls.randomScene=button("scene_"..random.id,root,random.label,149,439,138,24,function()
                    chooseScene(random.id,random.label)
                end)
            end
            controls.previewDestruction=button("preview_destruction",root,"Preview destruction",width-158,439,140,24,function()
                preview("destruction")
            end)
            controls.sceneButtons={}
            local span=math.floor(content/4)
            for i, scene in ipairs(actions.scenes) do
                local id,title=scene.id,scene.label
                local x,y=18+((i-1)%4)*span,467+math.floor((i-1)/4)*32
                controls.sceneButtons[i]=button("scene_"..id,root,title,x,y,span-5,28,function()
                    chooseScene(id,title)
                end)
                if id=="voyage" then
                    controls.previewShipwreck=button("voyage_shipwreck",root,"Preview shipwreck",width-158,439,140,24,function()
                        preview("shipwreck")
                    end)
                    controls.previewDetour=button("voyage_detour",root,"Preview detour",width-295,439,129,24,function()
                        preview("detour")
                    end)
                end
            end
            local previewY = 470 + sceneRows*32
            text("preview_title",root,"Preview outcome",18,previewY,118,28,"text",14)
            for i, outcome in ipairs(PREVIEW_OUTCOMES) do
                local id, label = outcome.id, outcome.label
                local control = button("preview_"..id,root,label,137+(i-1)*115,previewY,110,28,function()
                    preview(id)
                end)
                if id == "great" then controls.previewGreat = control end
            end
        end
        block("footer_rule", root, 18, height-37, content, 1, "edge")
        controls.status = text("status", root, "", 18, height-31, content - 100, 23, "muted", 12)
        controls.retry = button("retry_save", root, "Retry save", width - 115, height-31, 97, 23, function()
            if actions.model().save() then notice = "Settings saved." end
        end)

        requireSuccess(view.show())
        call(root, "SetHandler", "OnUpdate", function(_, elapsed)
            if not live or not visible or type(elapsed) ~= "number" or not (elapsed > 0) then return end
            pollElapsed = pollElapsed + elapsed
            if pollElapsed < 800 then return end
            pollElapsed = 0
            paintQuote()
        end)
        return true
    end

    function view.stop()
        visible, live = false, false
        finishMove()
        if root then call(root, "Show", false) end
        for i = #owned, 1, -1 do
            if not call(api.Interface, "Free", owned[i]) then return false end
            owned[i] = nil
        end
        root = nil
        return true
    end

    return view
end

return View
