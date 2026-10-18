local G=require("Factory/ConveyorGeometry")
local Network=require("Factory/ConveyorNetwork")
local Builder=require("Factory/ConveyorBuilder")
local Buildings=require("Factory/Buildings")
local Buffer=require("Factory/BufferStorage")
local Checks={}

function Checks.Run()
    local count,failed,results=0,0,{}
    local function check(name,ok)
        count=count+1; ok=not not ok; if not ok then failed=failed+1 end
        table.insert(results,{name=name,passed=ok})
        print("[Conveyor Editing QA] "..(ok and "PASS " or "FAIL ")..name)
    end
    local endpoints={
        a={id="a",name="a",kind="buffer",area="workshop",x=-6,z=0,width=1,depth=1,storage=Buffer.New()},
        b={id="b",name="b",kind="buffer",area="workshop",x=1,z=5,width=1,depth=1,storage=Buffer.New()},
    }
    local network=Network.New({resolve=function(id) return endpoints[id] end,endpoints=function() return {endpoints.a,endpoints.b} end,
        free=function(x,z,w,d)
            if math.abs(x)+w/2>15 or math.abs(z)+d/2>15 then return false end
            for _,ep in pairs(endpoints) do if G.Overlap(x,z,w,d,ep.x,ep.z,ep.width,ep.depth) then return false end end
            return true
        end})
    local function port(ep,side) for _,p in ipairs(G.Ports(ep)) do if p.side==side then return p end end; error("port") end
    local from,to=port(endpoints.a,1),port(endpoints.b,2)
    ---@type FactoryGridPoint[]
    local u={{x=-5,z=0},{x=5,z=0},{x=5,z=3},{x=1,z=3},{x=1,z=4}}
    local function builder(points)
        local b=Builder.New(network); b.mode="adjust"; b.sourceId,b.destinationId="a","b"
        b.plan=network:MakePlan(from,to,assert(G.Cells(points or u))); b.selected,b.handle=2,true; return b
    end
    local function signature(b)
        local list={}; for _,p in ipairs(G.Simplify(b.plan.cells)) do table.insert(list,p.x..":"..p.z) end
        return table.concat(list,";")
    end
    local function simple(b)
        local seen={}
        for i,p in ipairs(b.plan.cells) do
            local key=G.Key(p.x,p.z)
            if seen[key] or (i>1 and G.Distance(b.plan.cells[i-1],p)~=1) then return false end
            seen[key]=true
        end
        return b.plan.cells[1].x==b.plan.from.cx and b.plan.cells[1].z==b.plan.from.cz
            and b.plan.cells[#b.plan.cells].x==b.plan.to.cx and b.plan.cells[#b.plan.cells].z==b.plan.to.cz
    end
    local b=builder(); local original=signature(b)
    check("reference U route starts legal",b.plan.valid)
    b:BeginEdit(2,true); b:MoveBy(-4,0)
    local p=G.Simplify(b.plan.cells)
    check("moving U corner propagates the neighboring vertical run",p[2].x==1 and #p==3)
    check("overlapping reverse runs collapse to one L route",simple(b) and b.plan.valid and b.plan.length<14)
    b:MoveBy(4,0)
    check("inverse keyboard movement restores original U without extra corners",signature(b)==original)
    for _=1,12 do b:MoveBy(-1,0); b:MoveBy(1,0) end
    check("repeated opposite keystrokes do not grow a spiral",signature(b)==original and simple(b))
    b:EndEdit(); check("ending edit releases original snapshot",not b.editing and b.editPlan==nil)
    b=builder(); b:BeginEdit(3,false); b:MoveBy(0,-3)
    check("dragging return segment onto outgoing segment merges it",#G.Simplify(b.plan.cells)==3 and simple(b) and b.plan.valid)
    b:MoveBy(0,3)
    check("segment reverse restores original shape and endpoint ports",signature(b)==original and b.plan.from.key==from.key and b.plan.to.key==to.key)
    b=builder(); b:BeginEdit(3,true); b:MoveSelection(3,true,7,4)
    p=G.Simplify(b.plan.cells)
    check("interior corner moves both adjacent straight runs",p[2].x==7 and p[3].x==7 and p[3].z==4 and simple(b))
    b=builder(); b:BeginEdit(2,true)
    local allSimple=true
    for x=-8,9 do for z=-3,7 do b:MoveSelection(2,true,x,z); allSimple=allSimple and simple(b) end end
    check("corner sweep keeps routes orthogonal attached and loop free",allSimple)
    b:MoveSelection(2,true,5,0)
    check("large drag and exact return restores original route",signature(b)==original)
    b=builder(); b:BeginEdit(1,false); b:MoveBy(0,2); local shifted=signature(b)
    check("first segment creates a connected orthogonal offset",simple(b) and shifted~=original)
    b:MoveBy(0,-2); check("first segment offset retracts without an extra loop",signature(b)==original)
    b=builder(); b:BeginEdit(4,false); b:MoveBy(2,0)
    check("last segment remains attached to input port",simple(b))
    b:MoveBy(-2,0); check("last segment inverse retracts",signature(b)==original)

    b=builder(); b.selected,b.handle=2,true
    b:Navigate(0,1); local target=b:SelectedTarget()
    check("W chooses a visually higher target",target.z>0 and target.x==5)
    b:Navigate(0,-1); target=b:SelectedTarget()
    check("S chooses a visually lower target",target.z==0 and target.x==5)
    b:Navigate(-1,0); target=b:SelectedTarget()
    check("A chooses a visually left target",target.x<5 and target.z==0)
    b:Navigate(1,0); target=b:SelectedTarget()
    check("D chooses a visually right target",target.x==5 and target.z==0)
    b.selected,b.handle=1,true; b:Navigate(-1,0)
    check("direction with no target stays selected instead of wrapping",b.selected==1 and b.handle)

    b=Builder.New(network); b:Open(-6,0); b:Select("a"); b:SetCursor(0,-3)
    check("after A selection an uncommitted preview follows the cursor",b.mode=="destination" and b.hoverPlan and b.hoverPlan.from.id=="a" and b.hoverPlan.to.x==0 and b.hoverPlan.to.z==-3 and b.plan==nil)
    local revision=b.revision; b:SetCursor(2,-2)
    check("cursor movement replaces preview without placing cargo or belts",b.revision>revision and b.hoverPlan.to.x==2 and #network.belts==0 and network.total==0)
    b:SetCursor(1,5)
    check("hovering B snaps preview to its actual border",b.hoverPlan.to.id=="b" and b.mode=="destination")
    check("hover alone never confirms destination or placement",not b:Confirm() and #network.belts==0)
    b:Select("b"); b.focus,b.button="buttons",1
    check("confirmed belt starts fresh A selection",b:Confirm() and #network.belts==1 and b.mode=="source" and not b.sourceId and not b.destinationId and not b.hoverPlan and not b.editing)
    b:Select("b"); b:SetCursor(6,7)
    check("a second placement round has a new source preview",b.hoverPlan.from.id=="b" and b.mode=="destination")
    b:Back(); check("back clears provisional destination preview",b.mode=="source" and b.hoverPlan==nil)

    local created=0
    local build=Buildings.New({valid=function() return true,"ok" end,
        create=function(kind,x,z,q) created=created+1; return {id="created"..created,name="created",buildingKind=kind,x=x,z=z,quarter=q,width=1,depth=1} --[[@as FactoryStation]] end,
        update=function() end,remove=function() return true,"ok" end,processing=function() return false end})
    local origin={x=0,z=0} --[[@as Vector3]]
    build:Choose("junction",origin,{x=0,z=1} --[[@as Vector3]])
    build:Pointer(3,2,true,false,true)
    check("unfixed building preview follows mouse",build.x==3 and build.z==2 and not build.previewPinned)
    build:Pointer(3,2,false,true,true)
    check("scene click pins preview but creates no building",build.previewPinned and created==0)
    build:Pointer(8,6,true,false,true)
    check("pinned preview ignores later mouse motion",build.x==3 and build.z==2)
    build.confirmFocus=true; build:Pointer(3,2,false,true,false)
    check("clicking pinned projection or occupied world keeps pin",build.previewPinned and build.confirmFocus)
    build:Pointer(8,6,false,true,true)
    check("blank scene click only unlocks pinned preview",not build.previewPinned and build.x==3 and build.z==2 and created==0 and not build.confirmFocus)
    build:Pointer(7,5,true,false,true)
    check("mouse tracking resumes after unlock",build.x==7 and build.z==5)
    build:Pointer(7,5,false,true,true); build:Move(1,0)
    check("keyboard nudge keeps mouse pin",build.previewPinned and build.x==8)
    check("pinning does not bypass confirm button gate",not build:Confirm(origin) and created==0)
    build.confirmFocus=true; local placed=build:Confirm(origin)
    check("confirm places once and resets pin for continuous building",placed and created==1 and not build.previewPinned and build.mode=="preview")
    build:Pointer(0,0,false,true,true); build:Escape()
    check("canceling building preview clears pin",build.mode=="menu" and not build.previewPinned)
    print("[Conveyor Editing QA] COMPLETE checks="..count.." failures="..failed)
    return {passed=count-failed,failed=failed,results=results}
end
return Checks
