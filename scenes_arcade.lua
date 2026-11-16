local Plinko = require("mazrim_regrade_effects/plinko_routes")
local Scenes = {}
local copper = {0.85, 0.49, 0.25}
local amber = {1, 0.71, 0.37}
local gold = {1, 0.84, 0.49}
local paper = {0.97, 0.9, 0.76}
local subdued = {0.73, 0.66, 0.56}
local cyan = {0.48, 0.91, 0.87}
local scarlet = {1, 0.39, 0.30}
local olive = {0.55, 0.86, 0.64}

local outcomes = {
    [0] = {bay=76, color=scarlet, chute="Scrap", title="Item destroyed", verdict="PROPERTY CONDEMNED",
        reaction="Bailiff, find the blacksmith."},
    [1] = {bay=168, color=copper, chute="Downgrade", title="Regrade downgraded", verdict="GRADE REVOKED",
        reaction="The previous grade is struck from the record."},
    [2] = {bay=260, color=subdued, chute="No change", title="Regrade failed", verdict="APPLICATION DENIED",
        reaction="No change to the record. Next case."},
    [3] = {bay=352, color=olive, chute="Success", title="Regrade succeeded", verdict="UPGRADE APPROVED",
        reaction="Clerk, return the item at its new grade."},
    [4] = {bay=444, color=gold, chute="Great Success", title="Great success", verdict="HONOURS AWARDED",
        reaction="The court recognises an exceptional regrade."},
}
local pi = math.pi

local function clamp(t)
    return math.max(0, math.min(1, t))
end

local function mix(a, b, t)
    return a + (b-a)*t
end

local function smooth(t)
    return t*t*(3-2*t)
end

local function caption(value, limit, fallback)
    if type(value) ~= "string" or value == "" then return fallback or "" end
    if #value <= limit then return value end
    local stop = limit - 3
    while stop > 0 do
        local after = value:byte(stop+1)
        if after < 128 or after >= 192 then break end
        stop = stop - 1
    end
    return value:sub(1, stop) .. "..."
end

local function oddsLabel(chance)
    if type(chance) == "number" then return string.format("%.1f%% listed success", 100*chance) end
    return "Listed odds unavailable"
end

local function burst(c, x, y, t, count, radius, color)
    local opacity = 1-t
    local reach = 8 + radius*t
    for i = 1, count do
        local angle = i*2*pi/count + 0.21
        local sx = x + math.cos(angle)*reach
        local sy = y + math.sin(angle)*reach*0.62
        if sx >= 6 and sx <= 714 and sy >= 8 and sy <= 450 then
            local edgeX = math.max(2, math.min(718, sx + 9*math.cos(angle)))
            local edgeY = math.max(4, math.min(456, sy + 7*math.sin(angle)))
            c.line(sx, sy, edgeX, edgeY, 1.8, color, opacity*0.8)
        end
    end
end

local function twinkle(c, x, y, radius, opacity, color)
    c.sprite("diamond",x-radius,y-radius,radius*2,radius*2,opacity,color)
    if radius>=4 then
        c.line(x-radius*1.7,y,x+radius*1.7,y,1,paper,opacity*0.7)
        c.line(x,y-radius*1.7,x,y+radius*1.7,1,paper,opacity*0.7)
    end
end

local PLINKO_MS = 4200
local GATE_X, GATE_Y = 260, 83
local lastRow = 7

local function pegPoint(row, column)
    return 260+column*28, 102+row*31
end

local function pegImpacts(c,route,time,duration)
    local hits = 0
    for i,impact in ipairs(route.impacts) do
        local age = time - impact.at * duration
        if age < 0 then break end
        if impact.kind ~= "floor" then hits = hits + 1 end
        if age < 150 and impact.kind ~= "floor" then
            local q = age/150
            local light = (1-q)^2
            c.sprite("glow",impact.x-15,impact.y-15,30,30,0.68*light,amber)
            burst(c,impact.x,impact.y,q,4,22,i%3==0 and cyan or gold)
        end
    end
    return hits
end

local function chuteNames(c,confirmed)
    for code=0,4 do
        local result = outcomes[code]
        local active = result == confirmed
        c.text(result.chute,result.bay-40,404,80,18,"micro",active and result.color or subdued,active and 1 or 0.79)
    end
end

local violet = {0.68,0.49,1}
local railLampRows = {126,153,180,207,234,261,287,313,338}

local function lightWave(cycle)
    return (0.5 + 0.5*math.cos(2*pi*cycle))^3
end

local function tiltLights(t, across, down, power)
    local warning = 1-smooth(clamp((t-0.43)/0.13))
    local alarm = lightWave(t*2.2 + across*0.23 - down*0.43)
    local reset = lightWave(t*1.35 - down*0.83 + across*0.13)
    return mix(0.21+0.69*reset,0.14+0.80*alarm,warning)*power,
        warning > 0.5 and scarlet or (reset > 0.65 and gold or olive)
end

local function secretLights(t, across, down, power)
    local radius = math.sqrt(across^2+(down-0.45)^2*2.3)
    local outward = lightWave(t*1.62 - radius*0.87)
    local inward = lightWave(t*1.62 + radius*0.76 + 0.38)
    return (0.18+0.72*math.max(outward,inward*0.73))*power,
        outward >= inward and cyan or violet
end

local function jackpotLights(t, across, down, power)
    local climb = lightWave(t*1.82 + down*1.03 - across*0.21)
    local spill = lightWave(t*1.82 - down*0.68 - across*0.42 + 0.33)
    return (0.20+0.77*math.max(climb,spill*0.83))*power, climb >= spill and gold or cyan
end

local function successLights(t, across, down, power)
    local sweep = lightWave(t*0.88 - down*0.58 - math.abs(across)*0.18)
    local fade = 1-smooth(clamp((t-0.95)/0.70))
    return (0.14+0.30*sweep)*power*fade, olive
end

local function lightCabinet(c,pattern,ageMs)
    local t = ageMs/1000
    local power = smooth(clamp(t/0.12))*(1-0.22*smooth(clamp((t-1.35)/0.85)))
    for side=-1,1,2 do
        local x = 260+169*side
        local light,tint = pattern(t,side,0.19,power)
        local echo = pattern(t+0.09,side,0.28,power)
        c.spritePart("glow",x-57,101,114,52,0,0,1,1,light*0.87,tint)
        c.box(x-22,115,44,1,tint,light*0.91)
        c.spritePart("glow",x-33,124,66,21,0,0,1,1,echo*0.60,tint)
        c.box(x-13,132,26,1,tint,echo*0.67)
    end
    for _,y in ipairs(railLampRows) do
        local left = 213+(29-213)*(y-91)/(340-91)
        for side=-1,1,2 do
            local x = 260+side*(260-left)
            local light,tint = pattern(t,(x-260)/230,(y-102)/236,power)
            local radius = 12+8*light
            c.sprite("glow",x-radius,y-radius,2*radius,2*radius,light,tint)
            c.sprite("diamond",x-2.1,y-2.1,4.2,4.2,light*0.83,tint)
        end
    end
    for row=0,lastRow do
        for column=-row,row,2 do
            local x,y = pegPoint(row,column)
            local light,tint = pattern(t,(x-260)/230,row/lastRow,power)
            local radius = 8+8*light
            c.sprite("glow",x-radius,y-radius,2*radius,2*radius,light*0.93,tint)
            if light > 0.55 then
                c.sprite("diamond",x-1.5,y-1.5,3,3,(light-0.55)*1.55,tint)
            end
        end
    end
    for code=0,4 do
        local x = outcomes[code].bay
        local light,tint = pattern(t,(x-260)/230,1.16,power)
        c.spritePart("glow",x-40,338,80,35,0,0,1,1,light*0.74,tint)
        c.box(x-28,350,56,1,tint,light*0.70)
    end
    for index=0,5 do
        local x = 556+index*23
        local light,tint = pattern(t,(index-2.5)/2.5,-0.08,power)
        c.spritePart("glow",x-13,63,26,9,0,0,1,1,light*0.81,tint)
        c.box(x-7,67,14,1,tint,light*0.86)
    end
    local light,tint = pattern(t,0.76,0.42,power)
    c.spritePart("glow",526,151,155,101,0,0,1,1,light*0.42,tint)
    c.box(538,150,136,1,tint,light*0.75)
end

local function jackpot(c,seed,q,age,pace)
    for i=1,3 do
        local routes = Plinko.routes[(i*2)%5]
        local route = routes[(seed+3*i)%#routes+1]
        local progress = (age-85*(i-1))*pace/route.durationMs
        if progress >= 0 and progress < 1 then
            local x,y = Plinko.sample(route,progress)
            local fade = 1-smooth(clamp((q-0.72)/0.28))
            local tint = i == 2 and cyan or gold
            c.sprite("glow",x-17,y-17,34,34,fade*0.76,tint)
            c.sprite("diamond",x-3,y-3,6,6,fade,tint)
        end
    end
    for i=1,10 do
        local t = (q*1.6+i*0.19)%1
        local x = 122+(i*73)%275
        local y = 335-146*t
        twinkle(c,x,y,1.7+i%4,math.sin(pi*t)^2*(1-q),i%4==0 and cyan or gold)
    end
end

local function tiltOverride(c,q)
    local warning = smooth(clamp(q/0.12))*(1-smooth(clamp((q-0.38)/0.28)))
    local released = smooth(clamp((q-0.48)/0.27))
    if q < 0.54 then
        c.text("TILT",173,257,174,37,"large",scarlet,warning)
    else
        c.text("TILT CLEARED",150,257,220,37,"body",gold,released)
    end
end

local function secretTable(c,q)
    local open = smooth(clamp(q/0.45))
    local x,y = 260,203
    c.sprite("glow",x-143,y-119,286,238,open*0.72,cyan)
    for ring=1,2 do
        local phase = q*(ring==1 and -4.4 or 5.2)+ring*pi/7
        local radius = (41+ring*25)*open
        for i=1,14 do
            local a = phase+i*2*pi/14
            local sx,sy = x+radius*math.cos(a), y+radius*math.sin(a)*0.67
            twinkle(c,sx,sy,i%4==0 and 4 or 2.1,open*(0.66+math.sin(a*2)*0.25),ring==1 and gold or cyan)
        end
    end
    local award = smooth(clamp((q-0.37)/0.29))
    c.sprite("glow",x-45,y-45,90,90,award*0.88,gold)
    c.sprite("crest",x-26,y-27,52,54,award)
    c.text("EXTRA BALL",142,269,236,26,"body",cyan,award)
end

local function drawPinball(c,frame)
    local elapsed,seed,t = frame.elapsed or 0, frame.seed or 0, frame.t or 0
    local duration = frame.duration or PLINKO_MS
    local waitMs = frame.waitMs or 0
    local outcome = frame.phase == "reveal" and outcomes[frame.code] or nil
    local time = elapsed-waitMs
    local pace = PLINKO_MS/duration
    local x,y,hits = GATE_X,GATE_Y,0
    local route,confirmed,ageMs
    c.sprite("pinballPlinko",0,0,720,460,1)
    if outcome then
        local routes = Plinko.routes[frame.code]
        route = routes[frame.plinkoIndex or seed%#routes+1]
        local routeMs = route.durationMs/pace
        local touchdown = route.landing*routeMs
        local progress = clamp(t*duration/routeMs)
        x,y = Plinko.sample(route,progress)
        frame.cueAt = touchdown/duration
        confirmed = t >= frame.cueAt
        ageMs = math.max(0,time-touchdown)
        hits = pegImpacts(c,route,time,routeMs)
        if not confirmed then
            local ballTravel = smooth(clamp(t/0.03))
            for i=1,2 do
                local px,py = Plinko.sample(route,math.max(0,progress-i*18/routeMs))
                local size = 14-i*2
                c.sprite("glow",px-size/2,py-size/2,size,size,ballTravel*(0.24-i*0.06),amber)
            end
        end
    end
    local tint = confirmed and outcome.color or cyan
    local finale = confirmed and frame.code == 4 and frame.celebrationVariant
    local age = ageMs and clamp(ageMs/900) or 0
    if confirmed then
        if frame.code == 3 then
            lightCabinet(c,successLights,ageMs)
        elseif frame.code == 4 then
            local pattern = finale == 2 and tiltLights or finale == 3 and secretLights or jackpotLights
            lightCabinet(c,pattern,ageMs)
        end
        c.spritePart("glow",outcome.bay-42,345,84,70,0,0,1,1,0.79-age*0.29,tint)
        c.box(outcome.bay-37,356,74,1,tint,0.89)
        c.box(outcome.bay-35,420,70,1,tint,0.67)
        if age < 0.43 then
            local hitX,hitY = Plinko.sample(route,route.landing)
            burst(c,hitX,hitY,age/0.43,frame.code==4 and 15 or 10,frame.code==4 and 80 or 48,tint)
        end
        if frame.code == 4 then
            if finale == 2 then tiltOverride(c,age)
            elseif finale == 3 then secretTable(c,age)
            else jackpot(c,seed,age,ageMs,pace) end
        end
    end
    c.sprite("glow",x-11,y-11,22,22,confirmed and 0.60 or 0.47,confirmed and tint or amber)
    c.sprite("plinkoBall",x-6.5,y-6.5,13,13,1)

    local score = hits*130
    if confirmed then
        score = ({0,760,1320,4800,9999})[frame.code+1]
        if frame.code == 4 then score = math.floor(mix(4800,9999,smooth(clamp(age/0.72)))) end
    end
    c.text("Pinball Foundry",30,24,305,34,"title",paper)
    local theft = frame.theft
    local tilt = theft and theft.taken
    if tilt then
        local flicker=.52+.44*math.sin((theft.age or 0)/42)
        c.spritePart("glow",493,89,227,89,0,0,1,1,.55*flicker,scarlet)
        for i=1,5 do c.box(520+i*31,90,15,3,scarlet,flicker) end
    end
    c.text(confirmed and (tilt and "TILT" or frame.code==4 and "Jackpot" or "Chute locked") or outcome and "Dropping through the pins" or "Ingot ready at the gate",
        31,56,306,18,"small",tint)
    c.text(string.format("%04d",score),550,31,129,33,"large",tint)
    c.text(confirmed and "REVEAL" or "ON THE LINE",536,113,151,24,"small",tint)
    if confirmed and frame.code == 4 then
        c.sprite("item",550,164,91,83,0.96)
        c.sprite("crest",632,181,43,51,1)
    elseif confirmed and frame.code == 0 and not theft then
        c.sprite("item",570,166,84,80,0.41*(1-age))
        c.sprite("glow",554,160,119,89,0.67,scarlet)
        c.line(574,177,650,232,2,scarlet,0.66)
        c.line(650,177,574,232,2,scarlet,0.66)
    elseif not theft then
        c.sprite("item",570,166,84,80,0.96)
    end
    c.text(caption(frame.itemName,23,"Regrade item"),533,269,155,25,"small",paper)
    if confirmed then
        c.text(caption(frame.title,23,outcome.title),529,302,166,32,"body",tint)
        if frame.code == 4 then
            local award = age < 0.83 and "MULTIBALL" or "JACKPOT PAID"
            if finale == 2 then award = age < 0.54 and "TILT WARNING" or "TILT OVERRIDE"
            elseif finale == 3 then award = "SECRET TABLE" end
            c.text(award,533,339,155,24,"small",gold)
            c.text(caption(frame.grade,21,""),533,379,155,24,"small",subdued)
        elseif frame.code ~= 0 then
            c.text(caption(frame.grade,21,""),533,340,155,24,"small",subdued)
        end
    else
        c.text(oddsLabel(frame.chance),533,307,155,28,"small",subdued)
        c.text(outcome and "Approaching the chutes" or "Waiting for the forge",529,340,166,24,"small",tint)
    end
    chuteNames(c,confirmed and outcome or nil)
end

local linen = {0.15,0.10,0.10}
local wood = {0.24,0.137,0.116}
local woodEdge = {0.54,0.32,0.20}
local benchFace = {0.10,0.068,0.079}
local docket = {0.13,0.13,0.17}
local black = {0.046,0.042,0.06}

local function bench(c,x,y,w,h)
    c.box(x,y,w,h,wood,0.98)
    c.box(x,y+1,w,3,woodEdge)
    c.box(x+6,y+7,w-12,h-12,benchFace)
    c.box(x+6,y+h-7,w-12,1,woodEdge)
end

local function scrollProp(c,x,y,w,h)
    local scaleX,scaleY=w/40,h/35
    local function patch(px,py,pw,ph,color,opacity)
        c.box(x+px*scaleX,y+py*scaleY,pw*scaleX,ph*scaleY,color,opacity)
    end
    patch(7,5,26,26,{0.68,0.53,0.34})
    patch(10,4,20,24,{0.8,0.66,0.46})
    patch(3,2,34,6,woodEdge)
    patch(4,27,32,6,woodEdge)
    for i=1,3 do patch(15,11+i*4,10-i*3,1,wood,0.83) end
end

local function charmProp(c,x,y,w,h,alpha)
    local sx,sy=w/42,h/38
    c.sprite("glow",x,y,w,h,0.6*alpha,cyan)
    c.sprite("diamond",x+11*sx,y+6*sy,20*sx,26*sy,alpha,woodEdge)
    c.sprite("diamond",x+17*sx,y+11*sy,8*sx,17*sy,alpha,cyan)
end

-- The regular card puts two rows beside the icon. Longer names use the full card width.
local exhibitRows = {{63,30,82,13},{63,44,82,13},{7,60,137,13}}
local compactRows = {{7,35,137,10},{7,45,137,10},{7,55,137,10},{7,65,137,10}}

local function glyphWidth(glyph)
    local lead=glyph:byte()
    if lead>=224 or glyph:match("^[MW@%%&]$") then return 1 end
    if lead>=192 then return .68 end
    if glyph:match("^[iIl.,'! ]$") then return .34 end
    return .62
end

local function wrapExhibit(name, rows, size, breakWords)
    local lines={}
    for _,row in ipairs(rows) do
        if name=="" then break end
        local width,last,wordBoundary=0,0,nil
        for glyph in name:gmatch(".[\128-\191]*") do
            width=width+glyphWidth(glyph)*size
            if width>row[3] then break end
            if glyph==" " then wordBoundary=last end
            last=last+#glyph
        end
        if last<#name and name:sub(last+1,last+1)~=" " then
            if wordBoundary then last=wordBoundary
            elseif not breakWords then return end
        end
        lines[#lines+1]=name:sub(1,last):gsub(" +$","")
        name=name:sub(last+1):gsub("^ +","")
    end
    if name=="" then return lines end
end

local function exhibitLayout(frame,name,fallback)
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    name=name~="" and name:gsub("%s+"," ") or fallback
    frame.exhibitLayouts=frame.exhibitLayouts or {}
    local layout=frame.exhibitLayouts[name]
    if layout then return layout end
    local lines=wrapExhibit(name,exhibitRows,10,false)
    if lines then
        layout={lines=lines,rows=exhibitRows,size=10}
    else
        for size=10,5,-1 do
            lines=wrapExhibit(name,compactRows,size,true)
            if lines then
                layout={lines=lines,rows=compactRows,size=size,compact=true}
                break
            end
        end
        layout=layout or {lines={name},rows=compactRows,size=10,compact=true}
    end
    frame.exhibitLayouts[name]=layout
    return layout
end

local function evidence(c, frame, t, confirmed, color, itemTaken)
    local exhibits = {
        {"item",frame.itemName,"Item","Submitted"}, {"scroll",frame.scrollName,"Scroll","Regrade"},
        {"charm",frame.charmName,"Charm",frame.charm and "Equipped" or "Empty"},
    }
    local itemX,itemY,itemSize
    for i, exhibit in ipairs(exhibits) do
        local arrives = smooth(clamp((t-(i-1)*0.19)/0.23))
        if arrives > 0 then
            local x = 206 + (i-1)*160 + (1-arrives)*(i%2==0 and 13 or -13)
            local y = 326 + (1-arrives)*40
            local alpha = 0.62+0.38*arrives
            local layout=exhibitLayout(frame,exhibit[2],exhibit[4])
            c.box(x,y,151,79,docket,alpha)
            c.box(x,y,151,2,(confirmed and i==1) and color or woodEdge,alpha)
            local iconY,iconWidth,iconHeight=13,48,45
            local titleX,titleWidth=63,82
            if layout.compact then
                iconY,iconWidth,iconHeight=5,31,29
                titleX,titleWidth=48,97
            end
            c.box(x+12,y+iconY,iconWidth,iconHeight,black,alpha*0.88)
            if i==1 then
                itemX,itemY=x+12+iconWidth/2,y+iconY+.5+iconHeight/2
                itemSize=math.min(iconWidth-6,iconHeight-5)
            end
            local itemVisible = i==1 and not itemTaken
            if itemVisible or (i==2 and frame.scroll) or (i==3 and frame.charm) then
                c.sprite(exhibit[1],x+15,y+iconY+3,iconWidth-6,iconHeight-5,alpha)
            elseif i==2 then
                scrollProp(c,x+16,y+iconY+6,iconWidth-8,iconHeight-10)
            elseif i==3 then
                charmProp(c,x+15,y+iconY+4,iconWidth-6,iconHeight-7,frame.charm and alpha or alpha*0.35)
            end
            c.text(exhibit[3],x+titleX,y+8,titleWidth,19,"small",paper,alpha)
            for index,line in ipairs(layout.lines) do
                local row=layout.rows[index]
                c.text(line,x+row[1],y+row[2],row[3],row[4],layout.size,subdued,alpha,true)
            end
        end
    end
    return itemX,itemY,itemSize
end

local function courtSpeech(c, speaker, text, color)
    c.box(204,247,491,55,black,0.94)
    c.box(204,247,3,55,color,0.92)
    c.text(speaker,216,249,104,50,"small",color)
    c.line(321,255,321,294,1,woodEdge,0.6)
    c.text(text,328,250,355,49,"body",paper)
end

local AGURU_REACH, AGURU_GRAB, AGURU_RUN, AGURU_EXIT = 380, 510, 1210, 1840
local AGURU_SIZE, AGURU_AT_EVIDENCE = 132, 135
local AGURU_TINT = {0.57,0.84,0.85}

local function stageSprite(c, key, x, y, size)
    local left = math.max(x,0)
    local right = math.min(x+size,720)
    if right<=left then return end
    if right-left<size then
        c.spritePart(key,left,y,right-left,size,(left-x)/size,0,(right-left)/size,1,1)
    else
        c.sprite(key,x,y,size,size,1)
    end
end

local function aguruHeist(c, age, exhibitX, exhibitY, exhibitSize)
    if age>=AGURU_EXIT then return end
    local x,y,pose = AGURU_AT_EVIDENCE, 255, 2
    if age<AGURU_REACH then
        local approach = age/AGURU_REACH
        x = mix(-AGURU_SIZE,AGURU_AT_EVIDENCE,1-(1-approach)^1.35)
        y = y-math.abs(math.sin(age/27))*3
        pose = math.floor(age/75)%2
    elseif age>=AGURU_RUN then
        local escape = (age-AGURU_RUN)/(AGURU_EXIT-AGURU_RUN)
        x = mix(AGURU_AT_EVIDENCE,720,escape*(0.65+0.35*escape))
        y = y-math.abs(math.sin((age-AGURU_RUN)/23))*6
        pose = 4+math.floor((age-AGURU_RUN)/66)%2
        for i=1,5 do
            local puffX = x+30-i*15
            if puffX>12 and puffX<683 then
                c.spritePart("glow",puffX,y+99+i*2,22+i*3,12+i,0,0,1,1,0.22*(1-i/6),subdued)
            end
        end
    elseif age>=AGURU_GRAB then
        y = y-math.sin((age-AGURU_GRAB)/175)*1.5
        pose = 3
    end
    local shadowX=x+26
    if shadowX>0 and shadowX<635 then
        c.spritePart("glow",shadowX,y+110,85,22,0,0,1,1,0.58,black)
    end
    stageSprite(c,"aguru"..pose,x,y,AGURU_SIZE)
    if age>=AGURU_GRAB then
        -- Lift the same icon out of the exhibit and keep it aligned to the carrying pose.
        local lift = smooth(clamp((age-AGURU_GRAB)/155))
        local size = mix(exhibitSize,33,lift)
        local gripY = y+89+(pose==5 and 1.8 or 0)
        local itemX = mix(exhibitX,x+103,lift)-size/2
        local itemY = mix(exhibitY,gripY,lift)-size/2
        stageSprite(c,"item",itemX,itemY,size)
    end
end

local function aguruSpeech(c)
    c.box(255,244,440,36,black,0.95)
    c.box(255,244,3,36,AGURU_TINT,0.94)
    c.line(331,250,331,274,1,woodEdge,0.65)
    c.text("Aguru",265,244,63,36,"small",AGURU_TINT)
    c.text("I need this for my build it's mine now",337,244,350,36,14,paper)
end

local courtReplies = {
    [0]={"Judge","Bailiff, the scraps."},
    [1]={"Judge","A lesser rank."},
    [2]={"Judge","Next case."},
    [3]={"Blacksmith","Back to the forge!"},
    [4]={"Blacksmith","That's more like it!"},
}
local celebrationReplies = {
    [2]={"Judge","Bring the gold gavel."},
    [3]={"Judge","One more for the jury!"},
}

local function verdict(c, frame, outcome, t, finale)
    local revealed = smooth(clamp((t-0.61)/0.13))
    local w = mix(292,418,revealed)
    local x, y = (720-w)/2, mix(142,154,revealed)
    c.box(x-3,y-3,w+6,90,black,0.93)
    c.box(x,y,w,84,linen,0.98)
    c.box(x,y,w,2,outcome.color,0.95)
    c.box(x,y+82,w,2,outcome.color,0.95)
    local heading = outcome.verdict
    if finale==2 then heading="THE GOLDEN GAVEL"
    elseif finale==3 then heading="COURTROOM ENCORE" end
    c.text(heading,x+12,y+9,w-24,24,"small",outcome.color)
    local hasCrest = frame.code==4
    c.text(outcome.title,x+9,y+32,w-(hasCrest and 74 or 18),43,hasCrest and "large" or 23,paper)
    if hasCrest then
        c.sprite("glow",x+w-59,y+16,51,51,0.78,gold)
        c.sprite("crest",x+w-53,y+19,42,42,1)
    end
end

local function hop(t, start, duration, height)
    return math.sin(pi*clamp((t-start)/duration))*height
end

local function courtSparkles(c, t)
    local q = clamp((t-0.61)/0.39)
    local fade = math.min(1,q*7)
    local origins = {{108,146},{360,110},{609,152}}
    for i=1,36 do
        local origin = origins[(i-1)%#origins+1]
        local angle = i*2.4
        local reach = 14+i%11*7+q*(23+i%5*8)
        local x = origin[1]+math.cos(angle)*reach
        local y = origin[2]+math.sin(angle)*reach*0.57+q*q*(47+i%7*20)
        if x>16 and x<704 and y>48 and y<415 then
            local light = 0.38+0.42*(0.5+0.5*math.sin(q*18+i*1.73))
            twinkle(c,x,y,i%6==0 and 4 or 1+i%4*0.61,light*fade,i%7==0 and amber or gold)
        end
    end
    -- Spread the smaller sparks above the benches and along the hall walls.
    for i=1,16 do
        local x = 25+(i*109)%663
        local y = 66+(i*47)%69
        if i%3==0 then
            x = (i%2==0 and 573 or 23)+(i*13)%99
            y = 153+(i*55)%155+q*70
        end
        local light = 0.23+0.48*(0.5+0.5*math.sin(q*15+i*1.91))
        twinkle(c,x+q*((i%5)*4-8),y+q*11,i%5==0 and 4 or 1.35+i%3*.66,light*fade,paper)
    end
end

local GOLD_STRIKE = 0.50
local GAVEL_PIVOT_X, GAVEL_PIVOT_Y = 630, 145
local GAVEL_SCALE = 182/384
-- The lowest edge of the +13-degree pose, centered on the block's brass face.
local strikeX = GAVEL_PIVOT_X + (100-190)*GAVEL_SCALE
local strikeY = GAVEL_PIVOT_Y + (192-113)*GAVEL_SCALE

local function goldenGavel(c,t,elapsed)
    local q=clamp((t-0.61)/0.39)
    local drop=smooth(clamp(q/0.34))
    local appear=smooth(clamp(q/0.16))
    local burgundy={0.43,0.15,0.23}
    for _,x in ipairs({195,571}) do
        local h=11+118*drop
        c.box(x-24,60,48,h,burgundy,0.97)
        c.box(x-23,60,2,h,gold,0.75)
        c.box(x+22,60,2,h,gold,0.75)
        c.line(x-23,60+h,x,73+h,2,gold)
        c.line(x+22,60+h,x,73+h,2,gold)
        c.sprite("crest",x-15,66+h*.33,30,30,drop)
        c.sprite("glow",x-34,54+h*.38,68,53,0.46*drop,gold)
    end

    local pivotX=GAVEL_PIVOT_X+22*(1-appear)
    local pivotY,angle
    if q<GOLD_STRIKE then
        local lift=smooth(clamp(q/0.27))
        local swing=clamp((q-0.29)/(GOLD_STRIKE-0.29))^2
        pivotY=mix(145,119,lift)+26*swing
        angle=mix(3,-32,lift)+45*swing
    else
        local rebound=math.sin(pi*clamp((q-GOLD_STRIKE)/0.24))
        pivotY=GAVEL_PIVOT_Y-12*rebound
        angle=13-25*rebound
    end
    local pose=math.floor((angle+32)/5+0.5)
    local rotation=(pose*5-32)*pi/180
    local cos,sin=math.cos(rotation),math.sin(rotation)
    c.spritePart("glow",503,76,204,160,0,0,1,1,appear*0.46,amber)

    local pulse=clamp((q-GOLD_STRIKE)/0.46)
    if q>=GOLD_STRIKE and pulse<1 then
        local size=mix(102,211,smooth(pulse))
        local opacity=(1-pulse)^1.6
        c.spritePart("goldGavelBurst",strikeX-size/2,strikeY-size*0.35,size,size*0.70,
            0,0,1,1,0.89*opacity)
        c.sprite("glow",strikeX-63,strikeY-63,126,126,0.52*opacity^4,gold)
        for i=1,15 do
            local direction=(i*2.39996)%(2*pi)
            local flight=smooth(pulse)
            local reach=(34+i%5*14)*flight
            local x=strikeX+math.cos(direction)*reach
            local y=strikeY+math.sin(direction)*reach*0.56-35*flight+14*pulse*pulse
            local spark=mix(8+i%4*3,3,pulse)
            if x<710 then c.sprite("goldGavelGleam",x-spark/2,y-spark/2,spark,spark,opacity) end
        end
    end
    local blockSize=106
    c.sprite("goldGavelBlock",strikeX+8-blockSize/2,strikeY-61*(blockSize/384),blockSize,blockSize/3,appear)
    c.sprite("goldGavel"..pose,pivotX-190*GAVEL_SCALE,pivotY-113*GAVEL_SCALE,182,224*GAVEL_SCALE,appear)
    if q>=GOLD_STRIKE and pulse<1 then
        c.sprite("goldGavelGleam",strikeX-23,strikeY-23,46,46,(1-pulse)^4)
    end

    -- Follow the highlights on the head and handle. These keep moving during the result hold.
    for i=1,2 do
        local phase=(elapsed/1160+(i-1)*0.48)%1
        local dx=(mix(91,330,phase)-190)*GAVEL_SCALE
        local dy=(mix(89,111,phase)-113)*GAVEL_SCALE
        local x=pivotX+dx*cos+dy*sin
        local y=pivotY-dx*sin+dy*cos
        local flare=math.sin(phase*pi)^2
        local size=13+10*flare
        c.sprite("goldGavelGleam",x-size/2,y-size/2,size,size,appear*flare*0.88)
    end
end

local function courtEncore(c,t)
    local q=clamp((t-0.61)/0.39)
    local lift=smooth(clamp(q/0.21))
    local lilac={0.73,0.52,1}
    local colors={cyan,lilac,gold}
    c.box(22,58,674,252,{0.1,0.07,0.2},0.31*lift)
    for i=1,6 do
        local x=42+(i-1)*126
        local sway=45*math.sin(q*9+i*1.3)
        local endX=math.max(24,math.min(698,x+sway))
        local tint=colors[(i-1)%#colors+1]
        c.line(x,65,endX,283,24,tint,0.14*lift)
        c.sprite("glow",endX-36,253,72,57,0.64*lift,tint)
        twinkle(c,x,73,5,lift,tint)
    end
    for i=1,15 do
        local p=(q*2.01+i*.188)%1
        local x=40+(i*97)%622+p*24
        local y=257-p*167+(i%4)*6
        local opacity=math.sin(p*pi)^2*lift
        local tint=colors[(i-1)%#colors+1]
        c.sprite("diamond",x,y,7,5,opacity,tint)
        c.line(x+6,y+2,x+6,y-10,2,tint,opacity)
        c.line(x+6,y-10,x+12,y-5,2,tint,opacity)
    end
end

local function drawTrial(c, frame)
    local elapsed = frame.elapsed or 0
    local t = frame.t or 0
    local outcome = frame.phase=="reveal" and outcomes[frame.code] or nil
    local confirmed = outcome and t>=0.61
    local aguruAge
    if confirmed and frame.code==0 then
        local duration = frame.duration or 4300
        aguruAge = math.max((t-0.61)*duration,elapsed-(frame.waitMs or 0)-0.61*duration)
    end
    local itemTaken = aguruAge and aguruAge>=AGURU_GRAB
    local celebrating = confirmed and frame.code==4
    local finale = celebrating and frame.celebrationVariant
    local panic = confirmed and (frame.code==0 or frame.code==1)
    local retreat = confirmed and frame.code==0 and smooth(clamp((t-0.70)/0.24)) or 0
    local bell = confirmed and clamp((t-0.61)/0.13) or 0
    local tint = confirmed and outcome.color or amber
    local judgeLift = outcome and math.sin(pi*clamp((t-0.32)/0.29))*5 or 0
    c.sprite("trialPlate",0,0,720,460,1)
    c.sprite("glow",250,78,220,157,0.34,amber)
    if celebrating then
        judgeLift = hop(t,0.63,0.16,33)+hop(t,0.82,0.14,21)
        if finale==2 then
            frame.cueAt=0.61+0.39*GOLD_STRIKE
            goldenGavel(c,t,elapsed)
        elseif finale==3 then
            courtEncore(c,t)
            judgeLift=hop(t,0.64,0.11,31)+hop(t,0.79,0.11,30)+hop(t,0.94,0.085,17)
        end
        c.sprite("glow",244,39,230,199,0.48+judgeLift*0.008,gold)
        local laughing=t<0.80 and math.floor(elapsed/145)%3~=0
        c.sprite(laughing and "judgeCheer" or "judgeSmile",292,76-judgeLift,136,157,1)
    else
        c.sprite("judge",292,76-judgeLift,136,157,1)
    end
    if retreat < 1 then
        local smithX = 34-retreat*30
        local smithY = 136+retreat*33+math.sin(elapsed/242)*(panic and 3 or 1)
        if celebrating then
            local smithLift = hop(t,0.65,0.17,40)+hop(t,0.85,0.14,28)
            if finale==3 then smithLift=hop(t,0.70,0.12,39)+hop(t,0.85,0.12,32) end
            smithY = smithY-smithLift
            c.sprite("glow",18,95,177,213,0.41+smithLift*0.006,amber)
            local laughing=t>=0.80 and math.floor(elapsed/145)%3~=0
            c.sprite(laughing and "smithCheer" or "smithSmile",smithX,smithY,145,190,1)
        else
            c.sprite(panic and "smithPanic" or "smith",smithX,smithY,145,190,1-retreat*0.8)
        end
    end
    bench(c,247,210,229,33)
    bench(c,23,306,161,101)
    bench(c,194,315,506,101)
    c.text("Court of Regrades",26,18,355,33,"title",paper)
    c.text(confirmed and "VERDICT" or "HEARING",508,22,169,26,"small",tint)
    c.text(retreat>=1 and "Witness fled" or "The Blacksmith",31,375,146,22,"small",panic and scarlet or amber)
    local exhibitTime = elapsed/1000
    if outcome then exhibitTime=math.max(exhibitTime,t*2.2) end
    local exhibitX,exhibitY,exhibitSize=evidence(c,frame,exhibitTime,confirmed,tint,itemTaken)

    if outcome and t>=0.31 and finale~=2 then
        local up = math.sin(pi*clamp((t-0.31)/0.6))
        local strike = clamp((t-0.55)/0.06)
        local gavelY = 169-70*up*(1-strike)
        local gavelX = 413+up*18
        c.sprite("gavel",gavelX,gavelY,confirmed and 90 or 97,63,confirmed and 0.78 or 1)
    end
    if confirmed then
        if bell < 1 and finale~=2 then
            c.sprite("glow",337,117,180,156,(1-bell)*0.84,tint)
            burst(c,416,214,bell,frame.code==4 and 17 or 11,frame.code==4 and 168 or 109,tint)
        end
        local reply = celebrationReplies[finale] or courtReplies[frame.code]
        if celebrating and not celebrationReplies[finale] then courtSparkles(c,t) end
        if not itemTaken then courtSpeech(c,reply[1],reply[2],tint) end
        verdict(c,frame,outcome,t,finale)
        if aguruAge then
            aguruHeist(c,aguruAge,exhibitX,exhibitY,exhibitSize)
            if itemTaken then aguruSpeech(c) end
        end
    else
        courtSpeech(c,"Clerk","Exhibits ready.",cyan)
    end
    local footerText = confirmed and frame.code~=0 and frame.grade or oddsLabel(frame.chance)
    c.text(footerText,94,425,532,20,"small",subdued)
end

Scenes.pinball = {label="Pinball Foundry", duration=PLINKO_MS, draw=drawPinball}
Scenes.trial = {label="Court of Regrades", duration=4300, draw=drawTrial}
return Scenes
