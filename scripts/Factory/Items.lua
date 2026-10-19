-- Single-hand ownership and ground entities. No inventory, crafting or persistence.
---@alias FactoryItemType "bun"|"raw_beef"|"cooked_beef"|"lettuce"|"burger"
---@class FactoryItemDefinition
---@field name string
---@field color number[]
---@field source boolean

---@class FactoryGroundItem
---@field id integer
---@field itemType FactoryItemType
---@field position Vector3
---@field node Node
---@field label Label?
---@field identity? table

---@class FactoryItemContext
---@field createGround fun(itemType: FactoryItemType, position: Vector3): Node
---@field createHeld fun(itemType: FactoryItemType): Node
---@field isSpotFree fun(position: Vector3, radius: number): boolean
---@field isLineClear fun(origin: Vector3, destination: Vector3): boolean
---@field onAdded fun(item: FactoryGroundItem)
---@field onRemoved fun(item: FactoryGroundItem)

---@class FactoryItemService
---@field held FactoryItemType?
---@field heldNode Node?
---@field heldIdentity? table
---@field ground table<integer, FactoryGroundItem>
---@field nextId integer
---@field context FactoryItemContext
local Items = {}
Items.__index = Items

---@type table<FactoryItemType, FactoryItemDefinition>
Items.Definitions = {
    bun = { name = "汉堡胚", color = { 0.90, 0.73, 0.39 }, source = true },
    raw_beef = { name = "生牛肉饼", color = { 0.76, 0.29, 0.31 }, source = true },
    cooked_beef = { name = "熟牛肉饼", color = { 0.40, 0.23, 0.12 }, source = false },
    lettuce = { name = "生菜片", color = { 0.29, 0.76, 0.35 }, source = true },
    burger = { name = "汉堡", color = { 0.94, 0.51, 0.14 }, source = false },
}

---@param context FactoryItemContext
---@return FactoryItemService
function Items.New(context)
    return setmetatable({ context = context, held = nil, heldNode = nil, ground = {}, nextId = 1 }, Items)
end

---@param itemType FactoryItemType
---@return boolean, string
function Items:Give(itemType,identity)
    local definition = Items.Definitions[itemType]
    if not definition then return false, "未知物品。" end
    if self.held then return false, "手上已有物品，请先按 Q 放下。" end
    -- Create the visible entity before changing ownership.
    local node = self.context.createHeld(itemType)
    self.heldNode, self.held = node, itemType
    self.heldIdentity=identity or {}
    return true, "获得 " .. definition.name
end

-- Transfer one held item into a workstation after its input was validated.
---@param expected FactoryItemType
---@return boolean
function Items:ConsumeHeld(expected)
    if self.held ~= expected then return false end
    if self.heldNode then self.heldNode:Remove() end
    self.held, self.heldNode = nil, nil
    self.heldIdentity=nil
    return true
end

---@param itemType FactoryItemType
---@param position? Vector3
---@param facing? Vector3
---@return boolean, string
function Items:TakeSource(itemType, position, facing)
    local definition = Items.Definitions[itemType]
    if not definition or not definition.source then return false, "这不是可获取的原料。" end
    if self.held then
        if not position or not facing then return false, "原料互换需要附近的有效放置位置。" end
        local previous = self.held
        local incoming = self.context.createHeld(itemType)
        local dropped = self:Drop(position, facing)
        if not dropped then
            incoming:Remove()
            return false, "附近没有空位，原料未交换，原物品仍在手中。"
        end
        self.held, self.heldNode, self.heldIdentity = itemType, incoming, {}
        return true, "已换取 " .. definition.name .. "，" .. Items.Definitions[previous].name .. "留在附近地面。"
    end
    return self:Give(itemType)
end

---@param position Vector3
---@return boolean
function Items:IsSpotFree(position)
    if not self.context.isSpotFree(position, 0.18) then return false end
    for _, item in pairs(self.ground) do
        local delta = item.position - position
        delta.y = 0
        -- Items are boxes, so diagonal circle spacing alone can allow corner overlap.
        if math.abs(delta.x) < 0.36 and math.abs(delta.z) < 0.36 then return false end
    end
    return true
end

---@param itemType FactoryItemType
---@param position Vector3
---@return FactoryGroundItem?
function Items:SpawnGround(itemType, position,identity)
    if not Items.Definitions[itemType] or not self:IsSpotFree(position) then return nil end
    local item = {
        id = self.nextId, itemType = itemType,identity=identity or {},
        position = Vector3(position.x, 0.14, position.z),
        node = self.context.createGround(itemType, Vector3(position.x, 0.14, position.z)),
    } --[[@as FactoryGroundItem]]
    self.nextId = self.nextId + 1
    self.ground[item.id] = item
    self.context.onAdded(item)
    return item
end

---@param id integer
---@return boolean, string
function Items:Pickup(id)
    local item = self.ground[id]
    if not item then return false, "物品已被取走。" end
    if self.held then
        local previous = self.held
        local previousIdentity=self.heldIdentity
        -- Prepare both replacement visuals before committing either owner.
        local newHeld = self.context.createHeld(item.itemType)
        local newGround = self.context.createGround(previous, item.position)
        if self.heldNode then self.heldNode:Remove() end
        self.context.onRemoved(item)
        item.node:Remove()
        self.held, self.heldNode = item.itemType, newHeld
        self.heldIdentity=item.identity or {}
        item.itemType, item.node = previous, newGround
        item.identity=previousIdentity or {}
        self.context.onAdded(item)
        return true, "已交换：手持 " .. Items.Definitions[self.held].name .. "，原位置留下 " .. Items.Definitions[previous].name
    end
    local ok, message = self:Give(item.itemType,item.identity)
    if not ok then return false, message end
    self.context.onRemoved(item)
    item.node:Remove()
    self.ground[id] = nil
    return true, "拾取 " .. Items.Definitions[item.itemType].name
end

---@param position Vector3
---@param facing Vector3
---@return boolean, string
function Items:Drop(position, facing)
    if not self.held then return false, "" end
    local itemType = self.held
    local radii = { 0.7, 1.0, 0.5 }
    for _, radius in ipairs(radii) do
        for step = 0, 15 do
            local angle = step * math.pi / 8
            local dx = facing.x * math.cos(angle) - facing.z * math.sin(angle)
            local dz = facing.x * math.sin(angle) + facing.z * math.cos(angle)
            local spot = Vector3(position.x + dx * radius, 0.14, position.z + dz * radius)
            if self:IsSpotFree(spot) then
                local item = self:SpawnGround(itemType, spot,self.heldIdentity)
                if item then
                    if self.heldNode then self.heldNode:Remove() end
                    self.heldNode, self.held = nil, nil
                    self.heldIdentity=nil
                    return true, "已放下 " .. Items.Definitions[itemType].name
                end
            end
        end
    end
    return false, "附近没有可放置的位置，物品仍在手中。"
end

-- Withdrawn terminal items fall nearby when the existing hand is occupied.
function Items:PlaceNearby(itemType,position,facing,identity)
    for _,radius in ipairs({0.7,1.0,0.5}) do
        for step=0,15 do
            local angle=step*math.pi/8
            local dx=facing.x*math.cos(angle)-facing.z*math.sin(angle)
            local dz=facing.x*math.sin(angle)+facing.z*math.cos(angle)
            local spot=Vector3(position.x+dx*radius,0.14,position.z+dz*radius)
            if self:IsSpotFree(spot) then local item=self:SpawnGround(itemType,spot,identity); if item then return item end end
        end
    end
    return nil
end

---@param position Vector3
---@param direction Vector3
---@param range number
---@return FactoryGroundItem?, number
function Items:FindGround(position, direction, range)
    ---@type FactoryGroundItem?
    local nearest = nil
    local nearestDistance = range + 0.001
    for _, item in pairs(self.ground) do
        local delta = Vector3(item.position.x - position.x, 0, item.position.z - position.z)
        local centerDistance = delta:Length()
        local distance = math.max(0, centerDistance - 0.18)
        if centerDistance > 0.001 and distance < nearestDistance and delta:Normalized():DotProduct(direction) >= 0.5
            and self.context.isLineClear(position, item.position) then
            nearest, nearestDistance = item, distance
        end
    end
    return nearest, nearestDistance
end

function Items:Reset()
    self.heldIdentity=nil
    if self.heldNode then self.heldNode:Remove() end
    self.held, self.heldNode = nil, nil
    for _, item in pairs(self.ground) do
        self.context.onRemoved(item)
        item.node:Remove()
    end
    self.ground = {}
end

return Items
