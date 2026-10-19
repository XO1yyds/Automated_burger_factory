local Codec=require('Factory/SaveCodec')
local Config=require('Factory/DayConfig')
local Buildings=require('Factory/Buildings')
local Items=require('Factory/Items')
local World={}
local function fields(object,excluded)
    local data={}
    for k,v in pairs(object) do if not excluded[k] and type(v)~='function' then data[k]=v end end
    return data
end
function World.Capture(c,dayStart)
    local stations,ground={},{}
    for _,s in ipairs(c.stations) do
        local d={}; for _,key in ipairs({'id','name','baseName','component','x','z','width','depth','quarter','automaticKind','buildingKind','destination','marker','interactive','cylinder'}) do d[key]=s[key] end
        d.color={s.color.r,s.color.g,s.color.b}; stations[#stations+1]=d
    end
    for id,item in pairs(c.items.ground) do ground[id]={id=id,itemType=item.itemType,x=item.position.x,z=item.position.z,identity=item.identity} end
    return {campaign=c.campaign,loop=fields(c.loop,{orders=true,campaign=true}),
        orders=fields(c.orders,{items=true,config=true,deliveryStores=true,onDelivered=true,random=true}),
        manual=fields(c.manual,{items=true}),stations=stations,machines=c.machines,stores=c.logistics.buffers,
        conveyor=fields(c.logistics.network,{context=true}),cables=fields(c.automation.cables,{context=true}),
        service=fields(c.automation.service,{context=true,cables=true}),
        player={x=c.player.position.x,z=c.player.position.z,fx=c.facing.x,fz=c.facing.z,area=c.area},
        items={held=c.items.held,heldIdentity=c.items.heldIdentity,nextId=c.items.nextId,ground=ground},
        nextBuildingId=c.nextBuildingId,dayStart=dayStart}
end
function World.Clone(state) return Codec.Unpack(Codec.Pack(state)) end
function World.Validate(s)
    local ok=pcall(function()
        assert(type(s)=='table' and type(s.campaign)=='table' and type(s.loop)=='table')
        local c=s.campaign; assert(type(c.coins)=='number' and c.coins>=0 and c.coins%1==0)
        assert(type(c.owned)=='table' and type(c.events)=='table' and type(c.lessons)=='table' and type(c.machineTimes)=='table')
        assert(type(c.day)=='number' and c.day%1==0 and c.day>=1 and c.day<=10 and s.loop.day==c.day)
        assert(type(s.stations)=='table' and #s.stations>=9 and #s.stations<=5000)
        assert(type(s.machines)=='table' and type(s.stores)=='table' and type(s.conveyor)=='table' and type(s.cables)=='table' and type(s.service)=='table')
        assert(type(s.service.queues)=='table' and type(s.cables.edges)=='table' and type(s.cables.bindings)=='table' and type(s.conveyor.belts)=='table')
        assert(({title=true,preparation=true,running=true,paused=true,settlement=true,complete=true})[s.loop.state] and type(s.loop.history)=='table')
        assert(type(s.loop.remaining)=='number' and s.loop.remaining>=0 and s.loop.remaining<=Config.Day(c.day).seconds)
        assert(type(s.player)=='table' and type(s.player.x)=='number' and type(s.player.z)=='number')
        assert(s.player.area=='shop' or s.player.area=='workshop')
        assert(type(s.items)=='table' and type(s.items.ground)=='table' and (not s.items.held or Items.Definitions[s.items.held]))
        local ids,source={},{supply_raw=0,supply_bun=0,supply_lettuce=0}
        for _,v in ipairs(s.stations) do
            assert(type(v.id)=='string' and not ids[v.id]); ids[v.id]=true
            assert(type(v.x)=='number' and type(v.z)=='number' and type(v.width)=='number' and type(v.depth)=='number')
            assert(not v.buildingKind or Buildings.Definitions[v.buildingKind]); assert(not v.automaticKind or v.automaticKind=='cooker' or v.automaticKind=='assembler')
            if source[v.buildingKind] then source[v.buildingKind]=source[v.buildingKind]+1; assert(v.id==Config.SupplyIds[v.buildingKind]) end
        end
        for kind,n in pairs(source) do assert(n+(c.owned[kind] or 0)==(c.suppliesGranted and 1 or 0)) end
        for _,v in pairs(s.items.ground) do assert(Items.Definitions[v.itemType] and type(v.x)=='number' and type(v.z)=='number') end
        for id,store in pairs(s.stores) do
            assert(ids[id] and (store.capacity==6 or store.capacity==24)); local count=0
            for _,slot in pairs(store.slots) do assert(Items.Definitions[slot.itemType]); count=count+1 end
            assert(count<=store.capacity)
        end
        for id in pairs(s.machines) do assert(ids[id]) end
        for _,belt in ipairs(s.conveyor.belts) do
            assert(type(belt.cells)=='table' and #belt.cells>0 and belt.length>0)
            for _,cargo in ipairs(belt.cargo) do assert(Items.Definitions[cargo.itemType] and cargo.distance>=0) end
        end
    end)
    return ok
end
return World
