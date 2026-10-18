---@class FactoryOrder
---@field id integer
---@field required integer
---@field delivered integer

---@class FactoryOrders
---@field items FactoryItemService
---@field random fun(min:integer,max:integer): integer
---@field active FactoryOrder[]
---@field nextId integer
---@field day integer
---@field wait number?
---@field enabled boolean
---@field selectedId integer?
---@field stock integer
---@field completed integer
local Orders = {}
Orders.__index = Orders

---@param items FactoryItemService
---@param random? fun(min:integer,max:integer): integer
---@return FactoryOrders
function Orders.New(items, random)
    local self = setmetatable({ items = items, random = random or math.random, active = {}, nextId = 1, day = 1,
        enabled = true, stock = 0, completed = 0 }, Orders)
    self.wait = self.random(5, 15)
    return self
end

---@param dt number
function Orders:Update(dt)
    if not self.enabled then return end
    if #self.active >= 5 then self.wait = nil; return end
    if not self.wait then self.wait = self.random(5, 15) end
    local remaining = math.max(0, dt)
    while self.wait and remaining >= self.wait and #self.active < 5 do
        remaining = remaining - self.wait
        local need = self.day == 1 and 1 or self.random(1, math.min(3, self.day))
        table.insert(self.active, { id = self.nextId, required = need, delivered = 0 })
        self.nextId = self.nextId + 1
        self.wait = #self.active < 5 and self.random(5, 15) or nil
    end
    if self.wait then self.wait = self.wait - remaining end
end

---@param id integer?
---@return FactoryOrder?,integer?
function Orders:Find(id)
    for index, order in ipairs(self.active) do if order.id == id then return order, index end end
    return nil, nil
end

---@param id integer?
function Orders:Select(id)
    self.selectedId = self:Find(id) and id or nil
end

---@return boolean
function Orders:CanDeliver() return self.stock > 0 and self:Find(self.selectedId) ~= nil end

---@return boolean,string
function Orders:Deliver()
    local order, index = self:Find(self.selectedId)
    if not order or not index then self.selectedId = nil; return false, "请主动选择有效订单。" end
    if self.stock <= 0 then return false, "交付区域没有汉堡。" end
    local amount = math.min(self.stock, order.required - order.delivered)
    if amount <= 0 then return false, "该订单已经完成。" end
    local wasFull = #self.active == 5
    self.stock = self.stock - amount
    order.delivered = order.delivered + amount
    local message = string.format("订单 %02d 交付 %d 个，进度 %d/%d。", order.id, amount, order.delivered, order.required)
    if order.delivered == order.required then
        table.remove(self.active, index)
        self.selectedId = nil
        self.completed = self.completed + 1
        if wasFull and self.enabled then self.wait = self.random(5, 15) end
    end
    return true, message
end

---@return boolean,string
function Orders:InteractDepot()
    if self.items.held then
        if self.items.held ~= "burger" then return false, "交付区域只接收汉堡，原物仍在手中。" end
        if self.stock >= 5 then return false, "交付区域容量已满（5 个），汉堡仍在手中。" end
        if not self.items:ConsumeHeld("burger") then return false, "手持物品已变化，未存入。" end
        self.stock = self.stock + 1
        return true, "汉堡已放入交付区域。"
    end
    if self.stock == 0 then return false, "交付区域为空。" end
    local ok, message = self.items:Give("burger")
    if ok then self.stock = self.stock - 1 end
    return ok, message
end

-- Daily loop owns the timer; depot stock is retained at both boundaries.
function Orders:EndDay()
    self.enabled, self.active, self.selectedId, self.wait = false, {}, nil, nil
end

---@param day integer
function Orders:SetDay(day)
    self.day, self.active, self.selectedId, self.enabled, self.completed = day, {}, nil, true, 0
    self.wait = self.random(5, 15)
end

return Orders
