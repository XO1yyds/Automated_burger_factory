-- Native scene/IO regression. Only invoked by the disabled development flag.
local Save=require('Factory/LocalSave')
local World=require('Factory/CampaignWorld')
local Config=require('Factory/DayConfig')
local Cable=require('Factory/CableNetwork')
local Checks={}
function Checks.Run(c,r,h)
    local result={passed=0,failed=0,checks={},scope='Actual UrhoX scene, services and native File/cjson; automated commands, not human acceptance'}
    local function check(name,value)
        result.checks[#result.checks+1]={name=name,passed=not not value}
        if value then result.passed=result.passed+1 else result.failed=result.failed+1 end
        print('[V06 Native QA] '..(value and 'PASS ' or 'FAIL ')..name)
    end
    local originalFiles=Save.Files
    local originalState=World.Clone(World.Capture(c,nil))
    Save.Files={'burger-v06-qa-a.json','burger-v06-qa-b.json'}
    local ok,error=xpcall(function()
        check('normal startup opens title with frozen simulation',c.loop.state=='title' and not c.loop:CanSimulate())
        c.loop:Prepare(); local before=c.loop.remaining; h.step(100)
        check('preparation does not run actual simulation',c.loop.remaining==before and #c.orders.active==0)
        assert(r:Flush()); local record=r.save:Load()
        check('native File and cjson roundtrip campaign data',record and record.state.campaign.coins==50 and record.state.items~=nil)
        c.loop:StartTrading(); h.step(20)
        check('actual campaign emits configured first order',#c.orders.active==1 and c.orders.active[1].required==1)
        c.orders.stock=1; c.orders:Select(c.orders.active[1].id); assert(c.orders:Deliver())
        check('actual cashier delivery pays fifteen coins',c.campaign.coins==65 and c.campaign.delivered==1)
        c.loop:Pause(); assert(c.loop:EndDay('pause')); h.command('nextDay')
        c=h.context()
        local supplies=0; for _,s in ipairs(c.stations) do if Config.Supplies[s.buildingKind] then supplies=supplies+1 end end
        check('next day opens preparation and grants exactly three unique suppliers',c.loop.day==2 and c.loop.state=='preparation' and supplies==3)
        h.ensure(); local count=0; for _,s in ipairs(c.stations) do if Config.Supplies[s.buildingKind] then count=count+1 end end
        check('repeated day initialization does not duplicate suppliers',count==3)
        c.campaign.day,c.loop.day=10,10; c.loop.remaining=360; c.campaign.coins=2000
        assert(h.switch('workshop')); c=h.context()
        local function place(kind,x,z)
            local b=c.buildings; b:Choose(kind,c.player.position,c.facing); b:SetPosition(x,z); b.confirmFocus=true
            local money=c.campaign.coins; local cost=assert(c.campaign:Quote(kind)); assert(b:Confirm(c.player.position))
            local record=c.buildings.records[#c.buildings.records]
            check('confirmed '..kind..' placement charges expected price',c.campaign.coins==money-cost and record.buildingKind==kind)
            b:Cancel(); return record
        end
        local cooker=place('cooker',-44,8)
        local assembler=place('assembler',-38,8)
        local stock=place('storage',-31,5)
        local delivery=place('buffer',-26,5)
        assert(c.components:Bind(stock.id,'order')); assert(c.components:Bind(delivery.id,'delivery'))
        check('order and delivery use independent real hosts',stock.component=='order' and delivery.component=='delivery' and stock.id~=delivery.id)
        check('host components remain mutually exclusive',not c.components:Bind(stock.id,'delivery'))
        local wire=c.automation.cables
        for _,id in ipairs({'ws_raw','ws_bun','ws_lettuce',cooker.id,assembler.id}) do
            local a={id=stock.id,key=wire:Anchor(c.logistics:Endpoint(stock.id))}; local b={id=id,key=wire:Anchor(c.logistics:Endpoint(id))}
            assert(wire:Commit(a,b,{Cable.Point(a.key),Cable.Point(b.key)},false))
        end
        local edges=0; for _ in pairs(wire.edges) do edges=edges+1 end
        check('native network sees six intended endpoints',#wire:For(stock.id).endpoints==6 and edges>0)
        local plan=assert(c.logistics.network:Plan(stock.id,delivery.id)); local cash=c.campaign.coins
        assert(c.logistics.network:Place(plan))
        check('conveyor charges actual route cells',c.campaign.coins==cash-#plan.cells)
        assert(c.loop:StartTrading())
        local old={}; assert(c.logistics.buffers[stock.id]:Receive('burger',nil,old))
        local success,message,job=c.automation.service:Enqueue(stock.id,'burger',3,stock.id); assert(success,message)
        h.step(2.5)
        check('new job excludes old stock and contains actual unfinished machine',job.delivered==0 and c.machines[cooker.id]:IsProcessing())
        check('actual output belt has live cargo before saving',#c.logistics.network.belts[1].cargo>0)
        local beforeCoins=c.campaign.coins; local progress=c.machines[cooker.id].slots[1].progress
        assert(r:Flush()); local saved=r.save:Load(); assert(saved)
        h.restore(saved.state); c=h.context(); r=c.runtime
        result.processingRestore={coinsBefore=beforeCoins,coinsAfter=c.campaign.coins,secondsBefore=progress,secondsAfter=c.machines[cooker.id].slots[1].progress}
        check('native restore freezes until explicit resume',c.loop.state=='paused' and c.loop.pausedFrom=='running')
        check('native restore preserves currency and partial processing',c.campaign.coins==beforeCoins and math.abs(c.machines[cooker.id].slots[1].progress-progress)<0.000001)
        local restoredJob=c.automation.service.queues[stock.id][1]
        check('restored task ownership points to the restored real machine',c.machines[cooker.id].automationOwner==restoredJob.owner)
        check('belt cargo identity survives native save and scene rebuild',c.logistics.network.belts[1].cargo[1].identity~=nil)
        c.loop:Resume(); h.step(90)
        check('restored full cable job reaches three real arrivals',restoredJob.delivered==3 and restoredJob.state=='已完成')
        check('completed job releases restored machine ownership',not c.machines[cooker.id].automationOwner and not c.machines[assembler.id].automationOwner)
        check('separate delivery component receives output belt products',c.logistics.buffers[delivery.id]:CountKind('burger')==4)
        c.orders:Select(c.orders.active[1].id); local expected=math.min(4,c.orders.active[1].required)
        cash=c.campaign.coins; assert(c.orders:Deliver())
        check('cashier consumes delivery host and credits once',c.campaign.coins==cash+expected*10+5 and c.logistics.buffers[delivery.id]:CountKind('burger')==4-expected)
        assert(r:Flush()); saved=r.save:Load(); local balance=c.campaign.coins
        h.restore(saved.state); c=h.context(); r=c.runtime
        check('post delivery reload retains coins and depleted delivery inventory',c.campaign.coins==balance and c.logistics.buffers[delivery.id]:CountKind('burger')==4-expected)
        local source
        for _,s in ipairs(c.stations) do if s.id=='ws_raw' then source=s end end
        c.buildings.selected=source; local held=c.campaign.owned.supply_raw or 0
        check('connected supplier cannot be recovered without disconnect',not c.buildings:DeleteSelected(c.player.position) and (c.campaign.owned.supply_raw or 0)==held)
        c.automation.cables:RemoveBuilding('ws_raw'); c.buildings.selected=source; assert(c.buildings:DeleteSelected(c.player.position))
        check('supplier recovery stores exactly one building asset',c.campaign.owned.supply_raw==1 and not c.logistics:Endpoint('ws_raw'))
        balance=c.campaign.coins; place('supply_raw',-35,-3)
        check('replacing supplier uses stable identity for free',c.campaign.coins==balance and c.campaign.owned.supply_raw==0 and c.logistics:Endpoint('ws_raw').source=='raw_beef')
        assert(r:Flush()); saved=r.save:Load()
        check('final native snapshot passes unique ownership validation',saved and World.Validate(saved.state))
    end,debug.traceback)
    if not ok then result.failed=result.failed+1; result.error=tostring(error); print('[V06 Native QA] ERROR '..tostring(error)) end
    -- The regression uses dedicated files. Restore the title and real user namespace;
    -- never replace an actual player campaign with the automated test factory.
    h.restore(originalState); c=h.context(); c.loop.state='title'; c.loop.teaching=false; c.loop.briefing=false
    Save.Files=originalFiles; r=c.runtime; r.record,r.loadMessage,r.future=r.save:Load(); r.dayStart=nil
    print('[V06 Native QA] RESULT '..cjson.encode(result))
    return result
end
return Checks
