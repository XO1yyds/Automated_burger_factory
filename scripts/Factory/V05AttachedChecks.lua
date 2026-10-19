local Buffer=require('Factory/BufferStorage')
local Control=require('Factory/OrderAutomationControl')
local Components=require('Factory/AttachedComponents')
local Cable=require('Factory/CableNetwork')
local Machine=require('Factory/AutomaticWorkstation')
local Orders=require('Factory/Orders')
local Network=require('Factory/ConveyorNetwork')
local Checks={}
function Checks.Run()
    local results={}; local function check(n,ok) table.insert(results,{name=n,passed=not not ok}) end
    local function node() return {Remove=function() end} --[[@as Node]] end
    local hand=require('Factory/Items').New({createHeld=node,createGround=node,isSpotFree=function() return true end,isLineClear=function() return true end,onAdded=function() end,onRemoved=function() end})
    local hasSpace,dropped=true,nil
    function hand:PlaceNearby(kind) if not hasSpace then return nil end; dropped=kind; return {} end
    local hosts={
        {id='stock',name='库存',buildingKind='storage',x=-40,z=0,width=2,depth=4},
        {id='other',name='库存2',buildingKind='storage',x=-34,z=0,width=2,depth=4},
        {id='buffer',name='缓存台',buildingKind='buffer',x=-34,z=-5,width=2,depth=2},
    }
    local stores={stock=Buffer.New(24),other=Buffer.New(24),buffer=Buffer.New(6)}
    local endpoints={}
    for _,s in ipairs(hosts) do endpoints[s.id]={id=s.id,name=s.name,area='workshop',kind=s.buildingKind,x=s.x,z=s.z,width=s.width,depth=s.depth,storage=stores[s.id]} end
    for _,spec in ipairs({{'raw','raw_beef',-46,5},{'bun','bun',-42,5},{'lettuce','lettuce',-34,5}}) do endpoints[spec[1]]={id=spec[1],name=spec[1],area='workshop',kind='source',source=spec[2],x=spec[3],z=spec[4],width=1,depth=1} end
    for _,spec in ipairs({{'cooker','cooker',-46,0},{'assembler','assembler',-44,-5}}) do endpoints[spec[1]]={id=spec[1],name=spec[1],area='workshop',kind=spec[2],x=spec[3],z=spec[4],width=1,depth=1,machine=Machine.New(spec[2],hand)} end
    local function resolve(id)
        local ep=endpoints[id]; if ep then for _,s in ipairs(hosts) do if s.id==id then ep.name=s.name; ep.terminal=s.component=='order'; ep.component=s.component end end end
        return ep
    end
    local function all() local list={}; for id in pairs(endpoints) do table.insert(list,resolve(id)) end; table.sort(list,function(a,b) return a.id<b.id end); return list end
    local control=Control.New({resolve=resolve,endpoints=all,area=function() return 'workshop' end,player={position={x=-40,z=-3}},items=hand,facing=function() return {} end})
    local comp=Components.New({stations=function() return hosts end,storage=function(id) return stores[id] end,automation=function() return control end})
    stores.stock:Receive('burger')
    check('order component cannot bind a buffer',not comp:Bind('buffer','order'))
    assert(comp:Bind('stock','order'))
    check('attachment preserves host footprint capacity identity and old contents',hosts[1].width==2 and hosts[1].depth==4 and stores.stock.capacity==24 and stores.stock:Count()==1 and hosts[1].id=='stock')
    check('attachment changes host name and opens no second storage',hosts[1].name=='下单终端' and resolve('stock').terminal and #hosts==3)
    check('a second component cannot stack on a bound host',not comp:Bind('stock','delivery'))
    local function connect(id)
        local a={id='stock',key=control.cables:Anchor(resolve('stock'))}; local b={id=id,key=control.cables:Anchor(resolve(id))}
        assert(control.cables:Commit(a,b,{Cable.Point(a.key),Cable.Point(b.key)},false))
    end
    for _,id in ipairs({'raw','bun','lettuce','cooker','assembler','other'}) do connect(id) end
    check('bound storage is the only network controller',#control.cables:For('stock').terminals==1)
    check('binding checks single-controller network rule before mutation',not comp:Bind('other','order') and not hosts[2].component)
    local service=control.service
    local ok,_,job=service:Enqueue('stock','burger',3,'other'); assert(ok)
    check('bound terminal fixes result destination to its own storage',job.target=='stock' and job.arrivalBased)
    check('pre-existing terminal stock does not count as arrival',job.delivered==0)
    local identity={}; stores.stock:Receive('burger',nil,identity)
    check('external matching input increments receipt immediately',job.delivered==1)
    stores.stock:Receive('bun'); check('other item types do not advance receipt',job.delivered==1)
    stores.stock:TakeKind('burger'); stores.stock:Receive('burger',nil,identity)
    check('same physical item returning cannot count twice for the task',job.delivered==1)
    local network=Network.New({resolve=resolve,endpoints=all,free=function() return true end})
    stores.other:Receive('burger')
    local plan=assert(network:Plan('other','stock')); assert(network:Place(plan)); network:Update(30)
    check('actual conveyor receive advances terminal order',job.delivered==2)
    stores.other:Receive('burger'); local _,token=stores.other:PeekOutput()
    assert(service:Transfer(job,'burger',resolve('other'),resolve('stock'),token,true))
    check('cable receive counts once without a second transfer increment',job.delivered==3)
    service:Update(0); check('receipt completion moves task to history',job.state=='已完成' and not service:HasTasks('stock'))
    control:OpenTerminal('stock'); local modal=control:Modal()
    check('bound terminal has four fixed tabs',#modal.tabs==4 and modal.tabs[2].value=='inventory')
    control:Command('terminalProduct','burger'); modal=control:Modal()
    check('bound terminal does not offer another output destination',#modal.tools==1 and control.target=='stock')
    control:Command('terminalTab','inventory'); modal=control:Modal()
    check('local inventory groups actual stored types',#modal.entries==2 and modal.entries[1].action.command=='terminalInventoryKind')
    control:Command('terminalInventoryKind','burger'); modal=control:Modal()
    check('inventory inspect uses explicit one-item withdrawal',modal.buttons[1].command=='terminalWithdraw')
    local n=stores.stock:Count(); hand.held='lettuce'; hasSpace=false
    check('full ground rejects withdrawal atomically',not control:Command('terminalWithdraw') and stores.stock:Count()==n and hand.held=='lettuce')
    hasSpace=true; assert(control:Command('terminalWithdraw'))
    check('full hand retains old item and drops withdrawn type',hand.held=='lettuce' and dropped=='burger' and stores.stock:Count()==n-1)
    stores.stock:Receive('lettuce'); hand.held=nil; assert(stores.stock:Withdraw('burger',hand,{},{}))
    check('empty hand can take chosen type beneath a different stack top',hand.held=='burger' and stores.stock:PeekOutput()=='lettuce')
    hand.held=nil
    assert(service:Enqueue('stock','burger',2,'stock')); local waiting=service.queues.stock[1]
    control.cables:RemoveBuilding('raw'); control.cables:RemoveBuilding('cooker'); service:Update(3)
    check('network change retains task id product demand and progress',service.queues.stock[1]==waiting and waiting.quantity==2 and not waiting.cancelled)
    assert(service:Cancel('stock',waiting.id)); service:Update(10)
    check('player can cancel a task after network loss',waiting.state=='已取消' and not service:HasTasks('stock'))
    local count=stores.stock:Count(); assert(comp:Unbind('stock'))
    check('unbinding preserves inventory and clears terminal receipt observer',stores.stock:Count()==count and stores.stock.onReceive==nil and not resolve('stock').terminal)
    stores.other:Receive('bun'); stores.other:Receive('lettuce'); hand.held='raw_beef'; n=stores.other:Count()
    check('ordinary nonempty inventory refuses hand exchange',not stores.other:InteractStack(hand) and stores.other:Count()==n and hand.held=='raw_beef')
    local empty=Buffer.New(24); check('ordinary empty inventory refuses manual input',not empty:InteractStack(hand) and empty:Count()==0)
    hand.held=nil; assert(stores.other:InteractStack(hand)); check('ordinary empty hand still retrieves strict stack top',hand.held=='lettuce')
    assert(comp:Bind('buffer','delivery')); assert(comp:Bind('other','delivery'))
    stores.buffer:Receive('burger'); stores.buffer:Receive('bun'); stores.other:Receive('burger'); stores.other:Receive('lettuce')
    local orders=Orders.New(hand,function() return 5 end); orders.deliveryStores=function() return comp:DeliveryStores() end
    orders.stock=1; orders.active={{id=1,required=3,delivered=0}}; orders:Select(1)
    check('cashier sums original depot and attached delivery containers',orders:DeliveryCount()==3 and orders:CanDeliver())
    assert(orders:Deliver())
    check('cashier consumes only requested product across blocked stack tops',orders.completed==1 and orders:DeliveryCount()==0 and stores.buffer:PeekOutput()=='bun' and stores.other:PeekOutput()=='lettuce')
    stores.buffer:Receive('burger'); local _,top=stores.buffer:PeekOutput(); stores.buffer.locks[top]={}
    check('cashier never consumes task-locked items',orders:DeliveryCount()==0)
    check('delivery components retain host-specific building types',hosts[2].buildingKind=='storage' and hosts[2].name=='交付终端' and hosts[3].buildingKind=='buffer' and hosts[3].name=='交付缓存')
    assert(comp:Unbind('buffer')); check('unbound delivery host disappears from cashier sources',#comp:DeliveryStores()==1)
    local failed=0; for _,r in ipairs(results) do if not r.passed then failed=failed+1 end end
    return {passed=#results-failed,failed=failed,results=results}
end
return Checks
