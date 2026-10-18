local Definitions = require("Factory/Items").Definitions

---@class FactoryManualProduction
---@field items FactoryItemService
---@field grillItem FactoryItemType?
---@field grillProgress number
---@field grillArmed boolean
---@field materials table<FactoryItemType, boolean>
---@field burgerReady boolean
---@field burgersProduced integer
---@field onProduced? fun()
local Manual = {}
Manual.__index = Manual

---@type FactoryItemType[]
Manual.Recipe = { "bun", "cooked_beef", "lettuce" }
Manual.CookSeconds = 3

---@param items FactoryItemService
---@return FactoryManualProduction
function Manual.New(items)
    return setmetatable({ items = items, grillItem = nil, grillProgress = 0,
        grillArmed = false, materials = {}, burgerReady = false, burgersProduced = 0 }, Manual)
end

---@return boolean, string
function Manual:InteractGrill()
    if self.grillItem == "cooked_beef" then
        if self.items.held then return false, "请先腾出手，再取出熟牛肉饼。" end
        local ok, message = self.items:Give("cooked_beef")
        if ok then self.grillItem, self.grillProgress, self.grillArmed = nil, 0, false end
        return ok, message
    end
    if self.grillItem then
        return false, self.grillArmed and "空手连续长按 F 3 秒煎肉；生肉不能取出。" or "先松开 F，再长按 F 煎肉。"
    end
    if not self.items:ConsumeHeld("raw_beef") then return false, "煎肉铁板只接收生牛肉饼。" end
    self.grillItem, self.grillProgress, self.grillArmed = "raw_beef", 0, false
    return true, "已放入生牛肉饼。先松开 F，再连续长按 F 3 秒。"
end

-- called before F's one-shot action, so the placement press cannot start cooking.
---@param dt number
---@param aimedAtGrill boolean
---@param fDown boolean
---@param blocked boolean
---@return boolean, string
function Manual:UpdateGrill(dt, aimedAtGrill, fDown, blocked)
    if self.grillItem ~= "raw_beef" then return false, "" end
    if not fDown then self.grillArmed = true end
    if not self.grillArmed or not fDown or not aimedAtGrill or blocked or self.items.held then
        self.grillProgress = 0
        return false, ""
    end
    self.grillProgress = math.min(Manual.CookSeconds, self.grillProgress + math.max(0, dt))
    if self.grillProgress >= Manual.CookSeconds - 0.000001 then
        self.grillProgress = Manual.CookSeconds
        self.grillItem = "cooked_beef"
        return true, "熟牛肉饼已完成。松开 F 后，空手按 F 取出。"
    end
    return false, ""
end

---@return boolean, string
function Manual:InteractAssembly()
    if self.items.held then
        if self.burgerReady then return false, "请先空手取走汉堡，组合台成品容量为 1。" end
        local itemType = self.items.held
        local allowed = itemType == "bun" or itemType == "cooked_beef" or itemType == "lettuce"
        if not allowed then
            return false, itemType == "raw_beef" and "缺少熟牛肉饼：生肉不能用于手工组合。" or "组合台只接收汉堡胚、熟牛肉饼、生菜片。"
        end
        if self.materials[itemType] then return false, Definitions[itemType].name .. "已放入，每种最多 1 份。" end
        if not self.items:ConsumeHeld(itemType) then return false, "手持物品已变化，未放入。" end
        self.materials[itemType] = true
        if self.materials.bun and self.materials.cooked_beef and self.materials.lettuce then
            self.materials = {}
            self.burgerReady = true
            self.burgersProduced = self.burgersProduced + 1
            if self.onProduced then self.onProduced() end
            return true, "材料齐全，已手工生成汉堡。空手按 F 取出。"
        end
        return true, "已放入 " .. Definitions[itemType].name
    end
    if self.burgerReady then
        local ok, message = self.items:Give("burger")
        if ok then self.burgerReady = false end
        return ok, message
    end
    -- Stable retrieval order is sufficient for the whitebox, no extra selection UI.
    for _, itemType in ipairs(Manual.Recipe) do
        if self.materials[itemType] then
            local ok, message = self.items:Give(itemType)
            if ok then self.materials[itemType] = nil end
            return ok, message
        end
    end
    return false, "组合台为空。需要汉堡胚、熟牛肉饼、生菜片各 1 份。"
end

---@return string
function Manual:GrillStatus()
    if not self.grillItem then return "铁板：空（容量 1）" end
    if self.grillItem == "cooked_beef" then return "铁板：熟牛肉饼 ×1，等待空手取出" end
    return string.format("铁板：生牛肉饼 ×1，剩余 %.1fs / 3.0s", Manual.CookSeconds - self.grillProgress)
end

---@return string
function Manual:AssemblyStatus()
    if self.burgerReady then return "组合台：汉堡 ×1，等待空手取出" end
    return string.format("组合台：汉堡胚 %d/1 · 熟牛肉饼 %d/1 · 生菜片 %d/1",
        self.materials.bun and 1 or 0, self.materials.cooked_beef and 1 or 0, self.materials.lettuce and 1 or 0)
end

---@param id string
---@return string
function Manual:Prompt(id)
    if id == "grill" then
        if not self.grillItem then return "F：放入生牛肉饼" end
        if self.grillItem == "cooked_beef" then return "F：空手取出熟牛肉饼" end
        if not self.grillArmed then return "先松开 F，再长按 F 煎肉" end
        return self.items.held and "先腾出手，再长按 F 煎肉" or "长按 F：连续煎肉 3 秒（松开或离开则清零）"
    end
    if self.burgerReady then return "F：空手取出汉堡" end
    if self.items.held then return "F：放入 " .. Definitions[self.items.held].name end
    return "F：取回未合成材料（汉堡胚 → 熟牛肉饼 → 生菜片）"
end

function Manual:Reset()
    self.grillItem, self.grillProgress, self.grillArmed = nil, 0, false
    self.materials, self.burgerReady, self.burgersProduced = {}, false, 0
end

return Manual
