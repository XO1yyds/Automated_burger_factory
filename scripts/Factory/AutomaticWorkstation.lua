local Definitions = require("Factory/Items").Definitions

---@alias FactoryAutomaticKind "cooker"|"assembler"
---@class FactoryCookingSlot
---@field itemType FactoryItemType
---@field progress number
---@field order integer
---@field completedAt? number

---@class FactoryAutomaticWorkstation
---@field automationOwner? table
---@field automationIntakeOwner? table
---@field kind FactoryAutomaticKind
---@field items FactoryItemService
---@field slots table<integer, FactoryCookingSlot>
---@field nextOrder integer
---@field clock number
---@field materials table<FactoryItemType, boolean>
---@field processing boolean
---@field progress number
---@field burgerReady boolean
---@field burgersProduced integer
---@field onProduced? fun()
local Workstation = {}
Workstation.__index = Workstation
Workstation.CookSeconds = 3
Workstation.AssemblySeconds = 2
---@type FactoryItemType[]
Workstation.RetrievalOrder = { "raw_beef", "bun", "cooked_beef", "lettuce" }

---@param kind FactoryAutomaticKind
---@param items FactoryItemService
---@return FactoryAutomaticWorkstation
function Workstation.New(kind, items)
    assert(kind == "cooker" or kind == "assembler", "Unknown automatic workstation")
    return setmetatable({ kind = kind, items = items, slots = {}, nextOrder = 1, clock = 0,
        materials = {}, processing = false, progress = 0, burgerReady = false, burgersProduced = 0 }, Workstation)
end

function Workstation:TryStartAssembly()
    if self.automationIntakeOwner and not self.automationOwner then return end
    if not self.processing and not self.burgerReady and self.materials.bun
        and self.materials.cooked_beef and self.materials.lettuce and not self.materials.raw_beef then
        self.processing, self.progress = true, 0
    end
end

---@return boolean, string
function Workstation:InteractCooker()
    if self.items.held then
        if self.items.held ~= "raw_beef" then return false, "自动烹饪台只接收生牛肉饼，原物仍在手中。" end
        for index = 1, 3 do
            if not self.slots[index] then
                if not self.items:ConsumeHeld("raw_beef") then return false, "手持物品已变化，未放入。" end
                self.slots[index] = { itemType = "raw_beef", progress = 0, order = self.nextOrder }
                self.nextOrder = self.nextOrder + 1
                return true, "已放入自动烹饪槽 " .. index .. "，独立加工 3 秒。"
            end
        end
        return false, "三个槽位均满（熟肉也占槽），生肉仍在手中。"
    end
    ---@type FactoryCookingSlot?
    local selected = nil
    ---@type integer?
    local selectedIndex = nil
    for index = 1, 3 do
        local slot = self.slots[index]
        if slot then
            local choose = selected == nil
            if selected then
                if slot.itemType == "cooked_beef" and selected.itemType ~= "cooked_beef" then choose = true
                elseif slot.itemType == selected.itemType then
                    if slot.itemType == "cooked_beef" then
                        choose = assert(slot.completedAt) < assert(selected.completedAt)
                            or (slot.completedAt == selected.completedAt and slot.order < selected.order)
                    else choose = slot.order > selected.order end
                end
            end
            if choose then selected, selectedIndex = slot, index end
        end
    end
    if not selected or not selectedIndex then return false, "自动烹饪台为空。" end
    local ok, message = self.items:Give(selected.itemType)
    if ok then self.slots[selectedIndex] = nil end
    if ok and selected.itemType == "raw_beef" then return true, "已取回生牛肉饼，加工进度清零。" end
    return ok, message
end

---@return boolean, string
function Workstation:InteractAssembler()
    if self.processing then return false, "组合台正在加工，加工期间禁止投入或取回材料。" end
    if self.items.held then
        local itemType = self.items.held
        if itemType ~= "bun" and itemType ~= "cooked_beef" and itemType ~= "raw_beef" and itemType ~= "lettuce" then
            return false, "自动组合台只接收汉堡胚、牛肉饼和生菜片。"
        end
        local meat = itemType == "raw_beef" or itemType == "cooked_beef"
        if self.materials[itemType] or (meat and (self.materials.raw_beef or self.materials.cooked_beef)) then
            return false, "对应材料槽已满，每种最多 1 份；原物仍在手中。"
        end
        if not self.items:ConsumeHeld(itemType) then return false, "手持物品已变化，未放入。" end
        self.materials[itemType] = true
        self:TryStartAssembly()
        if itemType == "raw_beef" then return true, "生肉已占肉槽，但缺少熟牛肉饼，不能合成；空手 F 优先取回生肉。" end
        if self.processing then return true, "正确材料齐全，开始自动组合（2 秒）。" end
        return true, self.burgerReady and "已缓存下批材料，需先空手取走成品。" or ("已放入 " .. Definitions[itemType].name)
    end
    if self.burgerReady then
        local ok, message = self.items:Give("burger")
        if ok then
            self.burgerReady = false
            self:TryStartAssembly()
        end
        return ok, message
    end
    for _, itemType in ipairs(Workstation.RetrievalOrder) do
        if self.materials[itemType] then
            local ok, message = self.items:Give(itemType)
            if ok then self.materials[itemType] = nil end
            return ok, message
        end
    end
    return false, "自动组合台为空，需要汉堡胚、熟牛肉饼、生菜片各 1 份。"
end

---@return boolean, string
function Workstation:Interact()
    if self.automationOwner then return false,"设备被生产任务占用，请先取消任务。" end
    if self.automationIntakeOwner and self.items.held then return false,"下单任务等待使用设备，暂不接收新投料；已有成品仍可取出。" end
    if self.kind == "cooker" then return self:InteractCooker() end
    return self:InteractAssembler()
end

---@param dt number
---@return boolean, string
function Workstation:Update(dt)
    local step = math.max(0, dt)
    local previousClock = self.clock
    self.clock = self.clock + step
    if self.kind == "cooker" then
        local completed = 0
        for index = 1, 3 do
            local slot = self.slots[index]
            if slot and slot.itemType == "raw_beef" then
                local remaining = Workstation.CookSeconds - slot.progress
                slot.progress = math.min(Workstation.CookSeconds, slot.progress + step)
                if slot.progress >= Workstation.CookSeconds - 0.000001 then
                    slot.progress, slot.itemType = Workstation.CookSeconds, "cooked_beef"
                    slot.completedAt = previousClock + remaining
                    completed = completed + 1
                end
            end
        end
        return completed > 0, completed > 0 and ("自动烹饪完成 " .. completed .. " 份熟肉，空手 F 取出。") or ""
    end
    if self.processing then
        self.progress = math.min(Workstation.AssemblySeconds, self.progress + step)
        if self.progress >= Workstation.AssemblySeconds - 0.000001 then
            self.materials = {}
            self.processing, self.progress, self.burgerReady = false, 0, true
            self.burgersProduced = self.burgersProduced + 1
            if self.onProduced then self.onProduced() end
            return true, "自动组合完成，生成汉堡 ×1。空手 F 取出。"
        end
    end
    return false, ""
end

---@return boolean
function Workstation:IsProcessing()
    if self.kind == "assembler" then return self.processing end
    for index = 1, 3 do
        local slot = self.slots[index]
        if slot and slot.itemType == "raw_beef" then return true end
    end
    return false
end

-- Logistics never borrows the player's hand. Capacity is validated before
-- ownership is moved; manual retrieval keeps its original LIFO rules.
---@param itemType FactoryItemType
---@return boolean
function Workstation:CanReceive(itemType,owner)
    if self.automationOwner and self.automationOwner~=owner then return false end
    if self.automationIntakeOwner and self.automationIntakeOwner~=owner then return false end
    if self.kind == "cooker" then
        if itemType ~= "raw_beef" then return false end
        for index = 1, 3 do if not self.slots[index] then return true end end
        return false
    end
    if self.processing or self.materials[itemType] then return false end
    if itemType == "cooked_beef" then return not self.materials.raw_beef end
    return itemType == "bun" or itemType == "lettuce"
end

---@param itemType FactoryItemType
---@return boolean
function Workstation:Receive(itemType,owner)
    if not self:CanReceive(itemType,owner) then return false end
    if self.kind == "cooker" then
        for index = 1, 3 do
            if not self.slots[index] then
                self.slots[index] = { itemType = itemType, progress = 0, order = self.nextOrder }
                self.nextOrder = self.nextOrder + 1
                return true
            end
        end
        return false
    end
    self.materials[itemType] = true
    self:TryStartAssembly()
    return true
end

---@return FactoryItemType?, integer?
function Workstation:PeekOutput(owner)
    if self.automationOwner and self.automationOwner~=owner then return nil end
    if self.kind == "assembler" then return self.burgerReady and "burger" or nil end
    ---@type FactoryCookingSlot?
    local chosen = nil
    ---@type integer?
    local chosenIndex = nil
    for index = 1, 3 do
        local slot = self.slots[index]
        if slot and slot.itemType == "cooked_beef" and (not chosen
            or assert(slot.completedAt) < assert(chosen.completedAt)
            or (slot.completedAt == chosen.completedAt and slot.order < chosen.order)) then
            chosen, chosenIndex = slot, index
        end
    end
    return chosen and "cooked_beef" or nil, chosenIndex
end

---@param expected FactoryItemType
---@return boolean
function Workstation:TakeOutput(expected,token,owner)
    local itemType, index = self:PeekOutput(owner)
    if itemType ~= expected then return false end
    if self.kind == "cooker" then self.slots[assert(index)] = nil
    else self.burgerReady = false; self:TryStartAssembly() end
    return true
end

---@return string
function Workstation:Status()
    if self.kind == "cooker" then
        local parts = {}
        for index = 1, 3 do
            local slot = self.slots[index]
            local text = "空"
            if slot then text = slot.itemType == "cooked_beef" and "熟肉" or string.format("生肉 %.1fs", Workstation.CookSeconds - slot.progress) end
            parts[index] = index .. "：" .. text
        end
        return "自动烹饪台 | " .. table.concat(parts, " · ")
    end
    local meat = self.materials.raw_beef and "生肉（缺少熟牛肉饼）" or (self.materials.cooked_beef and "熟肉" or "空")
    local state = self.processing and string.format("加工剩余 %.1fs", Workstation.AssemblySeconds - self.progress)
        or (self.burgerReady and "汉堡 ×1，等待取出" or "等待材料")
    return string.format("自动组合台 | 胚 %d/1 · 肉 %s · 菜 %d/1 | %s", self.materials.bun and 1 or 0, meat,
        self.materials.lettuce and 1 or 0, state)
end

---@return string
function Workstation:Prompt()
    if self.kind == "cooker" then
        if self.items.held then return "F：放入生牛肉饼（最多 3 槽）" end
        return "F：优先取最早完成熟肉；生肉后进先出"
    end
    if self.processing then return "加工中：暂不能投入或取回材料" end
    if self.items.held then return "F：放入 " .. Definitions[self.items.held].name end
    return self.burgerReady and "F：取出汉堡" or "F：取回材料（误放生肉优先）"
end

function Workstation:Reset()
    self.automationOwner,self.automationIntakeOwner=nil,nil
    self.slots, self.materials = {}, {}
    self.nextOrder, self.clock, self.processing, self.progress = 1, 0, false, 0
    self.burgerReady, self.burgersProduced = false, 0
end

return Workstation
