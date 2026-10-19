local Config=require('Factory/DayConfig')
---@class FactoryCampaign
---@field day integer
---@field coins integer
---@field owned table<string,integer>
---@field events table<string,boolean>
---@field lessons table<string,boolean>
---@field income integer
---@field spent integer
---@field delivered integer
---@field bonusAvailable boolean
---@field bonusEnabled boolean
---@field dirty boolean
---@field suppliesGranted boolean
---@field machineTimes table<string,table>
---@field producers? table<string,boolean>
local Campaign={}
Campaign.__index=Campaign
function Campaign.New()
    return setmetatable({day=1,coins=50,owned={},events={},lessons={},income=0,spent=0,delivered=0,
        bonusAvailable=false,bonusEnabled=false,dirty=true,machineTimes={},suppliesGranted=false},Campaign)
end
function Campaign:Unlocked(kind) return self.day >= (Config.UnlockDay[kind] or 99) end
function Campaign:Quote(kind,count)
    count=count or 1
    if type(count)~='number' or count%1~=0 or count<0 then return nil,'数量无效。' end
    if not self:Unlocked(kind) then return nil,'第'..(Config.UnlockDay[kind] or '?')..'天开放。' end
    if Config.Supplies[kind] and (self.owned[kind] or 0)<count then return nil,'每种供货点全车间仅1个，请先回收已有供货点。' end
    local cost=math.max(0,count-(self.owned[kind] or 0))*(Config.Prices[kind] or 0)
    if cost>self.coins then return nil,'金币不足：需要'..cost..'，余额'..self.coins..'。' end
    return cost,string.format('持有%d · 本次%d金币 · 余额%d',self.owned[kind] or 0,cost,self.coins)
end
function Campaign:Buy(kind,count)
    count=count or 1
    local cost,message=self:Quote(kind,count); if not cost then return false,message end
    self.owned[kind]=math.max(0,(self.owned[kind] or 0)-count)
    self.coins,self.spent=self.coins-cost,self.spent+cost; self.dirty=true
    return true,message
end
function Campaign:Recover(kind,count)
    if Config.Supplies[kind] and (self.owned[kind] or 0)>0 then return false end
    self.owned[kind]=(self.owned[kind] or 0)+(count or 1); self.dirty=true
end
function Campaign:Credit(id,amount)
    if self.events[id] then return false end
    self.events[id]=true; self.coins,self.income=self.coins+amount,self.income+amount; self.dirty=true
    return true
end
function Campaign:Delivered(order,amount,finished,componentAmount)
    local id='deliver:'..self.day..':'..order.id..':'..order.delivered
    if self.events[id] then return false end
    self.delivered=self.delivered+amount
    self:Credit(id,amount*10+(finished and 5 or 0))
    if componentAmount and componentAmount>0 then self:Learn('delivery'); if self.day==10 then self:Learn('factory') end end
end
function Campaign:Learn(key) if not self.lessons[key] then self.lessons[key]=true; self.dirty=true end end
function Campaign:Next(day,bonus)
    self.day,self.income,self.spent,self.delivered=day,0,0,0
    self.bonusAvailable,self.bonusEnabled=not not bonus,false
    self.machineTimes={}; self.dirty=true
end
function Campaign:Card(kind)
    if not self:Unlocked(kind) then return '锁定 · 第'..(Config.UnlockDay[kind] or '?')..'天' end
    if Config.Supplies[kind] then return '持有'..(self.owned[kind] or 0)..' · 全车间仅1个' end
    if kind=='manage' then return '回收建筑 · 不返金币' end
    return string.format('持有%d · %d金币%s',self.owned[kind] or 0,Config.Prices[kind] or Config.Prices[kind=='conveyor' and 'belt' or kind] or 0,
        (kind=='conveyor' or kind=='cable') and '/格' or '')
end
return Campaign
