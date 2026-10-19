-- Runs against the actual scene services. No OS input or rendering is simulated.
local Checks={}
function Checks.Run(c)
    local passed,failed=0,0
    local function check(name,value)
        if value then passed=passed+1 else failed=failed+1 end
        print('[V05 Runtime QA] '..(value and 'PASS ' or 'FAIL ')..name)
    end
    local a=c.automation; local loop=c.loop
    local inventory=c.logistics.buffers.ws_inventory
    local components=c.ui.context.get().components
    local function drainStep(seconds)
        for _=1,seconds*2 do
            local buffer=c.logistics.buffers.ws_buffer
            while buffer:PeekOutput() do buffer:TakeOutput('burger') end
            c.step(0.5)
        end
    end
    check('sample network explicitly contains six endpoints',#a.service:Endpoints('ws_inventory')==6)
    check('cable sample reuses original workshop machines without duplicates',c.machines.ws_cooker~=nil and c.machines.ws_assembler~=nil and c.machines.ws_order_cooker==nil and c.machines.ws_order_assembler==nil)
    check('new storage and resized buffer retain distinct capacities',inventory.capacity==24 and c.logistics.buffers.ws_buffer.capacity==6)
    check('initial order and delivery are attached to existing containers',components:Host('ws_inventory').component=='order' and components:Host('ws_buffer').component=='delivery' and c.logistics:Endpoint('ws_terminal')==nil)
    c.switch('workshop'); a:OpenTerminal('ws_inventory'); c.ui:Update(0)
    check('terminal uses the real modal UI phase',c.ui:Phase()=='terminal' and c.view.model.modal.tabs[2].command=='terminalTab')
    check('terminal opens directly on compact product rows',a.tab=='products' and #c.view.model.modal.entries==2 and not a.details)
    check('bound terminal exposes local inventory as fourth-tab layout',#c.view.model.modal.tabs==4 and c.view.model.modal.tabs[2].value=='inventory')
    c.ui:Command('terminalTab','products'); c.ui:Command('terminalProduct','burger'); c.ui:Update(0)
    check('viewing product does not submit a task',not a.service:HasTasks('ws_inventory') and a.service.total==0)
    c.ui:Command('terminalSubmit'); c.ui:Update(0)
    local job=a.service.queues.ws_inventory[1]
    check('UI submit creates a production job distinct from customer orders',job and job.product=='burger' and c.orders.completed==0)
    c.step(1.5); local moves=a.service.total
    local clock=c.machines.ws_cooker.clock
    loop:Pause(); c.step(10)
    check('pause freezes production clock and cable allowance',a.service.total==moves and c.machines.ws_cooker.clock==clock)
    loop:Resume(); c.switch('shop'); c.step(15)
    check('production continues outside workshop and delivers one burger',job.delivered==1 and inventory:PeekOutput()=='burger')
    check('actual assemblies count once including independent conveyor work',loop.automatic==c.machines.ws_assembler.burgersProduced)
    local ok,_,nextJob=a.service:Enqueue('ws_inventory','burger',1,'ws_inventory')
    loop.remaining=0.1; c.step(0.2)
    check('day expiry clears customer orders without cancelling production',ok and loop.remaining==0 and #c.orders.active==0 and a.service:HasTasks('ws_inventory'))
    drainStep(30)
    check('production can complete after day timer reaches zero',nextJob.delivered==1 and inventory:Count()==2)
    assert(a.service:Enqueue('ws_inventory','burger',1,'ws_inventory'))
    assert(loop:EndDay('cashier')); moves=a.service.total; c.step(10)
    check('settlement freezes queued production',loop.state=='settlement' and a.service.total==moves)
    loop:Continue(); drainStep(30)
    check('next day resumes the same production queue',loop.day==2 and inventory:Count()==3 and not a.service:HasTasks('ws_inventory'))
    c.switch('workshop'); a:OpenEditor(); local revision=a.cables.revision
    a:Pick(-37,-4.5); a:SetCursor(-43,-2)
    local preview=a:Preview()
    check('destination selection has a live ceiling path without committing',a.mode=='destination' and preview and #preview.segments>0 and a.cables.revision==revision)
    a:Pick(-46,5); a:Command('cableTurn'); a:Command('cableConfirm')
    check('confirmed connection returns to next source selection',a.mode=='source' and a.cables.revision==revision+1)
    a:Pick(-37,-4.5); a:Pick(-46,5); a:Back(false)
    check('right back from adjustment returns to destination',a.mode=='destination')
    a:Back(false); check('second right back returns to source',a.mode=='source')
    a:Back(true); check('escape closes cable editor',a.mode=='idle')
    c.ui:OpenBuild(); c.ui.kind='manage'; c.ui:Command('enterKind'); c.ui:Command('manageCables'); c.ui:Update(0)
    check('equipment management exposes dedicated cable selection mode',a.managing and c.ui:Phase()=='manage' and c.view.model.actions[1].command=='manageDevices')
    local edgeKey,edge=next(a.cables.edges); local Cable=require('Factory/CableNetwork'); local p,q=Cable.Point(edge.a),Cable.Point(edge.b)
    local sx,sy=c.ui:Project((p.x+q.x)/2,(p.z+q.z)/2,2.4)
    c.ui:WorldClick('manage',{x=0,z=0},sx,sy); c.ui:Update(0)
    check('management picking uses cable ceiling projection',a.deleteEdge==edgeKey or a.deleteEdge~=nil and c.ui:Phase()=='selected')
    c.ui.elapsed=c.ui.elapsed+1; c.ui:Command('deleteManaged'); c.ui:Update(0)
    check('deleting cable stays in cable management for next segment',a.managing and a.deleteEdge==nil and c.ui:Phase()=='manage')
    c.ui:Command('manageDevices'); check('device switch clears cable management visibility',not a.managing)
    c.ui:Back(true); c.ui:Back(true)
    -- Restore precisely the removed sample connections before lifecycle checks.
    a:Sample()
    assert(a.service:Enqueue('ws_inventory','burger',1,'ws_inventory')); c.step(1.5)
    a.service:RemoveBuilding('ws_inventory'); c.step(6)
    check('removing controller safely cancels its owned in-progress work',not a.service:HasTasks('ws_inventory') and c.machines.ws_cooker.automationOwner==nil and c.machines.ws_assembler.automationIntakeOwner==nil and inventory:Reserved()==0)
    local hand=a.context.items
    a:OpenTerminal('ws_inventory'); c.ui:Command('terminalTab','inventory'); c.ui:Command('terminalInventoryKind','burger'); c.ui:Update(0)
    local before=inventory:Count(); c.ui:Command('terminalWithdraw'); c.ui:Update(0)
    check('real terminal inventory command places chosen item in empty hand',hand.held=='burger' and inventory:Count()==before-1)
    local ground=0; for _ in pairs(hand.ground) do ground=ground+1 end
    before=inventory:Count(); c.ui:Command('terminalWithdraw')
    local after=0; for _ in pairs(hand.ground) do after=after+1 end
    check('full hand withdrawal creates a real nearby ground item',hand.held=='burger' and inventory:Count()==before-1 and after==ground+1)
    local free=hand.context.isSpotFree; hand.context.isSpotFree=function() return false end
    before=inventory:Count(); c.ui:Command('terminalWithdraw'); hand.context.isSpotFree=free
    check('no valid ground space rejects without inventory or hand loss',hand.held=='burger' and inventory:Count()==before)
    a:Close(); assert(components:Unbind('ws_inventory'))
    before=inventory:Count(); local took=inventory:InteractStack(hand)
    check('ordinary storage refuses held interaction after component removal',not took and hand.held=='burger' and inventory:Count()==before)
    c.ui:OpenBuild(); c.ui.kind='terminal'; c.ui:Command('enterKind'); c.ui:Update(0)
    check('component build entry selects existing host rather than spawning a ghost',c.ui:Phase()=='attach' and components.mode=='order')
    c.ui:WorldClick('attach',{x=-37,z=-4.5},0,0); c.ui:Command('confirmAttachment'); c.ui:Update(0)
    check('explicit UI confirmation binds storage and preserves footprint',components:Host('ws_inventory').component=='order' and components:Host('ws_inventory').width==2 and components:Host('ws_inventory').depth==4 and c.ui:Phase()=='attach')
    c.ui:Back(true); c.ui:Back(true)
    local buffer=c.logistics.buffers.ws_buffer
    while buffer:PeekOutput() do local kind,token=buffer:PeekOutput(); buffer:TakeOutput(kind,token) end
    assert(buffer:Receive('burger')); assert(buffer:Receive('bun'))
    c.orders.stock=0; c.orders.active={{id=901,required=1,delivered=0}}; c.orders:Select(901)
    c.ui.context.cashier(true); c.ui:Update(0)
    check('cashier modal reflects attached delivery cache contents',c.orders:DeliveryCount()==1 and table.concat(c.view.model.modal.lines,' '):find('交付缓存',1,true)~=nil)
    c.ui:Command('deliver'); c.ui:Update(0)
    check('cashier delivers buried burger and keeps unrelated cache contents',c.orders:DeliveryCount()==0 and buffer:PeekOutput()=='bun' and c.orders.completed>=1)
    c.ui.context.cashier(false)
    print(string.format('[V05 Runtime QA] COMPLETE passed=%d failed=%d',passed,failed))
    return failed==0
end
return Checks
