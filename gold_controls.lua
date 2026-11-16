local Layout = require("mazrim_regrade_effects/voyage_layout")
local Controls = {}

local GOLD = "Addon/mazrim_regrade_effects/assets/voyage-common-gold.dds"
local WHITE, DISABLED = {1,1,1}, {.67,.65,.61}
local ENGRAVING, CAPTION = {1,.96,.82}, {.14,.10,.043}
local buttons = {
    {field="leftButton",caption="Enchant",phase=0},
    {field="rightButton",caption="Cancel",phase=16},
}

local function call(object, method, ...)
    local ok, first, second = pcall(function(...) return object[method](object,...) end,...)
    return ok and first~=false, first, second
end

local function passive(widget)
    local supported=false
    for _,method in ipairs({"EnablePick","Clickable"}) do
        if type(widget[method])=="function" then
            if not call(widget,method,false) then return false end
            supported=true
        end
    end
    return supported
end

function Controls.cuts(api, window, tab, w, h, enchant, cancel)
    if not Layout.visible(window) or not Layout.visible(tab) then return end
    local cuts = {}
    local overrides = {[0]=enchant,[16]=cancel}
    for _, skin in ipairs(buttons) do
        local button = overrides[skin.phase] or tab[skin.field]
        local bounds = Layout.rect(api,button,w,h,0)
        if bounds then
            bounds.button,bounds.caption,bounds.phase=button,skin.caption,skin.phase
            cuts[#cuts+1]=bounds
        end
    end
    return #cuts>0 and cuts or nil
end

function Controls.paint(cut, now, image, label)
    local x,y=cut.left,cut.top
    local w,h=cut.right-x,cut.bottom-y
    local _,enabled=call(cut.button,"IsEnabled")
    local _,text=call(cut.button,"GetText")
    if type(text)~="string" or not text:find("%S") or #text>80 or text:find("[%c|]") then text=cut.caption end
    -- Uses the original 50 ms glow cycle from Common Effects.
    local index=enabled==false and 64 or (math.floor(now/50)+cut.phase)%64
    local sx,sy=index%9*200+2,math.floor(index/9)*30+2
    local size=math.max(9,math.min(math.floor(h*12/26+.5),math.floor((w-8)/(#text*.62))))
    return image(x,y,w,h,GOLD,sx,sy,196,26,enabled==false and DISABLED or WHITE)~=false
        and label(text,x,y+1,w,h-1,size,ENGRAVING,enabled==false and .28 or .45)~=false
        and label(text,x,y,w,h-1,size,CAPTION)~=false
end

-- The reel uses an opaque child window over the native Regrade window. Keep its
-- pass-through controls on a separate root so that they can sit above the reel.
function Controls.new(api)
    local interface = api.Interface
    local self, slots, owned = {}, {}, {}
    local root, shown, updating, window, tab, lastFrame
    local width,height

    local function place(slot, x, y, w, h)
        if slot.x==x and slot.y==y and slot.w==w and slot.h==h then return true end
        if not call(slot.widget,"RemoveAllAnchors") or not call(slot.widget,"AddAnchor","TOPLEFT",root,x,y)
            or not call(slot.widget,"SetExtent",w,h) then return false end
        slot.x,slot.y,slot.w,slot.h=x,y,w,h
        return true
    end

    local function tint(widget, slot, color, alpha)
        local a=alpha or 1
        if slot.color==color and slot.alpha==a then return true end
        if not call(widget,"SetColor",color[1],color[2],color[3],a) then return false end
        slot.color,slot.alpha=color,a
        return true
    end

    local function show(value)
        if shown==value then return true end
        if not call(root,"Show",value) then return false end
        shown=value
        return true
    end

    function self.hide()
        window,tab,lastFrame=nil,nil,nil
        if not root then return true end
        local released=not updating or call(root,"ReleaseHandler","OnUpdate")
        if released then updating=false end
        return show(false) and released
    end

    function self.stop()
        local stopped=self.hide()
        for i=#owned,1,-1 do
            if not call(interface,"Free",owned[i]) then return false end
            owned[i]=nil
        end
        if root and not call(interface,"Free",root) then return false end
        root,shown,updating,slots,width,height=nil,nil,nil,{},nil,nil
        return stopped
    end

    local function create()
        local ok, widget=call(interface,"CreateEmptyWindow","mazrim_regrade_controls","UIParent")
        if not ok or not widget then return false end
        root=widget
        if not show(false) or not passive(root) or not call(root,"AddAnchor","TOPLEFT","UIParent",0,0) then return false end
        for i=1,2 do
            local made,face=call(root,"CreateImageDrawable",GOLD,"artwork")
            if not made or not face then return false end
            slots[i]={{widget=face}}
            for j=2,3 do
                local created,label=call(interface,"CreateWidget","label","mazrim_regrade_control_"..i.."_"..j,root)
                if not created or not label then return false end
                owned[#owned+1]=label
                if not passive(label) or not call(label.style,"SetAlign",ALIGN.CENTER) then return false end
                slots[i][j]={widget=label}
            end
        end
        return true
    end

    local function draw(cuts, now, w, h)
        if width~=w or height~=h then
            if not call(root,"SetExtent",w,h) then return false end
            width,height=w,h
        end
        for i,group in ipairs(slots) do
            local cut=cuts[i]
            if cut then
                local face, labelIndex=group[1], 1
                local drawn=Controls.paint(cut,now,function(x,y,sw,sh,_,sx,sy,tw,th,color)
                    if face.sx~=sx or face.sy~=sy then
                        if not call(face.widget,"SetCoords",sx,sy,tw,th) then return false end
                        face.sx,face.sy=sx,sy
                    end
                    return place(face,x,y,sw,sh) and tint(face.widget,face,color)
                end,function(text,x,y,sw,sh,size,color,alpha)
                    labelIndex=labelIndex+1
                    local label=group[labelIndex]
                    if label.text~=text and not call(label.widget,"SetText",text) then return false end
                    if label.size~=size and not call(label.widget.style,"SetFontSize",size) then return false end
                    label.text,label.size=text,size
                    return place(label,x,y,sw,sh) and tint(label.widget.style,label,color,alpha)
                end)
                if not drawn then return false end
            end
            for _,slot in ipairs(group) do
                local visible=cut~=nil
                if slot.visible~=visible then
                    if not call(slot.widget,"Show",visible) then return false end
                    slot.visible=visible
                end
            end
        end
        return true
    end

    function self.raise()
        if root and shown then return call(root,"Raise") end
        return true
    end

    function self.sync(currentWindow, currentTab)
        if not Layout.visible(currentWindow) or not Layout.visible(currentTab) then return self.hide() end
        local _,now=call(api.Time,"GetUiMsec")
        local _,w=call(interface,"GetScreenWidth")
        local _,h=call(interface,"GetScreenHeight")
        if type(now)~="number" or type(w)~="number" or type(h)~="number"
            or not (now>=0 and now<math.huge and w>0 and w<32768 and h>0 and h<32768) then return self.hide() end
        local cuts=Controls.cuts(api,currentWindow,currentTab,w,h)
        if not cuts then return self.hide() end
        if not root and not create() then self.stop(); return false end
        if not draw(cuts,now,w,h) then self.hide(); return false end
        window,tab,lastFrame=currentWindow,currentTab,now
        if not updating then
            if not call(root,"SetHandler","OnUpdate",function()
                local _,time=call(api.Time,"GetUiMsec")
                if not Layout.visible(window) or not Layout.visible(tab) then self.hide()
                elseif type(time)=="number" and (time<lastFrame or time-lastFrame>=50) then self.sync(window,tab) end
            end) then self.hide(); return false end
            updating=true
        end
        local wasShown=shown
        return show(true) and (wasShown or self.raise())
    end

    return self
end

return Controls
