-- Coordinates are meters. The accepted shop stays 18x14 at its original scale.
local Area = {}
Area.WorkshopCenter = -40

---@param x number
---@param z number
---@param width? number
---@param depth? number
---@return string?
function Area.At(x, z, width, depth)
    local halfWidth, halfDepth = (width or 0) / 2, (depth or 0) / 2
    if math.abs(z) + halfDepth > 7 then return nil end
    if math.abs(x) + halfWidth <= 9 then return "shop" end
    if math.abs(x - Area.WorkshopCenter) + halfWidth <= 9 then return "workshop" end
    return nil
end

---@param area string
---@return number
function Area.Center(area) return area == "workshop" and Area.WorkshopCenter or 0 end

---@return FactoryStation[]
function Area.Stations()
    return {
        { id = "ws_bun", name = "汉堡胚供料口", x = -40, z = 5, width = 2, depth = 1.5, color = Color(0.82, 0.67, 0.38) },
        { id = "ws_raw", name = "生牛肉供料口", x = -46, z = 5, width = 2, depth = 1.5, color = Color(0.67, 0.31, 0.30) },
        { id = "ws_lettuce", name = "生菜供料口", x = -35, z = 5, width = 2, depth = 1.5, color = Color(0.37, 0.65, 0.40) },
        { id = "ws_cooker", name = "车间烹饪台", x = -46, z = 1, width = 2.4, depth = 1.5,
            color = Color(0.40, 0.47, 0.52), automaticKind = "cooker" },
        { id = "ws_assembler", name = "车间组合台", x = -40, z = 1, width = 2.4, depth = 1.5,
            color = Color(0.48, 0.56, 0.48), automaticKind = "assembler" },
        { id = "ws_buffer", name = "成品缓存台", x = -34, z = -0.5, width = 2, depth = 4, buildingKind = "buffer", color = Color(0.39, 0.58, 0.61) },
        { id = "ws_return", name = "返回汉堡店", x = -33.5, z = -4.5, width = 3, depth = 3,
            color = Color(0.54, 0.68, 0.76), marker = true, destination = "shop" },
    }
end

return Area
