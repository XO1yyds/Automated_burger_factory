-- Components decorate a host; they never create a second footprint or container.
---@class FactoryAttachedComponents
---@field context table
---@field mode string?
---@field selected string?
local Components={}
Components.__index=Components
---@return FactoryAttachedComponents
function Components.New(context) return setmetatable({context=context,mode=nil,selected=nil},Components) end
function Components:Host(id)
    for _,s in ipairs(self.context.stations()) do if s.id==id then return s end end
end
function Components:CanBind(id,kind)
    local host=self:Host(id)
    if not host or (host.buildingKind~='storage' and (kind~='delivery' or host.buildingKind~='buffer')) then return false,kind=='order' and '下单组件只能依附库存。' or '请选择库存或缓存台。' end
    if host.component then return false,'该建筑已有组件，请先卸下；两类组件不能叠加。' end
    if kind=='order' then
        local net=self.context.automation().cables:For(id)
        if net and #net.terminals>0 then return false,'该电缆网络已有下单终端，不能再绑定。' end
    end
    return true,'可绑定；宿主占地、容量和物品保持不变。'
end
function Components:Rename(host)
    host.baseName=host.baseName or host.name
    host.name=host.component=='order' and '下单终端' or host.component=='delivery' and (host.buildingKind=='buffer' and '交付缓存' or '交付终端') or host.baseName
end
function Components:Bind(id,kind)
    local ok,message=self:CanBind(id,kind); if not ok then return false,message end
    if self.context.purchase then local paid,reason=self.context.purchase(kind=='order' and 'terminal' or 'delivery_component'); if not paid then return false,reason end end
    local host=self:Host(id); host.component=kind; self:Rename(host)
    local a=self.context.automation(); a.cables.revision=a.cables.revision+1
    if kind=='order' then a.service:ObserveStorage(id,self.context.storage(id)) end
    self.selected=nil
    return true,'已绑定为'..host.name..'。'
end
function Components:Unbind(id)
    local host=self:Host(id); if not host or not host.component then return false,'该建筑没有组件。' end
    local a=self.context.automation()
    if host.component=='order' then
        a.service:CancelAll(id)
        if a.terminal==id then a:Close() end
        local storage=self.context.storage(id); if storage then storage.onReceive=nil end
    end
    if self.context.recover then self.context.recover(host.component=='order' and 'terminal' or 'delivery_component',1) end
    host.component=nil; self:Rename(host); a.cables.revision=a.cables.revision+1
    return true,'组件已卸下，宿主和库存物品保留。'
end
function Components:DeliveryStores()
    local list={}
    for _,s in ipairs(self.context.stations()) do if s.component=='delivery' then
        local store=self.context.storage(s.id); if store then table.insert(list,{id=s.id,name=s.name,storage=store}) end
    end end
    table.sort(list,function(a,b) return a.id<b.id end); return list
end
return Components
