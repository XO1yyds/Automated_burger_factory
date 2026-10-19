local Definitions = require("Factory/Items").Definitions

---@class FactoryStoredItem
---@field id integer
---@field itemType FactoryItemType
---@field order integer
---@field identity? table

---@class FactoryBufferStorage
---@field slots table<integer,FactoryStoredItem>
---@field nextId integer
---@field capacity integer
---@field locks table
---@field reserved table
---@field onReceive? fun(kind:FactoryItemType,identity:table)
local Buffer = {}
Buffer.__index = Buffer
Buffer.Capacity = 6

---@return FactoryBufferStorage
function Buffer.New(capacity) return setmetatable({ slots = {}, nextId = 1, capacity = capacity or 6, locks = {}, reserved = {} }, Buffer) end

function Buffer:Count()
    local count = 0
    for _ in pairs(self.slots) do count = count + 1 end
    return count
end

function Buffer:Reserved(exceptOwner)
    local count=0
    for owner,n in pairs(self.reserved) do if owner~=exceptOwner then count=count+n end end
    return count
end
function Buffer:ReserveSpace(owner,count)
    count=count or 1
    if self:Count()+self:Reserved()+count>self.capacity then return false end
    self.reserved[owner]=(self.reserved[owner] or 0)+count
    return true
end
function Buffer:Release(owner)
    self.reserved[owner]=nil
    for id,value in pairs(self.locks) do if value==owner then self.locks[id]=nil end end
end
function Buffer:CanReceive(itemType,owner) return Definitions[itemType] ~= nil and self:Count()+self:Reserved(owner) < self.capacity end

---@param itemType FactoryItemType
function Buffer:Receive(itemType,owner,identity)
    if not self:CanReceive(itemType,owner) then return false end
    for index = 1, self.capacity do
        if not self.slots[index] then
            identity=identity or {}
            self.slots[index] = { id = self.nextId, itemType = itemType, order = self.nextId, identity=identity }
            self.nextId = self.nextId + 1
            if owner and self.reserved[owner] then self.reserved[owner]=math.max(0,self.reserved[owner]-1) end
            if self.onReceive then self.onReceive(itemType,identity) end
            return true
        end
    end
    return false
end

---@return FactoryItemType?,integer?,integer?
function Buffer:PeekOutput(owner,includeLocked)
    ---@type FactoryStoredItem?
    local selected = nil
    local selectedIndex = 0
    for index = 1, self.capacity do
        local item = self.slots[index]
        if item and (not selected or item.order > selected.order) then selected, selectedIndex = item, index end
    end
    if selected and not includeLocked and self.locks[selected.id] and self.locks[selected.id]~=owner then return nil end
    return selected and selected.itemType or nil, selected and selected.id or nil, selectedIndex, selected and selected.identity
end

---@param expected FactoryItemType
---@param id? integer
function Buffer:TakeOutput(expected, id,owner)
    local itemType, actualId, index = self:PeekOutput(owner)
    if itemType ~= expected or (id and actualId ~= id) then return false end
    self.slots[assert(index)] = nil
    return true
end

---@param index integer
---@param expectedId integer
---@param items FactoryItemService
---@return boolean,string
function Buffer:TakeOrSwap(index, expectedId, items)
    local selected = self.slots[index]
    if selected and self.locks[selected.id] then return false,"物品已被生产任务预约。" end
    if not selected and not self:CanReceive(items.held) then return false,"存储空间不足或已预约。" end
    if not selected and expectedId == 0 and items.held and index >= 1 and index <= self.capacity then
        local held = items.held
        if not items:ConsumeHeld(held) then return false, "手持物已变化。" end
        self.slots[index] = { id = self.nextId, itemType = held, order = self.nextId }
        self.nextId = self.nextId + 1
        return true, "已存入" .. Definitions[held].name .. "。"
    end
    if not selected or selected.id ~= expectedId then return false, "选中物品已经变化，请重新选择。" end
    local oldHeld = items.held
    if oldHeld then
        -- Allocate the incoming held visual before touching either ownership.
        local node = items.context.createHeld(selected.itemType)
        if not items:ConsumeHeld(oldHeld) then node:Remove(); return false, "手持物已变化，交换取消。" end
        items.held, items.heldNode = selected.itemType, node
        self.slots[index] = { id = self.nextId, itemType = oldHeld, order = self.nextId }
        self.nextId = self.nextId + 1
        return true, "已交换：取出" .. Definitions[selected.itemType].name .. "，放入" .. Definitions[oldHeld].name .. "。"
    end
    local ok, message = items:Give(selected.itemType)
    if ok then self.slots[index] = nil end
    return ok, message
end

---@return FactoryItemType[]
function Buffer:Contents()
    local sorted, result = {}, {}
    for _, item in pairs(self.slots) do table.insert(sorted, item) end
    table.sort(sorted, function(a, b) return a.order < b.order end)
    for _, item in ipairs(sorted) do table.insert(result, item.itemType) end
    return result
end

function Buffer:InteractStack(items)
    if items.held then return false,'库存不接受手动存入或交换，请先空手再取出。' end
    local _,id,index=self:PeekOutput(nil,true)
    if not id then return false,'库存为空。' end
    return self:TakeOrSwap(index,id,items)
end
function Buffer:LoadText()
    local count=self:Count()
    local level=count<=self.capacity/3 and "低" or count<=self.capacity*2/3 and "中" or "高"
    return string.format("载荷%s %d/%d",level,count,self.capacity)
end
function Buffer:FindKind(kind)
    local found,index=nil,nil
    for i,v in pairs(self.slots) do if v.itemType==kind and not self.locks[v.id] and (not found or v.order>found.order) then found,index=v,i end end
    return found,index
end
function Buffer:CountKind(kind)
    local n=0; for _,v in pairs(self.slots) do if v.itemType==kind and not self.locks[v.id] then n=n+1 end end; return n
end
function Buffer:TakeKind(kind)
    local item,index=self:FindKind(kind); if not item then return false end
    self.slots[index]=nil; return true
end
function Buffer:Withdraw(kind,items,position,facing)
    local item,index=self:FindKind(kind); if not item then return false,'该物品已被取走或已预约，请重新选择。' end
    if items.held then
        if not items:PlaceNearby(kind,position,facing) then return false,'附近地面已满，不可取出；物品仍在库存中。' end
        self.slots[index]=nil; return true,'已取出1件至附近地面，原手持物保持不变。'
    end
    local ok,message=items:Give(kind); if ok then self.slots[index]=nil end; return ok,message
end
return Buffer
