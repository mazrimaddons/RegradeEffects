local Aguru = {}
local ENTRY, GRAB, ESCAPE, EXIT = 445, 545, 810, 1500
local PEEK, POP, LAND = 130, 385, 955
local MOUTH_X, POP_Y, RUN_Y = 288, 151, 196
local INK = {0.033, 0.025, 0.035}
local PALE = {0.97, 0.91, 0.83}

-- The item point is in the scene's 720 by 460 design space. Its first owner
-- stops drawing it at "taken" so the handoff has one visible item.
local styles = {
    vault = {row=0, when=.64, duration=4080, x=359, y=237, size=145, item=43, speech=85, floor=309,
        accent={.55,.82,.67}, line="Security missed a spot."},
    mimic = {row=1, when=.60, duration=3840, size=147, speech=105, speechX=35,
        accent={.85,.69,1}, line="No chewing my upgrades."},
    workbench = {row=2, when=.62, duration=4250, x=388, y=258, size=134, speech=78, floor=334, step=29,
        accent={1,.70,.43}, line="Mine while it's hot."},
    pinball = {row=3, when=1, duration=4300, x=611, y=206, size=137, item=44, speech=129, speechX=209,
        accent={.41,.96,.88}, line="Bonus ball. Mine."},
}

Aguru.art = {}
for id, style in pairs(styles) do
    style.prefix = "aguru_" .. id .. "_"
    for pose = 0, 5 do
        Aguru.art[style.prefix .. pose] = {8+248*pose,8+240*style.row,224,224}
    end
end

local function clamp(n)
    return math.max(0,math.min(1,n))
end

local function mix(a,b,t)
    return a+(b-a)*t
end

local function smooth(t)
    t=clamp(t)
    return t*t*(3-2*t)
end

function Aguru.has(sceneId)
    return styles[sceneId]~=nil
end

function Aguru.hold(sceneId,duration)
    local style=styles[sceneId]
    if not style then return 0 end
    return math.ceil(math.max(0,EXIT+180-(1-style.when)*(duration or style.duration)))
end

function Aguru.prepare(f,sceneId)
    f.theft=nil
    local style=styles[sceneId]
    if not style or f.phase~="reveal" or f.code~=0 then return end
    local duration=f.duration or style.duration
    local time=f.revealElapsed or math.max((f.t or 0)*duration,(f.elapsed or 0)-(f.waitMs or 0))
    local age=time-style.when*duration
    if age<0 then return end
    if sceneId=="mimic" then
        local open=smooth(age/190)
        local settle=smooth((age-870)/190)
        local snap=smooth((age-745)/115)*(1-settle)
        f.theft={age=age, jaw=mix(.58,1.13,open)-snap*.99-settle*.81,
            lid=14*open*(1-math.max(snap,settle)), snap=snap}
        return
    end
    local reaction=smooth((age-GRAB)/80)*(1-smooth((age-GRAB-60)/330))
    f.theft={age=age,taken=age>=GRAB,reaction=reaction}
end

local function clipped(c, key, x, y, size, alpha, color)
    local left,right=math.max(x,0),math.min(x+size,720)
    local top,bottom=math.max(y,0),math.min(y+size,460)
    if right<=left or bottom<=top then return end
    local w,h=right-left,bottom-top
    if w==size and h==size then
        c.sprite(key,x,y,size,size,alpha,color)
    else
        c.spritePart(key,left,top,w,h,(left-x)/size,(top-y)/size,w/size,h/size,alpha,color)
    end
end

local function prop(c,key,x,y,size,alpha,color)
    clipped(c,key,x-size/2,y-size/2,size,alpha,color)
end

local function rope(c,x,y,accent)
    if y<58 then return end
    c.line(x+1,40,x,math.min(y,242),3,INK,.89)
    c.line(x+1,40,x+1,math.min(y,242),1,accent,.63)
    c.sprite("diamond",x-3,y-1,7,7,.90,accent)
end

local function dust(c, sceneId, x, y, age, accent)
    local roll=age-ESCAPE
    if roll<0 then return end
    for i=1,6 do
        local life=(roll/260+i*.147)%1
        local px=x-i*11-life*24
        local py=y-(sceneId=="pinball" and i%3*4 or life*12+i%3*5)
        if px>12 and px<701 then
            if sceneId=="pinball" then
                c.line(px-21,py+6,px,py,1.3,accent,(1-life)*.71)
            else
                c.spritePart("glow",px-10,py-3,24+i,9+i,0,0,1,1,(1-life)*.34,accent)
            end
        end
    end
end

local function speech(c,style,age)
    local fade=smooth((age-GRAB)/100)*(1-smooth((age-EXIT+210)/190))
    if fade<=0 then return end
    local x=style.speechX or 365
    c.box(x,style.speech,281,31,INK,.92*fade)
    c.box(x,style.speech,2,31,style.accent,.93*fade)
    c.text("Aguru",x+4,style.speech,53,31,"small",style.accent,fade)
    c.text(style.line,x+58,style.speech,215,31,"small",PALE,fade)
end

local function pickup(c,style)
    c.spritePart("glow",style.x-39,style.y+6,78,28,0,0,1,1,.41,style.accent)
    prop(c,"item",style.x,style.y,style.item,.93)
end

local function mimicCarry(c,x,y,pose)
    local style=styles.mimic
    local size=style.size
    clipped(c,style.prefix..pose,x,y,size,1)
    local stride=pose>=4 and 8 or 0
    prop(c,"item",x+size*(169+stride)/224,y+size*(143+(pose==5 and 3 or 0))/224,33,1)
end

function Aguru.peekMimic(c,theft,lip)
    if theft.age<PEEK or theft.age>=POP then return end
    local rise=smooth((theft.age-PEEK)/(POP-PEEK))
    mimicCarry(c,MOUTH_X,mix(lip+6,POP_Y,rise),3)
end

local function escapeMimic(c,style,age)
    if age<POP then return end
    local x,y,pose
    if age<LAND then
        local flight=(age-POP)/(LAND-POP)
        x=mix(MOUTH_X,537,flight)
        y=mix(POP_Y,RUN_Y,flight)-math.sin(flight*math.pi)*86
        pose=3
        local flash=1-smooth((age-POP)/220)
        c.sprite("glow",332,191,106,88,flash*.52,style.accent)
    else
        local run=(age-LAND)/(EXIT-LAND)
        x=mix(537,728,run)
        y=RUN_Y-math.abs(math.sin((age-LAND)/35))*6
        pose=4+math.floor((age-LAND)/56)%2
        dust(c,"mimic",x+53,333,age,style.accent)
    end
    mimicCarry(c,x,y,pose)
    speech(c,style,age)
end

function Aguru.draw(c,f,sceneId)
    local theft,style=f.theft,styles[sceneId]
    if not theft or not style then return end
    local age,size=theft.age,style.size
    if age>=EXIT then return end
    if sceneId=="mimic" then
        escapeMimic(c,style,age)
        return
    end
    local x=style.x-size*184/224
    local y=style.y-size*174/224
    local pose=2
    if age<ENTRY then
        local progress=age/ENTRY
        pose=math.floor(age/69)%2
        if sceneId=="vault" then
            y=mix(-size*.64,y,smooth(progress))
            x=x-8*math.sin(progress*math.pi)
        else
            local stride=sceneId=="pinball" and progress^1.4 or 1-(1-progress)^1.48
            x=mix(-size,x,stride)
            y=y-math.abs(math.sin(age/31))*(sceneId=="pinball" and 8 or 4)
            y=y+(style.step or 0)*(1-smooth((progress-.51)/.49))
            if sceneId=="pinball" then y=y+109*(1-smooth(progress)) end
        end
    elseif age>=ESCAPE then
        local progress=clamp((age-ESCAPE)/(EXIT-ESCAPE))
        pose=4+math.floor((age-ESCAPE)/56)%2
        x=mix(x,728,progress*(.61+.39*progress))
        y=y-math.abs(math.sin((age-ESCAPE)/24))*6
        if sceneId=="vault" then y=y+48*smooth(progress/.30)
        else y=y+(style.step or 0)*smooth(progress/.35) end
        dust(c,sceneId,x+size*.39,y+size*.91,age,style.accent)
    elseif theft.taken then
        pose=3
        y=y-2*math.sin((age-GRAB)/88)
    end
    if not theft.taken and sceneId~="workbench" then pickup(c,style) end
    if sceneId=="vault" and age<ESCAPE then rope(c,x+size*.45,y+size*.43,style.accent) end
    if x>4 and x<676 then
        local foot=y+size*.91
        local floor=style.floor or foot
        local shade=1-clamp((floor-foot)/89)*.65
        c.spritePart("glow",x+size*.16,floor,size*.61,size*.13,0,0,1,1,.60*shade,INK)
    end
    clipped(c,style.prefix..pose,x,y,size,1)
    if theft.taken then
        local grip=smooth((age-GRAB)/136)
        local handX=mix(style.x,x+size*(169+(pose>=4 and 8 or 0))/224,grip)
        local handY=mix(style.y,y+size*(143+(pose==5 and 3 or 0))/224,grip)
        if sceneId=="workbench" then
            local w=mix(93,59,grip)
            local h=w/4.25
            local left,right=math.max(0,handX-w/2),math.min(720,handX+w/2)
            if right>left then
                c.spritePart("workbenchPlate",left,handY-h/2,right-left,h,
                    (left-handX+w/2)/w,0,(right-left)/w,1,1,{.77,.66,.59})
            end
            local scale=w/93
            prop(c,"item",handX-10*scale,handY-22*scale,34*scale,1)
        else
            prop(c,"item",handX,handY,mix(style.item,32,grip),1)
        end
    end
    speech(c,style,age)
end

return Aguru

