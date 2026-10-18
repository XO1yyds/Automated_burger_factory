-- Pure Lua, orthogonal one-meter grid. Positions here are X/Z world meters.
---@class FactoryGridPoint
---@field x number
---@field z number
local GridPoint = {}
---@class FactoryConveyorPort: FactoryGridPoint
---@field id string
---@field side integer
---@field cx integer
---@field cz integer
---@field key string
local Port = {}
---@class FactoryConveyorGeometryModule
local Geometry = {}
Geometry.Directions = { { x = 0, z = 1 }, { x = 1, z = 0 }, { x = 0, z = -1 }, { x = -1, z = 0 } }

function Geometry.Key(x, z) return x .. ":" .. z end
function Geometry.Round(value) return math.floor(value + 0.5) end
---@param point FactoryGridPoint
---@return FactoryGridPoint
function Geometry.Copy(point) return { x = point.x, z = point.z } end

---@param a FactoryGridPoint
---@param b FactoryGridPoint
function Geometry.Distance(a, b) return math.abs(a.x - b.x) + math.abs(a.z - b.z) end

function Geometry.Overlap(x, z, width, depth, ox, oz, ow, od)
    return math.abs(x - ox) < (width + ow) / 2 - 0.00001 and math.abs(z - oz) < (depth + od) / 2 - 0.00001
end

---@param endpoint table
---@return FactoryConveyorPort[]
function Geometry.Ports(endpoint)
    local result = {}
    local width, depth = endpoint.width, endpoint.depth
    local junction = endpoint.kind == "junction" or endpoint.kind == "isolator_straight" or endpoint.kind == "isolator_corner"
    local function add(side, tangent)
        local x, z, cx, cz
        if side == 0 then x, z = tangent, endpoint.z + depth / 2; cx, cz = tangent, math.ceil(z + 0.5 - 0.00001)
        elseif side == 1 then x, z = endpoint.x + width / 2, tangent; cx, cz = math.ceil(x + 0.5 - 0.00001), tangent
        elseif side == 2 then x, z = tangent, endpoint.z - depth / 2; cx, cz = tangent, math.floor(z - 0.5 + 0.00001)
        else x, z = endpoint.x - width / 2, tangent; cx, cz = math.floor(x - 0.5 + 0.00001), tangent end
        table.insert(result, { id = endpoint.id, side = side, x = x, z = z, cx = cx, cz = cz, key = side .. ":" .. tangent })
    end
    for side = 0, 3 do
        local center = side % 2 == 0 and endpoint.x or endpoint.z
        local size = side % 2 == 0 and width or depth
        if junction then add(side, Geometry.Round(center))
        else
            for tangent = math.ceil(center - size / 2 + 0.4), math.floor(center + size / 2 - 0.4) do add(side, tangent) end
        end
    end
    return result
end

---@param points FactoryGridPoint[]
---@return FactoryGridPoint[]
function Geometry.Simplify(points)
    local result = {}
    for _, point in ipairs(points) do
        local last = result[#result]
        if not last or last.x ~= point.x or last.z ~= point.z then
            table.insert(result, Geometry.Copy(point))
            while #result >= 3 do
                local a, b, c = result[#result - 2], result[#result - 1], result[#result]
                local aligned = (a.x == b.x and b.x == c.x and (b.z - a.z) * (c.z - b.z) >= 0)
                    or (a.z == b.z and b.z == c.z and (b.x - a.x) * (c.x - b.x) >= 0)
                if not aligned then break end
                table.remove(result, #result - 1)
            end
        end
    end
    return result
end

---@param points FactoryGridPoint[]
---@return FactoryGridPoint[]?,string
function Geometry.Cells(points)
    local cells = {}
    for index, point in ipairs(points) do
        if index == 1 then table.insert(cells, Geometry.Copy(point))
        else
            local previous = points[index - 1]
            if previous.x ~= point.x and previous.z ~= point.z then return nil, "路径必须为直角，不能存在斜线。" end
            local length = Geometry.Distance(previous, point)
            local dx, dz = length > 0 and (point.x - previous.x) / length or 0, length > 0 and (point.z - previous.z) / length or 0
            for step = 1, length do table.insert(cells, { x = previous.x + dx * step, z = previous.z + dz * step }) end
        end
    end
    return cells, ""
end

-- Editing may fold a route onto itself. Erase the closed excursion at its
-- first repeated grid cell, then simplify. Committed paths still use Validate.
---@param points FactoryGridPoint[]
---@return FactoryGridPoint[]?
function Geometry.Clean(points)
    local cells = Geometry.Cells(points)
    if not cells then return nil end
    local result, positions = {}, {}
    for _,cell in ipairs(cells) do
        local key = Geometry.Key(cell.x,cell.z)
        local previous = positions[key]
        if previous then
            for index=#result,previous+1,-1 do
                positions[Geometry.Key(result[index].x,result[index].z)]=nil
                table.remove(result,index)
            end
        else
            table.insert(result,Geometry.Copy(cell)); positions[key]=#result
        end
    end
    return Geometry.Simplify(result)
end

-- A* with direction in the state: shortest length first, then fewest turns.
---@param start FactoryConveyorPort
---@param finish FactoryConveyorPort
---@param free fun(x:number,z:number):boolean
---@return FactoryGridPoint[]?
function Geometry.Find(start, finish, free)
    if not free(start.cx, start.cz) or not free(finish.cx, finish.cz) then return nil end
    local heap, costs, parents, states = {}, {}, {}, {}
    local function push(item)
        local index = #heap + 1; heap[index] = item
        while index > 1 do
            local parent = index // 2
            if heap[parent].score <= item.score then break end
            heap[index], heap[parent] = heap[parent], item; index = parent
        end
    end
    local function pop()
        local first, last = heap[1], table.remove(heap)
        if #heap > 0 then
            heap[1] = last
            local index = 1
            while index * 2 <= #heap do
                local child = index * 2
                if child < #heap and heap[child + 1].score < heap[child].score then child = child + 1 end
                if heap[index].score <= heap[child].score then break end
                heap[index], heap[child] = heap[child], heap[index]; index = child
            end
        end
        return first
    end
    local key = Geometry.Key(start.cx, start.cz) .. ":0"
    costs[key], states[key] = 0, { x = start.cx, z = start.cz, dir = 0 }
    push({ key = key, cost = 0, score = (math.abs(start.cx - finish.cx) + math.abs(start.cz - finish.cz)) * 10000 })
    while #heap > 0 do
        local item = pop()
        local state = states[item.key]
        if costs[item.key] == item.cost then
            if state.x == finish.cx and state.z == finish.cz then
                local reversed, current = {}, item.key
                while current do
                    local value = states[current]
                    table.insert(reversed, { x = value.x, z = value.z }); current = parents[current]
                end
                local route = {}
                for index = #reversed, 1, -1 do table.insert(route, reversed[index]) end
                return route
            end
            for index, direction in ipairs(Geometry.Directions) do
                local x, z = state.x + direction.x, state.z + direction.z
                if free(x, z) then
                    local nextKey = Geometry.Key(x, z) .. ":" .. index
                    local cost = item.cost + 10000 + ((state.dir ~= 0 and state.dir ~= index) and 1 or 0)
                    if not costs[nextKey] or cost < costs[nextKey] then
                        costs[nextKey], parents[nextKey], states[nextKey] = cost, item.key, { x = x, z = z, dir = index }
                        push({ key = nextKey, cost = cost, score = cost + (math.abs(x - finish.cx) + math.abs(z - finish.cz)) * 10000 })
                    end
                end
            end
        end
    end
    return nil
end

---@param cells FactoryGridPoint[]
---@param from FactoryConveyorPort
---@param to FactoryConveyorPort
---@return FactoryGridPoint[],number
function Geometry.Travel(cells, from, to)
    ---@type FactoryGridPoint[]
    local points = { { x = from.x, z = from.z } }
    for _, cell in ipairs(cells) do table.insert(points, Geometry.Copy(cell)) end
    table.insert(points, { x = to.x, z = to.z })
    local simplified = Geometry.Simplify(points)
    local length = 0
    for index = 2, #simplified do length = length + Geometry.Distance(simplified[index - 1], simplified[index]) end
    return simplified, length
end

---@param points FactoryGridPoint[]
---@param distance number
---@return number,number,number,number
function Geometry.Position(points, distance)
    for index = 2, #points do
        local a, b = points[index - 1], points[index]
        local length = Geometry.Distance(a, b)
        if distance <= length or index == #points then
            local t = length > 0 and math.max(0, math.min(1, distance / length)) or 0
            return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, b.x - a.x, b.z - a.z
        end
        distance = distance - length
    end
    return points[1].x, points[1].z, 0, 1
end

return Geometry
