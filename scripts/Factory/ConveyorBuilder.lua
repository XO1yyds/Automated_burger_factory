local G = require("Factory/ConveyorGeometry")
local Network = require("Factory/ConveyorNetwork")

---@class FactoryConveyorSelection: FactoryGridPoint
---@field index integer
---@field handle boolean
local Selection = {}

---@class FactoryConveyorBuilder
---@field network FactoryConveyorNetwork
---@field mode string
---@field sourceId string?
---@field destinationId string?
---@field plan FactoryConveyorPlan?
---@field hoverPlan FactoryConveyorPlan?
---@field hoverKey string?
---@field editPlan FactoryConveyorPlan?
---@field editIndex integer?
---@field editHandle boolean?
---@field editTarget FactoryGridPoint?
---@field cursor FactoryGridPoint
---@field selected integer
---@field handle boolean
---@field editing boolean
---@field focus string
---@field button integer
---@field message string
---@field revision integer
local Builder = {}
Builder.__index = Builder
Builder.Buttons = { "confirm", "reverse", "type", "cancel" }

---@param network FactoryConveyorNetwork
---@return FactoryConveyorBuilder
function Builder.New(network)
    return setmetatable({ network = network, mode = "idle", cursor = { x = -40, z = 0 }, selected = 1,
        handle = false, editing = false, focus = "path", button = 1, message = "", revision = 0 }, Builder)
end

function Builder:Open(x, z)
    self:EndEdit()
    self.mode, self.sourceId, self.destinationId, self.plan = "source", nil, nil, nil
    self.hoverPlan,self.hoverKey=nil,nil
    self.cursor, self.focus, self.editing = { x = G.Round(x), z = G.Round(z) }, "path", false
    self.message, self.revision = "选择输出建筑A：WASD移动选择光标，F确认；或左键点击建筑。", self.revision + 1
end

function Builder:Cancel()
    self:EndEdit()
    self.hoverPlan,self.hoverKey=nil,nil
    self.mode, self.sourceId, self.destinationId, self.plan, self.editing = "idle", nil, nil, nil, false
    self.focus, self.revision = "path", self.revision + 1
end

function Builder:Back()
    self:EndEdit()
    if self.mode == "adjust" then self.mode, self.destinationId, self.plan, self.editing = "destination", nil, nil, false
    elseif self.mode == "destination" then self.mode, self.sourceId = "source", nil; self.hoverPlan=nil
    else self:Cancel() end
    self.focus, self.revision = "path", self.revision + 1
    self.hoverKey=nil
    self:Hover()
end

---@param id string
---@return boolean,string
function Builder:Select(id)
    local endpoint = self.network.context.resolve(id)
    if not endpoint or endpoint.area ~= "workshop" then return false, "请选择自动化车间内的可接入建筑。" end
    if self.mode == "source" then
        if not Network.CanOutput(endpoint) then return false, "该建筑不能输出物品。" end
        self.sourceId, self.mode = id, "destination"
        self.message = "已选输出建筑；请选择输入建筑B。"
        self:Hover()
    elseif self.mode == "destination" then
        if id == self.sourceId then return false, "不能连接同一建筑。" end
        if not Network.CanInput(endpoint) then return false, "该建筑不能作为输入端。" end
        self.destinationId = id
        self.plan, self.message = self.network:Plan(assert(self.sourceId), id)
        if not self.plan then return false, self.message end
        self.hoverPlan=nil
        self.mode, self.focus, self.selected, self.handle, self.editing = "adjust", "path", 1, true, false
    else return false, "当前不是建筑选择阶段。" end
    self.revision = self.revision + 1
    return true, self.message
end

function Builder:Reverse()
    if self.mode ~= "adjust" or not self.plan then return false, "请先选择两个端点。" end
    self:EndEdit()
    local from, to = self.plan.to, self.plan.from
    local cells = {}
    for index = #self.plan.cells, 1, -1 do table.insert(cells, G.Copy(self.plan.cells[index])) end
    self.sourceId, self.destinationId = self.destinationId, self.sourceId
    self.plan = self.network:MakePlan(from, to, cells)
    self.revision = self.revision + 1
    return true, self.plan.valid and "运输方向已反转，请选择确认摆放按钮。" or self.plan.reason
end

---@return boolean,string
function Builder:Confirm()
    if self.mode ~= "adjust" or not self.plan then return false, "请先完成路径预览。" end
    if self.focus ~= "buttons" or self.button ~= 1 then return false, "先选中“确认摆放”按钮，再左键或F确认。" end
    local ok, message = self.network:Place(self.plan)
    if ok then self:Open(self.cursor.x,self.cursor.z); message=message.."继续选择下一条带的输出建筑A。"
    else self.message = message end
    return ok, message
end

function Builder:SetCursor(x,z)
    x,z=G.Round(x),G.Round(z)
    if x~=self.cursor.x or z~=self.cursor.z then
        self.cursor={x=x,z=z}; self.hoverKey=nil; self.revision=self.revision+1
    end
    self:Hover()
end

-- This is a construction-only visual. It never becomes the committed plan.
function Builder:Hover()
    if self.mode~="destination" or not self.sourceId then return end
    local source=self.network.context.resolve(self.sourceId)
    if not source then self.hoverPlan=nil; return end
    local x,z=self.cursor.x,self.cursor.z
    local key=x..":"..z..":"..self.network.revision
    if self.hoverKey==key then return end
    self.hoverKey=key
    for _,endpoint in ipairs(self.network.context.endpoints()) do
        if endpoint.id~=source.id and math.abs(x-endpoint.x)<=endpoint.width/2 and math.abs(z-endpoint.z)<=endpoint.depth/2 then
            self.hoverPlan=self.network:Plan(source.id,endpoint.id)
            self.revision=self.revision+1; return
        end
    end
    local ports=G.Ports(source)
    table.sort(ports,function(a,b)
        local da=math.abs(a.cx-x)+math.abs(a.cz-z)+(self.network:PortOccupied(a) and 10000 or 0)
        local db=math.abs(b.cx-x)+math.abs(b.cz-z)+(self.network:PortOccupied(b) and 10000 or 0)
        return da<db
    end)
    local from=ports[1]
    if not from then self.hoverPlan=nil; return end
    ---@type FactoryConveyorPort
    local to={id="__cursor",key="cursor",side=0,x=x,z=z,cx=x,cz=z}
    local function free(cx,cz) return self.network.context.free(cx,cz,0.8,0.8) and self.network:Clear(cx,cz,0.8,0.8) end
    local cells=G.Find(from,to,free) or assert(G.Cells({{x=from.cx,z=from.cz},{x=x,z=from.cz},{x=x,z=z}}))
    local points,length=G.Travel(cells,from,to)
    local plan={from=from,to=to,cells=cells,points=points,length=length,valid=not self.network:PortOccupied(from),reason="跟随预览：请选择输入建筑B。"}
    for _,r in ipairs(Network.Rects(plan)) do
        if not self.network.context.free(r.x,r.z,r.width,r.depth) or not self.network:Clear(r.x,r.z,r.width,r.depth) then plan.valid=false end
    end
    self.hoverPlan=plan; self.revision=self.revision+1
end

---@return FactoryConveyorSelection[]
function Builder:Targets()
    local result={}
    if not self.plan then return result end
    local points=G.Simplify(self.plan.cells)
    for i,p in ipairs(points) do
        table.insert(result,{index=i,handle=true,x=p.x,z=p.z})
        local nextPoint=points[i+1]
        if nextPoint then table.insert(result,{index=i,handle=false,x=(p.x+nextPoint.x)/2,z=(p.z+nextPoint.z)/2}) end
    end
    return result
end

---@return FactoryConveyorSelection?
function Builder:SelectedTarget()
    for _,value in ipairs(self:Targets()) do if value.index==self.selected and value.handle==self.handle then return value end end
    return self:Targets()[1]
end

-- The camera is fixed: world +X is screen-right and +Z is screen-up.
---@param dx number
---@param dz number
function Builder:Navigate(dx,dz)
    local current=self:SelectedTarget()
    if not current then return end
    local selected,score=current,math.huge
    for _,candidate in ipairs(self:Targets()) do
        local x,z=candidate.x-current.x,candidate.z-current.z
        local forward=x*dx+z*dz
        if forward>0.0001 then
            local lateral=math.abs(x*dz-z*dx)
            local cost=(x*x+z*z)*(1+4*lateral/forward)
            if cost<score then selected,score=candidate,cost end
        end
    end
    self.selected,self.handle=selected.index,selected.handle
    self.revision=self.revision+1
end

function Builder:BeginEdit(index,handle)
    if not self.plan then return end
    self.selected,self.handle=index,handle
    self.editPlan,self.editIndex,self.editHandle=self.plan,index,handle
    local target=self:SelectedTarget()
    self.editTarget=target and {x=target.x,z=target.z} or nil
    self.editing=true
end

function Builder:EndEdit()
    self.editPlan,self.editIndex,self.editHandle,self.editTarget=nil,nil,nil,nil
    self.editing=false
end

function Builder:MoveBy(dx,dz)
    if not self.editTarget then self:BeginEdit(self.selected,self.handle) end
    if not self.editTarget then return end
    self.editTarget.x,self.editTarget.z=self.editTarget.x+dx,self.editTarget.z+dz
    self:MoveSelection(assert(self.editIndex),not not self.editHandle,self.editTarget.x,self.editTarget.z)
end

---@param old FactoryConveyorPort
---@param x number
---@param z number
---@param keepSide boolean
function Builder:PortNear(old, x, z, keepSide)
    local endpoint = self.network.context.resolve(old.id)
    if not endpoint then return old end
    local best, distance = old, math.huge
    for _, port in ipairs(G.Ports(endpoint)) do
        local d = math.abs(port.x - x) + math.abs(port.z - z)
        if (not keepSide or port.side==old.side) and not self.network:PortOccupied(port) and d < distance then best, distance = port, d end
    end
    return best
end

-- Local orthogonal editing. Endpoint cells remain attached; insert bends where
-- a fixed endpoint cannot follow a moved corner. Simplify only redundant points.
---@param index integer
---@param handle boolean
---@param x number
---@param z number
function Builder:MoveSelection(index, handle, x, z)
    if not self.plan then return end
    x, z = G.Round(x), G.Round(z)
    local base=self.editPlan or self.plan
    if self.editIndex then index,handle=assert(self.editIndex),not not self.editHandle end
    local original=G.Simplify(base.cells)
    local points=G.Simplify(base.cells)
    local from,to=base.from,base.to
    if #points == 1 then table.insert(points, G.Copy(points[1])); table.insert(original,G.Copy(original[1])) end
    if handle and (index == 1 or index == #points) then
        local field = index == 1 and "from" or "to"
        local port=self:PortNear(field=="from" and from or to,x,z,false)
        if field=="from" then from=port else to=port end
        points[index] = { x = port.cx, z = port.cz }
    elseif handle and points[index] then
        local old = G.Copy(points[index]); points[index] = { x = x, z = z }
        if index > 2 then
            if points[index - 1].x == old.x then points[index - 1].x = x else points[index - 1].z = z end
        elseif index==2 then
            local vertical=points[1].x==old.x
            from=self:PortNear(from,vertical and x or points[1].x,vertical and points[1].z or z,true)
            points[1]={x=from.cx,z=from.cz}
        end
        if index < #points - 1 then
            if points[index + 1].x == old.x then points[index + 1].x = x else points[index + 1].z = z end
        elseif index==#points-1 then
            local vertical=points[#points].x==old.x
            to=self:PortNear(to,vertical and x or points[#points].x,vertical and points[#points].z or z,true)
            points[#points]={x=to.cx,z=to.cz}
        end
    elseif points[index] and points[index + 1] then
        local a, b = points[index], points[index + 1]
        if a.x == b.x then a.x, b.x = x, x else a.z, b.z = z, z end
        local lastSegment = index + 1 == #points
        if index == 1 then
            from=self:PortNear(from,a.x,a.z,true)
            table.insert(points, 1, { x = from.cx, z = from.cz })
            table.insert(original,1,G.Copy(original[1]))
        end
        if lastSegment then
            to=self:PortNear(to,b.x,b.z,true)
            table.insert(points, { x = to.cx, z = to.cz })
            table.insert(original,G.Copy(original[#original]))
        end
    end
    local orthogonal = { points[1] }
    for i = 2, #points do
        local previous, point = orthogonal[#orthogonal], points[i]
        if previous.x ~= point.x and previous.z ~= point.z then
            local horizontal=original[i-1].z==original[i].z
            if i==2 then horizontal=from.side%2==1 end
            if i==#points then horizontal=to.side%2==0 end -- first leg is perpendicular to the final approach
            table.insert(orthogonal,horizontal and {x=point.x,z=previous.z} or {x=previous.x,z=point.z})
        end
        table.insert(orthogonal, point)
    end
    local clean=G.Clean(orthogonal)
    local cells=clean and G.Cells(clean)
    if cells then self.plan = self.network:MakePlan(from,to,cells) end
    ---@type FactoryConveyorSelection?
    local nearest=nil
    local score=math.huge
    for _,candidate in ipairs(self:Targets()) do
        local d=math.abs(candidate.x-x)+math.abs(candidate.z-z)+(candidate.handle~=handle and 0.1 or 0)
        if d<score then nearest,score=candidate,d end
    end
    if nearest then self.selected,self.handle=nearest.index,nearest.handle end
    self.revision = self.revision + 1
end

---@param x number
---@param z number
function Builder:Hit(x, z)
    if not self.plan then return nil end
    local points = G.Simplify(self.plan.cells)
    for index, point in ipairs(points) do
        if math.abs(x - point.x) < 0.4 and math.abs(z - point.z) < 0.4 then return index, true end
    end
    for index = 1, #points - 1 do
        local a, b = points[index], points[index + 1]
        local cx, cz = math.max(math.min(x, math.max(a.x, b.x)), math.min(a.x, b.x)), math.max(math.min(z, math.max(a.z, b.z)), math.min(a.z, b.z))
        if math.abs(x - cx) < 0.45 and math.abs(z - cz) < 0.45 then return index, false end
    end
    return nil
end

return Builder
