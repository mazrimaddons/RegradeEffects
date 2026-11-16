local Picker = {}

local PREFIX = "mazrim_regrade_picker_"
local LAUNCHER_WIDTH, LAUNCHER_HEIGHT = 128, 30
local LAUNCHER_LABEL = "Regrade Effects"
local EDGE, GAP = 5, 5
local PANEL_WIDTH, HEADER, ROW, INSET = 342, 34, 28, 8
local TEST_WIDTH, TEST_GAP = 36, 4
local ARMORY_WIDTH, GUN_ROW = 370, 35
local WEAPONS_TITLE = "Basic CS Skins weapons"
local PANEL = {0.10, 0.075, 0.058}
local BUTTON = {0.25, 0.175, 0.112}
local SELECTED = {0.43, 0.271, 0.128}
local TEXT = {0.97, 0.91, 0.83}
local GOLD = {1.00, 0.79, 0.48}
local LAUNCHER_EDGE = {0.72, 0.52, 0.33}
local LAUNCHER_FACE = {0.36, 0.23, 0.13}
local DISABLED = {0.16, 0.116, 0.087}
local MUTED = {0.70, 0.62, 0.54}

local function call(object, method, ...)
    local ok, first, second = pcall(function(...) return object[method](object, ...) end, ...)
    return ok and first ~= false, first, second
end

local function finite(value)
    return type(value) == "number" and math.abs(value) < 32768
end

local function clamp(value, low, high)
    return math.min(math.max(value, low), high)
end

local function requireSuccess(ok)
    if not ok then error("Regrade picker widget setup failed") end
end

local function paint(widget, color)
    return call(widget, "SetColor", color[1], color[2], color[3], 1)
end

local function fill(widget, color)
    local ok, image = call(widget, "CreateColorDrawable", color[1], color[2], color[3], 1, "background")
    requireSuccess(ok and image and call(image, "AddAnchor", "TOPLEFT", widget, 0, 0)
        and call(image, "AddAnchor", "BOTTOMRIGHT", widget, 0, 0) and call(image, "Show", true))
    return image
end

local function nativePosition(api, window)
    local _, visible = call(window, "IsVisible")
    if visible ~= true then return end
    local _, x, y = call(window, "GetOffset")
    local _, width, height = call(window, "GetExtent")
    local _, scale = call(api.Interface, "GetUIScale")
    scale = finite(scale) and scale > 0 and scale or 1
    if not finite(x) or not finite(y) then
        _, x, y = call(window, "GetEffectiveOffset")
        if finite(x) and finite(y) then x, y = x / scale, y / scale end
    end
    if not finite(width) or width <= 0 then _, width = call(window, "GetWidth") end
    if not finite(height) or height <= 0 then _, height = call(window, "GetHeight") end
    if not finite(width) or width <= 0 or not finite(height) or height <= 0 then
        local _, effectiveWidth, effectiveHeight = call(window, "GetEffectiveExtent")
        if not finite(width) or width <= 0 then
            width = finite(effectiveWidth) and effectiveWidth / scale or nil
        end
        if not finite(height) or height <= 0 then
            height = finite(effectiveHeight) and effectiveHeight / scale or nil
        end
    end
    if finite(x) and finite(y) and finite(width) and width > 0 then
        return x, y, width, finite(height) and height > 0 and height or nil
    end
end

local function launcherPosition(x, y, width, height, screenW, screenH)
    local left, right = math.floor(x + .5), math.floor(x + width + .5)
    local top = math.floor(y + .5)
    local headerY = clamp(top + 7, EDGE, screenH - LAUNCHER_HEIGHT - EDGE)
    if right + GAP + LAUNCHER_WIDTH <= screenW - EDGE then
        return right + GAP, headerY, "right"
    end
    if left - GAP - LAUNCHER_WIDTH >= EDGE then
        return left - GAP - LAUNCHER_WIDTH, headerY, "left"
    end
    local alignedRight = clamp(right - GAP - LAUNCHER_WIDTH, EDGE, screenW - LAUNCHER_WIDTH - EDGE)
    if top - GAP - LAUNCHER_HEIGHT >= EDGE then
        return alignedRight, top - GAP - LAUNCHER_HEIGHT, "above"
    end
    local below = height and math.ceil(y + height) + GAP
    if below and below + LAUNCHER_HEIGHT <= screenH - EDGE then
        return alignedRight, below, "below"
    end
    -- In a tight viewport, use the left end of the title bar and leave the native close control free.
    return clamp(left + GAP, EDGE, screenW - LAUNCHER_WIDTH - EDGE), headerY, "header"
end

function Picker.new(api, choices, onChoose, controls)
    local picker, anchorWidgets, panelWidgets = {}, {}, {}
    controls = controls or {}
    local speedChoices, weaponChoices = controls.speeds or {}, controls.weapons or {}
    local randomChoice = controls.randomChoice
    local canTest = type(controls.onTest) == "function" and type(controls.testOutcomes) == "function"
    local anchor, panel, launcherFace, hint, status, title, close, pages
    local options, speeds, guns, page = {}, {}, {}, "scenes"
    local testScene, testChoices, testButtons
    local windowShown, panelShown, stopped = nil, false, false
    local selected, scrollHint, pace, disabled, notice
    local screenW, screenH, launcherX, launcherY, launcherSide
    local anchorX, anchorY, panelX, panelY, panelWidth, panelHeight
    local scenesStart = HEADER + (randomChoice and ROW or 0)
    local scenesEnd = scenesStart + math.ceil(#choices / 2) * ROW
    local mainEnd = scenesEnd + (#speedChoices > 0 and ROW + 19 or 0)
    local mainHeight = mainEnd + (#weaponChoices > 0 and ROW or 0) + INSET
    local armoryHeight = HEADER + math.ceil(#weaponChoices / 2) * GUN_ROW + INSET
    local paintedPage

    local function own(list, ok, widget)
        requireSuccess(ok and widget ~= nil)
        list[#list + 1] = widget
        return widget
    end

    local function dispose(list)
        for index = #list, 1, -1 do
            local widget = list[index]
            call(widget, "ReleaseHandler", "OnClick")
            if not call(api.Interface, "Free", widget) then return false end
            list[index] = nil
        end
        return true
    end

    local function child(list, parent, kind, id, x, y, width, height)
        local widget = own(list, call(api.Interface, "CreateWidget", kind, PREFIX .. id, parent))
        requireSuccess(call(widget, "AddAnchor", "TOPLEFT", parent, x, y)
            and call(widget, "SetExtent", width, height))
        return widget
    end

    local function label(parent, id, value, x, y, width, height, size)
        local widget = child(panelWidgets, parent, "label", id, x, y, width, height)
        call(widget, "EnablePick", false)
        call(widget, "Clickable", false)
        requireSuccess(call(widget.style, "SetAlign", ALIGN.LEFT) and call(widget.style, "SetFontSize", size)
            and paint(widget.style, TEXT) and call(widget, "SetText", value) and call(widget, "Show", true))
        return widget
    end

    local function button(list, parent, id, value, x, y, width, height, size, action)
        local widget = child(list, parent, "button", id, x, y, width, height)
        local face = fill(widget, BUTTON)
        call(widget.style, "SetAlign", ALIGN.CENTER)
        call(widget.style, "SetFontSize", size)
        call(widget.style, "SetColor", TEXT[1], TEXT[2], TEXT[3], 1)
        requireSuccess(call(widget, "SetText", value) and call(widget, "Show", true)
            and call(widget, "SetHandler", "OnClick", function(_, mouse)
                if not stopped and windowShown and (mouse == nil or mouse == "LeftButton") then action() end
            end))
        return widget, face
    end

    local function closePanel()
        panelShown, notice, page = false, nil, "scenes"
        testScene, testChoices = nil, nil
        if launcherFace then paint(launcherFace, LAUNCHER_FACE) end
        return not panel or call(panel, "Show", false)
    end

    local function position(widget, parent, x, y)
        return call(widget, "RemoveAllAnchors") and call(widget, "AddAnchor", "TOPLEFT", parent, x, y)
    end

    local function mark(option, current, face, ink)
        if option.selected ~= current then
            paint(option.face, face)
            paint(option.widget.style, ink)
            option.selected = current
        end
    end

    local function refreshPanel()
        local armory = page == "armory"
        local testing = page == "tests"
        local noticeShown = type(notice) == "string" and notice ~= ""
        local showHint = page == "scenes" and scrollHint ~= nil
        local width = armory and ARMORY_WIDTH or PANEL_WIDTH
        local baseHeight = armory and armoryHeight or mainHeight
        if testing then baseHeight = HEADER + (1 + math.ceil(#testChoices / 2)) * ROW + INSET end
        local height = baseHeight + (showHint and 18 or 0) + (noticeShown and 18 or 0)
        if screenW < width + 2 * EDGE or screenH < height + 2 * EDGE then return false end
        local left = launcherX
        if launcherSide == "left" or left + width > screenW - EDGE then
            left = launcherX + LAUNCHER_WIDTH - width
        end
        left = clamp(left, EDGE, screenW - width - EDGE)
        local top, above = launcherY + LAUNCHER_HEIGHT + GAP, launcherY - height - GAP
        if above >= EDGE and (launcherSide == "above" or top + height > screenH - EDGE) then top = above end
        top = clamp(top, EDGE, screenH - height - EDGE)
        if panelX ~= left or panelY ~= top then
            if not position(panel, "UIParent", left, top) then return false end
            panelX, panelY = left, top
        end
        if panelWidth ~= width or panelHeight ~= height then
            if not call(panel, "SetExtent", width, height) then return false end
            panelWidth, panelHeight = width, height
        end
        if paintedPage ~= page then
            call(pages.scenes, "Show", page == "scenes")
            if pages.armory then call(pages.armory, "Show", armory) end
            if pages.tests then call(pages.tests, "Show", testing) end
            local heading = armory and WEAPONS_TITLE or testing and ("Test · " .. testScene.label) or "Regrade effects"
            call(title, "SetText", heading)
            position(close, panel, width - INSET - 22, 5)
            paintedPage = page
        end
        if noticeShown then
            position(status, panel, INSET, baseHeight - INSET + (showHint and 18 or 0))
            call(status, "SetExtent", width - 2 * INSET, 18)
            call(status, "SetText", notice)
        end
        if showHint then call(hint, "SetText", scrollHint) end
        call(hint, "Show", showHint)
        call(status, "Show", noticeShown)
        if armory then
            for id, option in pairs(guns) do
                local on = not disabled or disabled[id] ~= true
                if on ~= option.selected then
                    call(option.toggle, "SetText", on and "ON" or "OFF")
                    paint(option.toggle.style, on and GOLD or MUTED)
                    paint(option.name.style, on and TEXT or MUTED)
                    mark(option, on, on and BUTTON or DISABLED, on and TEXT or MUTED)
                end
            end
        elseif testing then
            for i, widget in ipairs(testButtons) do
                local outcome = testChoices[i]
                if outcome then call(widget, "SetText", outcome.label) end
                call(widget, "Show", outcome ~= nil)
            end
        else
            for id, option in pairs(options) do
                local current = id == selected
                mark(option, current, current and SELECTED or BUTTON, current and GOLD or TEXT)
            end
            for id, option in pairs(speeds) do
                local current = id == pace
                mark(option, current, current and SELECTED or BUTTON, current and GOLD or TEXT)
            end
        end
        return true
    end

    local function choosePage(newPage)
        if not panelShown then return end
        local previous = page
        page, notice = newPage, nil
        if not refreshPanel() then
            page, notice = previous, "Screen is too small for these controls."
            refreshPanel()
        end
    end

    local function failure(ok, message, fallback)
        return ok and type(message) == "string" and message or fallback
    end

    local function sceneButton(parent, choice, x, y, width)
        local id = choice.id
        local widget, face = button(panelWidgets, parent, "scene_" .. id, choice.label, x, y, width, ROW - 4, 12,
            function()
                if not panelShown or page ~= "scenes" then return end
                local ok, applied, message = pcall(onChoose, id)
                if ok and applied == true then
                    selected = id
                    closePanel()
                else
                    notice = failure(ok, message, "Could not choose this effect.")
                    refreshPanel()
                end
            end)
        options[id] = {widget = widget, face = face, selected = false}
    end

    local function runTest(outcome)
        if not panelShown or page ~= "tests" then return end
        local ok, shown, message = pcall(controls.onTest, testScene.id, outcome)
        if ok and shown == true then
            closePanel()
        else
            notice = failure(ok, message, "Could not preview this effect.")
            refreshPanel()
        end
    end

    local function buildTests(parent)
        button(panelWidgets, parent, "test_back", "‹ Back", PANEL_WIDTH - 102, 5, 60, 22, 12,
            function() choosePage("scenes") end)
        button(panelWidgets, parent, "test_random", "Random", INSET, HEADER, PANEL_WIDTH - 2 * INSET, ROW - 4, 12,
            function() runTest() end)
        testButtons = {}
        local maxChoices = 0
        for _, scene in ipairs(choices) do maxChoices = math.max(maxChoices, #controls.testOutcomes(scene.id)) end
        local width = (PANEL_WIDTH - 3 * INSET) / 2
        for i = 1, maxChoices do
            local index = i
            local paired = index < maxChoices or maxChoices % 2 == 0
            local x = INSET + ((index - 1) % 2) * (width + INSET)
            local y = HEADER + ROW + math.floor((index - 1) / 2) * ROW
            testButtons[index] = button(panelWidgets, parent, "test_outcome_" .. index, "", x, y,
                paired and width or PANEL_WIDTH - 2 * INSET, ROW - 4, 12, function()
                    if page ~= "tests" or not testChoices[index] then return end
                    runTest(testChoices[index].id)
                end)
        end
    end

    local function buildArmory(parent)
        local columnWidth = (ARMORY_WIDTH - 3 * INSET) / 2
        button(panelWidgets, parent, "back", "‹ Back", ARMORY_WIDTH - 102, 5, 60, 22, 12,
            function() choosePage("scenes") end)
        for index, choice in ipairs(weaponChoices) do
            local id = choice.id
            local key = "weapon_" .. tostring(id)
            local x = INSET + ((index - 1) % 2) * (columnWidth + INSET)
            local y = HEADER + math.floor((index - 1) / 2) * GUN_ROW
            local widget, face = button(panelWidgets, parent, key, "",
                x, y, columnWidth, GUN_ROW - 4, 11, function()
                    if not panelShown or page ~= "armory" then return end
                    local wasDisabled = disabled and disabled[id] == true
                    local ok, applied, message = pcall(controls.onWeapon, id)
                    if ok and applied == true then
                        local updated = {}
                        if disabled then
                            for key, value in pairs(disabled) do updated[key] = value end
                        end
                        if wasDisabled then updated[id] = nil else updated[id] = true end
                        disabled, notice = updated, nil
                    else
                        notice = failure(ok, message, "Could not change this gun.")
                    end
                    refreshPanel()
                end)
            local name = label(widget, key .. "_name", choice.label, 6, 1, columnWidth - 45, 15, 12)
            local finish = label(widget, key .. "_finish", choice.finish or "", 6, 16, columnWidth - 43, 13, 10)
            local toggle = label(widget, key .. "_state", "", columnWidth - 28, 3, 26, 24, 10)
            paint(finish.style, MUTED)
            guns[id] = {widget = widget, face = face, name = name, toggle = toggle}
        end
    end

    local function createPanel()
        paintedPage = nil
        panelX, panelY, panelWidth, panelHeight = nil, nil, nil, nil
        options, speeds, guns = {}, {}, {}
        panel = own(panelWidgets, call(api.Interface, "CreateEmptyWindow", PREFIX .. "panel", "UIParent"))
        requireSuccess(call(panel, "Show", false))
        fill(panel, PANEL)
        title = label(panel, "title", "Regrade effects", INSET, 3, 190, 26, 14)
        close = button(panelWidgets, panel, "close", "×", PANEL_WIDTH - INSET - 22, 5, 22, 22, 15, closePanel)
        local parent = child(panelWidgets, panel, "emptywidget", "scenes", 0, 0, PANEL_WIDTH, mainHeight)
        pages = {scenes = parent}
        call(parent, "EnablePick", false)
        call(parent, "Clickable", false)
        if #weaponChoices > 0 then
            pages.armory = child(panelWidgets, panel, "emptywidget", "armory", 0, 0, ARMORY_WIDTH, armoryHeight)
            call(pages.armory, "EnablePick", false)
            call(pages.armory, "Clickable", false)
            buildArmory(pages.armory)
        end
        if canTest then
            pages.tests = child(panelWidgets, panel, "emptywidget", "tests", 0, 0, PANEL_WIDTH, mainHeight)
            call(pages.tests, "EnablePick", false)
            call(pages.tests, "Clickable", false)
            buildTests(pages.tests)
        end
        local columnWidth = (PANEL_WIDTH - 3 * INSET) / 2
        local nameWidth = canTest and columnWidth - TEST_WIDTH - TEST_GAP or columnWidth
        if randomChoice then
            sceneButton(parent, randomChoice, INSET, HEADER, PANEL_WIDTH - INSET * 2)
        end
        for index, choice in ipairs(choices) do
            local id = choice.id
            local x = INSET + ((index - 1) % 2) * (columnWidth + INSET)
            local y = scenesStart + math.floor((index - 1) / 2) * ROW
            sceneButton(parent, choice, x, y, nameWidth)
            if canTest then
                local test = button(panelWidgets, parent, "test_" .. id, "Test",
                    x + nameWidth + TEST_GAP, y, TEST_WIDTH, ROW - 4, 11, function()
                        if not panelShown or page ~= "scenes" then return end
                        testScene, testChoices = choice, controls.testOutcomes(id)
                        choosePage("tests")
                    end)
                paint(test.style, GOLD)
            end
        end
        if #speedChoices > 0 then
            label(parent, "speed", "Speed", INSET, scenesEnd, 140, 18, 12)
            local width = (PANEL_WIDTH - INSET * (#speedChoices + 1)) / #speedChoices
            for index, choice in ipairs(speedChoices) do
                local id = choice.id
                local x = INSET + (index - 1) * (width + INSET)
                local widget, face = button(panelWidgets, parent, "pace_" .. id, choice.label or choice.title,
                    x, scenesEnd + 18, width, ROW - 4, 11, function()
                        if not panelShown or page ~= "scenes" then return end
                        local ok, applied, message = pcall(controls.onSpeed, id)
                        if ok and applied == true then pace, notice = id, nil
                        else notice = failure(ok, message, "Could not change the speed.") end
                        refreshPanel()
                    end)
                speeds[id] = {widget = widget, face = face, selected = false}
            end
        end
        if #weaponChoices > 0 then
            button(panelWidgets, parent, "guns", WEAPONS_TITLE .. "  ›", INSET, mainEnd,
                PANEL_WIDTH - 2 * INSET, ROW - 3, 12, function() choosePage("armory") end)
        end
        hint = label(panel, "hint", "", INSET, mainHeight - INSET, PANEL_WIDTH - 2 * INSET, 18, 11)
        status = label(panel, "status", "", INSET, mainHeight - INSET, PANEL_WIDTH - 2 * INSET, 18, 11)
        paint(hint.style, GOLD)
        paint(status.style, GOLD)
    end

    local function togglePanel()
        if panelShown then closePanel(); return end
        if not panel then
            if not dispose(panelWidgets) then return end
            if not pcall(createPanel) then
                if panel then call(panel, "Show", false) end
                panel = nil
                dispose(panelWidgets)
                return
            end
        end
        if refreshPanel() and call(panel, "Show", true) then
            panelShown = true
            paint(launcherFace, SELECTED)
            call(panel, "Raise")
        end
    end

    local function createAnchor()
        anchor = own(anchorWidgets, call(api.Interface, "CreateEmptyWindow", PREFIX .. "anchor", "UIParent"))
        requireSuccess(call(anchor, "Show", false) and call(anchor, "SetExtent", LAUNCHER_WIDTH, LAUNCHER_HEIGHT))
        fill(anchor, LAUNCHER_EDGE)
        local launch, face = button(anchorWidgets, anchor, "plus", LAUNCHER_LABEL, 1, 1,
            LAUNCHER_WIDTH - 2, LAUNCHER_HEIGHT - 2, 14, togglePanel)
        launcherFace = face
        paint(launcherFace, LAUNCHER_FACE)
        paint(launch.style, GOLD)
    end

    function picker.hide()
        if not windowShown then return true end
        windowShown = nil
        local closed = closePanel()
        return (not anchor or call(anchor, "Show", false)) and closed
    end

    function picker.raise()
        if not windowShown then return true end
        local ok = call(anchor, "Raise")
        if panelShown then return call(panel, "Raise") and ok end
        return ok
    end

    function picker.sync(window, scene, scrollMessage, speed, disabledWeapons)
        if stopped then return false end
        if not window then return picker.hide() end
        local x, y, width, height = nativePosition(api, window)
        local _, w = call(api.Interface, "GetScreenWidth")
        local _, h = call(api.Interface, "GetScreenHeight")
        if not x or not finite(w) or not finite(h)
            or w < LAUNCHER_WIDTH + 2 * EDGE or h < LAUNCHER_HEIGHT + 2 * EDGE then
            return picker.hide()
        end
        if x + width <= 0 or x >= w or y >= h or (height and y + height <= 0) then return picker.hide() end
        selected, scrollHint, pace, disabled = scene, scrollMessage, speed, disabledWeapons
        screenW, screenH = w, h
        launcherX, launcherY, launcherSide = launcherPosition(x, y, width, height, w, h)
        if not anchor then
            if not dispose(anchorWidgets) then return false end
            if not pcall(createAnchor) then
                if anchor then call(anchor, "Show", false) end
                anchor, launcherFace = nil, nil
                dispose(anchorWidgets)
                return false
            end
        end
        if launcherX ~= anchorX or launcherY ~= anchorY then
            if not call(anchor, "RemoveAllAnchors") or not call(anchor, "AddAnchor", "TOPLEFT", "UIParent", launcherX, launcherY) then
                picker.hide()
                return false
            end
            anchorX, anchorY = launcherX, launcherY
        end
        if windowShown ~= window then
            closePanel()
            if not call(anchor, "Show", true) then return false end
            windowShown = window
            picker.raise()
        end
        if panelShown and not refreshPanel() then return closePanel() end
        return true
    end

    function picker.stop()
        stopped = true
        picker.hide()
        local panelFreed = dispose(panelWidgets)
        local anchorFreed = dispose(anchorWidgets)
        return panelFreed and anchorFreed
    end

    return picker
end

return Picker
