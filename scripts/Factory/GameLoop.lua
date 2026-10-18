---@class FactoryDaySummary
---@field day integer
---@field orders integer
---@field manual integer
---@field automatic integer
---@field total integer
---@field early boolean

---@class FactoryGameLoop
---@field orders FactoryOrders
---@field state string
---@field day integer
---@field remaining number
---@field manual integer
---@field automatic integer
---@field history FactoryDaySummary[]
local Loop = {}
Loop.__index = Loop
Loop.DaySeconds = 300
Loop.DayCount = 3

---@param orders FactoryOrders
---@return FactoryGameLoop
function Loop.New(orders)
    return setmetatable({ orders = orders, state = "running", day = 1, remaining = Loop.DaySeconds,
        manual = 0, automatic = 0, history = {} }, Loop)
end

---@return boolean
function Loop:IsRunning() return self.state == "running" end

function Loop:Expire()
    self.remaining = 0
    self.orders:EndDay()
end

---@param dt number
function Loop:Update(dt)
    if not self:IsRunning() then return end
    local step = math.max(0, dt)
    if self.remaining > 0 then
        -- Only the portion before expiry can produce new orders. Expiry clears
        -- all outstanding orders, even if an interval ends in the same frame.
        self.orders:Update(math.min(step, self.remaining))
        self.remaining = math.max(0, self.remaining - step)
        if self.remaining <= 0.000001 then self:Expire() end
    end
end

---@return boolean
function Loop:Pause()
    if not self:IsRunning() then return false end
    self.state = "paused"
    return true
end

---@return boolean
function Loop:Resume()
    if self.state ~= "paused" then return false end
    self.state = "running"
    return true
end

---@param route string
function Loop:RecordBurger(route)
    if not self:IsRunning() then return end
    if route == "manual" then self.manual = self.manual + 1
    elseif route == "automatic" then self.automatic = self.automatic + 1 end
end

---@return boolean
function Loop:CanCashierEnd() return self:IsRunning() and self.remaining == 0 end

---@param source string
---@return boolean,string
function Loop:EndDay(source)
    local allowed = (source == "pause" and self.state == "paused")
        or (source == "cashier" and self:CanCashierEnd())
    if not allowed then return false, "收银台只能在计时归零后结束；提前结束请使用暂停菜单。" end
    table.insert(self.history, { day = self.day, orders = self.orders.completed,
        manual = self.manual, automatic = self.automatic, total = self.manual + self.automatic,
        early = self.remaining > 0 })
    self.orders:EndDay()
    self.state = "settlement"
    return true, "当天已结束，进入结算。"
end

---@return boolean
function Loop:Continue()
    if self.state ~= "settlement" then return false end
    if self.day == Loop.DayCount then self.state = "complete"; return true end
    self.day = self.day + 1
    self.remaining, self.manual, self.automatic = Loop.DaySeconds, 0, 0
    self.orders:SetDay(self.day)
    self.state = "running"
    return true
end

---@return string
function Loop:ClockText()
    local seconds = math.ceil(self.remaining)
    return string.format("Day %d/%d · %02d:%02d%s", self.day, Loop.DayCount, seconds // 60, seconds % 60,
        self.remaining == 0 and " · 营业结束，可继续整理；收银台结束当天" or "")
end

return Loop
