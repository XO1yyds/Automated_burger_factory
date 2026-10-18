local Definitions = require("Factory/Items").Definitions

---@class FactoryStoredItem
---@field id integer
---@field itemType FactoryItemType
---@field order integer

---@class FactoryBufferStorage
---@field slots table<integer,FactoryStoredItem>
---@field nextId integer
local Buffer = {}
Buffer.__index = Buffer
Buffer.Capacity = 6

---@return FactoryBufferStorage
function Buffer.New() return setmetatable({ slots = {}, nextId = 1 }, Buffer) end

function Buffer:Count()
    local count = 0
    for _ in pairs(self.slots) do count = count + 1 end
    return count
end

---@param itemType FactoryItemType
function Buffer:CanReceive(itemType) return Definitions[itemType] ~= nil and self:Count() < Buffer.Capacity end

---@param itemType FactoryItemType
function Buffer:Receive(itemType)
    if not self:CanReceive(itemType) then return false end
    for index = 1, Buffer.Capacity do
        if not self.slots[index] then
            self.slots[index] = { id = self.nextId, itemType = itemType, order = self.nextId }
            self.nextId = self.nextId + 1
            return true
        end
    end
    return false
end

---@return FactoryItemType?,integer?,integer?
function Buffer:PeekOutput()
    ---@type FactoryStoredItem?
    local selected = nil
    local selectedIndex = 0
    for index = 1, Buffer.Capacity do
        local item = self.slots[index]
        if item and (not selected or item.order > selected.order) then selected, selectedIndex = item, index end
    end
    return selected and selected.itemType or nil, selected and selected.id or nil, selectedIndex
end

---@param expected FactoryItemType
---@param id? integer
function Buffer:TakeOutput(expected, id)
    local itemType, actualId, index = self:PeekOutput()
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
    if not selected and expectedId == 0 and items.held and index >= 1 and index <= Buffer.Capacity then
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

return Buffer
