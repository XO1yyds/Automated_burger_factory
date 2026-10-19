local G = require("Factory/ConveyorGeometry")

---@class FactoryConveyorEndpoint
---@field id string
---@field name string
---@field kind string
---@field area string
---@field x number
---@field z number
---@field width number
---@field depth number
---@field quarter? integer
---@field source? FactoryItemType
---@field machine? FactoryAutomaticWorkstation
---@field storage? FactoryBufferStorage
---@field terminal? boolean
---@field component? string

---@class FactoryConveyorPlan
---@field from FactoryConveyorPort
---@field to FactoryConveyorPort
---@field cells FactoryGridPoint[]
---@field points FactoryGridPoint[]
---@field length number
---@field valid boolean
---@field reason string

---@class FactoryConveyorCargo
---@field id integer
---@field itemType FactoryItemType
---@field distance number
---@field identity? table

---@class FactoryConveyor: FactoryConveyorPlan
---@field id integer
---@field cargo FactoryConveyorCargo[]
---@field state string
---@field delivered integer

---@class FactoryConveyorContext
---@field resolve fun(id:string):FactoryConveyorEndpoint?
---@field endpoints fun():FactoryConveyorEndpoint[]
---@field free fun(x:number,z:number,width:number,depth:number):boolean

---@class FactoryConveyorNetwork
---@field context FactoryConveyorContext
---@field belts FactoryConveyor[]
---@field nextId integer
---@field nextCargoId integer
---@field revision integer
---@field total integer
---@field inputCursor table<string,integer>
---@field outputCursor table<string,integer>
local Network = {}
Network.__index = Network
Network.Speed, Network.Spacing = 0.5, 1

---@param context FactoryConveyorContext
---@return FactoryConveyorNetwork
function Network.New(context)
    return setmetatable({ context = context, belts = {}, nextId = 1, nextCargoId = 1, revision = 0, total = 0,
        inputCursor = {}, outputCursor = {} }, Network)
end

---@param endpoint FactoryConveyorEndpoint
function Network.Passive(endpoint)
    return endpoint.kind == "junction" or endpoint.kind == "isolator_straight" or endpoint.kind == "isolator_corner"
end

---@param endpoint FactoryConveyorEndpoint
function Network.CanOutput(endpoint) return endpoint.source ~= nil or endpoint.machine ~= nil or endpoint.storage ~= nil or Network.Passive(endpoint) end
---@param endpoint FactoryConveyorEndpoint
function Network.CanInput(endpoint) return endpoint.machine ~= nil or endpoint.storage ~= nil or Network.Passive(endpoint) end

---@param endpoint FactoryConveyorEndpoint
---@param side integer
function Network.Channel(endpoint, side)
    if endpoint.kind == "isolator_straight" or endpoint.kind == "isolator_corner" then
        local localSide = (side - (endpoint.quarter or 0)) % 4
        local channel = endpoint.kind == "isolator_straight" and localSide % 2 or (localSide < 2 and 0 or 1)
        return endpoint.id .. ":" .. channel
    end
    return endpoint.id
end

function Network:HasAttached(id)
    for _, belt in ipairs(self.belts) do if belt.from.id == id or belt.to.id == id then return true end end
    return false
end

---@param port FactoryConveyorPort
---@param ignore? FactoryConveyor
function Network:PortOccupied(port, ignore)
    for _, belt in ipairs(self.belts) do
        if belt ~= ignore and ((belt.from.id == port.id and belt.from.key == port.key) or (belt.to.id == port.id and belt.to.key == port.key)) then return true end
    end
    return false
end

---@param plan FactoryConveyorPlan
function Network.Rects(plan)
    local rectangles = {}
    for index = 2, #plan.points do
        local a, b = plan.points[index - 1], plan.points[index]
        local dx, dz = math.abs(b.x - a.x), math.abs(b.z - a.z)
        if dx + dz > 0.00001 then
            table.insert(rectangles, { x = (a.x + b.x) / 2, z = (a.z + b.z) / 2,
                width = dx > 0 and dx or 0.8, depth = dz > 0 and dz or 0.8 })
        end
    end
    for _, cell in ipairs(plan.cells) do table.insert(rectangles, { x = cell.x, z = cell.z, width = 0.8, depth = 0.8 }) end
    return rectangles
end

---@param x number
---@param z number
---@param width number
---@param depth number
---@param ignore? FactoryConveyor
function Network:Clear(x, z, width, depth, ignore)
    for _, belt in ipairs(self.belts) do
        if belt ~= ignore then
            for _, r in ipairs(Network.Rects(belt)) do
                if G.Overlap(x, z, width, depth, r.x, r.z, r.width, r.depth) then return false end
            end
        end
    end
    return true
end

---@param from FactoryConveyorPort
---@param to FactoryConveyorPort
---@param ignore? FactoryConveyor
---@return boolean,string
function Network:Topology(from, to, ignore)
    local source, destination = self.context.resolve(from.id), self.context.resolve(to.id)
    if not source or not destination then return false, "连接端建筑不存在。" end
    if from.id == to.id then return false, "不能连接建筑自身。" end
    if source.area ~= "workshop" or destination.area ~= "workshop" then return false, "实体传送带仅支持自动化车间。" end
    if not Network.CanOutput(source) or not Network.CanInput(destination) then return false, "所选建筑不具备对应输入或输出能力。" end
    for _, port in ipairs({ from, to }) do
        local ep = assert(self.context.resolve(port.id))
        local matches = false
        for _, current in ipairs(G.Ports(ep)) do
            if current.key == port.key and math.abs(current.x - port.x) < 0.00001 and math.abs(current.z - port.z) < 0.00001 then matches = true; break end
        end
        if not matches then return false, "端点必须贴合当前建筑的离散网格位置。" end
        if self:PortOccupied(port, ignore) then return false, "端口已被传送带占用。" end
    end
    for _, ep in ipairs({ source, destination }) do
        if Network.Passive(ep) then
            local incoming, outgoing, channels = 0, 0, {}
            local function count(a, b)
                for index, port in ipairs({ a, b }) do
                    if port.id == ep.id then
                        local channel = Network.Channel(ep, port.side)
                        channels[channel] = channels[channel] or { input = 0, output = 0 }
                        if index == 1 then outgoing = outgoing + 1; channels[channel].output = channels[channel].output + 1
                        else incoming = incoming + 1; channels[channel].input = channels[channel].input + 1 end
                    end
                end
            end
            for _, belt in ipairs(self.belts) do if belt ~= ignore then count(belt.from, belt.to) end end
            count(from, to)
            if ep.kind == "junction" and incoming == 2 and outgoing == 2 then return false, "普通十字接口不允许2输入2输出。" end
            if ep.kind ~= "junction" then
                for _, channel in pairs(channels) do
                    if channel.input > 1 or channel.output > 1 then return false, "隔离接口每条配对通道只允许一进一出。" end
                end
            end
        end
    end
    local edges = {}
    for _, belt in ipairs(self.belts) do
        if belt ~= ignore then
            local a, b = self.context.resolve(belt.from.id), self.context.resolve(belt.to.id)
            if a and b then
                local key = Network.Channel(a, belt.from.side)
                edges[key] = edges[key] or {}; table.insert(edges[key], Network.Channel(b, belt.to.side))
            end
        end
    end
    local goal, start = Network.Channel(source, from.side), Network.Channel(destination, to.side)
    local visited = {}
    local function reaches(key)
        if key == goal then return true end
        if visited[key] then return false end
        visited[key] = true
        for _, nextKey in ipairs(edges[key] or {}) do if reaches(nextKey) then return true end end
        return false
    end
    if reaches(start) then return false, "该连接会形成物流环路。" end
    return true, "端口可连接"
end

---@param from FactoryConveyorPort
---@param to FactoryConveyorPort
---@param cells FactoryGridPoint[]
---@return FactoryConveyorPlan
function Network:MakePlan(from, to, cells)
    local points, length = G.Travel(cells, from, to)
    local plan = { from = from, to = to, cells = cells, points = points, length = length, valid = false, reason = "未校验" }
    plan.valid, plan.reason = self:Validate(plan)
    return plan
end

---@param plan FactoryConveyorPlan
---@param ignore? FactoryConveyor
---@return boolean,string
function Network:Validate(plan, ignore)
    local valid, reason = self:Topology(plan.from, plan.to, ignore)
    if not valid then return false, reason end
    if #plan.cells == 0 or plan.length < 0.001 then return false, "传送带需要至少一格有效路径。" end
    local seen = {}
    for index, cell in ipairs(plan.cells) do
        if cell.x ~= G.Round(cell.x) or cell.z ~= G.Round(cell.z) then return false, "路径必须对齐1米网格。" end
        local key = G.Key(cell.x, cell.z)
        if seen[key] then return false, "路径自交或重复占格。" end
        seen[key] = true
        if index > 1 and G.Distance(plan.cells[index - 1], cell) ~= 1 then return false, "路径断开或存在斜线。" end
    end
    local first, last = plan.cells[1], plan.cells[#plan.cells]
    if first.x ~= plan.from.cx or first.z ~= plan.from.cz or last.x ~= plan.to.cx or last.z ~= plan.to.cz then return false, "路径端点与建筑端口脱离。" end
    for _, rectangle in ipairs(Network.Rects(plan)) do
        if not self.context.free(rectangle.x, rectangle.z, rectangle.width, rectangle.depth) then return false, "路径与建筑、地面物品、入口或边界冲突。" end
        if not self:Clear(rectangle.x, rectangle.z, rectangle.width, rectangle.depth, ignore) then return false, "传送带之间不能重叠。" end
    end
    return true, "可摆放"
end

---@param sourceId string
---@param destinationId string
---@param preferredFrom? FactoryConveyorPort
---@param preferredTo? FactoryConveyorPort
---@return FactoryConveyorPlan?,string
function Network:Plan(sourceId, destinationId, preferredFrom, preferredTo)
    local source, destination = self.context.resolve(sourceId), self.context.resolve(destinationId)
    if not source or not destination then return nil, "端点建筑不存在。" end
    local starts, finishes = preferredFrom and { preferredFrom } or G.Ports(source), preferredTo and { preferredTo } or G.Ports(destination)
    local pairsToTry = {}
    for _, from in ipairs(starts) do
        for _, to in ipairs(finishes) do
            local valid = self:Topology(from, to)
            if valid then table.insert(pairsToTry, { from = from, to = to, bound = math.abs(from.cx - to.cx) + math.abs(from.cz - to.cz) }) end
        end
    end
    table.sort(pairsToTry, function(a, b) return a.bound < b.bound end)
    ---@type FactoryConveyorPlan?
    local best = nil
    local function free(x, z) return self.context.free(x, z, 0.8, 0.8) and self:Clear(x, z, 0.8, 0.8) end
    for _, pair in ipairs(pairsToTry) do
        if best and pair.bound + 1 > #best.cells then break end
        local cells = G.Find(pair.from, pair.to, free)
        if cells then
            local plan = self:MakePlan(pair.from, pair.to, cells)
            if plan.valid and (not best or #plan.cells < #best.cells or (#plan.cells == #best.cells and #G.Simplify(plan.cells) < #G.Simplify(best.cells))) then best = plan end
        end
    end
    if best then return best, "可摆放" end
    local pair = pairsToTry[1] or { from = starts[1], to = finishes[1] }
    if not pair.from or not pair.to then return nil, "没有可用端点。" end
    local a, b = pair.from, pair.to
    ---@type FactoryGridPoint[]
    local fallback = { { x = a.cx, z = a.cz }, { x = b.cx, z = a.cz }, { x = b.cx, z = b.cz } }
    local cells = assert(G.Cells(fallback))
    local plan = self:MakePlan(a, b, cells)
    plan.valid = false
    plan.reason = "无合法自动路径：" .. plan.reason .. "；请手动调整。"
    return plan, plan.reason
end

---@param plan FactoryConveyorPlan
---@return boolean,string,FactoryConveyor?
function Network:Place(plan)
    local valid, reason = self:Validate(plan)
    if not valid then return false, reason, nil end
    local belt = {
        id = self.nextId, from = plan.from, to = plan.to, cells = plan.cells, points = plan.points,
        length = plan.length, valid = true, reason = "", cargo = {}, state = "等待物品", delivered = 0,
    }
    self.nextId, self.revision = self.nextId + 1, self.revision + 1
    table.insert(self.belts, belt)
    return true, "传送带已摆放。", belt
end

---@param id integer
---@return FactoryItemType[],FactoryConveyor?
function Network:Remove(id)
    for index, belt in ipairs(self.belts) do
        if belt.id == id then
            local contents = {}
            for _, item in ipairs(belt.cargo) do table.insert(contents, item.itemType) end
            table.remove(self.belts, index); self.revision = self.revision + 1
            return contents, belt
        end
    end
    return {}, nil
end

---@param endpoint FactoryConveyorEndpoint
function Network:Reattach(endpoint)
    for _, belt in ipairs(self.belts) do
        for _, field in ipairs({ "from", "to" }) do
            local old = belt[field]
            if not self.context.resolve(old.id) then
                for _, port in ipairs(G.Ports(endpoint)) do
                    if port.side == old.side and math.abs(port.x - old.x) < 0.00001 and math.abs(port.z - old.z) < 0.00001 then
                        belt[field] = port
                        local valid = self:Topology(belt.from, belt.to, belt)
                        local other = field == "from" and belt.to or belt.from
                        if not self.context.resolve(other.id) then
                            -- Reserve one reconstructed end even if the other building
                            -- is still absent. Completing it later checks cycles again.
                            valid = not self:PortOccupied(port,belt)
                                and (field=="from" and Network.CanOutput(endpoint) or field=="to" and Network.CanInput(endpoint))
                            local incoming,outgoing,channels=0,0,{}
                            for _,existing in ipairs(self.belts) do
                                for index,p in ipairs({existing.from,existing.to}) do if p.id==endpoint.id then
                                    local key=Network.Channel(endpoint,p.side)
                                    channels[key]=channels[key] or {input=0,output=0}
                                    if index==1 then outgoing=outgoing+1; channels[key].output=channels[key].output+1
                                    else incoming=incoming+1; channels[key].input=channels[key].input+1 end
                                end end
                            end
                            if endpoint.kind=="junction" and incoming==2 and outgoing==2 then valid=false end
                            if endpoint.kind=="isolator_straight" or endpoint.kind=="isolator_corner" then
                                for _,channel in pairs(channels) do if channel.input>1 or channel.output>1 then valid=false end end
                            end
                        end
                        if valid then self.revision = self.revision + 1; break else belt[field] = old end
                    end
                end
            end
        end
    end
end

---@param belt FactoryConveyor
function Network.Room(belt)
    if #belt.cargo >= #belt.cells then return false end
    local last = belt.cargo[#belt.cargo]
    return not last or last.distance >= Network.Spacing - 0.000001
end

---@param belt FactoryConveyor
---@param itemType FactoryItemType
function Network:Push(belt, itemType, identity)
    assert(Network.Room(belt), "Conveyor received without space")
    table.insert(belt.cargo, { id = self.nextCargoId, itemType = itemType, distance = 0, identity=identity or {} })
    self.nextCargoId = self.nextCargoId + 1
end

---@param belt FactoryConveyor
function Network.Ready(belt) return belt.cargo[1] and belt.cargo[1].distance >= belt.length - 0.000001 end

---@param endpoint FactoryConveyorEndpoint
function Network:Groups(endpoint)
    local groups = {}
    for _, belt in ipairs(self.belts) do
        local port, input
        if belt.from.id == endpoint.id then port, input = belt.from, false
        elseif belt.to.id == endpoint.id then port, input = belt.to, true end
        if port then
            local key = Network.Channel(endpoint, port.side)
            groups[key] = groups[key] or { input = {}, output = {} }
            table.insert(input and groups[key].input or groups[key].output, belt)
        end
    end
    return groups
end

---@param dt number
function Network:Step(dt)
    for _, belt in ipairs(self.belts) do
        for index, item in ipairs(belt.cargo) do
            local limit = index == 1 and belt.length or belt.cargo[index - 1].distance - Network.Spacing
            item.distance = math.min(limit, item.distance + Network.Speed * dt)
        end
        belt.state = (not self.context.resolve(belt.from.id) or not self.context.resolve(belt.to.id)) and "断头带：等待接入"
            or (Network.Ready(belt) and "带尾等待接收" or (#belt.cargo > 0 and "运输中" or "等待物品"))
    end
    for _, endpoint in ipairs(self.context.endpoints()) do
        for key, group in pairs(self:Groups(endpoint)) do
            local inputs, outputs = group.input, group.output
            if Network.Passive(endpoint) then
                local begin = self.inputCursor[key] or 1
                for offset = 0, #inputs - 1 do
                    local index = (begin - 1 + offset) % #inputs + 1
                    local incoming = inputs[index]
                    if Network.Ready(incoming) then
                        local outputBegin = self.outputCursor[key] or 1
                        for shift = 0, #outputs - 1 do
                            local outputIndex = (outputBegin - 1 + shift) % #outputs + 1
                            local outgoing = outputs[outputIndex]
                            if Network.Room(outgoing) then
                                local item = table.remove(incoming.cargo, 1)
                                self:Push(outgoing, item.itemType,item.identity)
                                incoming.delivered, self.total = incoming.delivered + 1, self.total + 1
                                self.inputCursor[key], self.outputCursor[key] = index % #inputs + 1, outputIndex % #outputs + 1
                                break
                            end
                        end
                    end
                end
            else
                local receiver = endpoint.machine or endpoint.storage
                if receiver then
                    local begin = self.inputCursor[key] or 1
                    for offset = 0, #inputs - 1 do
                        local index = (begin - 1 + offset) % #inputs + 1
                        local belt = inputs[index]
                        local item = belt.cargo[1]
                        if item and Network.Ready(belt) and receiver:CanReceive(item.itemType) then
                            assert(receiver:Receive(item.itemType,nil,item.identity)); table.remove(belt.cargo, 1)
                            belt.delivered, self.total, self.inputCursor[key] = belt.delivered + 1, self.total + 1, index % #inputs + 1
                        end
                    end
                end
                local begin = self.outputCursor[key] or 1
                for offset = 0, #outputs - 1 do
                    local index = (begin - 1 + offset) % #outputs + 1
                    local belt = outputs[index]
                    if Network.Room(belt) then
                        local provider = endpoint.machine or endpoint.storage
                        local itemType, token, identity = endpoint.source, nil, nil
                        if provider then local ignored; itemType, token, ignored, identity = provider:PeekOutput() end
                        if itemType then
                            if provider then assert(provider:TakeOutput(itemType, token)) end
                            self:Push(belt, itemType,identity); self.outputCursor[key] = index % #outputs + 1
                        end
                    end
                end
            end
        end
    end
end

---@param dt number
function Network:Update(dt)
    local remaining = math.max(0, dt)
    while remaining > 0.000001 do
        local step = math.min(0.05, remaining); self:Step(step); remaining = remaining - step
    end
end

return Network
