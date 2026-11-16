local Cinema = {}
local VoyageLayout = require("mazrim_regrade_effects/voyage_layout")
local GoldControls = require("mazrim_regrade_effects/gold_controls")
local Aguru = require("mazrim_regrade_effects/aguru_cameo")
local BASE = "Addon/mazrim_regrade_effects/assets/"
local SHAPES, CREST = BASE.."cinema-primitives.dds", BASE.."case-reel.dds"
local CREATURES = BASE.."vault-mimic.dds"
local MIMIC, MIMIC_CHAMBER = BASE.."mimic-forge.dds", BASE.."mimic-chamber.dds"
local VAULT_SUN, DRAGON = BASE.."vault-sealed-sun.dds", BASE.."mimic-dragon.dds"
local ARCADE = BASE.."arcade-scenes.dds"
local GOLD_GAVEL = BASE.."court-golden-gavel.dds"
local COURT, VAULT_HOARD = BASE.."court-portraits.dds", BASE.."vault-iris-hoard.dds"
local PINBALL_PLINKO = BASE.."pinball-plinko.dds"
local SLOT_CABINET, SLOT_PARTS = BASE.."slot-cabinet.dds", BASE.."slot-parts.dds"
local SLOT_BOMB, COURT_AGURU = BASE.."slots-bomb.dds", BASE.."court-aguru.dds"
local SLOT_BLAST = BASE.."slots-blast.dds"
local WORKBENCH = BASE.."workbench-forge.dds"
local AGURU = BASE.."aguru-cameos-v2.dds"
local VOYAGE = BASE.."forge-voyage.dds"
local VOYAGE_MAP = BASE.."forge-voyage-reefs.dds"
local props = {item={400,144,96,96}, hammer={16,16,96,96}}
local materialKeys = {"scroll","charm"}
local sceneArt = {
    vaultdoor={0,0,384,384}, vaultdrill={384,0,288,160},
    mimicupper={8,8,1024,384,MIMIC}, mimiclower={8,408,1024,384,MIMIC},
    mimiceye={1056,8,384,192,MIMIC}, mimiciris={1456,8,192,192,MIMIC},
    mimicegg={1056,224,544,640,MIMIC},
    mimicchamber={8,8,1440,920,MIMIC_CHAMBER},
    vaultSun={0,0,2048,2048,VAULT_SUN},
    vaultHoard={0,0,512,512,VAULT_HOARD},
    dragonHeadRight={0,0,384,256,DRAGON}, dragonHeadLeft={384,0,384,256,DRAGON},
    dragonRoarRight={768,0,384,256,DRAGON}, dragonRoarLeft={1152,0,384,256,DRAGON},
    dragonClawRight={1536,0,192,128,DRAGON}, dragonClawLeft={1728,0,192,128,DRAGON},
    dragonFlareRight={0,384,384,144,DRAGON}, dragonFlareLeft={384,384,384,144,DRAGON},
}
for i=0,15 do sceneArt["dragonCoil"..i]={i*112,256,112,112,DRAGON} end
local arcadeArt = {
    pinballPlinko={0,0,1440,920,PINBALL_PLINKO}, plinkoBall={1472,32,96,96,PINBALL_PLINKO},
    trialPlate={768,0,720,460},
    gavel={576,512,160,110},
    goldGavelBlock={8,472,384,128,GOLD_GAVEL},
    goldGavelGleam={416,480,128,128,GOLD_GAVEL}, goldGavelBurst={560,480,224,224,GOLD_GAVEL},
    slotPlate={8,8,1440,920,SLOT_CABINET}, slotGlass={1472,8,240,348,SLOT_CABINET},
    slotGleam={1744,8,192,192,SLOT_CABINET},
    slotBomb={8,8,144,112,SLOT_BOMB},
    slotBlastRing={0,0,512,512,SLOT_BLAST}, slotBlastFire={512,0,512,512,SLOT_BLAST},
    slotBlastSmoke={0,512,512,512,SLOT_BLAST}, slotBlastShard={512,512,160,160,SLOT_BLAST},
    -- A separate texture path keeps an older court backdrop cached by the client usable.
    smith={8,8,160,210,COURT}, smithPanic={264,8,160,210,COURT}, judge={520,8,168,200,COURT},
    smithCheer={8,264,160,210,COURT}, judgeCheer={264,264,168,200,COURT},
    smithSmile={520,264,160,210,COURT}, judgeSmile={776,264,168,200,COURT},
}
for i=0,9 do arcadeArt["goldGavel"..i]={8+i%5*400,8+math.floor(i/5)*232,384,224,GOLD_GAVEL} end
for i=0,5 do arcadeArt["aguru"..i]={8+i%4*248,8+math.floor(i/4)*240,224,224,COURT_AGURU} end
for i=0,11 do arcadeArt["slotLever"..i]={8+i%8*248,8+math.floor(i/8)*336,240,324,SLOT_PARTS} end
for i,symbol in ipairs({"Bell","Gem","Coin","Bar","Crown","Seven","Cracked","Arrow","Null"}) do
    arcadeArt["slot"..symbol]={8+(i-1)*160,704,144,112,SLOT_PARTS}
end
local WIDTH, HEIGHT = 720, 460
-- Enchant, Cancel and the result window can split one scene image into several drawables.
local MAX_DRAWABLES, MAX_LABELS = 320, 28
local WAIT_MS, RESULT_HOLD, PREVIEW_EXTRA_MS = 12000, 1000, 2000
local INK, BLACK = {1,1,1}, {.021,.012,.023}
local FONT = {micro=10,small=13,body=17,large=25,title=31,hero=40}
local GRADE = {[0]="Crude","Basic","Grand","Rare","Arcane","Heroic","Unique","Celestial","Divine","Epic","Legendary","Mythic"}
local PREVIEW_GRADE_CHANGE = {[0]=0,[1]=-1,[2]=0,[3]=1,[4]=2}
local NO_SHIP_GREAT = "Ship components have no Great Success outcome."
local SPEED = {quick=.62,classic=1,cinematic=1.32}
local SCENE_CUES={
    vault={.23,"vault"},mimic={.17,"mimic"},
    workbench={.41,"workbench"},pinball={.832,"pinball"},trial={.61,"gavel"},
}
local scenes = {}
for _, file in ipairs({"scenes_vault","scenes_time","scenes_arcade","scenes_slots","scenes_voyage"}) do
    local loaded, module=pcall(require,"mazrim_regrade_effects/"..file)
    if loaded and type(module)=="table" then
        for id, entry in pairs(module) do scenes[id] = entry end
    end
end
Cinema.choices = {{id="ember",label="Basic CS Skins"}}
for _, id in ipairs({"vault","mimic","workbench","pinball","slots","trial","voyage"}) do
    local scene=scenes[id]
    if scene and type(scene.draw)=="function" and type(scene.duration)=="number" then
        Cinema.choices[#Cinema.choices+1] = {id=id,label=scene.label}
    else
        scenes[id]=nil
    end
end

function Cinema.normalize(id)
    return (id=="random" or scenes[id]) and id or "ember"
end

function Cinema.previewSample(id, press, outcome, example)
    local change=type(outcome)=="table" and PREVIEW_GRADE_CHANGE[outcome.code]
    if not change then return false,"That outcome has no preview." end
    local destroyed=outcome.code==0
    if destroyed and id=="voyage" then return false,"Use Preview shipwreck for ship components." end
    if id=="voyage" and outcome.code==4 then return false,NO_SHIP_GREAT end

    local selected={}
    for key,value in pairs(press or {}) do selected[key]=value end
    local minGrade,maxGrade,fallbackGrade=math.max(0,-change),math.min(#GRADE,#GRADE-change),6
    if destroyed then
        minGrade,fallbackGrade=8,8
    elseif id=="voyage" then
        minGrade,maxGrade,fallbackGrade=2,10,2
        if outcome.code==1 or (outcome.code==2 and example=="shipwreck") then
            minGrade=7
        elseif outcome.code==2 and example=="detour" then
            maxGrade=6
        end
    end
    local old=type(selected.grade)=="number" and GRADE[selected.grade] and selected.grade or fallbackGrade
    selected.grade=math.max(minGrade,math.min(maxGrade,old))
    if not press or selected.grade~=press.grade then selected.chance=.42 end
    return {
        code=outcome.code,title=outcome.title,great=outcome.great,succeeded=outcome.succeeded,
        itemName=selected.itemName or "Example regrade",newGrade=not destroyed and selected.grade+change or nil,
    },selected
end

local function call(object, method, ...)
    local ok, first, second = pcall(function(...) return object[method](object, ...) end, ...)
    return ok and first ~= false, first, second
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

local function visible(widget)
    local ok, shown = call(widget,"IsVisible")
    return ok and shown == true
end

local function clock(api)
    local _, time = call(api.Time,"GetUiMsec")
    if type(time)=="number" and time>=0 and time<math.huge then return time end
end

local function round(value) return math.floor(value+.5) end
local function grade(value)
    if type(value)=="number" and value>=0 and value<=255 then return GRADE[value] or "Grade "..value end
end
local function extents(api)
    local _, w = call(api.Interface,"GetScreenWidth")
    local _, h = call(api.Interface,"GetScreenHeight")
    if type(w)=="number" and type(h)=="number" and w>=360 and h>=260 and w<16384 and h<16384 then
        return w,h
    end
end

local function geometry(widget, root, slot, x, y, w, h)
    if slot.parent==root and slot.x==x and slot.y==y and slot.w==w and slot.h==h then return true end
    if not call(widget,"RemoveAllAnchors") or not call(widget,"AddAnchor","TOPLEFT",root,x,y)
        or not call(widget,"SetExtent",w,h) then return false end
    slot.parent,slot.x,slot.y,slot.w,slot.h=root,x,y,w,h
    return true
end

local function tint(widget, slot, color, alpha)
    local r,g,b,a=color[1],color[2],color[3],alpha or color[4] or 1
    if slot.r==r and slot.g==g and slot.b==b and slot.a==a then return true end
    if not call(widget,"SetColor",r,g,b,a) then return false end
    slot.r,slot.g,slot.b,slot.a=r,g,b,a
    return true
end

local function show(slot, value)
    if slot.shown==value then return true end
    if not call(slot.widget,"Show",value) then return false end
    slot.shown=value
    return true
end

function Cinema.new(api, fault)
    local root, background, iconProbe, playing, updating, soundClient, soundTried
    local controls = GoldControls.new(api)
    local controlWindow,controlTab
    local previewVariants = {}
    local plinkoRoutes = {}
    local images, labels, drawCount, labelCount = {}, {}, 0, 0
    local scale, scaleX, scaleY, dx, dy, good, frame, apertures, captions
    local self, canvas = {}, {}
    local rootLayout={}

    local function nextPlinkoRoute(code,seed)
        local cycle=plinkoRoutes[code]
        if not cycle then
            local steps={1,3,7,9}
            cycle={index=seed%10,step=steps[math.floor(seed/10)%#steps+1]}
            plinkoRoutes[code]=cycle
        end
        local index=cycle.index+1
        cycle.index=(cycle.index+cycle.step)%10
        return index
    end

    local function iconSize(path)
        if not path then return end
        if not iconProbe then
            local made, widget=call(root,"CreateImageDrawable",path,"artwork")
            if not made or not widget or not call(widget,"Show",false) then return end
            iconProbe=widget
        elseif not call(iconProbe,"SetTexture",path) then
            return
        end
        local ok,w,h=call(iconProbe,"GetTextureSize")
        if ok and type(w)=="number" and type(h)=="number" and w>=16 and h>=16 and w<=512 and h<=512 then
            return {w,h}
        end
    end

    local function source(key)
        if key=="item" or key=="scroll" or key=="charm" then
            local path=frame[key]
            local size=frame.iconSizes[key]
            if size==nil then
                size=iconSize(path) or false
                frame.iconSizes[key]=size
            end
            if size then return path,0,0,size[1],size[2] end
        end
        local art=sceneArt[key]
        if art then return art[5] or CREATURES,art[1],art[2],art[3],art[4] end
        local arcade=arcadeArt[key]
        if arcade then return arcade[5] or ARCADE,arcade[1],arcade[2],arcade[3],arcade[4] end
        local bench=scenes.workbench and scenes.workbench.art and scenes.workbench.art[key]
        if bench then return bench[5] and BASE..bench[5] or WORKBENCH,bench[1],bench[2],bench[3],bench[4] end
        local cameo=Aguru.art[key]
        if cameo then return AGURU,cameo[1],cameo[2],cameo[3],cameo[4] end
        local voyage=scenes.voyage and scenes.voyage.art and scenes.voyage.art[key]
        if voyage then return VOYAGE,voyage[1],voyage[2],voyage[3],voyage[4] end
        local voyageMap=scenes.voyage and scenes.voyage.mapArt and scenes.voyage.mapArt[key]
        if voyageMap then return VOYAGE_MAP,voyageMap[1],voyageMap[2],voyageMap[3],voyageMap[4] end
        local shape=props[key]
        if shape then return SHAPES,shape[1],shape[2],shape[3],shape[4] end
        if key=="crest" then return CREST,128,0,128,128 end
        if key=="glow" then return SHAPES,384,0,128,128 end
        if key=="diamond" then return SHAPES,0,128,128,128 end
    end

    local function paintImage(x,y,w,h,texture,sx,sy,sw,sh,color,alpha)
        if w<=0 or h<=0 or (alpha and alpha<=0) then return end
        if drawCount>=MAX_DRAWABLES then good=false; return end
        drawCount=drawCount+1
        local slot=images[drawCount]
        if not slot then
            local ok, widget=call(root,"CreateImageDrawable",texture,"artwork")
            if not ok or not widget then good=false; return end
            slot={widget=widget,texture=texture}
            images[drawCount]=slot
        end
        if slot.texture~=texture then
            if not call(slot.widget,"SetTexture",texture) then good=false; return end
            slot.texture,slot.sx=texture,nil
        end
        if slot.sx~=sx or slot.sy~=sy or slot.sw~=sw or slot.sh~=sh then
            if not call(slot.widget,"SetCoords",sx,sy,sw,sh) then good=false; return end
            slot.sx,slot.sy,slot.sw,slot.sh=sx,sy,sw,sh
        end
        if not geometry(slot.widget,root,slot,x,y,w,h)
            or not tint(slot.widget,slot,color or INK,alpha) or not show(slot,true) then good=false end
    end

    local function intersects(hole,left,top,right,bottom)
        return left<hole.right and right>hole.left and top<hole.bottom and bottom>hole.top
    end

    local function paintOutside(art,index,left,top,right,bottom)
        if right<=left or bottom<=top then return end
        local cut=apertures[index]
        while cut and not intersects(cut,left,top,right,bottom) do
            index=index+1
            cut=apertures[index]
        end
        if cut then
            local middleTop,middleBottom=math.max(top,cut.top),math.min(bottom,cut.bottom)
            paintOutside(art,index+1,left,top,right,middleTop)
            paintOutside(art,index+1,left,middleBottom,right,bottom)
            paintOutside(art,index+1,left,middleTop,math.min(right,cut.left),middleBottom)
            paintOutside(art,index+1,math.max(left,cut.right),middleTop,right,middleBottom)
            return
        end
        local sx=art.sx+math.min(art.sw-1,math.floor((left-art.x)*art.sw/art.w))
        local sy=art.sy+math.min(art.sh-1,math.floor((top-art.y)*art.sh/art.h))
        local sw=art.sx+math.ceil((right-art.x)*art.sw/art.w)-sx
        local sh=art.sy+math.ceil((bottom-art.y)*art.sh/art.h)-sy
        paintImage(left,top,right-left,bottom-top,art.texture,sx,sy,sw,sh,art.color,art.alpha)
    end

    local function image(x,y,w,h,texture,sx,sy,sw,sh,color,alpha)
        if w<=0 or h<=0 or (alpha and alpha<=0) then return end
        x,y,w,h=round(dx+x*scaleX),round(dy+y*scaleY),math.max(1,round(w*scaleX)),math.max(1,round(h*scaleY))
        local right,bottom=x+w,y+h
        if apertures then
            for i,cut in ipairs(apertures) do
                if intersects(cut,x,y,right,bottom) then
                    paintOutside({x=x,y=y,w=w,h=h,texture=texture,sx=sx,sy=sy,sw=sw,sh=sh,color=color,alpha=alpha},
                        i,x,y,right,bottom)
                    return
                end
            end
        end
        paintImage(x,y,w,h,texture,sx,sy,sw,sh,color,alpha)
    end

    function canvas.box(x,y,w,h,color,alpha)
        image(x,y,w,h,SHAPES,2,2,4,4,color,alpha)
    end

    function canvas.viewport()
        return -dx/scaleX,-dy/scaleY,rootLayout.w/scaleX,rootLayout.h/scaleY
    end

    function canvas.line(x1,y1,x2,y2,thickness,color,alpha)
        local x,y=math.min(x1,x2),math.min(y1,y2)
        local w,h=math.abs(x2-x1),math.abs(y2-y1)
        if w<1 or h<1 then
            canvas.box(x-(w<1 and thickness/2 or 0),y-(h<1 and thickness/2 or 0),
                math.max(w,thickness),math.max(h,thickness),color,alpha)
            return
        end
        local flip=(x2-x1)*(y2-y1)<0
        image(x-thickness*.15,y-thickness*.15,w+thickness*.3,h+thickness*.3,
            SHAPES,flip and 256 or 128,thickness>=4 and 128 or 0,128,128,color,alpha)
    end

    function canvas.sprite(key,x,y,w,h,alpha,color)
        local texture,sx,sy,sw,sh=source(key)
        if not texture then return end
        local ratio=math.min(w/sw,h/sh)
        local dw,dh=sw*ratio,sh*ratio
        image(x+(w-dw)/2,y+(h-dh)/2,dw,dh,texture,sx,sy,sw,sh,color,alpha)
    end

    function canvas.spritePart(key,x,y,w,h,sx,sy,sw,sh,alpha,color)
        local texture,tx,ty,tw,th=source(key)
        if not texture then return end
        local x1,y1=round(tw*math.max(0,sx)),round(th*math.max(0,sy))
        local x2,y2=round(tw*math.min(1,sx+sw)),round(th*math.min(1,sy+sh))
        if x2<=x1 or y2<=y1 then return end
        image(x,y,w,h,texture,tx+x1,ty+y1,x2-x1,y2-y1,color,alpha)
    end

    local function captionClear(blocked, center, half, top, height)
        for _,cut in ipairs(blocked) do
            if intersects(cut,center-half,top,center+half,top+height) then return false end
        end
        return true
    end

    local function captionPosition(label, blocked)
        local center,half,y,height=label.center,label.half,label.y,label.h
        local bestX,bestY,distance
        local function tryRow(top)
            if top<0 or top+height>rootLayout.h then return end
            local function check(x)
                if x-half<0 or x+half>rootLayout.w or not captionClear(blocked,x,half,top,height) then return end
                local moved=math.abs(x-center)+2*math.abs(top-y)
                if not distance or moved<distance then bestX,bestY,distance=x,top,moved end
            end
            check(center)
            for _,cut in ipairs(blocked) do
                if top<cut.bottom and top+height>cut.top then
                    check(cut.left-half)
                    check(cut.right+half)
                end
            end
        end
        tryRow(y)
        if bestX then return bestX,bestY end
        for _,cut in ipairs(blocked) do
            tryRow(cut.top-height-2)
            tryRow(cut.bottom+2)
        end
        return bestX,bestY
    end

    local function paintText(text,x,y,w,h,size,color,alpha,fit)
        if labelCount>=MAX_LABELS then good=false; return end
        labelCount=labelCount+1
        local slot=labels[labelCount]
        if not slot then
            local ok, widget=call(api.Interface,"CreateWidget","label","mazrim_scene_text_"..labelCount,root)
            if not ok or not widget then good=false; return end
            slot={widget=widget}
            labels[labelCount]=slot
            slot.failed=not passive(widget) or not call(widget.style,"SetAlign",ALIGN.CENTER)
        end
        if slot.failed then good=false; return end
        local widget=slot.widget
        if fit then
            if slot.fitText~=text or slot.fitWidth~=w or slot.fitFont~=size then
                if slot.size~=size and not call(widget.style,"SetFontSize",size) then good=false; return end
                slot.size=size
                local ok,pixels=call(widget.style,"GetTextWidth",text)
                local usable=math.max(1,w-2)
                slot.fitSize=ok and type(pixels)=="number" and pixels>usable
                    and math.max(1,math.floor(size*usable/pixels)) or size
                slot.fitText,slot.fitWidth,slot.fitFont=text,w,size
            end
            size=slot.fitSize
        end
        if slot.size~=size and not call(widget.style,"SetFontSize",size) then good=false; return end
        if slot.text~=text and not call(widget,"SetText",text) then good=false; return end
        slot.size,slot.text=size,text
        if not geometry(widget,root,slot,x,y,w,h)
            or not tint(widget.style,slot,color or INK,alpha) or not show(slot,true) then good=false end
    end

    function canvas.text(text,x,y,w,h,style,color,alpha,fit)
        if text==nil or text=="" or (alpha and alpha<=0) then return end
        local designSize=FONT[style] or (type(style)=="number" and style or 17)
        local resultHeading=apertures and frame.title and text:find(frame.title,1,true)
        local limit=math.max(4,math.floor(w/(designSize*.61)))
        if not fit and #text>limit then
            local endAt=limit-3
            while endAt>0 do
                local nextByte=text:byte(endAt+1)
                if not nextByte or nextByte<128 or nextByte>=192 then break end
                endAt=endAt-1
            end
            text=text:sub(1,endAt).."..."
        end
        x,y=round(dx+x*scaleX),round(dy+y*scaleY)
        w,h=math.max(1,round(w*scaleX)),math.max(1,round(h*scaleY))
        local size=math.max(fit and 1 or 9,round(scale*designSize))
        if apertures then
            local characters=fit and #text:gsub("[\128-\191]","") or #text
            captions[#captions+1]={text=text,x=x,y=y,w=w,h=h,size=size,color=color,alpha=alpha,
                center=x+w/2,half=math.min(w,characters*size*.67)/2+4,result=resultHeading~=nil,fit=fit}
        else
            paintText(text,x,y,w,h,size,color,alpha,fit)
        end
    end

    local function paintCaptions()
        local blocked={}
        for _,cut in ipairs(apertures) do blocked[#blocked+1]=cut end
        local function reserve(label, center, top)
            label.left,label.top=center-label.w/2,top
            blocked[#blocked+1]={left=center-label.half,top=top,right=center+label.half,bottom=top+label.h}
        end
        -- Keep the rest of the scene's captions seated when one crosses a native button.
        for _,label in ipairs(captions) do
            if captionClear(apertures,label.center,label.half,label.y,label.h) then reserve(label,label.center,label.y) end
        end
        for _,result in ipairs({true,false}) do
            for _,label in ipairs(captions) do
                if not label.left and label.result==result then
                    local x,y=captionPosition(label,blocked)
                    if x then reserve(label,x,y) end
                end
            end
        end
        for _,label in ipairs(captions) do
            if label.left then
                paintText(label.text,round(label.left),label.top,label.w,label.h,label.size,label.color,label.alpha,label.fit)
            end
        end
    end

    local function connectSound()
        if soundTried then return end
        soundTried=true
        local library=api.SharedSound
        if type(library)~="table" then
            local ok, value=pcall(require,"aac_sound_service/library")
            if ok then library=value end
        end
        if type(library)=="table" and type(library.NewClient)=="function" then
            local ok, client=pcall(library.NewClient,"mazrim_regrade_effects")
            if ok and type(client)=="table" and type(client.Play)=="function" then soundClient=client end
        end
    end

    local function playCue(r,t)
        local cue=SCENE_CUES[r.id]
        if r.confirmed and cue and not r.cue and t>=(r.frame.cueAt or cue[1]) then
            r.cue=true
            connectSound()
            call(soundClient,"Play","sounds/forge-"..cue[2]..".wav",42)
        end
    end

    function self.hide()
        playing=nil
        if not root then return true end
        local released=not updating or call(root,"ReleaseHandler","OnUpdate")
        if released then updating=false end
        local hidden=call(root,"Show",false)
        controls.sync(controlWindow,controlTab)
        return hidden and released
    end

    function self.syncControls(window,tab)
        controlWindow,controlTab=window,tab
        if playing then return controls.hide() end
        return controls.sync(window,tab)
    end

    function self.raiseControls()
        return controls.raise()
    end

    function self.stop()
        controlWindow,controlTab=nil,nil
        local stopped=self.hide()
        local controlsStopped=controls.stop()
        if soundClient then call(soundClient,"Close"); soundClient=nil end
        soundTried=false
        for i=#labels,1,-1 do
            if not call(api.Interface,"Free",labels[i].widget) then return false end
            labels[i]=nil
        end
        if root and not call(api.Interface,"Free",root) then return false end
        root,background,iconProbe,images=nil,nil,nil,{}
        rootLayout={}
        return stopped and controlsStopped
    end

    local function draw(r, now)
        local w,h=extents(api)
        if not w then return false end
        if rootLayout.w~=w or rootLayout.h~=h then
            if not call(background,"SetExtent",w,h) then return false end
        end
        if not geometry(root,"UIParent",rootLayout,0,0,w,h) then return false end
        scale=math.min(w/WIDTH,h/HEIGHT)
        scaleX,scaleY=scale,scale
        if r.id=="voyage" then scaleX,scaleY=w/WIDTH,h/HEIGHT end
        dx,dy=(w-WIDTH*scaleX)/2,(h-HEIGHT*scaleY)/2
        local window,tab,button,cancel=r.window,r.tab,r.button,r.cancel
        if not window or (r.preview and controlWindow and (controlWindow~=window or controlTab~=tab)) then
            window,tab,button,cancel=controlWindow,controlTab,nil,nil
        end
        apertures=GoldControls.cuts(api,window,tab,w,h,button,cancel)
        if r.liveVoyage and r.frame.phase=="docked" and (not apertures or apertures[1].phase~=0) then return false end
        if r.liveVoyage and r.ended and not r.alarmDismissed then
            if r.dismissAlarmAt and now>=r.dismissAlarmAt then
                r.alarmDismissed,r.alarmRect=true,nil
            else
                r.alarmRect,r.alarmTracked=VoyageLayout.alarmRect(api,w,h)
                if r.alarmRect then
                    apertures=apertures or {}
                    apertures[#apertures+1]=r.alarmRect
                elseif r.alarmTracked then r.alarmDismissed=true end
            end
        end
        local fill=not r.liveVoyage and not apertures
        if rootLayout.fill~=fill then
            if not call(background,"Show",fill) then return false end
            rootLayout.fill=fill
        end
        frame=r.frame
        if not frame.materialsChecked then
            for _,key in ipairs(materialKeys) do
                frame.iconSizes[key]=iconSize(frame[key]) or false
                if not frame.iconSizes[key] then frame[key]=nil end
            end
            frame.materialsChecked=true
        end
        frame.elapsed=now-r.started
        frame.revealElapsed=r.confirmed and now-r.confirmed or 0
        frame.t=math.max(0,math.min(1,frame.revealElapsed/r.duration))
        Aguru.prepare(frame,r.id)
        good,drawCount,labelCount=true,0,0
        captions=apertures and {} or nil
        if not r.liveVoyage and apertures then
            canvas.box(-dx/scaleX,-dy/scaleY,w/scaleX,h/scaleY,BLACK,1)
        end
        r.scene.draw(canvas,frame)
        Aguru.draw(canvas,frame,r.id)
        if r.preview then canvas.text("PREVIEW",8,3,117,21,"small",{.88,.72,.57}) end
        if apertures then
            paintCaptions()
            for _,cut in ipairs(apertures) do
                if cut.button then GoldControls.paint(cut,now,paintImage,paintText) end
            end
        end
        for i=drawCount+1,#images do if not show(images[i],false) then good=false end end
        for i=labelCount+1,#labels do if not show(labels[i],false) then good=false end end
        if good then playCue(r,frame.t) end
        return good
    end

    local function refresh()
        local r=playing
        if not r then return end
        local now=clock(api)
        local hold=RESULT_HOLD
        if r.frame.code==0 then hold=math.max(hold,Aguru.hold(r.id,r.duration)) end
        if r.preview then hold=hold+PREVIEW_EXTRA_MS end
        local expired=r.confirmed and now and now>=r.confirmed+r.duration+hold
        if not now or now<r.started or (expired and not r.liveVoyage)
            or (r.liveVoyage and (not visible(r.window) or not visible(r.tab)))
            or (r.frame.phase=="waiting" and (now>=r.started+WAIT_MS or not visible(r.window) or not visible(r.tab))) then
            self.hide()
            return
        end
        if r.raise then call(root,"Raise"); r.raise=nil end
        local interval=(r.ended or r.frame.phase=="docked") and 50 or 25
        if now-r.lastFrame<interval then return end
        r.lastFrame=now
        r.ended=expired and r.liveVoyage or false
        local ok, rendered=pcall(draw,r,now)
        if not ok or not rendered then self.hide(); fault("The cinematic could not be drawn.") end
    end

    local function showRound(r, time)
        if not root then
            local ok, widget=call(api.Interface,"CreateEmptyWindow","mazrim_regrade_scene","UIParent")
            if not ok or not widget then return false end
            root=widget
            call(root,"Show",false)
            if not passive(root) then self.stop(); return false end
            local made, bg=call(root,"CreateColorDrawable",BLACK[1],BLACK[2],BLACK[3],1,"background")
            if not made or not bg or not call(root,"AddAnchor","TOPLEFT","UIParent",0,0)
                or not call(bg,"AddAnchor","TOPLEFT",root,0,0) or not call(bg,"Show",true) then
                self.stop()
                return false
            end
            background=bg
        end
        local ok, rendered=pcall(draw,r,time)
        if not ok or not rendered then self.hide(); return false end
        if not updating and not call(root,"SetHandler","OnUpdate",refresh) then return false end
        playing, updating=r,true
        controls.hide()
        r.raise,r.lastFrame=true,time
        if call(root,"Show",true) and call(root,"Raise") then return true end
        self.hide()
        return false
    end

    local function newRound(id, pace, press, time)
        local scene=scenes[id]
        if not scene then return nil end
        local seed=math.floor(time+(press.itemType or 0))%7919
        local duration=math.max(1250, math.floor(scene.duration*(SPEED[pace] or 1)))
        return {
            id=id,scene=scene,started=time,window=press.window,tab=press.tab,itemType=press.itemType,grade=press.grade,
            button=press.button,cancel=press.cancel,
            duration=duration,
            frame={
                phase="waiting",seed=seed,duration=duration,itemName=press.itemName or "Regrade item",
                item=press.icon,chance=press.chance,oldGrade=grade(press.grade),
                oldGradeIndex=press.grade,noItem=press.itemType==nil and press.itemName==nil,
                scroll=press.scroll,charm=press.charm,iconSizes={},
                scrollName=press.scrollName,charmName=press.charmName,
            },
        }
    end

    function self.begin(id,pace,press)
        local time=clock(api)
        if not time then return false end
        local r=playing
        if r and r.frame.phase=="waiting" and not r.preview and time-r.started<WAIT_MS
            and r.id==id and r.window==press.window and r.itemType==press.itemType and r.grade==press.grade then return true end
        r=newRound(id,pace,press,time)
        if r and id=="voyage" then r.liveVoyage=true end
        return r and showRound(r,time)
    end

    function self.finish(id,pace,result,press,preview)
        local time=clock(api)
        if not time then return false end
        local r=playing
        if preview or not r or r.frame.phase~="waiting" or r.preview or r.id~=id or time-r.started>=WAIT_MS
            or r.itemType~=press.itemType or r.grade~=press.grade
            or (id=="voyage" and (r.window~=press.window or r.tab~=press.tab)) then
            r=newRound(id,pace,press,time)
        end
        if not r then return false end
        r.liveVoyage=id=="voyage" and not preview and press.window~=nil
        r.confirmed,r.preview=time,preview
        local f=r.frame
        f.phase,f.code,f.title,f.great,f.succeeded="reveal",result.code,result.title,result.great,result.succeeded
        if id=="pinball" then
            f.plinkoIndex=nextPlinkoRoute(result.code,f.seed)
        end
        if result.code==4 and id~="voyage" then
            if preview then
                -- All three endings can be found without spending a scroll.
                f.celebrationVariant=(previewVariants[id] or 0)%3+1
                previewVariants[id]=f.celebrationVariant
            else
                local roll=(math.floor(time)*73+f.seed*29)%100
                f.celebrationVariant=roll<8 and 3 or roll<26 and 2 or 1
            end
        end
        f.noItem=false
        f.waitMs=time-r.started
        f.itemName,f.grade,f.chance=result.itemName or f.itemName,
            result.code~=0 and grade(result.newGrade) or nil,press.chance
        f.newGradeIndex=result.newGrade
        if not f.item and press.icon then f.item,f.iconSizes.item=press.icon,nil end
        return showRound(r,time)
    end

    function self.leaveVoyage(window,tab)
        local r=playing
        if r and r.liveVoyage then
            -- The native client may consume the last ship scroll before the result arrives.
            if r.window==window and r.tab==tab and (r.frame.phase=="waiting"
                or (r.confirmed and (not r.ended or not r.alarmDismissed))) then return true end
            return self.hide()
        end
        return true
    end

    function self.nativePointer()
        local r=playing
        if r and r.liveVoyage and r.alarmRect and not r.alarmTracked and not r.alarmDismissed
            and VoyageLayout.clickedAlarm(api,r.alarmRect) then
            local time=clock(api)
            if time then r.dismissAlarmAt=time+230 end
        end
    end

    function self.dockVoyage(pace, press)
        local time=clock(api)
        if not time then return false end
        local r=playing
        if r and r.preview then return true end
        if r and r.liveVoyage and r.window==press.window and r.tab==press.tab then
            if r.frame.phase=="waiting" or (r.confirmed and not r.ended) then return true end
            if r.confirmed and not press.itemType and not r.alarmDismissed then return true end
            if r.confirmed and r.frame.code~=0 and press.itemType==r.itemType
                and (press.grade==r.grade or press.grade==r.frame.newGradeIndex)
                and (not r.alarmDismissed or VoyageLayout.ready(press.button)) then return true end
            if r.frame.phase=="docked" and press.itemType==r.itemType and press.grade==r.grade and VoyageLayout.ready(press.button) then
                r.frame.chance=press.chance
                return true
            end
        end
        if not press.itemType or not VoyageLayout.ready(press.button) then return self.leaveVoyage() end
        r=newRound("voyage",pace,press,time)
        if not r then return false end
        r.liveVoyage,r.frame.phase=true,"docked"
        return showRound(r,time)
    end

    function self.canPreview()
        return not playing or playing.preview==true
            or playing.liveVoyage==true and (playing.frame.phase=="docked" or playing.ended==true)
    end

    function self.scenePickerState()
        local r = playing
        if not r then return true, false end
        local atRest = r.liveVoyage and (r.frame.phase=="docked" or (r.ended and r.alarmDismissed))
        return atRest == true, atRest == true
    end

    function self.preview(id,pace,press,sample)
        if not self.canPreview() then
            return false,"A real regrade reveal is already in progress."
        end
        if type(sample)~="table" then
            local outcome={code=4,title="Great success",succeeded=true,great=true}
            if id=="voyage" then
                local failed=sample=="shipwreck" or sample=="detour"
                outcome={code=failed and 2 or 3,
                    title=failed and "Regrade failed" or "Regrade succeeded",succeeded=not failed}
            end
            sample,press=Cinema.previewSample(id,press,outcome,sample)
        end
        if not sample then return false,press end
        if id=="voyage" and sample.code==4 then return false,NO_SHIP_GREAT end
        return self.finish(id,pace,sample,press,true)
    end

    return self
end

return Cinema
