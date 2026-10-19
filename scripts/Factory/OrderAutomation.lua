-- Production jobs are independent of customer orders. One running job per terminal/network.
local Planner=require('Factory/ProductionPlanner')
local Definitions=require('Factory/Items').Definitions
---@class FactoryOrderAutomation
---@field context table
---@field cables FactoryCableNetwork
---@field queues table<string,table[]>
---@field history table[]
---@field events table[]
---@field nextId integer
---@field total integer
local Automation={}
Automation.__index=Automation
---@return FactoryOrderAutomation
function Automation.New(cables,context)
    return setmetatable({cables=cables,context=context,queues={},history={},nextId=1,total=0,events={}},Automation)
end
function Automation:Endpoints(terminal)
    local network=self.cables:For(terminal)
    return network and network.endpoints or {}
end
function Automation:Check(terminal,product,quantity,target)
    local component=self.cables:For(terminal)
    if not component or #component.terminals~=1 or component.terminals[1]~=terminal then return false,'网络没有唯一的有效下单组件。' end
    return Planner.Check(component.endpoints,product,quantity,target)
end
function Automation:Enqueue(terminal,product,quantity,target)
    local host=self.context.resolve(terminal)
    if host and host.terminal and host.storage then target=terminal end
    local queue=self.queues[terminal] or {}
    if #queue>=10 then return false,'生产队列已满（最多10项）。' end
    local ok,message=self:Check(terminal,product,quantity,target)
    if not ok then return false,message end
    local job={id=self.nextId,terminal=terminal,product=product,quantity=quantity,delivered=0,target=target,
        state='待执行',reason='',clock=0,owned={},units={},moves=0,arrivalBased=host and host.terminal and host.storage~=nil}
    job.owner={job=job.id}; self.nextId=self.nextId+1
    table.insert(queue,job); self.queues[terminal]=queue
    return true,'生产任务已提交：'..Definitions[product].name..' ×'..quantity..'。',job
end
function Automation:ObserveStorage(id,storage)
    storage.onReceive=function(kind,identity) self:Arrival(id,kind,identity) end
end
function Automation:Arrival(id,kind,identity)
    for _,job in ipairs(self.queues[id] or {}) do
        if job.arrivalBased and not job.cancelled and job.product==kind and job.delivered<job.quantity then
            identity.arrivals=identity.arrivals or {}
            if identity.arrivals[job.owner] then return end
            identity.arrivals[job.owner]=true; job.delivered=job.delivered+1
            job.reason='已到货 '..job.delivered..'/'..job.quantity
            return
        end
    end
end
function Automation:HasTasks(terminal) return #(self.queues[terminal] or {})>0 end
function Automation:Release(job)
    for _,m in pairs(job.pending or {}) do if m.automationIntakeOwner==job.owner then m.automationIntakeOwner=nil; m:TryStartAssembly() end end
    for _,ep in ipairs(self.context.endpoints()) do
        if ep.storage then ep.storage:Release(job.owner) end
        if ep.machine and ep.machine.automationOwner==job.owner then ep.machine.automationOwner=nil end
    end
    -- Also release detached/deleted adapters that a job still owns.
    for _,m in pairs(job.owned) do if m.automationOwner==job.owner then m.automationOwner=nil end end
    if job.destination then job.destination:Release(job.owner) end
end
function Automation:Cancel(terminal,id)
    for _,job in ipairs(self.queues[terminal] or {}) do if job.id==id then
        job.cancelled=true; job.state='取消收尾'; job.reason='停止新投料；等待已开始加工安全完成。'
        -- Cancelled outputs stay on the machine, so no delivery capacity is
        -- needed while its already-started processing safely finishes.
        if job.destination then job.destination:Release(job.owner) end
        return true,'已请求取消生产任务。'
    end end
    return false,'该任务已结束。'
end
function Automation:CancelAll(terminal)
    for _,job in ipairs(self.queues[terminal] or {}) do self:Cancel(terminal,job.id) end
end
function Automation:RemoveBuilding(id)
    self:CancelAll(id); self.cables:RemoveBuilding(id)
end
local function sortedMachines(endpoints,kind)
    local list={}
    for _,ep in ipairs(endpoints) do if ep.machine and ep.machine.kind==kind then table.insert(list,ep) end end
    table.sort(list,function(a,b)
        local function filled(ep) local n=0; for _ in pairs(ep.machine.materials) do n=n+1 end; return n end
        local x,y=filled(a),filled(b); return x==y and a.id<b.id or x>y
    end)
    return list
end
function Automation:FindSource(endpoints,kind,job,destination)
    for _,ep in ipairs(endpoints) do if ep.id~=destination then
        local provider=ep.storage or ep.machine
        if provider then
            local value,token=provider:PeekOutput(job.owner)
            -- Final output belongs to its own unit and can only go to the selected target.
            if value==kind and not (job.units[ep.id] and kind==job.product) then return ep,token end
        end
    end end
    for _,ep in ipairs(endpoints) do if ep.source==kind then return ep end end
    return nil
end
function Automation:Transfer(job,kind,from,destination,token,final)
    local receiver=destination.storage or destination.machine
    if not receiver or not receiver:CanReceive(kind,job.owner) then return false end
    local component=self.cables:For(job.terminal); local members={}
    for _,ep in ipairs(component and component.endpoints or {}) do members[ep.id]=true end
    if not members[from.id] or not members[destination.id] then return false end
    local provider=from.storage or from.machine
    local identity=nil
    if provider then
        local current,currentToken,ignored; current,currentToken,ignored,identity=provider:PeekOutput(job.owner)
        if current~=kind or (token and currentToken~=token) then return false end
        if from.storage then from.storage.locks[currentToken]=job.owner end
        local took=provider:TakeOutput(kind,currentToken,job.owner)
        if from.storage then from.storage.locks[currentToken]=nil end
        if not took then return false end
    elseif from.source~=kind then return false end
    -- No callbacks/yields can change ownership between the precheck and this receive.
    assert(receiver:Receive(kind,job.owner,identity),'Reserved cable receiver rejected an atomic transfer')
    job.moves=job.moves+1; self.total=self.total+1
    table.insert(self.events,{job=job.id,item=kind,from=from.id,to=destination.id})
    if #self.events>128 then table.remove(self.events,1) end
    if final and not job.arrivalBased then job.delivered=job.delivered+1 end
    return true
end
function Automation:Own(job,ep)
    if ep.machine.automationOwner and ep.machine.automationOwner~=job.owner then return false end
    ep.machine.automationOwner=job.owner; job.owned[ep.id]=ep.machine; ep.machine:TryStartAssembly()
    return true
end
-- Pause only new intake while older work drains through its original output.
-- This creates a handover point even on continuously supplied conveyor machines.
function Automation:RequestMachine(job,ep)
    local m=ep.machine
    if (m.automationOwner and m.automationOwner~=job.owner) or (m.automationIntakeOwner and m.automationIntakeOwner~=job.owner) then return false end
    job.pending=job.pending or {}; job.pending[ep.id]=m; m.automationIntakeOwner=job.owner
    return true
end
function Automation:MoveNext(job,endpoints)
    local target=nil; local map={}
    for _,ep in ipairs(endpoints) do map[ep.id]=ep; if ep.id==job.target then target=ep end end
    if not target or not target.storage then job.reason='成品目标失联：等待恢复连接。'; return false end
    job.destination=target.storage
    -- Deliver already produced task outputs first, freeing finite machine output slots.
    for _,ep in ipairs(endpoints) do if job.units[ep.id] and ep.machine then
        local kind,token=ep.machine:PeekOutput(job.owner)
        if kind==job.product and self:Transfer(job,kind,ep,target,token,true) then
            if kind=='burger' then job.units[ep.id]=nil else job.units[ep.id]=job.units[ep.id]-1; if job.units[ep.id]==0 then job.units[ep.id]=nil end end
            job.reason=(job.arrivalBased and '已到货 ' or '已交付 ')..job.delivered..'/'..job.quantity; return true
        end
    end end
    local function newUnit()
        local n=job.delivered
        for _,count in pairs(job.units) do n=n+count end
        return n<job.quantity and (job.arrivalBased and target.storage:CanReceive(job.product,job.owner) or not job.arrivalBased and target.storage:ReserveSpace(job.owner,1))
    end
    if job.product=='burger' then
        local allocated=job.delivered; for _,n in pairs(job.units) do allocated=allocated+n end
        for _,ep in ipairs(sortedMachines(endpoints,'assembler')) do
            local m=ep.machine
            if allocated<job.quantity and not job.units[ep.id] and target.storage:Count()+target.storage:Reserved()<target.storage.capacity then self:RequestMachine(job,ep) end
            if not job.units[ep.id] and not m:IsProcessing() and not m.burgerReady and not m.materials.raw_beef
                and (not m.automationOwner or m.automationOwner==job.owner) then
                if newUnit() then self:Own(job,ep); job.units[ep.id]=1; allocated=allocated+1 end
            end
        end
        for _,ep in ipairs(sortedMachines(endpoints,'assembler')) do if job.units[ep.id] then
            local m=ep.machine
            if not m:IsProcessing() and not m.burgerReady then
                for _,kind in ipairs({'bun','lettuce','cooked_beef'}) do if not m.materials[kind] and m:CanReceive(kind,job.owner) then
                    local source,token=self:FindSource(endpoints,kind,job,ep.id)
                    if source and self:Transfer(job,kind,source,ep,token) then job.reason='向组合台配送'..Definitions[kind].name; return true end
                end end
            end
        end end
        local needCooked=0
        for id in pairs(job.units) do local ep=map[id]
            if ep and ep.machine.kind=='assembler' and not ep.machine:IsProcessing() and not ep.machine.burgerReady and not ep.machine.materials.cooked_beef then needCooked=needCooked+1 end
        end
        for _,ep in ipairs(endpoints) do if ep.machine and job.owned[ep.id] and ep.machine.kind=='cooker' then for _ in pairs(ep.machine.slots) do needCooked=needCooked-1 end end end
        if needCooked>0 then
            for _,ep in ipairs(sortedMachines(endpoints,'cooker')) do
                local m=ep.machine
                self:RequestMachine(job,ep)
                -- Existing unrelated work remains autonomous; ready cooked output can be used above.
                if (job.owned[ep.id] or not m:IsProcessing()) and m:CanReceive('raw_beef',job.owner) then
                    local source,token=self:FindSource(endpoints,'raw_beef',job,ep.id)
                    if source and self:Own(job,ep) and self:Transfer(job,'raw_beef',source,ep,token) then job.reason='索取生牛肉，等待烹饪。'; return true end
                end
            end
        end
    else
        for _,ep in ipairs(sortedMachines(endpoints,'cooker')) do
            local m=ep.machine
            if target.storage:Count()+target.storage:Reserved()<target.storage.capacity then self:RequestMachine(job,ep) end
            if (job.owned[ep.id] or (not m:IsProcessing() and not m:PeekOutput())) and m:CanReceive('raw_beef',job.owner) then
                local source,token=self:FindSource(endpoints,'raw_beef',job,ep.id)
                if source and self:Own(job,ep) and newUnit() then
                    if self:Transfer(job,'raw_beef',source,ep,token) then job.units[ep.id]=(job.units[ep.id] or 0)+1; job.reason='索取生牛肉，等待烹饪。'; return true end
                    if not job.arrivalBased then target.storage.reserved[job.owner]=math.max(0,(target.storage.reserved[job.owner] or 0)-1) end
                end
            end
        end
    end
    if target.storage:Count()+target.storage:Reserved()>=target.storage.capacity and not next(job.units) then job.reason='等待成品存放空间。'
    else
        local ok,reason=self:Check(job.terminal,job.product,math.max(1,job.quantity-job.delivered),job.target)
        job.reason=ok and '等待加工、就绪材料或可用设备槽。' or reason
        for _,m in pairs(job.pending or {}) do if m.automationOwner~=job.owner and (m.burgerReady or m:IsProcessing() or m:PeekOutput()) then
            job.reason='等待车间设备交接；请取走原有成品或疏通下游传送带。'; break
        end end
    end
    return false
end
function Automation:Update(dt)
    dt=math.max(0,dt)
    local keys={}; for id in pairs(self.queues) do table.insert(keys,id) end; table.sort(keys)
    for _,terminal in ipairs(keys) do
        local queue=self.queues[terminal]; local job=queue[1]
        -- Cancel queued items without waiting for the current task.
        for i=#queue,2,-1 do if queue[i].cancelled then local cancelled=table.remove(queue,i); cancelled.state='已取消'; table.insert(self.history,cancelled) end end
        if job then
            local finished=false
            if job.cancelled then
                local busy=false; for _,m in pairs(job.owned) do if m:IsProcessing() then busy=true end end
                job.state,job.reason='取消收尾','等待已开始加工安全完成。'
                if not busy then job.state='已取消'; finished=true end
            elseif job.delivered>=job.quantity then job.state='已完成'; finished=true
            else
                job.state='执行中'; job.clock=job.clock+dt
                while job.clock>=0.5-0.000001 do
                    job.clock=math.max(0,job.clock-0.5)
                    if not self:MoveNext(job,self:Endpoints(terminal)) then job.state='等待'; job.clock=0; break end
                    if job.delivered>=job.quantity then job.state='已完成'; finished=true; break end
                end
            end
            if finished then self:Release(job); table.remove(queue,1); table.insert(self.history,job); if #self.history>40 then table.remove(self.history,1) end end
        end
    end
end
function Automation:Snapshot(terminal)
    local lines={}; local total,available,locked,processing={},{},{},{}
    local function count(t,k,n) t[k]=(t[k] or 0)+(n or 1) end
    for _,ep in ipairs(self:Endpoints(terminal)) do
        local state=''
        if ep.source then state='无限来源 '..Definitions[ep.source].name..' ∞'
        elseif ep.storage then
            state=ep.storage:LoadText()..' · 预约位 '..ep.storage:Reserved()
            local stack={}; for _,v in pairs(ep.storage.slots) do table.insert(stack,v); count(total,v.itemType); if ep.storage.locks[v.id] then count(locked,v.itemType) end end
            table.sort(stack,function(a,b) return a.order>b.order end)
            local top=stack[1] and stack[1].itemType
            for _,v in ipairs(stack) do if v.itemType~=top or ep.storage.locks[v.id] then break end; count(available,v.itemType) end
        elseif ep.machine then
            local m=ep.machine; state=m.automationOwner and '生产任务占用' or (m:IsProcessing() and '加工中' or '可用')
            for _,v in pairs(m.slots) do count(total,v.itemType); if v.itemType=='raw_beef' then count(processing,v.itemType) end; if m.automationOwner then count(locked,v.itemType) elseif v.itemType=='cooked_beef' then count(available,v.itemType) end end
            for k in pairs(m.materials) do count(total,k); if m.automationOwner then count(locked,k) end; if m:IsProcessing() then count(processing,k) end end
            if m.burgerReady then count(total,'burger'); if m.automationOwner then count(locked,'burger') else count(available,'burger') end end
        else state='下单组件' end
        table.insert(lines,ep.name..'：'..state)
    end
    return {lines=lines,total=total,available=available,locked=locked,processing=processing}
end
function Automation:Stop()
    for _,queue in pairs(self.queues) do for _,job in ipairs(queue) do self:Release(job) end end
    self.queues={}; self.history={}
end
return Automation
