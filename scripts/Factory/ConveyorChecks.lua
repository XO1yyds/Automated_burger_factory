local G = require("Factory/ConveyorGeometry")
local Network = require("Factory/ConveyorNetwork")
local Buffer = require("Factory/BufferStorage")
local Automatic = require("Factory/AutomaticWorkstation")
local Builder = require("Factory/ConveyorBuilder")
local Items = require("Factory/Items")
local Checks = {}

---@param runtimeItems? FactoryItemService
function Checks.Run(runtimeItems)
    local count, failures, results = 0, 0, {}
    local function check(name, passed)
        count = count + 1; passed = not not passed
        if not passed then failures = failures + 1 end
        table.insert(results, { name = name, passed = passed })
        print("[Conveyor QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local function node() return { Remove = function() end } --[[@as Node]] end
    local items = runtimeItems or Items.New({ createHeld = function() return node() end,
        createGround = function() return node() end, isSpotFree = function() return true end,
        isLineClear = function() return true end, onAdded = function() end, onRemoved = function() end })
    items:Reset()
    local function world()
        local endpoints, obstacles = {}, {}
        local network = Network.New({ resolve = function(id) return endpoints[id] end,
            endpoints = function()
                local list = {}; for _, ep in pairs(endpoints) do table.insert(list, ep) end
                table.sort(list, function(a,b) return a.id < b.id end); return list
            end,
            free = function(x,z,w,d)
                if math.abs(x) + w/2 > 12 or math.abs(z) + d/2 > 12 then return false end
                for _, ep in pairs(endpoints) do if G.Overlap(x,z,w,d,ep.x,ep.z,ep.width,ep.depth) then return false end end
                for _, ep in ipairs(obstacles) do if G.Overlap(x,z,w,d,ep.x,ep.z,ep.width,ep.depth) then return false end end
                return true
            end })
        local function add(id, kind, x, z, value)
            local ep = { id=id,name=id,kind=kind,x=x,z=z,width=1,depth=1,area="workshop",quarter=0 }
            if kind=="source" then ep.source=value
            elseif kind=="buffer" then ep.storage=Buffer.New()
            elseif kind=="cooker" or kind=="assembler" then ep.machine=Automatic.New(kind,items) end
            endpoints[id]=ep; return ep
        end
        local function port(id, side)
            for _, value in ipairs(G.Ports(endpoints[id])) do if value.side==side then return value end end
            error("port absent")
        end
        local function connect(a,b,sa,sb)
            local plan = assert(network:Plan(a,b,sa and port(a,sa),sb and port(b,sb)))
            local ok,message,belt=network:Place(plan); assert(ok,message); return assert(belt)
        end
        return network, endpoints, add, connect, port, obstacles
    end
    local n, ep, add, connect, port = world()
    add("source","source",-5,0,"bun"); local sink=add("sink","buffer",5,0)
    local belt=connect("source","sink",1,3)
    check("grid ports remain on building border", belt.from.x==-4.5 and belt.to.x==4.5)
    check("route has one input and one output", belt.from.id=="source" and belt.to.id=="sink")
    check("physical length is measured", math.abs(belt.length-9)<0.000001)
    n:Update(0.05); n:Update(2)
    check("cargo moves half a grid each second", math.abs(belt.cargo[1].distance-1)<0.000001)
    check("no instantaneous source-to-destination transfer", sink.storage:Count()==0)
    n:Update(17)
    check("cargo arrives only after traversing its route", sink.storage:Count()>0)
    n:Update(100)
    check("storage capacity remains six", sink.storage:Count()==6)
    check("n occupied grid cells hold at most n cargo", #belt.cargo==#belt.cells)
    check("downstream saturation stops source pickup", not Network.Room(belt))
    local before=#belt.cargo+sink.storage:Count(); n:Update(20)
    check("saturated inventory does not grow or disappear", before==#belt.cargo+sink.storage:Count())
    local typeBefore=assert(sink.storage:PeekOutput()); assert(sink.storage:TakeOutput(typeBefore)); n:Update(0.05)
    check("freeing destination resumes blocked output", sink.storage:Count()==6)
    check("same path cannot be stacked", not n:Place(assert(n:Plan("source","sink",port("source",1),port("sink",3)))))
    check("source cannot be an input endpoint", not assert(n:Plan("sink","source")).valid)
    check("self connection is rejected", not assert(n:Plan("source","source")).valid)
    ep.sink.area="shop"
    check("cross-area connection rejected", not assert(n:Plan("source","sink")).valid)
    ep.sink.area="workshop"
    local seen={}; local unique=true
    for _, cargo in ipairs(belt.cargo) do if seen[cargo.id] then unique=false end; seen[cargo.id]=true end
    check("cargo identities are unique",unique)

    n,ep,add,connect,port=world()
    add("wrong","source",-5,0,"bun"); local cooker=add("cook","cooker",5,0)
    belt=connect("wrong","cook",1,3); n:Update(60)
    check("belts do not filter incompatible material",#belt.cargo>0 and belt.cargo[1].itemType=="bun")
    check("machine rejects illegal input at belt tail",next(cooker.machine.slots)==nil and Network.Ready(belt))
    local contents, removed=n:Remove(belt.id)
    check("whole-belt removal returns every cargo in queue order",removed==belt and #contents==#belt.cargo)
    check("removing belt clears occupied footprint",n:Clear(0,0,0.8,0.8))

    n,ep,add,connect,port=world()
    local j=add("j","junction",0,0)
    add("north","source",0,5,"bun"); add("west","source",-5,0,"lettuce"); add("south","source",0,-5,"raw_beef")
    local out=add("out","buffer",5,0)
    local b1=connect("north","j",2,0)
    n:Update(20)
    check("input-only junction remains buildable but passive",Network.Ready(b1) and n.total==0)
    local b2=connect("west","j",1,3); local b3=connect("south","j",0,2); local bo=connect("j","out",1,3)
    n:Update(12)
    local initial1, initial2, initial3 = b1.delivered, b2.delivered, b3.delivered
    n:Update(88)
    check("three-in one-out merge transports all three types",out.storage:Count()==6)
    local types={}; for _, value in pairs(out.storage.slots) do types[value.itemType]=true end
    check("merge does not introduce a material filter",types.bun and types.lettuce and types.raw_beef)
    check("merge fairly arbitrates simultaneously ready inputs",math.max(b1.delivered-initial1,b2.delivered-initial2,b3.delivered-initial3)-math.min(b1.delivered-initial1,b2.delivered-initial2,b3.delivered-initial3)<=1)
    check("junction has no extra inventory or movement speed",j.storage==nil and j.machine==nil)
    check("one output is the merge throughput bottleneck",b1.delivered+b2.delivered+b3.delivered==bo.delivered+#bo.cargo)

    n,ep,add,connect,port=world()
    add("j","junction",0,0); add("in","source",-5,0,"bun")
    local top=add("top","buffer",0,5); local right=add("right","buffer",5,0); local bottom=add("bottom","buffer",0,-5)
    connect("in","j",1,3); local topB=connect("j","top",0,2); local rightB=connect("j","right",1,3); local bottomB=connect("j","bottom",2,0)
    n:Update(100)
    check("one-in three-out splitter serves every branch",top.storage:Count()==6 and right.storage:Count()==6 and bottom.storage:Count()==6)
    check("splitter distributes equally on available outputs",math.max(#topB.cargo,#rightB.cargo,#bottomB.cargo)-math.min(#topB.cargo,#rightB.cargo,#bottomB.cargo)<=1)

    n,ep,add,connect,port=world()
    add("j","junction",0,0); add("n","source",0,5,"bun"); add("w","source",-5,0,"lettuce")
    add("e","buffer",5,0); add("s","buffer",0,-5)
    connect("n","j",2,0); connect("w","j",1,3); connect("j","e",1,3)
    local invalid=assert(n:Plan("j","s",port("j",2),port("s",0)))
    check("ordinary two-in two-out combination rejected",not invalid.valid and not n:Place(invalid))

    n,ep,add,connect,port=world()
    local iso=add("iso","isolator_straight",0,0); add("n","source",0,5,"bun"); add("w","source",-5,0,"lettuce")
    local e=add("e","buffer",5,0); local s=add("s","buffer",0,-5)
    connect("n","iso",2,0); connect("iso","s",2,0); connect("w","iso",1,3); connect("iso","e",1,3)
    n:Update(100)
    local clean=true
    for _, value in pairs(e.storage.slots) do clean=clean and value.itemType=="lettuce" end
    for _, value in pairs(s.storage.slots) do clean=clean and value.itemType=="bun" end
    check("straight isolator supports independent two-in two-out",e.storage:Count()==6 and s.storage:Count()==6)
    check("isolator channels never cross-contaminate",clean)
    check("isolator has no shared or per-channel inventory",iso.storage==nil)
    iso.kind,iso.quarter="isolator_corner",0
    check("corner channel pairs north-east",Network.Channel(iso,0)==Network.Channel(iso,1))
    check("corner channel pairs south-west independently",Network.Channel(iso,2)==Network.Channel(iso,3) and Network.Channel(iso,0)~=Network.Channel(iso,2))
    iso.quarter=1
    check("rotating corner rotates pairing",Network.Channel(iso,1)==Network.Channel(iso,2) and Network.Channel(iso,3)==Network.Channel(iso,0))

    n,ep,add,connect,port=world()
    add("a","buffer",-5,0); add("b","buffer",5,0)
    connect("a","b",1,3)
    invalid=assert(n:Plan("b","a"))
    check("directed loops are rejected even through buffers",not invalid.valid)

    n,ep,add,connect,port=world()
    add("in","source",-5,0,"bun"); add("j","junction",0,0); out=add("out","buffer",5,0)
    b1=connect("in","j",1,3); bo=connect("j","out",1,3)
    n:Update(5); local savedCargo=#b1.cargo+#bo.cargo
    ep.j=nil; n:Update(30)
    check("deleting junction retains belts and queued items",#n.belts==2 and #b1.cargo+#bo.cargo>=savedCargo)
    check("dangling belt blocks without hidden transfer",b1.state:find("断头带",1,true)~=nil)
    local replacement=add("replacement","junction",0,0); n:Reattach(replacement)
    check("replacement junction reattaches dangling ends",b1.to.id=="replacement" and bo.from.id=="replacement")
    n:Update(40)
    check("reattached line resumes without losing cargo",out.storage:Count()>0)

    n,ep,add,connect,port=world()
    add("left","junction",-3,0); add("right","junction",3,0)
    local missing=connect("left","right",1,3)
    ep.left,ep.right=nil,nil
    local left=add("left_new","junction",-3,0); n:Reattach(left)
    check("one end reattaches while opposite building is still absent",missing.from.id=="left_new" and missing.to.id=="right")
    local right=add("right_new","junction",3,0); n:Reattach(right)
    check("two rebuilt junctions restore their dangling route",missing.to.id=="right_new" and n:Topology(missing.from,missing.to,missing))

    local storage=Buffer.New()
    for _=1,6 do assert(storage:Receive("bun")) end
    check("buffer rejects seventh item",not storage:Receive("lettuce") and storage:Count()==6)
    local kind,token=storage:PeekOutput(); assert(storage:TakeOutput(assert(kind),token)); assert(storage:Receive("lettuce"))
    check("buffer output follows last-in first-out order",storage:PeekOutput()=="lettuce")
    local selected=storage.slots[2]; assert(items:Give("raw_beef")); local heldNode=items.heldNode
    check("stale buffer selection cannot swap another item",not storage:TakeOrSwap(2,999999,items) and items.heldNode==heldNode)
    check("valid selection swaps held and stored item",storage:TakeOrSwap(2,selected.id,items) and items.held=="bun" and storage.slots[2].itemType=="raw_beef" and storage:Count()==6)
    items:Reset(); selected=storage.slots[2]
    check("empty-hand selection retrieves exact chosen item",storage:TakeOrSwap(2,selected.id,items) and items.held=="raw_beef" and storage:Count()==5)
    check("selection cannot retrieve the same item twice",not storage:TakeOrSwap(2,selected.id,items))
    check("held material can be deposited into selected empty slot",storage:TakeOrSwap(2,0,items) and items.held==nil and storage:Count()==6)
    items:Reset()

    n,ep,add,connect,port=world()
    add("a","source",-5,0,"bun"); add("b","buffer",5,0)
    local builder=Builder.New(n); builder:Open(-5,0)
    check("builder starts with world source selection",builder.mode=="source")
    check("source selection advances to destination",builder:Select("a") and builder.mode=="destination")
    check("destination selection generates adjustment preview",builder:Select("b") and builder.mode=="adjust" and builder.plan~=nil)
    check("F without confirm-button focus cannot place",not builder:Confirm() and #n.belts==0)
    builder.focus,builder.button="buttons",1
    check("focused confirm places and starts the next source selection",builder:Confirm() and #n.belts==1 and builder.mode=="source" and builder.sourceId==nil and builder.plan==nil)
    builder:Open(0,0); builder:Select("a"); builder:Select("b"); builder:Back()
    check("right back from adjustment returns destination selection",builder.mode=="destination")
    builder:Back(); check("right back from destination returns source selection",builder.mode=="source")
    builder:Back(); check("right back from source returns building home signal",builder.mode=="idle")

    local obstacles
    n,ep,add,connect,port,obstacles=world()
    add("a","source",-5,0,"bun"); add("b","buffer",5,0)
    table.insert(obstacles,{x=0,z=0,width=1,depth=24})
    local preview=assert(n:Plan("a","b"))
    check("no legal path still returns editable preview",not preview.valid and #preview.cells>0)
    check("invalid preview cannot be confirmed",not n:Place(preview) and #n.belts==0)
    table.remove(obstacles)
    builder=Builder.New(n); builder:Open(0,0); builder:Select("a"); builder:Select("b")
    builder:MoveSelection(1,false,0,3)
    check("segment drag produces orthogonal path with attached endpoints",builder.plan.cells[1].x==builder.plan.from.cx and builder.plan.cells[#builder.plan.cells].x==builder.plan.to.cx)
    check("segment drag changes intermediate shape",#G.Simplify(builder.plan.cells)>2)
    local beforeFrom=builder.plan.from.id; builder:Reverse()
    check("preview direction reversal exchanges endpoint roles",builder.plan.to.id==beforeFrom)
    local version=#n.belts; builder:Cancel()
    check("cancel never removes committed belts",#n.belts==version)
    print("[Conveyor QA] COMPLETE checks="..count.." failures="..failures)
    return { passed=count-failures, failed=failures, results=results }
end

return Checks
