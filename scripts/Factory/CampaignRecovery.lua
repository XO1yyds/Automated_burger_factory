local G=require('Factory/ConveyorGeometry')
local Area=require('Factory/AutomationArea')
local Items=require('Factory/Items')
local Automatic=require('Factory/AutomaticWorkstation')
local Recovery={}
-- Predict the existing queue-ordered spill without mutating containers or ground.
-- The selected object is excluded because actual removal happens before spilling.
function Recovery.Forecast(c,station,beltId)
    local contents={}; local x,z=station and station.x or 0,station and station.z or 0
    local ignoredBelt
    if station then
        local m=c.machines[station.id]; local store=c.logistics.buffers[station.id]
        if m then
            local slots={}; for _,s in pairs(m.slots) do slots[#slots+1]=s end
            table.sort(slots,function(a,b) return a.order<b.order end)
            for _,s in ipairs(slots) do contents[#contents+1]=s.itemType end
            for _,kind in ipairs(Automatic.RetrievalOrder) do if m.materials[kind] then contents[#contents+1]=kind end end
            if m.burgerReady then contents[#contents+1]='burger' end
        elseif store then contents=store:Contents() end
    elseif beltId then
        for _,belt in ipairs(c.logistics.network.belts) do if belt.id==beltId then
            ignoredBelt=belt; x,z=G.Position(belt.points,belt.length/2)
            for _,item in ipairs(belt.cargo) do contents[#contents+1]=item.itemType end
        end end
    end
    local chosen,lost={},{}
    local function free(px,pz)
        if not Area.At(px,pz,0.36,0.36) then return false end
        for _,s in ipairs(c.stations) do if s~=station and not s.marker and math.abs(px-s.x)<=s.width/2+0.18 and math.abs(pz-s.z)<=s.depth/2+0.18 then return false end end
        if not c.logistics.network:Clear(px,pz,0.36,0.36,ignoredBelt) then return false end
        for _,item in pairs(c.items.ground) do if math.abs(px-item.position.x)<0.36 and math.abs(pz-item.position.z)<0.36 then return false end end
        for _,p in ipairs(chosen) do if math.abs(px-p.x)<0.36 and math.abs(pz-p.z)<0.36 then return false end end
        return true
    end
    for _,kind in ipairs(contents) do
        local done=false
        for ring=0,9 do
            if done then break end
            for step=0,31 do
                local a=step*math.pi/16; local px,pz=x+math.cos(a)*ring*0.45,z+math.sin(a)*ring*0.45
                if free(px,pz) then chosen[#chosen+1]={x=px,z=pz}; done=true; break end
            end
        end
        if not done then lost[kind]=(lost[kind] or 0)+1 end
    end
    local text={}
    for _,kind in ipairs({'bun','raw_beef','cooked_beef','lettuce','burger'}) do if lost[kind] then text[#text+1]=Items.Definitions[kind].name..'×'..lost[kind] end end
    return table.concat(text,'、'),lost
end
return Recovery
