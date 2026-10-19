local Cable=require('Factory/CableNetwork')
local Automation=require('Factory/OrderAutomation')
local Buffer=require('Factory/BufferStorage')
local Automatic=require('Factory/AutomaticWorkstation')
local Items=require('Factory/Items')
local Control=require('Factory/OrderAutomationControl')
local Checks={}
---@param endpoints table<string,FactoryConveyorEndpoint>
---@param id string
---@return FactoryAutomaticWorkstation
local function machine(endpoints,id) return assert(endpoints[id].machine) end
function Checks.Run()
    local results={}
    local function check(name,condition) table.insert(results,{name=name,passed=not not condition}); print('[V05 QA] '..(condition and 'PASS ' or 'FAIL ')..name) end
    local function world(offset)
        offset=offset or 0
        ---@type table<string,FactoryConveyorEndpoint>
        local endpoints={}
        local function all() local a={}; for _,ep in pairs(endpoints) do table.insert(a,ep) end; table.sort(a,function(x,y) return x.id<y.id end); return a end
        local node=function() return {Remove=function() end} end
        local hand=Items.New({createHeld=node,createGround=node,isSpotFree=function() return true end,isLineClear=function() return true end,onAdded=function() end,onRemoved=function() end})
        local function add(id,kind,x,z,source)
            local ep={id=id,name=id,kind=kind,area='workshop',x=x+offset,z=z,width=1,depth=1,source=source}
            if kind=='buffer' or kind=='storage' then ep.storage=Buffer.New(kind=='storage' and 24 or 6) end
            if kind=='cooker' or kind=='assembler' then ep.machine=Automatic.New(kind,hand) end
            endpoints[id]=ep; return ep
        end
        add('terminal','terminal',0,0); add('raw','source',-4,4,'raw_beef'); add('bun','source',0,4,'bun'); add('lettuce','source',4,4,'lettuce')
        add('cooker','cooker',-4,0); add('assembler','assembler',4,0); add('store','storage',8,0)
        local context={resolve=function(id) return endpoints[id] end,endpoints=all}
        local cable=Cable.New(context)
        local function connect(a,b)
            local x,y=endpoints[a],endpoints[b]; local s={id=a,key=cable:Anchor(x)}; local f={id=b,key=cable:Anchor(y)}
            return cable:Commit(s,f,{Cable.Point(s.key),Cable.Point(f.key)},false)
        end
        for _,id in ipairs({'raw','bun','lettuce','cooker','assembler','store'}) do assert(connect('terminal',id)) end
        local service=Automation.New(cable,context)
        local function step(seconds)
            local left=seconds
            while left>0.000001 do local dt=math.min(0.05,left); for _,ep in ipairs(all()) do if ep.machine then ep.machine:Update(dt) end end; service:Update(dt); left=left-dt end
        end
        return endpoints,cable,service,step,connect,add,hand,context
    end
    local ep,cable,service,step,connect,add,hand,context=world()
    check('all seven explicitly connected buildings share a network',#service:Endpoints('terminal')==7)
    local originalEdges=0; for _ in pairs(cable.edges) do originalEdges=originalEdges+1 end
    assert(connect('terminal','store')); local duplicateEdges=0; for _ in pairs(cable.edges) do duplicateEdges=duplicateEdges+1 end
    check('overlapping cables deduplicate unit edges',originalEdges==duplicateEdges)
    step(20); check('no cable requests or material without a job',service.total==0 and ep.store.storage:Count()==0 and next(machine(ep,'cooker').slots)==nil)
    local ok,_,job=service:Enqueue('terminal','burger',2,'store'); check('burger preflight traces the complete upstream recipe',ok)
    step(0.49); check('first transfer waits a half simulated second',service.total==0)
    step(0.01); check('one half-second permits exactly one transfer',service.total==1)
    step(30); check('two new burgers arrive in selected inventory',job.delivered==2 and ep.store.storage:Count()==2 and job.state=='已完成')
    check('full chain performs exactly five endpoint moves per burger',job.moves==10)
    local raw=0; for _,e in ipairs(service.events) do if e.from=='raw' then raw=raw+1 end end
    check('source requests are finite and match job demand',raw==2)
    check('completed job releases machine ownership',machine(ep,'cooker').automationOwner==nil and machine(ep,'assembler').automationOwner==nil)
    check('completed job releases destination reservations',ep.store.storage:Reserved()==0)
    local before=service.total; step(10); check('idle cable network does not continue producing',service.total==before and ep.store.storage:Count()==2)
    ok,_,job=service:Enqueue('terminal','burger',1,'store'); step(15)
    check('existing target products do not fulfill a request for new production',ok and job.delivered==1 and ep.store.storage:Count()==3)
    check('invalid quantity is rejected',not service:Enqueue('terminal','burger',0,'store'))
    check('non-storage output target is rejected',not service:Enqueue('terminal','burger',1,'raw'))
    add('terminal2','terminal',8,4)
    local beforeRevision=cable.revision; local joined=connect('store','terminal2')
    check('merging two controllers is rejected atomically',not joined and cable.revision==beforeRevision)
    check('new unconnected controller remains a separate network',#cable:For('terminal2').terminals==1)
    local k=cable:NearestEdge(2,0); local removed=cable:RemoveSegment(k)
    check('selected straight cable section is removable',removed)

    ep,cable,service,step,connect,add,hand=world()
    ep.cooker=nil; ep.store.storage:Receive('cooked_beef')
    ok,_,job=service:Enqueue('terminal','burger',1,'store'); step(12)
    check('ready cooked inventory permits burgers without a cooker',ok and job.delivered==1)
    local impossible,message=service:Enqueue('terminal','burger',1,'store')
    check('missing cooked meat and cooker report a blocking dependency',not impossible and message:find('自动烹饪台',1,true)~=nil)

    ep,cable,service,step=world()
    ep.raw.source=nil; ep.store.storage:Receive('raw_beef'); ep.store.storage:Receive('burger')
    ok,message=service:Enqueue('terminal','burger',1,'store')
    check('strict stack prevents buried ingredient extraction',not ok and message:find('栈顶',1,true)~=nil)
    ep.store.storage:TakeOutput('burger'); ok,_,job=service:Enqueue('terminal','burger',1,'store'); step(15)
    check('removing the obstruction makes the same finite source usable',ok and job.delivered==1)

    ep,cable,service,step=world()
    for _=1,24 do assert(ep.store.storage:Receive('burger')) end
    ok,_,job=service:Enqueue('terminal','burger',1,'store'); step(8)
    check('full target waits without infinite source pulls',ok and job.delivered==0 and service.total==0)
    ep.store.storage:TakeOutput('burger'); step(15)
    check('making one target slot available resumes the job',job.delivered==1 and ep.store.storage:Count()==24)

    ep,cable,service,step=world()
    ok,_,job=service:Enqueue('terminal','cooked_beef',3,'store'); step(1.5)
    local slots=0; for _ in pairs(machine(ep,'cooker').slots) do slots=slots+1 end
    check('cooked-meat order uses all three parallel cooking slots',slots==3)
    check('reserved output space cannot be consumed by a belt',ep.store.storage:Reserved()==3)
    local received=0; while ep.store.storage:Receive('bun') do received=received+1 end
    check('ordinary input respects reserved capacity',received==21)
    step(8); check('reserved outputs can still enter a saturated inventory',job.delivered==3 and ep.store.storage:Count()==24)

    ep,cable,service,step=world()
    ok,_,job=service:Enqueue('terminal','burger',1,'store'); step(1.5)
    service:Cancel('terminal',job.id); step(0.1)
    check('cancel immediately frees no-longer-needed delivery capacity',ep.store.storage:Reserved()==0)
    check('cancel does not destroy already cooking material',machine(ep,'cooker'):IsProcessing() and job.state=='取消收尾')
    step(5); check('cancel safely finishes without a manufactured refund',job.state=='已取消' and machine(ep,'cooker'):PeekOutput()=='cooked_beef' and ep.store.storage:Count()==0)
    check('cancel releases all ownership and target reservations',machine(ep,'cooker').automationOwner==nil and machine(ep,'assembler').automationOwner==nil and ep.store.storage:Reserved()==0)

    ep,cable,service,step,connect=world()
    ok,_,job=service:Enqueue('terminal','burger',1,'store'); cable:RemoveBuilding('store'); step(4)
    check('disconnected target waits with no source ownership loss',job.delivered==0 and service.total==0)
    assert(connect('terminal','store')); step(15)
    check('reconnecting the same target resumes remaining work',job.delivered==1)

    ep,cable,service,step=world()
    for _=1,10 do assert(service:Enqueue('terminal','burger',1,'store')) end
    check('eleventh queued production task is rejected',not service:Enqueue('terminal','burger',1,'store'))
    local queue=service.queues.terminal; service:Cancel('terminal',queue[5].id); step(0.05)
    check('queued cancellation removes only the chosen task',#service.queues.terminal==9)
    local s=Buffer.New(24); check('inventory capacity is twenty-four, not six',s.capacity==24)
    s:Receive('bun'); s:Receive('lettuce'); local _,token=s:PeekOutput(); s.locks[token]={}
    check('a belt cannot skip a locked stack top',s:PeekOutput()==nil and s:Count()==2)
    s.locks={}; check('inventory output is last-in-first-out',s:PeekOutput()=='lettuce')
    assert(hand:Give('raw_beef')); local count=s:Count(); local accepted=s:InteractStack(hand)
    check('held interaction refuses inventory exchange without mutation',not accepted and hand.held=='raw_beef' and s:PeekOutput()=='lettuce' and s:Count()==count)
    hand:Reset(); s=Buffer.New(24); assert(hand:Give('bun')); accepted=s:InteractStack(hand)
    check('held interaction cannot seed an empty inventory',not accepted and hand.held=='bun' and s:Count()==0)
    local load=Buffer.New(24); for _=1,8 do load:Receive('bun') end; check('eight items are low load',load:LoadText():find('低',1,true))
    load:Receive('bun'); check('nine items are medium load',load:LoadText():find('中',1,true))
    for _=10,17 do load:Receive('bun') end; check('seventeen items are high load',load:LoadText():find('高',1,true))
    service:Stop(); check('service stop releases reservations',not next(service.queues))

    ep,cable,service,step,connect,add=world()
    ep.bun.source=nil; ep.lettuce.source=nil
    machine(ep,'assembler'):Receive('bun')
    add('assembler2','assembler',4,-4); assert(connect('terminal','assembler2'))
    machine(ep,'assembler2'):Receive('lettuce')
    check('partial inputs on two assemblers cannot be combined for one unit',not service:Enqueue('terminal','burger',1,'store'))
    ep.store.storage:Receive('lettuce')
    ok,_,job=service:Enqueue('terminal','burger',1,'store'); step(15)
    check('preflight allocation matches the selected preloaded assembler',ok and job.delivered==1)

    ep,cable,service,step,connect,add=world()
    add('assembler2','assembler',4,-4); assert(connect('terminal','assembler2'))
    ok,_,job=service:Enqueue('terminal','burger',8,'store'); step(90)
    check('multiple assemblers deliver exactly the requested new products',ok and job.delivered==8 and ep.store.storage:Count()==8 and job.moves==40)
    local outputs=0; for _,e in ipairs(service.events) do if e.to=='store' then outputs=outputs+1 end end
    check('parallel work creates no hidden excess completed burgers',outputs==8 and not machine(ep,'assembler').burgerReady and not machine(ep,'assembler2').burgerReady)

    ep,cable,service,step,connect,add=world()
    add('terminal2','terminal',100,0); add('raw2','source',96,4,'raw_beef'); add('cooker2','cooker',96,0); add('store2','storage',104,0)
    for _,id in ipairs({'raw2','cooker2','store2'}) do assert(connect('terminal2',id)) end
    assert(service:Enqueue('terminal','cooked_beef',3,'store'))
    assert(service:Enqueue('terminal2','cooked_beef',3,'store2'))
    step(0.5); check('independent networks each get their own half-second transfer',service.total==2)
    step(0.5); check('branches share bandwidth while separate networks remain independent',service.total==4)
    step(10); check('independent queues finish in their own inventories',ep.store.storage:Count()==3 and ep.store2.storage:Count()==3 and #service.history==2)

    ep,cable,service,step,connect,add,hand,context=world(-40)
    local control=Control.New({resolve=context.resolve,endpoints=context.endpoints,area=function() return 'workshop' end,player={position={x=-40,z=0}}})
    assert(control:OpenEditor()); assert(control:Pick(-40,0)); control:SetCursor(-38,2)
    local preview=control:Preview()
    check('editor keeps a live source-to-cursor route before endpoint selection',control.mode=='destination' and preview and #preview.segments>0 and control.cables.revision==0)
    assert(control:Pick(-32,0)); control:SetCursor(-36,2); control:Command('cableAdd'); control:Keyboard(0,1,false)
    check('added cable waypoint moves one grid step with keyboard',control.waypoints[1].x==-36 and control.waypoints[1].z==3)
    control:Pointer('down',{x=-36,z=3}); control:Pointer('move',{x=-35,z=2}); control:Pointer('up',{x=-35,z=2})
    check('cable waypoint pointer drag ends without retaining ownership',control.waypoints[1].x==-35 and control.drag==nil)
    control:Pick(-37,1); control:Pointer('move',{x=-33,z=-5})
    check('clicked grid location remains stable on the way to the Add button',control.cursor.x==-37 and control.cursor.z==1)
    assert(control:Command('cableConfirm'))
    check('explicit cable confirmation returns to continuous source selection',control.mode=='source' and control.cables.revision==1)
    assert(control:Pick(-40,0)); assert(control:Pick(-32,0)); control:Back(false)
    check('right back unwinds cable adjustment to destination',control.mode=='destination')
    control:Back(false); check('right back unwinds destination to source',control.mode=='source')
    control:Back(true); check('escape closes editor to parent construction state',control.mode=='idle')
    for _,id in ipairs({'cooker','assembler'}) do local s={id='terminal',key=control.cables:Anchor(ep.terminal)}; local f={id=id,key=control.cables:Anchor(ep[id])}; assert(control.cables:Commit(s,f,{Cable.Point(s.key),Cable.Point(f.key)},false)) end
    control:OpenTerminal('terminal'); local modal=control:Modal() --[[@as table]]
    check('terminal opens on compact product list with fixed tabs',#modal.tabs==3 and modal.tabs[1].value=='products' and #modal.entries==2 and modal.entries[1].action.command=='terminalProduct')
    control:Command('terminalTab','products'); control:Command('terminalProduct','burger'); control:Command('terminalQuantity',100)
    check('terminal quantity controls clamp at ninety-nine',control.quantity==99)
    modal=control:Modal()
    check('product quantity stays fixed above scrollable content',modal.summary:find('99',1,true)~=nil and modal.quantity.value==99 and #modal.quantity.actions==4)
    check('recipe and material details are initially collapsed',not control.details and #modal.entries==0 and #modal.tools==2)
    control:Command('terminalDetails'); check('recipe details expand only on request',#control:Modal().entries==5)
    control:Command('terminalChooseTarget'); local entry=control:Modal().entries[1] --[[@as table]]
    check('destination chooser has explicit adjacent selection action',entry.action.command=='terminalTarget')
    control:Back(false); check('destination back preserves product and quantity',control.product=='burger' and control.quantity==99 and not control.choosingTarget)
    control:Back(false); check('terminal detail back retains the component page',control.terminal=='terminal' and control.product==nil)
    control:Back(false); check('terminal list back closes the component page',control.terminal==nil)
    control:ManageCables(); check('equipment cable management does not enter placement mode',control.managing and control.mode=='idle')
    check('equipment cable management selects a ceiling segment',control:PickManaged(-39,0))
    local before=control.cables.revision; local deleted=control:DeleteManaged()
    check('cable removal retains continuous management and clears selection',deleted and control.managing and control.deleteEdge==nil and control.cables.revision==before+1)
    control:Close(); check('closing equipment management hides cable selection state',not control.managing and control.deleteEdge==nil)
    local failed=0; for _,r in ipairs(results) do if not r.passed then failed=failed+1 end end
    return {passed=#results-failed,failed=failed,results=results}
end
return Checks
