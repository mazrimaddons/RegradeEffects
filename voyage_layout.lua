local Layout = {}

local function call(object, method, ...)
    local ok, first, second=pcall(function(...) return object[method](object,...) end,...)
    if ok then return first,second end
end

local function finite(value)
    return type(value)=="number" and math.abs(value)<32768
end

local function uiScale(api)
    local factor=call(api.Interface,"GetUIScale")
    return finite(factor) and factor>0 and factor or 1
end

function Layout.visible(widget)
    return call(widget,"IsVisible")==true
end

function Layout.ready(button)
    return Layout.visible(button) and call(button,"IsEnabled")==true
end

function Layout.rect(api, widget, sw, sh, gutter)
    if not Layout.visible(widget) then return end
    local x,y=call(widget,"GetOffset")
    local w,h=call(widget,"GetExtent")
    if not finite(w) then w=call(widget,"GetWidth") end
    if not finite(h) then h=call(widget,"GetHeight") end
    local factor=uiScale(api)
    if not finite(x) or not finite(y) then
        x,y=call(widget,"GetEffectiveOffset")
        if finite(x) and finite(y) then x,y=x/factor,y/factor end
    end
    if not finite(w) or not finite(h) or w<=0 or h<=0 then
        w,h=call(widget,"GetEffectiveExtent")
        if finite(w) and finite(h) then w,h=w/factor,h/factor end
    end
    if not finite(x) or not finite(y) or not finite(w) or not finite(h) or w<=0 or h<=0
        or w>sw or h>sh or x<0 or y<0 or x+w>sw+1 or y+h>sh+1 then return end
    return {
        left=math.max(0,math.floor(x-gutter)), top=math.max(0,math.floor(y-gutter)),
        right=math.min(sw,math.ceil(x+w+gutter)), bottom=math.min(sh,math.ceil(y+h+gutter)),
    }
end

function Layout.alarmRect(api, sw, sh)
    local ok,alarm=pcall(function() return gradeEnchantAlarm end)
    if ok and alarm then
        if not Layout.visible(alarm) then return nil,true end
        local bounds=Layout.rect(api,alarm,sw,sh,5)
        if bounds then return bounds,true end
    end
    -- The native alarm anchors to the top center at y=70 and is outside the enchant window.
    local halfWidth=math.min(255,sw/2)
    return {left=math.floor(sw/2-halfWidth),top=64,right=math.ceil(sw/2+halfWidth),bottom=math.min(sh,390)},false
end

function Layout.clickedAlarm(api, rect)
    local x,y=call(api.Input,"GetMousePos")
    if not finite(x) or not finite(y) then return false end
    local factor=uiScale(api)
    x,y=x/factor,y/factor
    local center=(rect.left+rect.right)/2
    return math.abs(x-center)<=105 and y>=rect.top+(rect.bottom-rect.top)*.61 and y<rect.bottom
end

return Layout
