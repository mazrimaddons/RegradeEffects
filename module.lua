local Effects = require("mazrim_regrade_effects/effects")
local Cinema = require("mazrim_regrade_effects/cinema")
local Workshop = require("mazrim_regrade_effects/workshop_model")
local Store = require("mazrim_regrade_effects/workshop_store")
local View = require("mazrim_regrade_effects/workshop_view")
local ScenePicker = require("mazrim_regrade_effects/scene_picker")
local Regrade = {}
local RESULT_EVENT, POINTER_EVENT = "GRADE_ENCHANT_RESULT", "MOUSE_DOWN"
local QUOTE_LIFETIME = 12000
local SHIP_QUOTE_LIFETIME = 1500
-- Item types from the AAClassic item catalogue, including the bound scroll.
local SHIP_SCROLL_TYPES = {[35036]=true,[39099]=true}
local SHIP_SCROLL_NAMES = {["ship component regrade scroll"]=true,["bound ship component regrade scroll"]=true}

-- AAC commonui/baselib/variable.lua ENCHANT_RESULT.
local outcomes = {
    [0] = {title = "Item destroyed", succeeded = false},
    [1] = {title = "Regrade downgraded", succeeded = false},
    [2] = {title = "Regrade failed", succeeded = false},
    [3] = {title = "Regrade succeeded", succeeded = true},
    [4] = {title = "Great success", succeeded = true, great = true},
}
local previewCodes = {destruction=0, downgrade=1, failure=2, success=3, great=4, detour=2, shipwreck=2}
local standardTests = {
    {id="downgrade", label="Downgrade"}, {id="failure", label="Fail"},
    {id="success", label="Success"}, {id="great", label="Great Success"},
    {id="destruction", label="Destruction"},
}
local voyageTests = {
    {id="downgrade", label="Downgrade"}, {id="success", label="Success"},
    {id="detour", label="Fail · Detour"}, {id="shipwreck", label="Fail · Shipwreck"},
}
local randomChoice = {id="random", label="Random scene"}
local randomScenes = {}
for _, choice in ipairs(Cinema.choices) do
    if choice.id~="ember" and choice.id~="voyage" then
        randomScenes[#randomScenes+1] = choice.id
    end
end
local PREVIEW_ITEM_TYPE = 29692

local function testOutcomes(scene)
    return scene == "voyage" and voyageTests or standardTests
end

local function call(object, method, ...)
    local ok, value = pcall(function(...)
        return object[method](object, ...)
    end, ...)
    return ok and value ~= false, value
end

local function visible(widget)
    local ok, shown = call(widget, "IsVisible")
    return ok and shown == true
end

local function enchantWindow()
    local ok, root, grade = pcall(function()
        local window = ADDON:GetContent(UIC.ENCHANT_WINDOW)
        if not visible(window) then return end
        local tab = window.tab and window.tab.window and window.tab.window[1]
        if visible(tab) then return window, tab end
    end)
    if ok then return root, grade end
end

local function percentage(text)
    if type(text) ~= "string" or #text > 72 then return nil end
    local raw, suffix = text:match("^%s*(%d+[.,]?%d*)%s*%%%s*(.-)%s*$")
    if not raw or (suffix ~= "" and not suffix:match("^%([^()]*%)$")) then return nil end
    local value = tonumber((raw:gsub(",", ".")))
    if value and value >= 0 and value <= 100 then return value / 100 end
end

local function linkItemType(link)
    if type(link) ~= "string" or #link > 2048 then return nil end
    -- The native item link starts with a two-byte tag and the item type.
    return tonumber(link:match("^..(%d+),"))
end

local function readName(info)
    if type(info) ~= "table" or type(info.name) ~= "string"
        or #info.name < 1 or #info.name > 120 or info.name:find("[%z\1-\31\127|]") then return nil end
    return info.name
end

local function readIcon(info)
    if type(info)~="table" then return nil end
    local function texture(path)
        if type(path)~="string" or #path>256 then return nil end
        path=path:gsub("\\","/")
        if not path:match("^[%w_-][%w_/%-%. ]*%.[%a]+$") or path:find("..",1,true) then return nil end
        local ext=path:sub(-4):lower()
        if ext==".dds" or ext==".tga" then return path end
    end
    local named=texture(info.path) or texture(info.icon) or texture(info.iconPath) or texture(info.itemIcon)
    if named then return named end
    local unique
    for _,value in pairs(info) do
        local path=texture(value)
        if path then
            if unique and unique~=path then return nil end
            unique=path
        end
    end
    return unique
end

local function itemDetails(api, itemType)
    if not itemType then return nil end
    local _, info = call(api.Item, "GetItemInfoByType", itemType)
    return readName(info), readIcon(info)
end

local function previewItem(api)
    local name, icon = itemDetails(api, PREVIEW_ITEM_TYPE)
    return {
        itemType = PREVIEW_ITEM_TYPE,
        itemName = name or "Caernord Zephyr Triangular Rig",
        icon = icon or "game/ui/icon/icon_item_2179.dds",
    }
end

local function slotIcon(slot, itemType)
    local _, info=call(slot,"GetInfo")
    if type(info)=="table" and tonumber(info.itemType)==itemType then return readIcon(info) end
end

local function readItemType(info)
    local value=type(info)=="table" and tonumber(info.itemType)
    if value and value>0 and value<math.huge and value%1==0 then return value end
end

local function knownScroll(scroll)
    return readItemType(scroll) or readName(scroll)
end

local function readScroll(api, tab)
    local _, info=call(api.ItemEnchant,"GetEnchantItemInfo")
    if readItemType(info) then return info end
    local _, slot=call(tab.slotEnchantItem,"GetInfo")
    local itemType=readItemType(slot)
    if itemType then
        return {itemType=itemType,name=readName(info) or readName(slot),icon=readIcon(info) or readIcon(slot)}
    end
    return readName(info) and info or slot
end

local function shipScroll(scroll)
    local itemType=readItemType(scroll)
    if itemType then return SHIP_SCROLL_TYPES[itemType]==true end
    local name=readName(scroll)
    return name and SHIP_SCROLL_NAMES[name:lower():match("^%s*(.-)%s*$")]==true
end

local function sceneFor(selected, scroll)
    if shipScroll(scroll) then return "voyage" end
    return selected=="voyage" and "ember" or selected
end

local function randomIndex(count, time)
    if type(math.random)=="function" then return math.random(count) end
    return math.floor(time or 0)%count+1
end

local function resolveScene(mode, time)
    if mode~="random" then return mode end
    if #randomScenes==0 then return nil end
    return randomScenes[randomIndex(#randomScenes,time)]
end

local function material(api, info, slot)
    local name, icon=readName(info),readIcon(info)
    local itemType=readItemType(info)
    if itemType and (not name or not icon) then
        local fallbackName, fallbackIcon=itemDetails(api,itemType)
        name,icon=name or fallbackName,icon or slotIcon(slot,itemType) or fallbackIcon
    end
    return name,icon
end

local function captureMaterials(api, scene, press, scroll)
    if scene=="trial" or scene=="workbench" then
        local _, charm=call(api.ItemEnchant,"GetSupportItemInfo")
        press.scrollName,press.scroll=material(api,scroll,press.tab.slotEnchantItem)
        press.charmName,press.charm=material(api,charm,press.tab.slotSupportItem)
    end
end

local function quote(api, widgetId, root, grade)
    local ok, value = pcall(function()
        if not root then root,grade=enchantWindow() end
        if not root then return nil end
        local button=grade.leftButton
        if widgetId ~= nil then
            local identified, id = call(button, "GetId")
            if not identified or id ~= widgetId or not visible(button) then return nil end
            local _, enabled = call(button, "IsEnabled")
            if enabled == false then return nil end
        end
        local itemRead, info = call(api.ItemEnchant, "GetTargetItemInfo")
        if not itemRead or type(info) ~= "table" or type(info.itemGrade) ~= "number"
            or type(info.itemType) ~= "number" or info.itemType < 1 then return nil end
        local label = grade.successPossibility and grade.successPossibility.resultLabel
        local chance
        if visible(label) then
            local read, text = call(label, "GetText")
            if read then chance = percentage(text) end
        end
        local name, icon = readName(info), readIcon(info)
        icon=icon or slotIcon(grade.slotTargetItem,info.itemType)
        if not name or not icon then
            local fallbackName, fallbackIcon = itemDetails(api,info.itemType)
            name,icon = name or fallbackName,icon or fallbackIcon
        end
        return {
            window = root, tab = grade, button = button, cancel = grade.rightButton,
            grade = info.itemGrade, itemType = info.itemType,
            chance = chance, itemName = name, icon=icon,
        }
    end)
    if ok then return value end
end

local function clock(api)
    local _, value = call(api.Time, "GetUiMsec")
    if type(value) == "number" and value >= 0 and value < math.huge then return value end
end

function Regrade.definition(api)
    local profiles = {}
    return {
        contract = 2,
        id = "mazrim.regrade_effects",
        label = "Regrade Effects",
        category = "Interface",
        description = "Regrade cinematics, Forge Voyage and the Odds Planner.",
        defaultEnabled = false,
        settings = {
            case_opening = {type = "boolean", label = "Case opening", default = false},
            workshop = {type = "boolean", label = "Open Odds Planner", default = false},
        },
        onStart = function(ctx)
            local caseOpening = false
            local alive, listener, resultRegistered, pointerRegistered = false, nil, false, false
            local reported, view, ownerKey, pending, shipQuote, picker
            local function fault(message)
                if alive and not reported then
                    reported = true
                    ctx.summary(message)
                end
            end
            local cinema = Cinema.new(api,fault)
            local effects = Effects.new(api, cinema.raiseControls, fault)
            local function model()
                local owner = Store.owner(api)
                local key = owner or false
                if not profiles[key] then profiles[key] = Workshop.new(api, owner) end
                if ownerKey ~= key then
                    if ownerKey ~= nil then effects.hide(); cinema.hide() end
                    ownerKey, pending, shipQuote = key, nil, nil
                    effects.configure(profiles[key].studio)
                end
                return profiles[key]
            end
            local function freshPress(time)
                return pending and pending.at and time and time>=pending.at and time-pending.at<QUOTE_LIFETIME
            end
            local function waitingForResult()
                return pending and not pending.detached and freshPress(clock(api))
                    and visible(pending.window) and visible(pending.tab)
            end
            local function freshShipQuote(observed, time, window, tab, itemType, oldGrade)
                return observed and time and time>=observed.at and time-observed.at<SHIP_QUOTE_LIFETIME
                    and observed.window==window and observed.tab==tab
                    and observed.itemType==itemType and observed.grade==oldGrade
            end
            local function currentScroll(tab)
                local scroll=readScroll(api,tab)
                if knownScroll(scroll) and not shipScroll(scroll) then shipQuote=nil end
                return scroll
            end
            local function playPreview(scene, example, pace)
                local code=previewCodes[example or (scene=="voyage" and "success" or "great")]
                if not code then return false,"Choose a preview outcome." end
                if waitingForResult() or not effects.canPreview() or not cinema.canPreview() then
                    return false,"A real regrade reveal is already in progress."
                end
                local window,tab=enchantWindow()
                local selected=window and quote(api,nil,window,tab)
                if selected then
                    captureMaterials(api,scene,selected,readScroll(api,selected.tab))
                else
                    selected=previewItem(api)
                    if selected then selected.window,selected.tab=window,tab end
                end
                local outcome=outcomes[code]
                local sample,press=Cinema.previewSample(scene,selected,{
                    code=code,title=outcome.title,succeeded=outcome.succeeded,great=outcome.great,
                },example)
                if not sample then return false,press end
                local shown,why
                if scene=="ember" then
                    shown,why=effects.preview(sample,press)
                    if shown then cinema.hide() end
                else
                    shown,why=cinema.preview(scene,pace,press,sample)
                    if shown then effects.hide() end
                end
                if shown then picker.hide() end
                return shown,why
            end
            local function syncWindow()
                local window,tab=enchantWindow()
                local showControls = caseOpening or effects.isPreviewing()
                cinema.syncControls(showControls and window or nil,showControls and tab or nil)
                if pending and not freshPress(clock(api)) then pending=nil end
                if pending and (pending.window~=window or pending.tab~=tab) then pending.detached=true end
                if shipQuote and (shipQuote.window~=window or shipQuote.tab~=tab) then shipQuote=nil end
                if not window then
                    picker.hide()
                    cinema.leaveVoyage()
                    return
                end
                if effects.isActive() or not cinema.scenePickerState() or waitingForResult() then
                    picker.hide()
                    return
                end
                local settings=model().studio
                local scroll = caseOpening and currentScroll(tab)
                local effective = caseOpening and sceneFor(settings.scene,scroll)
                if effective=="voyage" then
                    local selected=quote(api,nil,window,tab) or {window=window,tab=tab}
                    if visible(selected.button) then
                        local _, enabled=call(selected.button,"IsEnabled")
                        local time=enabled==true and clock(api)
                        if time then
                            selected.at,selected.shipScroll=time,scroll
                            shipQuote=selected
                        end
                    end
                    cinema.dockVoyage(settings.pace,selected)
                else
                    cinema.leaveVoyage(window,tab)
                end
                local available, aboveVoyage = cinema.scenePickerState()
                if not available then picker.hide(); return end
                local scrollHint
                if effective=="voyage" and settings.scene~="voyage" then
                    scrollHint="Ship components use Forge Voyage."
                elseif caseOpening and settings.scene=="voyage" and effective~="voyage" then
                    scrollHint="Forge Voyage requires a ship-component scroll."
                end
                picker.sync(window,caseOpening and settings.scene or nil,scrollHint,
                    settings.pace,settings.disabledWeapons)
                if aboveVoyage then picker.raise() end
            end
            local function pickerReady()
                return alive and enchantWindow() and not effects.isActive() and cinema.scenePickerState()
                    and not waitingForResult()
            end
            local function chooseScene(id)
                if not pickerReady() then
                    return false,"Choose a scene when the regrade is ready."
                end
                local saved = model().setScene(id)
                local enabled, why = ctx.enableCaseOpening()
                if view then pcall(view.refresh) end
                if not enabled then return false,why end
                if not saved then return false,"Scene applied until reload. Could not save." end
                return true
            end
            local lastTest = {}
            picker = ScenePicker.new(api,Cinema.choices,chooseScene,{
                speeds = Effects.paces,
                weapons = Effects.weaponOptions,
                randomChoice = randomChoice,
                testOutcomes = testOutcomes,
                onTest = function(scene, example)
                    if not pickerReady() then return false,"Wait for the current reveal to finish." end
                    local pace = model().studio.pace
                    if example then return playPreview(scene, example, pace) end
                    local choices = testOutcomes(scene)
                    local previous = lastTest[scene]
                    local count = #choices - (previous and 1 or 0)
                    local index = randomIndex(count,clock(api))
                    if previous and index >= previous then index = index + 1 end
                    local shown, why = playPreview(scene, choices[index].id, pace)
                    if shown then lastTest[scene] = index end
                    return shown, why
                end,
                onSpeed = function(id)
                    if not pickerReady() then return false end
                    local profile = model()
                    local saved = profile.setPace(id)
                    effects.configure(profile.studio)
                    if view then pcall(view.refresh) end
                    return saved,"Speed applied until reload. Could not save."
                end,
                onWeapon = function(id)
                    if not pickerReady() then return false end
                    local profile = model()
                    local saved = profile.toggleWeapon(id)
                    effects.configure(profile.studio)
                    return saved,"Gun setting applied until reload. Could not save."
                end,
            })
            local function cleanup()
                alive = false
                local pickerStopped = picker.stop()
                local plannerStopped = not view or view.stop()
                local animationStopped = effects.stop()
                local cinemaStopped = cinema.stop()
                if not listener then return pickerStopped and animationStopped and plannerStopped and cinemaStopped end
                if pointerRegistered and call(listener, "UnregisterEvent", POINTER_EVENT) then pointerRegistered = false end
                if resultRegistered and call(listener, "UnregisterEvent", RESULT_EVENT) then resultRegistered = false end
                call(listener, "ReleaseHandler", "OnEvent")
                call(listener,"ReleaseHandler","OnUpdate")
                call(listener, "Show", false)
                if not call(api.Interface, "Free", listener) then return false end
                listener, resultRegistered, pointerRegistered = nil, false, false
                return pickerStopped and animationStopped and plannerStopped and cinemaStopped
            end
            if ctx.defer(cleanup) ~= true then return false end
            local created, widget = call(api.Interface, "CreateEmptyWindow", "mazrim_regrade_listener", "UIParent")
            if not created or not widget then
                ctx.summary("Could not create the regrade listener.")
                return false
            end
            listener = widget
            if not call(widget, "EnablePick", false) or not call(widget, "Clickable", false)
                or not call(widget, "SetExtent", 1, 1)
                or not call(widget, "SetHandler", "OnEvent", function(_, event, first, itemLink, oldGrade, newGrade)
                    if not alive or listener ~= widget then return end
                    if event == POINTER_EVENT and caseOpening then
                        if (type(first) ~= "number" and type(first) ~= "string") or first == "" then return end
                        local pressed = quote(api, first)
                        if pressed then
                            pcall(picker.hide)
                            local settings=model().studio
                            local scroll=currentScroll(pressed.tab)
                            pressed.at = clock(api)
                            local route=sceneFor(settings.scene,scroll)
                            if waitingForResult() and pending.window==pressed.window and pending.tab==pressed.tab
                                and pending.itemType==pressed.itemType and pending.grade==pressed.grade
                                and pending.route==route then return end
                            pending = pressed
                            pending.route,pending.pace=route,settings.pace
                            pending.scene=resolveScene(route,pressed.at)
                            captureMaterials(api,pending.scene,pressed,scroll)
                            if pending.scene and pending.scene~="ember" then
                                effects.hide()
                                local rendered, started=pcall(cinema.begin,pending.scene,pending.pace,pressed)
                                if rendered and started then return end
                            end
                            cinema.hide()
                            if route=="random" then return end
                            pending.scene="ember"
                            local ok, displayed = pcall(effects.begin, pressed)
                            if not ok or not displayed then
                                effects.hide()
                                fault("Could not start the regrade reel.")
                            end
                        else
                            cinema.nativePointer()
                        end
                        return
                    end
                    if event ~= RESULT_EVENT then return end
                    local outcome = type(first) == "number" and outcomes[first]
                    if not outcome then return end
                    pcall(picker.hide)
                    local settings = caseOpening and model().studio
                    local itemType = caseOpening and linkItemType(itemLink) or nil
                    local time = clock(api)
                    local pendingFresh = freshPress(time)
                    if first == 0 and not itemType and pendingFresh and (oldGrade==nil or pending.grade==oldGrade) then
                        itemType,oldGrade=pending.itemType,oldGrade or pending.grade
                    end
                    local same = pendingFresh and pending.itemType == itemType and (oldGrade==nil or pending.grade==oldGrade)
                    if same then oldGrade=oldGrade or pending.grade end
                    local name,icon
                    if same then name,icon=pending.itemName,pending.icon end
                    if itemType and (not name or not icon) then
                        local fallbackName,fallbackIcon=itemDetails(api,itemType)
                        name,icon=name or fallbackName,icon or fallbackIcon
                    end
                    local result = {
                        code = first, title = outcome.title, succeeded = outcome.succeeded, great = outcome.great,
                        itemName = name,
                        oldGrade = oldGrade, newGrade = newGrade,
                    }
                    local verifiedChance = same and pending.chance or nil
                    local scene,route
                    if same then scene,route=pending.scene,pending.route end
                    local pace=caseOpening and (same and pending.pace or settings.pace)
                    local press = same and pending or {}
                    local observedShip=shipQuote
                    pending,shipQuote = nil,nil
                    local window,tab
                    if caseOpening then
                        window,tab=enchantWindow()
                        if not same then
                            local scroll
                            if window then
                                local selected=quote(api,nil,window,tab)
                                local loaded=readScroll(api,tab)
                                if first==0 or selected and selected.itemType==itemType
                                    and (selected.grade==oldGrade or selected.grade==newGrade) then
                                    scroll=loaded
                                end
                                if not knownScroll(loaded)
                                    and freshShipQuote(observedShip,time,window,tab,itemType,oldGrade) then
                                    scroll=observedShip.shipScroll
                                end
                            end
                            route=sceneFor(settings.scene,scroll)
                            scene=resolveScene(route,time)
                            if window and scene then
                                press.tab=tab
                                captureMaterials(api,scene,press,scroll)
                            end
                        end
                    end
                    if scene and scene~="ember" then
                        effects.hide()
                        press.itemType,press.grade,press.itemName,press.icon=itemType,oldGrade,name,icon
                        press.window,press.tab,press.chance=window,tab,verifiedChance
                        if scene=="voyage" and tab then press.button,press.cancel=tab.leftButton,tab.rightButton end
                        local rendered,shown=pcall(cinema.finish,scene,pace,result,press)
                        if rendered and shown then return end
                    end
                    cinema.hide()
                    local ok, displayed = pcall(effects.finish, result, caseOpening and route~="random", window,
                        itemType, oldGrade, verifiedChance)
                    if not ok or not displayed then
                        effects.hide()
                        fault("Could not draw the regrade effect.")
                    end
                    if view then pcall(view.refresh) end
                end) then
                ctx.summary("Could not set up the regrade listener.")
                return false
            end
            resultRegistered = call(widget, "RegisterEvent", RESULT_EVENT)
            if not resultRegistered or not call(widget, "Show", true) then
                ctx.summary("This client could not register personal regrade results.")
                return false
            end
            alive = true
            local elapsedSincePoll=150
            local function updateWindow(_,elapsed)
                if not alive or listener~=widget or type(elapsed)~="number" or not (elapsed>0) then return end
                elapsedSincePoll=elapsedSincePoll+elapsed
                if elapsedSincePoll<150 then return end
                elapsedSincePoll=0
                if not pcall(syncWindow) then pcall(picker.hide) end
            end
            if not call(widget,"SetHandler","OnUpdate",updateWindow) then fault("Could not attach regrade window controls.") end
            function ctx.setCaseOpening(enabled)
                if not alive then return false end
                if caseOpening == enabled then return true end
                caseOpening = enabled
                if enabled then
                    if not pointerRegistered then pointerRegistered = call(widget,"RegisterEvent",POINTER_EVENT) end
                    if not pointerRegistered then fault("This client starts the reel when the regrade result arrives.") end
                else
                    pending,shipQuote = nil,nil
                    cinema.syncControls()
                    if pointerRegistered and call(widget,"UnregisterEvent",POINTER_EVENT) then pointerRegistered = false end
                    effects.hide()
                    cinema.hide()
                end
                return true
            end
            function ctx.openPlanner()
                if not alive then return false end
                if view then return view.show() end
                local ok, started = pcall(function()
                    view = View.new(api, nil, {
                        model = model,
                        current = function() return quote(api) end,
                        configure = function() return effects.configure(model().studio) end,
                        sceneChanged = function()
                            pcall(syncWindow)
                        end,
                        scenes = Cinema.choices,
                        randomChoice = randomChoice,
                        preview = function(example)
                            local settings=model().studio
                            local scene=resolveScene(settings.scene,clock(api))
                            if not scene then return false,"No random scenes are available." end
                            return playPreview(scene,example,settings.pace)
                        end,
                    })
                    return view.start()
                end)
                if not ok or not started then
                    if view and view.stop() then view = nil end
                    ctx.summary("Could not open the Odds Planner.")
                    return false
                end
                return true
            end
            model()
            ctx.setCaseOpening(ctx.get("case_opening") == true)
            return true
        end,
    }
end

return Regrade
