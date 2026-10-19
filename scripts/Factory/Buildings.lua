---@alias FactoryBuildingKind "cooker"|"assembler"|"junction"|"isolator_straight"|"isolator_corner"|"buffer"|"storage"|"terminal"|"delivery_component"
---@class FactoryBuildingContext
---@field valid fun(x:number,z:number,width:number,depth:number,ignore:FactoryStation?): boolean,string
---@field create fun(kind:FactoryBuildingKind,x:number,z:number,quarter:integer): FactoryStation
---@field update fun(record:FactoryStation,x:number,z:number,quarter:integer)
---@field remove fun(record:FactoryStation): boolean,string
---@field processing fun(record:FactoryStation): boolean
---@field attached? fun(record:FactoryStation):boolean

---@class FactoryBuildingController
---@field context FactoryBuildingContext
---@field records FactoryStation[]
---@field mode string
---@field kind FactoryBuildingKind
---@field confirmFocus boolean
---@field previewPinned boolean
---@field x number
---@field z number
---@field quarter integer
---@field selected FactoryStation?
local Buildings = {}
Buildings.__index = Buildings
---@type table<string,{name:string,width:number,depth:number}>
Buildings.Definitions = {
    cooker = { name = "自动烹饪台", width = 2.4, depth = 1.5 },
    assembler = { name = "自动汉堡组合台", width = 2.4, depth = 1.5 },
    junction = { name = "十字拓展接口", width = 1, depth = 1 },
    isolator_straight = { name = "直通隔离接口", width = 1, depth = 1 },
    isolator_corner = { name = "转角隔离接口", width = 1, depth = 1 },
    buffer = { name = "缓存台", width = 2, depth = 2 },
    storage = { name = "库存", width = 2, depth = 4 },
    terminal = { name = "下单组件", width = 0, depth = 0 },
    delivery_component = { name = "交付组件", width = 0, depth = 0 },
}
---@type FactoryBuildingKind[]
Buildings.Order = { "cooker", "assembler", "junction", "isolator_straight", "isolator_corner", "buffer", "storage", "terminal" }

---@param context FactoryBuildingContext
---@return FactoryBuildingController
function Buildings.New(context)
    return setmetatable({ context = context, records = {}, mode = "idle", kind = "cooker", x = 0, z = 0, quarter = 0, confirmFocus = false,previewPinned=false }, Buildings)
end

---@param record FactoryStation
function Buildings:Register(record) table.insert(self.records, record) end

function Buildings:Menu() self.mode, self.selected, self.previewPinned = "menu", nil, false end
function Buildings:Manage() self.mode, self.selected, self.previewPinned = "manage", nil, false end
function Buildings:Cancel() self.mode, self.selected, self.previewPinned = "idle", nil, false end

-- Right mouse walks one level; ESC always returns to the building home.
function Buildings:Back()
    if self.mode == "move" then self:Manage()
    elseif self.mode == "preview" or self.mode == "manage" then self:Menu()
    else self:Cancel() end
end

function Buildings:Escape()
    if self.mode == "menu" then self:Cancel() else self:Menu() end
end

---@param kind FactoryBuildingKind
---@param origin Vector3
---@param direction Vector3
function Buildings:Choose(kind, origin, direction)
    self.kind, self.quarter, self.selected, self.mode = kind, 0, nil, "preview"
    self.confirmFocus,self.previewPinned = false,false
    self:SetPosition(origin.x + direction.x * 2.5, origin.z + direction.z * 2.5)
end

---@param x number
---@param z number
function Buildings:SetPosition(x, z)
    self.x, self.z = math.floor(x + 0.5), math.floor(z + 0.5)
end

-- Pinning is independent of the final placement button. Clicking a world
-- preview only holds it for review and can never instantiate a building.
function Buildings:Pointer(x,z,moved,clicked,blank)
    if self.mode~="preview" and self.mode~="move" then return false end
    if self.previewPinned then
        if clicked and blank then self.previewPinned,self.confirmFocus=false,false; return true end
        return false
    end
    if not moved and not clicked then return false end
    self:SetPosition(x,z); self.confirmFocus=false
    if clicked then self.previewPinned=true end
    return true
end

---@param dx number
---@param dz number
function Buildings:Move(dx, dz) self:SetPosition(self.x + dx, self.z + dz) end

---@param steps? integer
function Buildings:Rotate(steps) self.quarter = (self.quarter + (steps or 1)) % 4 end

---@return number,number
function Buildings:Dimensions()
    local definition = Buildings.Definitions[self.kind]
    if self.quarter % 2 == 1 then return definition.depth, definition.width end
    return definition.width, definition.depth
end

---@param origin Vector3
---@return boolean,string
function Buildings:Validate(origin)
    local width, depth = self:Dimensions()
    return self.context.valid(self.x, self.z, width, depth, self.selected)
end

---@param record FactoryStation
---@param origin Vector3
---@return boolean,string
function Buildings:BeginMove(record, origin)
    if not record.automaticKind and not record.buildingKind then return false, "固定建筑不能移动或删除。" end
    if self.context.processing(record) then return false, "加工中的建筑不能移动或删除。" end
    self.selected, self.kind, self.x, self.z, self.mode = record, assert(record.buildingKind or record.automaticKind), record.x, record.z, "move"
    self.confirmFocus,self.previewPinned = false,false
    self.quarter = record.quarter or 0
    return true, "移动建筑：WASD/鼠标调整，R/滚轮旋转，F/左键确认，Q 删除，ESC/右键取消。"
end

---@param origin Vector3
---@return boolean,string
function Buildings:Confirm(origin)
    if self.kind=='terminal' or self.kind=='delivery_component' then return false,'组件不能独立放置，请选择兼容宿主后确认绑定。' end
    if not self.confirmFocus then return false, "请先选中确认摆放按钮。" end
    if self.selected and self.context.attached and self.context.attached(self.selected) then return false, "请先拆除相连传送带/电缆，再移动或旋转建筑。" end
    local valid, message = self:Validate(origin)
    if not valid then return false, message end
    if self.mode == "move" and self.selected then
        if self.context.processing(self.selected) then return false, "加工中的建筑不能移动。" end
        self.context.update(self.selected, self.x, self.z, self.quarter)
        self:Manage()
        return true, "建筑移动完成，内部物品保留。"
    end
    if self.mode ~= "preview" then return false, "请先选择要建造的建筑。" end
    local record = self.context.create(self.kind, self.x, self.z, self.quarter)
    self:Register(record)
    self.mode = "preview"
    self.confirmFocus,self.previewPinned = false,false
    return true, "免费建筑已放置，继续移动投影建造；ESC/右键返回建筑页面。"
end

---@param origin Vector3
---@return boolean,string
function Buildings:DeleteSelected(origin)
    local record = self.selected
    if not record then return false, "请先在建筑管理模式选中建筑。" end
    if self.context.processing(record) then return false, "加工中的建筑不能删除。" end
    local ok, message = self.context.remove(record)
    if not ok then return false, message end
    for index, value in ipairs(self.records) do if value == record then table.remove(self.records, index); break end end
    self:Manage()
    return true, message
end

return Buildings
