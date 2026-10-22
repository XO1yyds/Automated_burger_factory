-- Opt-in native visual fixture. Start under a dedicated LocalSave.Files namespace.
-- Never enabled in the delivered entry point; no player save is read or written.
local Art=require('Factory/StaticArt')
local Cable=require('Factory/CableNetwork')
local Checks={}
function Checks.Run(c,r,h)
    c.loop:Prepare(); c.loop.briefing=false; c.loop.teaching=false
    c.campaign.day,c.loop.day,c.campaign.coins=10,10,10000
    h.ensure(); assert(h.switch('workshop')); c=h.context()
    c.player.position=Vector3(-29,0.55,2.2)
    c.player:GetComponent('RigidBody').position=c.player.position
    c.cameraNode.position=Vector3(-40,30.2,1)
    local function place(kind,x,z,q)
        local b=c.buildings; b:Choose(kind,c.player.position,c.facing); b:SetPosition(x,z); b.quarter=q or 0; b.confirmFocus=true
        assert(b:Confirm(c.player.position)); local s=b.records[#b.records]; b:Cancel(); return s
    end
    local cooker=place('cooker',-49,6)
    local rotated=place('cooker',-44,6,1)
    local assembler=place('assembler',-39,6)
    local buffer=place('buffer',-34,6)
    local stock=place('storage',-29,5)
    local plain=place('storage',-49,0,1)
    place('junction',-44,0); place('isolator_straight',-41,0);place('isolator_corner',-38,0)
    assert(c.components:Bind(stock.id,'order')); assert(c.components:Bind(buffer.id,'delivery'))
    for _,kind in ipairs({'bun','raw_beef','cooked_beef','lettuce','burger','bun'}) do assert(c.logistics.buffers[buffer.id]:Receive(kind)) end
    for _,kind in ipairs({'burger','cooked_beef','raw_beef','bun','lettuce'}) do assert(c.logistics.buffers[stock.id]:Receive(kind)) end
    for i=1,18 do assert(c.logistics.buffers[plain.id]:Receive('burger')) end
    for _,id in ipairs({cooker.id,rotated.id}) do
        for i,kind in ipairs({'raw_beef','cooked_beef','raw_beef'}) do c.machines[id].slots[i]={itemType=kind,progress=0,order=i,completedAt=1} end
    end
    c.machines[assembler.id].materials={bun=true,cooked_beef=true,lettuce=true}
    local plan=assert(c.logistics.network:Plan(buffer.id,stock.id)); assert(c.logistics.network:Place(plan))
    c.logistics.network:Update(1); c.logistics:Refresh()
    local wire=c.automation.cables
    for _,id in ipairs({cooker.id,assembler.id,buffer.id}) do
        local a={id=stock.id,key=wire:Anchor(c.logistics:Endpoint(stock.id))};local b={id=id,key=wire:Anchor(c.logistics:Endpoint(id))}
        assert(wire:Commit(a,b,{Cable.Point(a.key),Cable.Point(b.key)},false))
    end
    local root=c.player.parent:CreateChild('StaticArtFixture')
    for i,spec in ipairs({{'front',0,-1},{'left',-1,0},{'right',1,0},{'back',0,1}}) do
        local actor=root:CreateChild(spec[1]); actor.position=Vector3(-48+(i-1)*4,0.55,-6)
        Art.Player(actor,actor,Vector3(spec[2],0,spec[3]),nil,false)
        local food=actor:CreateChild('HeldSample'); food.scale=Vector3(0.30,0.20,0.30); Art.Quad(food,'Food','burger',1.55,1.55,0.55)
        Art.Player(actor,actor,Vector3(spec[2],0,spec[3]),food,false)
    end
    assert(c.items:Give('burger')); h.ui():Update(0)
    local zone=c.player.parent:GetComponent('Zone',true) --[[@as Zone?]]
    if zone then print('[StaticArt Native QA] DISPLAY '..cjson.encode({fog=zone.fogDensity,heightFog=zone.heightFog,exposure=zone.autoExposureEnabled,tonemap=zone.tonemapMode})) end
    print('[StaticArt Native QA] fixture ready; isolated save namespace; 4 whole-body directions, rotated machines, 6 real buffer slots, closed inventory, live belt cargo')
    print('[StaticArt Native QA] MATERIALS '..cjson.encode(Art.Report()))
    return {stock=stock.id,buffer=buffer.id}
end
return Checks
