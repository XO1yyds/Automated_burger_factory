---@class FactoryDaySummary
---@field day integer
---@field orders integer
---@field manual integer
---@field automatic integer
---@field total integer
---@field early boolean
---@field delivered integer
---@field goal integer
---@field achieved boolean
---@field income integer
---@field spent integer
---@field coins integer
---@field seconds number
---@field rate number
---@field bonus boolean

---@class FactoryGameLoop
---@field orders FactoryOrders
---@field state string
---@field day integer
---@field remaining number
---@field manual integer
---@field automatic integer
---@field history FactoryDaySummary[]
---@field campaign? FactoryCampaign
---@field briefing boolean
---@field teaching? boolean
---@field pausedFrom? string
local Loop = {}
local Days=require('Factory/DayConfig')
Loop.__index = Loop
Loop.DaySeconds = 300
Loop.DayCount = 3

---@param orders FactoryOrders
---@return FactoryGameLoop
function Loop.New(orders,campaign)
    if campaign then orders:Configure(Days.Day(1),false) end
    return setmetatable({ orders = orders, campaign=campaign,state = campaign and 'title' or "running", day = 1,
        remaining = campaign and Days.Day(1).seconds or Loop.DaySeconds,briefing=false,
        manual = 0, automatic = 0, history = {} }, Loop)
end

---@return boolean
function Loop:IsRunning() return self.state == "running" or self.state=='preparation' end
function Loop:CanSimulate() return self.state=='running' and not self.teaching end
function Loop:StartTrading()
    if self.state~='preparation' then return false end
    self.orders:Configure(Days.Day(self.day),self.campaign.bonusEnabled)
    self.state,self.briefing='running',false; self.campaign.dirty=true; return true
end
function Loop:Prepare()
    self.state,self.briefing='preparation',true
    self.orders.day=self.day; self.orders.limit=Days.Day(self.day).limit
    self.orders:EndDay()
end

function Loop:Expire()
    self.remaining = 0
    self.orders:EndDay()
end

---@param dt number
function Loop:Update(dt)
    if not self:CanSimulate() then return end
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
    self.pausedFrom=self.state; self.state = "paused"
    return true
end

---@return boolean
function Loop:Resume()
    if self.state ~= "paused" then return false end
    self.state = self.pausedFrom or "running"
    return true
end

---@param route string
function Loop:RecordBurger(route)
    if not self:CanSimulate() or self.remaining<=0 then return end
    if self.campaign then self.campaign:Learn(route=='manual' and 'manual' or 'assembler') end
    if route == "manual" then self.manual = self.manual + 1
    elseif route == "automatic" then self.automatic = self.automatic + 1 end
end

---@return boolean
function Loop:CanCashierEnd() return self.state=='running' and self.remaining == 0 end

---@param source string
---@return boolean,string
function Loop:EndDay(source)
    local allowed = (source == "pause" and self.state == "paused" and self.pausedFrom~='preparation')
        or (source == "cashier" and self:CanCashierEnd())
    if not allowed then return false, "收银台只能在计时归零后结束；提前结束请使用暂停菜单。" end
    table.insert(self.history, { day = self.day, orders = self.orders.completed,
        manual = self.manual, automatic = self.automatic, total = self.manual + self.automatic,
        early = self.remaining > 0 })
    if self.campaign then
        local c,d=self.campaign,Days.Day(self.day); local s=self.history[#self.history]
        s.delivered,s.goal=c.delivered,d.goal; s.achieved=c.delivered>=d.goal
        if s.achieved then c:Credit('goal:'..self.day,20) end
        s.income,s.spent,s.coins=c.income,c.spent,c.coins
        s.seconds=d.seconds-self.remaining; s.rate=s.seconds>0 and s.total*60/s.seconds or 0
        s.bonus=s.achieved and s.seconds>=60 and s.rate>=Days.Total(d)*60/d.seconds*1.25
        c.dirty=true
    end
    self.orders:EndDay()
    self.state = "settlement"
    return true, "当天已结束，进入结算。"
end

---@return boolean
function Loop:Continue()
    if self.state ~= "settlement" then return false end
    if self.day == (self.campaign and 10 or Loop.DayCount) then self.state = "complete"; if self.campaign then self.campaign.dirty=true end; return true end
    self.day = self.day + 1
    self.remaining, self.manual, self.automatic = self.campaign and Days.Day(self.day).seconds or Loop.DaySeconds, 0, 0
    if self.campaign then
        self.campaign:Next(self.day,self.day>=3 and self.history[#self.history].bonus)
        self:Prepare(); return true
    end
    self.orders:SetDay(self.day)
    self.state = "running"
    return true
end

---@return string
function Loop:ClockText()
    local seconds = math.ceil(self.remaining)
    return string.format("Day %d/%d · %02d:%02d%s", self.day, self.campaign and 10 or Loop.DayCount, seconds // 60, seconds % 60,
        self.remaining == 0 and " · 营业结束，可继续整理；收银台结束当天" or "")
end

return Loop
