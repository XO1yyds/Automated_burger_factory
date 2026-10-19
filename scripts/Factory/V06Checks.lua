local Days=require('Factory/DayConfig')
local Campaign=require('Factory/Campaign')
local Orders=require('Factory/Orders')
local Loop=require('Factory/GameLoop')
local Codec=require('Factory/SaveCodec')
local Save=require('Factory/LocalSave')
local Buildings=require('Factory/Buildings')
local Cable=require('Factory/CableNetwork')
local Machine=require('Factory/AutomaticWorkstation')
local Buffer=require('Factory/BufferStorage')
local Checks={}
function Checks.Run(json)
    local fakeItems={} --[[@as FactoryItemService]]
    local origin={} --[[@as Vector3]]
    local results={}
    local function check(name,ok) results[#results+1]={name=name,passed=not not ok} end
    local c=Campaign.New(); local o=Orders.New(fakeItems); local loop=Loop.New(o,c)
    loop:Update(600); check('title never advances day or orders',loop.state=='title' and loop.remaining==180 and #o.active==0)
    loop:Prepare(); loop:Update(600); check('preparation allows controls but cannot simulate',loop:IsRunning() and not loop:CanSimulate() and loop.remaining==180)
    assert(loop:StartTrading()); loop:Update(20); check('day one first customer waits twenty seconds',#o.active==1 and o.active[1].required==1)
    loop:Pause(); local before=loop.remaining; loop:Update(60); check('pause freezes campaign clock',loop.remaining==before)
    loop:Resume(); check('resume restores trading',loop.state=='running')
    o.stock=1; o:Select(o.active[1].id); o.onDelivered=function(order,n,finished,component) c:Delivered(order,n,finished,component) end
    assert(o:Deliver()); check('one burger and full order credit exactly fifteen',c.coins==65 and c.delivered==1)
    local receipt={id=1,delivered=1}; c:Delivered(receipt,1,true); check('duplicate delivery event cannot add coins or daily progress',c.coins==65 and c.delivered==1)
    check('illegal building before its unlock cannot be bought',not c:Buy('cooker') and c.coins==65)
    c.day=2; assert(c:Buy('cooker')); check('building purchase charges only confirmation cost',c.coins==5 and c.spent==60)
    c:Recover('cooker'); assert(c:Buy('cooker')); check('recovered building can be placed without paying twice',c.coins==5 and c.owned.cooker==0)
    check('insufficient coins cannot mutate ownership',not c:Buy('cooker') and c.coins==5 and c.owned.cooker==0)
    check('invalid quantities do not mint money',not c:Buy('cooker',-1) and c.coins==5)
    c:Recover('supply_raw'); c:Recover('supply_raw'); check('unique supply cannot be recovered into two held assets',c.owned.supply_raw==1)
    assert(c:Buy('supply_raw')); check('unique supply cannot be purchased a second time',not c:Buy('supply_raw'))
    local wallet=Campaign.New(); wallet.day=10; wallet.coins=5
    local count=0
    local b=Buildings.New({valid=function() return false,'occupied' end,create=function() count=count+1; return {} --[[@as FactoryStation]] end,
        update=function() end,remove=function() return true,'' end,processing=function() return false end,purchase=function(kind) return wallet:Buy(kind) end})
    b.kind,b.mode,b.confirmFocus='cooker','preview',true
    check('illegal building placement never charges coins',not b:Confirm(origin) and wallet.coins==5 and count==0)
    b.context.valid=function() return true,'' end
    check('unaffordable legal placement never creates a machine',not b:Confirm(origin) and count==0)
    wallet:Recover('cooker'); assert(b:Confirm(origin)); check('owned machine placement consumes one piece atomically',count==1 and wallet.coins==5 and wallet.owned.cooker==0)
    local configs=0
    for day,d in ipairs(Days.Days) do
        local x=Orders.New(fakeItems); x.day=day; x:Configure(d,false)
        local issued,total=0,0
        for _=1,d.seconds do
            x:Update(1)
            for _,order in ipairs(x.active) do issued=issued+1; total=total+order.required end
            x.active={}
        end
        check('day '..day..' finite schedule matches configured orders',issued==#d.orders and total==Days.Total(d))
        configs=configs+1
    end
    local full=Orders.New(fakeItems); full.day=10; full:Configure(Days.Day(10),false); full:Update(180)
    local wait=full.wait; full:Update(20)
    check('full order board pauses release clock without burst',#full.active==6 and full.wait==wait)
    full.active={}; full:Update(0); check('freeing board does not instantly emit overdue batch',#full.active==0)
    local cutoff=Orders.New(fakeItems); cutoff.day=1; cutoff:Configure(Days.Day(1),false); cutoff:Update(179); local n=cutoff.issued; cutoff:Update(500)
    check('end window stops new orders',cutoff.issued==n)
    local base=Orders.New(fakeItems); base.day=10; base:Configure(Days.Day(10),true)
    local extra=0; for _,v in ipairs(base.sequence) do extra=extra+v end
    check('optional extra demand is capped at quarter of baseline',extra==60)
    local x=Campaign.New(); local orders=Orders.New(fakeItems); local game=Loop.New(orders,x); game:Prepare()
    local summaries=0
    for day=1,10 do
        check('day '..day..' begins in frozen preparation',game.state=='preparation' and x.day==day and game.day==day)
        assert(game:StartTrading()); x.delivered=Days.Day(day).goal
        game:Update(Days.Day(day).seconds); check('day '..day..' expiry clears customer orders',#orders.active==0 and game.remaining==0)
        assert(game:EndDay('cashier')); summaries=summaries+1
        local money=x.coins; check('day '..day..' reward cannot be granted twice',not game:EndDay('cashier') and x.coins==money)
        game:Continue()
    end
    check('ten day campaign ends only after tenth settlement',game.state=='complete' and #game.history==10 and summaries==10)
    local owner={job=7}; local identity={arrivals={[owner]=true}}; local root={owner=owner,locks={[1]=owner},identity=identity,cargo={identity=identity}}
    root.self=root
    local decoded=Codec.Unpack(Codec.Pack(root))
    check('graph codec restores cyclic and shared identities',decoded.self==decoded and decoded.owner==decoded.locks[1] and decoded.identity==decoded.cargo.identity)
    check('table keyed arrival deduplication survives save',decoded.identity.arrivals[decoded.owner]==true)
    local m=Machine.New('cooker',fakeItems); m:Receive('raw_beef'); m:Update(1.25)
    local restored=Codec.Unpack(Codec.Pack({machine=m})).machine; setmetatable(restored,Machine); restored.items={}
    restored:Update(1.7); check('restored machine preserves partial cook time',restored.slots[1].itemType=='raw_beef')
    restored:Update(0.1); check('restored machine completes without restarting cook timer',restored.slots[1].itemType=='cooked_beef')
    local store=Buffer.New(6); store:Receive('bun'); store:Receive('burger'); store.locks[2]=owner
    local data=Codec.Unpack(Codec.Pack({store=store,owner=owner})); setmetatable(data.store,Buffer)
    check('storage stack and lock owner survive reference roundtrip',data.store:PeekOutput(data.owner)=='burger' and data.store.locks[2]==data.owner)
    local raw={}; local fail=false
    local backend={read=function(path) return raw[path] end,write=function(path,text) raw[path]=fail and text:sub(1,12) or text; return not fail end}
    local saver=Save.New(backend,json); local state={loop={day=1,state='paused'},campaign={day=1,coins=50},stations={}}
    assert(saver:Write(state)); state.campaign.coins=60; assert(saver:Write(state))
    check('two local save slots select latest generation',saver:Load().state.campaign.coins==60)
    fail=true; state.campaign.coins=90
    check('interrupted inactive slot write reports failure',not saver:Write(state))
    check('interrupted write retains previous valid save',saver:Load().state.campaign.coins==60)
    fail=false; state.campaign.coins=70; assert(saver:Write(state))
    local latest=saver:Load(); raw[latest.path]=raw[latest.path]:sub(1,8)
    check('corrupt main falls back to preceding valid data',saver:Load().state.campaign.coins==60)
    raw[Save.Files[1]]=json.encode({version=99})
    local record,_,future=saver:Load()
    check('future schema prevents fallback overwrite',not record and future and not saver:Write(state))
    local recovery=require('Factory/CampaignRecovery')
    local buffer=Buffer.New(6); buffer:Receive('burger'); buffer:Receive('burger')
    local station={id='forecast',x=-40,z=0,width=2,depth=2}
    local context={machines={},stations={station},items={ground={}},logistics={buffers={forecast=buffer},network={Clear=function() return false end}}}
    local text,loss=recovery.Forecast(context,station)
    check('full ground forecast names exact losses without taking items',loss.burger==2 and text~='' and buffer:Count()==2)
    context.logistics.network.Clear=function() return true end
    text,loss=recovery.Forecast(context,station)
    check('recovery forecast uses removed building footprint for free space',text=='' and next(loss)==nil and buffer:Count()==2)
    local realHand=require('Factory/Items').New({createHeld=function() return {Remove=function() end} --[[@as Node]] end} --[[@as FactoryItemContext]])
    local marker={arrivals={[owner]=true}}; local vault=Buffer.New(6); vault:Receive('burger',nil,marker)
    assert(vault:Withdraw('burger',realHand,origin,origin))
    check('manual terminal withdrawal retains physical item identity',realHand.heldIdentity==marker and realHand.heldIdentity.arrivals[owner])
    assert(vault:TakeOrSwap(1,0,realHand))
    check('manual buffer deposit retains arrival dedup identity',vault.slots[1].identity==marker)
    local broken={}; local archiveBackend={read=function(path) return broken[path] end,write=function(path,text) broken[path]=text; return true end}
    broken[Save.Files[1]],broken[Save.Files[2]]='broken-a','broken-b'
    local archiveSaver=Save.New(archiveBackend,json)
    assert(archiveSaver:Write(state)); local retained=0
    for path,value in pairs(broken) do if path:find('.invalid-',1,true) and (value=='broken-a' or value=='broken-b') then retained=retained+1 end end
    check('new profile preserves both corrupt slot contents before writing',retained==2 and archiveSaver:Load().state.campaign.coins==70)
    local protectedRaw={[Save.Files[1]]='broken-original'}
    local protectedSaver=Save.New({read=function(path) return protectedRaw[path] end,write=function() return false end},json)
    check('failed corrupt archive refuses to overwrite original',not protectedSaver:Write(state) and protectedRaw[Save.Files[1]]=='broken-original')
    local area=require('Factory/AutomationArea'); area.Campaign=true
    local w,h=area.Size('workshop'); check('workshop area is four times with shop unchanged',w*h==18*14*4 and area.Size('shop')==18)
    check('expanded workshop includes formerly outside grid',area.At(-56,12,1,1)=='workshop' and not area.At(-59,0))
    area.Campaign=false
    local passed=0; for _,v in ipairs(results) do if v.passed then passed=passed+1 end end
    return {passed=passed,failed=#results-passed,checks=results}
end
return Checks
