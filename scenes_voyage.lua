local Voyage = {
    label = "Forge Voyage",
    duration = 3600,
    art = {},
    mapArt = {
        voyageMap = {0, 0, 720, 340},
        voyageReefA = {0, 352, 192, 112},
        voyageReefB = {192, 352, 192, 112},
        voyageReefC = {384, 352, 192, 112},
        voyageReefD = {576, 352, 192, 112},
    },
}

local art = Voyage.art
local function cell(key, row, column)
    art[key] = {column*256, row*256, 256, 176}
end
for _, entry in ipairs({{"R", 0, 0}, {"L", 1, 4}}) do
    local face, hullColumn, sailOffset = entry[1], entry[2], entry[3]
    cell("voyageHull"..face, 0, hullColumn)
    cell("voyageStern"..face, 0, hullColumn+2)
    cell("voyageBow"..face, 0, hullColumn+4)
    for i = 0, 3 do
        cell("voyageRig"..face..i, 1, sailOffset+i)
        cell("voyageSternRig"..face..i, 2, sailOffset+i)
        cell("voyageBowRig"..face..i, 3, sailOffset+i)
    end
end
art.voyageDebris1 = {6*256+102, 135, 49, 23}
art.voyageDebris2 = {7*256+108, 135, 42, 25}

local gradeNames = {
    [0]="Crude","Basic","Grand","Rare","Arcane","Heroic","Unique",
    "Celestial","Divine","Epic","Legendary","Mythic",
}
local chart = {
    [2]={87,168},[3]={216,148},[4]={360,168},[5]={504,138},[6]={626,165},
    [7]={626,288},[8]={504,298},[9]={360,264},[10]={216,301},[11]={87,281},
}
local curves = {
    [2]={139,150,182,143},[3]={266,158,306,169},[4]={406,154,465,135},
    [5]={547,148,574,162},[6]={651,202,647,258},[7]={588,301,550,301},
    [8]={458,286,409,267},[9]={318,280,265,299},[10]={176,289,138,278},
}
local paint = {
    wood={.155,.101,.068}, darkWood={.112,.074,.051}, border={.49,.365,.217},
    paper={.99,.881,.706}, muted={.817,.769,.660}, copper={.834,.621,.374},
    gold={1,.788,.437}, china={.717,.818,.792}, route={.565,.702,.672},
    mapInk={.052,.115,.139}, mapGlass={.086,.172,.189},
    foam={.716,.829,.787}, fog={.538,.686,.677}, danger={1,.573,.411},
}
local pi = math.pi
local shipWidth, shipHeight = 143, 143*176/256
local WRECK_TURN, WRECK_IMPACT = .16, .48
local function clamp(value, lo, hi)
    return math.max(lo or 0, math.min(hi or 1, value))
end

local function mix(a, b, t)
    return a + (b-a)*t
end

local function smooth(t)
    t=clamp(t)
    return t*t*(3-2*t)
end

local function grade(value, alternative)
    if type(value)~="number" or not (value>=0 and value<=255) then return alternative end
    return math.floor(value)
end

local function nameOf(value)
    return gradeNames[value] or ("Grade "..value)
end

local function routeAt(progress)
    local idx=math.floor(clamp(progress,2,10.999999))
    local t=clamp(progress-idx)
    local a,b,curve=chart[idx],chart[idx+1],curves[idx]
    local s=1-t
    local q,r,v,u=s*s*s,3*s*s*t,3*s*t*t,t*t*t
    return q*a[1]+r*curve[1]+v*curve[3]+u*b[1],
        q*a[2]+r*curve[2]+v*curve[4]+u*b[2]
end

local reefs = {}
local reefStyles = {
    {"voyageReefA", .65, 34, 83},
    {"voyageReefB", .64, 36, 75},
    {"voyageReefC", .64, 34, 85},
    {"voyageReefD", .66, 36, 74},
    {"voyageReefB", 0, 38, 52},
}
for i, style in ipairs(reefStyles) do
    local harbor = i+6
    local x,y = routeAt(harbor+style[2])
    reefs[harbor] = {key=style[1],x=x-(harbor==11 and 42 or 0),y=y-style[3],width=style[4]}
end

local function drawReef(c,reef)
    local width, height = reef.width, reef.width*112/192
    c.sprite(reef.key,reef.x-width/2,reef.y-height*.77,width,height,1)
end

local function drawReefs(c, cameAshore)
    for harbor=7,11 do
        if harbor~=cameAshore then drawReef(c,reefs[harbor]) end
    end
end

local function route(c, complete, active)
    for leg=2,10 do
        for j=0,7 do
            local begin=leg+j/8
            local finish=begin+.125
            local endMark=math.max(complete,active)
            local lit=begin<endMark
            local x,y=routeAt(begin)
            local bx,by=routeAt(lit and math.min(finish,endMark) or (begin+.0625))
            c.line(x,y,bx,by,lit and 1.75 or 1.02,lit and paint.copper or paint.route,lit and .93 or .72)
        end
    end
end

local function marks(c, harbor, completed, missing)
    for i=2,11 do
        local xy=chart[i]
        local x,y=xy[1],xy[2]
        local current=i==harbor and not missing
        local passed=i<=completed and not missing
        local ink=current and paint.gold or passed and paint.copper or paint.route
        local size=current and 13 or 11
        if current then c.sprite("glow",x-24,y-24,48,48,.72,paint.gold) end
        c.sprite("diamond",x-size/2,y-size/2,size,size,current and 1 or .84,ink)
        c.sprite("diamond",x-3,y-3,6,6,1,current and paint.wood or paint.mapInk)
        local name=gradeNames[i]
        local plateWidth=math.max(41,#name*7.3+9)
        if current then c.box(x-plateWidth/2-1,y+7,plateWidth+2,19,paint.copper,.68) end
        c.box(x-plateWidth/2,y+8,plateWidth,17,current and paint.wood or paint.mapInk,.92)
        c.text(name,x-52,y+6,104,20,15,current and paint.gold or passed and paint.paper or paint.china)
    end
end

local function breeze(c, elapsed, energy, x, y, direction)
    if energy<=0 then return end
    for i=1,9 do
        local pulse=((elapsed/15+i*37)%180)/180
        local offset=(15+i*5)*(1-pulse)+i*2
        local fromX=x+direction*(i%3==0 and offset*.84 or -offset)
        local fromY=y-41-i*5+math.sin(pulse*pi+i)*3
        local length=(19+i*4)*(1-pulse*.45)
        local toX=fromX-direction*length
        if fromX>18 and fromX<702 and toX>18 and toX<702 and fromY>51 then
            c.line(fromX,fromY,toX,fromY+.7,1.4,paint.foam,math.sin(pulse*pi)*(.14+.48*energy))
        end
    end
end

local function water(c, x, y, direction, strength, elapsed)
    for i=1,3 do
        local drift=((elapsed/70+i*10)%32)*strength
        local left=x-direction*(20+i*11+drift)
        local right=left+direction*(11+i*2)
        if left>7 and left<713 and right>7 and right<713 then
            c.line(left,y+i*3,right,y+i*3+1,1,paint.foam,(.32-i*.06)*strength)
        end
    end
end

local frameOrder={0,1,2,3,2,1}
local function sailFrame(elapsed, energy)
    local slot=frameOrder[math.floor(elapsed/(energy>.3 and 102 or 168))%#frameOrder+1]
    return energy>.3 and math.min(3,slot+1) or slot
end

local function afloat(c, x, y, face, elapsed, energy, turn)
    local direction=face=="R" and 1 or -1
    local bob=math.sin(elapsed/238)*(.93+energy*1.2)
    local width=shipWidth*(1-(turn or 0)*.33)
    local left,top=x-width/2,y-shipWidth*152/256-7+bob
    water(c,x,y-2,direction,.22+energy*.78,elapsed)
    breeze(c,elapsed,energy,x,y,direction)
    local rig="voyageRig"..face..sailFrame(elapsed,energy)
    local hull="voyageHull"..face
    if width<shipWidth and c.spritePart then
        c.spritePart(rig,left,top,width,shipHeight,0,0,1,1,1)
        c.spritePart(hull,left,top,width,shipHeight,0,0,1,1,1)
    else
        c.sprite(rig,left,top,width,shipHeight,1)
        c.sprite(hull,left,top,width,shipHeight,1)
    end
end

local function fragment(c,key,x,y,height,waterline,alpha)
    if alpha<=0 then return end
    local fraction=clamp((waterline-y)/height)
    if fraction>=.999 or not c.spritePart then
        c.sprite(key,x,y,shipWidth,height,alpha)
    elseif fraction>.025 then
        c.spritePart(key,x,y,shipWidth,height*fraction,0,0,1,fraction,alpha)
    end
end

local function broken(c,x,y,face,elapsed,t)
    local direction=face=="R" and 1 or -1
    local snap=smooth((t-WRECK_IMPACT)/.18)
    local sink=smooth((t-.70)/.28)
    local left,top=x-shipWidth/2,y-shipWidth*152/256-7
    local front,back=direction*(12*snap+14*sink),-direction*(12*snap+8*sink)
    local sail=sailFrame(elapsed,1)
    local alpha=1-sink
    if sink<.999 then
        local drop=(18*snap+88*sink)
        local kick=math.sin(pi*snap)*15
        fragment(c,"voyageSternRig"..face..sail,left+back-direction*12*snap,
            top+drop-kick,shipHeight,y+3,alpha)
        fragment(c,"voyageBowRig"..face..sail,left+front+direction*11*snap,
            top+drop*.72-kick*.7,shipHeight,y+3,alpha)
        fragment(c,"voyageStern"..face,left+back,top+snap*8+sink*34,shipHeight,y+8,alpha)
        fragment(c,"voyageBow"..face,left+front,top+snap*3+sink*40,shipHeight,y+8,alpha)
    end
    for i=1,9 do
        local radius=(9+i*3)*snap
        local px=x+(i%2==0 and 1 or -1)*radius
        local py=y+((i%4)-1.4)*7*snap-22*math.sin(pi*snap)*(i%3+.2)*.64
            + math.sin(elapsed/235+i)*1.5
        c.sprite("voyageDebris"..(i%2+1),px-7,py-4,14+i%3*3,8+i%2*2,.76*snap-i*.025*sink)
    end
    water(c,x,y,direction,.88,elapsed)
end

local function impactSpray(c,reef,t)
    local age=(t-WRECK_IMPACT)/.26
    if age>=1 then return end
    local rise=smooth(age/.28)
    local fade=rise*(1-smooth((age-.26)/.74))
    local impactX,impactY=reef.x+6,reef.y+4
    c.sprite("glow",impactX-31,impactY-20,62,40,.74*fade,paint.foam)
    for i=1,12 do
        local angle=pi+i*pi/13
        local radius=5+math.sqrt(age)*(18+i%4*6)
        local dx,dy=math.cos(angle),math.sin(angle)
        local px,py=impactX+dx*radius,impactY+dy*radius*.83+age*age*7
        c.line(px,py,px+dx*(5+i%3),py+dy*5,1.4,paint.foam,fade*(1-i*.025))
    end
end

local function departure(old, waitMs)
    if old==11 then return old end
    return old+smooth(waitMs/920)*.24
end

local function berth(f, old, target, waiting, t)
    if f.phase=="docked" then return old,0 end
    if f.phase=="waiting" then return departure(old, f.elapsed or 0),.60 end
    return mix(waiting,target,smooth(t/.85)),.95*(1-smooth((t-.70)/.26))
end

local function wreckCourse(old,wait,t)
    local reef=reefs[old]
    local turn=math.min(11,old+.31)
    local progress=mix(wait,turn,smooth(t/WRECK_TURN))
    local x,y=routeAt(progress)
    if t<=WRECK_TURN then return x,y,progress end
    local drift=clamp((t-WRECK_TURN)/(WRECK_IMPACT-WRECK_TURN))
    local contactX,contactY=reef.x+37,reef.y+12
    local across=drift*drift
    return mix(x,contactX,smooth(drift)),mix(y,contactY,across),turn
end

local function wreckWake(c,old,wait,t)
    local endAt=math.min(t,WRECK_IMPACT)
    for i=1,5 do
        local before=endAt-i*.033
        if before>=WRECK_TURN then
            local ax,ay=wreckCourse(old,wait,before)
            local bx,by=wreckCourse(old,wait,before+.015)
            local fade=1-smooth((t-WRECK_IMPACT)/.31)
            c.line(ax+13,ay-3,bx+13,by-3,1.5,paint.foam,fade*(.6-i*.08))
        end
    end
end

local LEAVE_COURSE, TURN_BACK, HOME = .25, .56, .91

local function lostCourse(old, waiting, t)
    local mid=old+.45
    if t<=LEAVE_COURSE then
        local progress=mix(waiting,mid,smooth(t/LEAVE_COURSE))
        local x,y=routeAt(progress)
        return x,y,progress,"R",.68,0
    end
    local x,y=routeAt(mid)
    local turnX=math.min(642,x+26)
    local turnY=y+59
    local pivot=1-smooth(math.abs(t-TURN_BACK)/.115)
    if t<TURN_BACK then
        local drift=smooth((t-LEAVE_COURSE)/(TURN_BACK-LEAVE_COURSE))
        return mix(x,turnX,drift),mix(y,turnY,drift),mid,"R",.96,pivot
    end
    local back=smooth((t-TURN_BACK)/(HOME-TURN_BACK))
    local dockX,dockY=routeAt(old)
    return mix(turnX,dockX,back),mix(turnY,dockY,back)+math.sin(pi*back)*22,
        mix(mid,old,back),"L",.89*(1-smooth((t-.83)/.08)),pivot
end

local function seaFog(c,old,waiting,t,elapsed)
    local mist=smooth((t-.19)/.16)*(1-smooth((t-.68)/.18))
    if mist<=0 then return end
    local x,y=lostCourse(old,waiting,TURN_BACK)
    for i=1,7 do
        local drift=(elapsed/40+i*26)%92-46
        local px=clamp(x+drift+(i-4)*13,52,668)
        local py=y-58+(i%3)*24
        c.sprite("glow",px-47,py-27,94,54,mist*(.34+i%3*.05),paint.fog)
    end
    for i=1,7 do
        local before=math.max(LEAVE_COURSE,t-i*.022)
        local after=math.max(LEAVE_COURSE,before+.011)
        local ax,ay=lostCourse(old,waiting,before)
        local bx,by=lostCourse(old,waiting,after)
        c.line(ax,ay+3,bx,by+3,1.2,paint.foam,mist*(.60-i*.07))
    end
end

local function faceFor(position, direction)
    local segment=math.floor(clamp(position,2,10.999999))
    local face=segment<=5 and "R" or segment>=7 and "L" or (position-6<.5 and "R" or "L")
    if direction<0 then return face=="R" and "L" or "R" end
    return face
end

local function title(c,f,old,target,t,shipwreck,lost)
    local label, ink
    if f.noItem then
        label="Select an item to regrade"
    elseif f.phase=="docked" then
        label=nameOf(old).." harbour"
    elseif lost then
        if t<LEAVE_COURSE then
            label="Regrading..."
        elseif t<TURN_BACK then
            label="Lost in the fog"
            ink=paint.china
        elseif t<HOME then
            label="Returning to "..nameOf(old)
        else
            label=(f.title or "Regrade failed").." · Back at "..nameOf(old)
            if f.code==1 then label=label.." · New grade "..nameOf(target) end
            ink=paint.danger
        end
    elseif f.phase=="waiting" or (t<(shipwreck and WRECK_IMPACT or .86)) then
        label="Regrading..."
    elseif shipwreck then
        label=(f.title or "Regrade failed").." · Shipwreck"
        ink=paint.danger
        if f.code==1 then label=(f.title or "Regrade downgraded").." · "..nameOf(target) end
    elseif target>=11 and f.succeeded then
        label="Mythic reached · "..(f.title or "Regrade succeeded")
    elseif target~=old then
        label=nameOf(old).." → "..nameOf(target).." · "..(f.title or "Regraded")
    else
        label=f.title or nameOf(target)
    end
    local second=(type(f.itemName)=="string" and f.itemName~="" and f.itemName) or ""
    if second=="" and not f.noItem then
        second=type(f.chance)=="number" and string.format("%.1f%% listed success",f.chance*100) or "Selected item"
    end
    return label,second,ink or paint.gold
end

local function leftCaption(c, text, x, y, maxWidth, h, font, color)
    local width=math.min(maxWidth,math.max(8,#text*font*.62))
    c.text(text,x,y,width,h,font,color)
end

function Voyage.draw(c,f)
    local elapsed=f.elapsed or 0
    local t=clamp(f.t or 0)
    local oldGrade=grade(f.oldGradeIndex,2)
    local targetGrade=grade(f.newGradeIndex,oldGrade)
    local old,target=clamp(oldGrade,2,11),clamp(targetGrade,2,11)
    local waiting=departure(old,f.waitMs or 0)
    local revealing=f.phase=="reveal"
    local unsuccessful=revealing and (f.code==0 or f.code==1 or f.code==2)
    local shipwreck=unsuccessful and oldGrade>=7
    local lost=unsuccessful and oldGrade<7
    local hitReef=shipwreck and t>=WRECK_IMPACT
    local x,y,face,turn,progress,energy
    if lost then
        x,y,progress,face,energy,turn=lostCourse(old,waiting,t)
    elseif shipwreck then
        x,y,progress=wreckCourse(old,waiting,t)
        face,energy="L",.93
    else
        progress,energy=berth(f,old,target,waiting,t)
        local moveBack=revealing and target<old
        face=faceFor(progress,moveBack and -1 or 1)
        x,y=routeAt(progress)
    end
    local harbor=old
    if revealing and not unsuccessful and t>=.85 then harbor=target end
    if shipwreck and f.code==1 and t>=.78 then harbor=target end
    local completed=harbor
    if revealing and not unsuccessful then completed=math.max(harbor,math.floor(progress)) end

    c.box(0,0,720,460,paint.border)
    c.box(1,1,718,45,paint.wood)
    c.sprite("voyageMap",0,47,720,340,1)
    c.box(1,388,718,71,paint.darkWood)
    drawReefs(c,hitReef and old)
    local active=(f.noItem or (shipwreck and f.code==1 and t>=.78)) and completed or progress
    route(c,f.noItem and 2 or completed,active)
    marks(c,harbor,completed,f.noItem)
    if not f.noItem then
        if lost then seaFog(c,old,waiting,t,elapsed) end
        if shipwreck then wreckWake(c,old,waiting,t) end
        if hitReef then broken(c,x,y,face,elapsed,t)
        else afloat(c,x,y,face,elapsed,energy,turn) end
        if revealing and not unsuccessful and t>=.84 and (f.great or target>=11) then
            local pulse=clamp((t-.84)/.16)
            c.sprite("glow",x-62,y-29,124,58,.50+(1-pulse)*.27,paint.gold)
        end
    end
    if hitReef then
        local reef=reefs[old]
        drawReef(c,reef)
        impactSpray(c,reef,t)
    end
    local result,item,ink=title(c,f,oldGrade,targetGrade,t,shipwreck,lost)
    leftCaption(c,"Forge Voyage",9,4,252,34,28,paint.paper)
    local status=type(f.chance)=="number" and string.format("%.1f%% listed success",f.chance*100)
        or "Regrade voyage"
    c.text(status,523,8,182,27,"small",paint.paper)
    if not f.noItem then
        c.box(16,400,38,38,paint.border)
        c.box(17,401,36,36,paint.mapInk)
        c.sprite("item",19,403,32,32,1)
    end
    leftCaption(c,result,57,393,606,28,17,ink)
    leftCaption(c,item,57,419,606,22,13,paint.muted)
end

return {voyage=Voyage}
