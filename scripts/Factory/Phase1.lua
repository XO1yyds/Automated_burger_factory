-- Scaffold-derived lifecycle: scene -> character -> UI -> event subscriptions.
-- Shared whitebox world, construction, checkout and three-day loop (Phases 1-8).
local UI = require("urhox-libs/UI")
local ItemService = require("Factory/Items")
local ItemChecks = require("Factory/ItemChecks")
local ManualService = require("Factory/ManualProduction")
local ManualChecks = require("Factory/ManualChecks")
local AutomaticService = require("Factory/AutomaticWorkstation")
local AutomaticChecks = require("Factory/AutomaticChecks")
local BuildingService = require("Factory/Buildings")
local OrderService = require("Factory/Orders")
local InterfaceService = require("Factory/Interface")
local CommerceChecks = require("Factory/CommerceChecks")
local StageChecks = require("Factory/StageChecks")
local LoopService = require("Factory/GameLoop")
local LoopChecks = require("Factory/LoopChecks")
local HudDiagnostics = require("Factory/HudDiagnostics")
local AreaService = require("Factory/AutomationArea")
local ConveyorControl = require("Factory/ConveyorControl")
local ConveyorChecks = require("Factory/ConveyorChecks")
local ConveyorEditingChecks = require("Factory/ConveyorEditingChecks")
local BufferService = require("Factory/BufferStorage")
local Grid = require("Factory/ConveyorGeometry")
local UIController = require("Factory/UIController")
local OrderAutomationControl = require("Factory/OrderAutomationControl")
local AttachedComponents = require('Factory/AttachedComponents')
---@type table?
local components=nil
---@type table?
local automation = nil
local Phase1 = {}
---@type FactoryUIController?
local uiController = nil
local gridNodes = {}
---@type Node?
local playerVisual = nil
local presentationEditing = false

---@type table<string, FactoryItemType>
local SOURCE_TYPES = { bun = "bun", raw = "raw_beef", lettuce = "lettuce",
    ws_bun = "bun", ws_raw = "raw_beef", ws_lettuce = "lettuce" }

local CONFIG = {
    roomWidth = 18, roomDepth = 14, gridSize = 1,
    moveSpeed = 4, interactionRange = 1, playerRadius = 0.28,
    yaw = 0, pitch = 90,
}

---@class FactoryStation
---@field id string
---@field name string
---@field x number
---@field z number
---@field width number
---@field depth number
---@field color Color
---@field interactive? boolean
---@field marker? boolean
---@field cylinder? boolean
---@field node Node?
---@field highlight Node?
---@field nameNode Node?
---@field nameText Text3D?
---@field component? string
---@field baseName? string
---@field nameBackground Node?
---@field body RigidBody?
---@field visual Node?
---@field quarter? integer
---@field automaticKind? FactoryAutomaticKind
---@field buildingKind? FactoryBuildingKind
---@field destination? string

---@type FactoryStation[]
local stations = {
    { id = "bun", name = "汉堡胚", x = 5.3, z = 5.8, width = 1.25, depth = 1.8, color = Color(0.82, 0.67, 0.38) },
    { id = "raw", name = "生牛肉", x = 6.65, z = 5.8, width = 1.25, depth = 1.8, color = Color(0.67, 0.31, 0.30) },
    { id = "lettuce", name = "生菜", x = 8, z = 5.8, width = 1.25, depth = 1.8, color = Color(0.37, 0.65, 0.40) },
    { id = "grill", name = "煎肉铁板", x = 2.7, z = 5.8, width = 3, depth = 1.8, color = Color(0.48, 0.48, 0.50) },
    { id = "assembly", name = "组合台", x = -0.9, z = 5.8, width = 3.2, depth = 1.8, color = Color(0.56, 0.55, 0.45) },
    { id = "cashier", name = "收银台", x = -1.2, z = -2.5, width = 2.8, depth = 1.8, color = Color(0.35, 0.49, 0.66) },
    { id = "delivery", name = "交付区域", x = 2.95, z = -2.5, width = 5.5, depth = 1.8, color = Color(0.39, 0.58, 0.61) },
    { id = "entry", name = "自动化区域入口", x = -6.7, z = 4.2, width = 4.4, depth = 5.5, color = Color(0.61, 0.65, 0.68), marker = true, destination = "workshop" },
    { id = "trash", name = "垃圾桶", x = -8.1, z = -0.9, width = 0.85, depth = 0.85, color = Color(0.42, 0.44, 0.46), cylinder = true },
    -- V0.3: shop retains manual stations; automatic equipment lives in workshop.
}

-- Restart reconstructs the V0.3 initial map, without shop automatic fixtures.
---@type FactoryStation[]
local initialStations = {}
for _, definition in ipairs(stations) do
    local copy = {}
    for key, value in pairs(definition) do copy[key] = value end
    table.insert(initialStations, copy)
end

for _, station in ipairs(AreaService.Stations()) do table.insert(initialStations, station) end

---@type Scene?
local scene = nil
---@type PhysicsWorld?
local physics = nil
---@type Camera?
local camera = nil
---@type Node?
local cameraNode = nil
---@type Node?
local player = nil
---@type RigidBody?
local playerBody = nil
---@type Node?
local facingMarker = nil
---@type Label?
local promptLabel = nil
---@type Label?
local feedbackLabel = nil
---@type Label?
local heldLabel = nil
---@type Label?
local aimNameLabel = nil
---@type Label?
local grillStatusLabel = nil
---@type Label?
local assemblyStatusLabel = nil
---@type Label?
local autoCookerStatusLabel = nil
---@type Label?
local autoAssemblyStatusLabel = nil
---@type FactoryInterface?
local interface = nil
---@type FactoryBuildingController?
local buildings = nil
---@type FactoryOrders?
local orders = nil
---@type FactoryGameLoop?
local gameLoop = nil
---@type integer
local lifecycleSelection = 1
local restartPending = false
---@type table[]
local uiCommands = {}
local cashierOpen = false
local currentArea = "shop"
---@type FactoryConveyorControl?
local logistics = nil
---@type Label?
local areaLabel = nil
---@type Node?
local buildingGhost = nil
local nextBuildingId = 1
local ghostSignature = ""
local worldMousePending = false
local worldMouseMoved = false
---@type integer?
local worldPressX = nil
---@type integer?
local worldPressY = nil
local worldUICommand = false
---@type table<string, FactoryAutomaticWorkstation>
local automatics = {}
---@type FactoryManualProduction?
local manual = nil
---@type Node[]
local stationContents = {}
local contentsSignature = ""
---@type FactoryItemService?
local items = nil
---@type FactoryGroundItem?
local groundTarget = nil
---@type FactoryStation?
local target = nil
local facing = Vector3(0, 0, 1)
local screenForward = Vector3(0, 0, 1)
local screenRight = Vector3(1, 0, 0)
---@type number
local elapsed = 0
---@type number
local messageUntil = 0
-- Developer smoke test only; restored to false before delivery.
local RUN_SMOKE_CHECKS = false
local RUN_ITEM_CHECKS = false
local RUN_MANUAL_CHECKS = false
local RUN_AUTOMATIC_CHECKS = false
local RUN_STAGE_CHECKS = false
local RUN_LOOP_CHECKS = false
local RUN_HUD_DIAGNOSIS = false
local RUN_CONVEYOR_CHECKS = false
local RUN_UI_V3_CHECKS = false
local RUN_V05_VISUAL = false -- Development-only scene setup; keep disabled in playable delivery.
local RUN_V05_RUNTIME = false -- Development-only integration suite; keep disabled in playable delivery.
local v05RuntimeChecked = false
local uiV3ChecksDone=false
local RUN_CONVEYOR_VISUAL = false
local conveyorRestarting = false
local conveyorChecksDone = false
local hudDiagnosisFrames = 0
local hudDiagnosisRestarts = 0
-- Remains true over in-game restart; the development suite must run only once.
local loopChecksDone = false
local stageChecksDone = false
local RUN_BUILDING_LABEL_CHECKS = false
local labelCheckStage, labelCheckCount, labelCheckFailures = 0, 0, 0
local itemChecksDone = false
local aimLabelChecked = false
local manualRouteChecked = false
local automaticRouteChecked = false
---@type number
local qaTime = 0
local qaMotionTime = 0
local qaStage = 0
local qaFailures = 0
---@type number
local zoom = 1

---@param kind FactoryAutomaticKind
---@return FactoryAutomaticWorkstation
local function NewAutomatic(kind)
    local machine = AutomaticService.New(kind, assert(items))
    machine.onProduced = function() if gameLoop then gameLoop:RecordBurger("automatic") end end
    return machine
end

---@param color Color
---@return Material
local function MakeMaterial(color)
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(color))
    material:SetShaderParameter("Metallic", Variant(0.0))
    material:SetShaderParameter("Roughness", Variant(0.9))
    return material
end

---@param parent Node
---@param name string
---@param position Vector3
---@param size Vector3
---@param color Color
---@param solid boolean
---@return Node
local function MakeBox(parent, name, position, size, color, solid)
    local node = parent:CreateChild(name)
    node.position = position
    node.scale = size
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(MakeMaterial(color))
    model.castShadows = true
    if solid then
        local body = node:CreateComponent("RigidBody")
        body.mass = 0
        body.collisionLayer = 1
        body.collisionMask = 2
        body.friction = 0
        node:CreateComponent("CollisionShape"):SetBox(Vector3.ONE)
    end
    return node
end

---@param station FactoryStation
local function CreateStation(station)
    local root = assert(scene):CreateChild(station.id)
    root.position = Vector3(station.x, station.marker and 0.04 or (station.cylinder and 0.35 or 0.5), station.z)
    station.node = root
    if station.cylinder then
        local bodyVisual = root:CreateChild("Body")
        bodyVisual.scale = Vector3(station.width, 0.7, station.depth)
        local model = bodyVisual:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        model:SetMaterial(MakeMaterial(station.color))
        station.visual = bodyVisual
    else
        station.visual = MakeBox(root, "Body", Vector3.ZERO, Vector3(station.width, station.marker and 0.025 or 1, station.depth), station.color, false)
    end
    if not station.marker then
        station.body = root:CreateComponent("RigidBody")
        station.body.collisionLayer, station.body.collisionMask = 1, 2
        local shape = root:CreateComponent("CollisionShape")
        if station.cylinder then shape:SetCylinder(station.width, 0.7)
        else shape:SetBox(Vector3(station.width, 1, station.depth)) end
        station.highlight = MakeBox(root, "TargetMarker", Vector3(0, 0.54, 0), Vector3(station.width + 0.06, 0.04, station.depth + 0.06), Color(0.95, 0.82, 0.30), false)
        station.highlight.enabled = false
    end
    local nameNode = root:CreateChild("BuildingName")
    nameNode.position = Vector3(0, 0.65, station.depth / 2 + 0.1)
    local text = nameNode:CreateComponent("Text3D")
    assert(text:SetFont("Fonts/MiSans-Regular.ttf", 24), "World-name font unavailable")
    local sourceType = SOURCE_TYPES[station.id]
    text:SetText(sourceType and ItemService.Definitions[sourceType].name or station.name)
    text:SetAlignment(HA_CENTER, VA_BOTTOM)
    text.textAlignment = HA_CENTER
    text.faceCameraMode = FC_ROTATE_XYZ
    text.fixedScreenSize = false
    text.color = Color(1, 1, 1)
    text.textEffect, text.effectColor = TE_STROKE, Color(0.08, 0.09, 0.10)
    text.effectStrokeThickness = 2
    local height = text.worldBoundingBox.size.y
    if height > 0.00001 then nameNode.scale = Vector3.ONE * (0.28 / height) end
    local textWidth = 0.28 * text:GetWidth() / math.max(1, text:GetHeight())
    local background = MakeBox(root, "BuildingNameBackground", Vector3(0, 0.62, station.depth / 2 + 0.24),
        Vector3(textWidth + 0.16, 0.015, 0.38), Color(0.025, 0.03, 0.035, 0.88), false)
    local model = background:GetComponent("StaticModel") --[[@as StaticModel]]
    local material = Material:new()
    material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    material:SetShaderParameter("MatDiffColor", Variant(Color(0.025, 0.03, 0.035, 0.88)))
    model:SetMaterial(material)
    model.castShadows = false
    background.enabled = false
    nameNode.enabled = false
    station.nameNode, station.nameText, station.nameBackground = nameNode, text, background
end

local function CreateScene()
    gridNodes = {}
    scene = Scene()
    scene:CreateComponent("Octree")
    physics = scene:CreateComponent("PhysicsWorld")
    physics.gravity = Vector3.ZERO
    physics.fps = 60
    physics.maxSubSteps = 8
    local lightGroup = scene:CreateChild("LightGroup")
    lightGroup:LoadXML(cache:GetResource("XMLFile", "LightGroup/Daytime.xml"):GetRoot())

    MakeBox(scene, "Floor", Vector3(0, -0.15, 0), Vector3(CONFIG.roomWidth, 0.3, CONFIG.roomDepth), Color(0.72, 0.73, 0.73), true)
    local lineColor = Color(0.55, 0.57, 0.58)
    for x = -9, 9 do
        table.insert(gridNodes, MakeBox(scene, "GridX", Vector3(x, 0.025, 0), Vector3(0.012, 0.012, 14), lineColor, false))
    end
    for z = -7, 7 do
        table.insert(gridNodes, MakeBox(scene, "GridZ", Vector3(0, 0.025, z), Vector3(18, 0.012, 0.012), lineColor, false))
    end
    local wallColor = Color(0.50, 0.52, 0.54)
    MakeBox(scene, "NorthWall", Vector3(0, 0.45, 7.15), Vector3(18.6, 0.9, 0.3), wallColor, true)
    MakeBox(scene, "SouthWall", Vector3(0, 0.45, -7.15), Vector3(18.6, 0.9, 0.3), wallColor, true)
    MakeBox(scene, "EastWall", Vector3(9.15, 0.45, 0), Vector3(0.3, 0.9, 14), wallColor, true)
    MakeBox(scene, "WestWall", Vector3(-9.15, 0.45, 0), Vector3(0.3, 0.9, 14), wallColor, true)
    for _, station in ipairs(stations) do CreateStation(station) end
    MakeBox(assert(scene), 'EntryEdge', Vector3(-5.8, 0.07, 2.1), Vector3(0.08, 0.04, 1.3), Color(0.35, 0.37, 0.39), false)
    local center = AreaService.WorkshopCenter
    MakeBox(scene, "WorkshopFloor", Vector3(center, -0.15, 0), Vector3(18, 0.3, 14), Color(0.54, 0.61, 0.63), true)
    for x = -9, 9 do table.insert(gridNodes, MakeBox(scene, "WorkshopGridX", Vector3(center + x, 0.025, 0), Vector3(0.012, 0.012, 14), lineColor, false)) end
    for z = -7, 7 do table.insert(gridNodes, MakeBox(scene, "WorkshopGridZ", Vector3(center, 0.025, z), Vector3(18, 0.012, 0.012), lineColor, false)) end
    MakeBox(scene, "WorkshopNorth", Vector3(center, 0.45, 7.15), Vector3(18.6, 0.9, 0.3), wallColor, true)
    MakeBox(scene, "WorkshopSouth", Vector3(center, 0.45, -7.15), Vector3(18.6, 0.9, 0.3), wallColor, true)
    MakeBox(scene, "WorkshopEast", Vector3(center + 9.15, 0.45, 0), Vector3(0.3, 0.9, 14), wallColor, true)
    MakeBox(scene, "WorkshopWest", Vector3(center - 9.15, 0.45, 0), Vector3(0.3, 0.9, 14), wallColor, true)
end

local function CreateCharacter()
    assert(scene, "Scene must exist before creating the player")
    player = scene:CreateChild("Player")
    player.position = Vector3(0, 0.55, 1)
    playerVisual = MakeBox(player, "PlayerVisual", Vector3.ZERO, Vector3(0.55, 1.1, 0.55), Color(0.20, 0.37, 0.56), false)
    facingMarker = MakeBox(player, "FacingMarker", facing * 0.40 + Vector3(0, 0.40, 0), Vector3(0.18, 0.12, 0.18), Color(0.98, 0.93, 0.66), false)
    playerBody = player:CreateComponent("RigidBody")
    playerBody.mass = 1
    playerBody.useGravity = false
    playerBody.linearFactor = Vector3(1, 0, 1)
    playerBody.angularFactor = Vector3.ZERO
    playerBody.friction = 0
    playerBody.collisionLayer = 2
    playerBody.collisionMask = 1
    playerBody.ccdRadius = 0.25
    playerBody.ccdMotionThreshold = 0.15
    player:CreateComponent("CollisionShape"):SetCapsule(0.56, 1.1)
end

local function SetupCamera()
    assert(scene, "Scene must exist before creating the camera")
    cameraNode = scene:CreateChild("Camera")
    cameraNode.rotation = Quaternion(CONFIG.pitch, CONFIG.yaw, 0)
    cameraNode.position = Vector3(0, 0.2, 0) - cameraNode.direction * 30
    camera = cameraNode:CreateComponent("Camera")
    camera.orthographic = true
    camera.nearClip = 0.1
    camera.farClip = 100
    camera.orthoSize = 18
    renderer:SetViewport(0, Viewport:new(scene, camera))
end

local function CreateUI()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    interface = InterfaceService.New(function(command, value) table.insert(uiCommands, { command = command, value = value }) end)
    promptLabel, feedbackLabel, heldLabel = interface.prompt, interface.feedback, interface.held
    grillStatusLabel, assemblyStatusLabel = interface.grill, interface.assembly
    autoCookerStatusLabel, autoAssemblyStatusLabel = interface.cooker, interface.automaticAssembly
    aimNameLabel, areaLabel = nil, nil
end
---@param position Vector3
---@param radius number
---@return boolean
local function IsWorldSpotFree(position, radius)
    if not AreaService.At(position.x, position.z, radius * 2, radius * 2) then return false end
    for _, station in ipairs(stations) do
        if not station.marker then
            if math.abs(position.x - station.x) <= station.width / 2 + radius
                and math.abs(position.z - station.z) <= station.depth / 2 + radius then return false end
        end
    end
    if logistics and not logistics.network:Clear(position.x, position.z, radius*2, radius*2) then return false end
    return true
end

---@param origin Vector3
---@param destination Vector3
---@return boolean
local function IsLineClear(origin, destination)
    if not physics then return false end
    local delta = Vector3(destination.x - origin.x, 0, destination.z - origin.z)
    local distance = delta:Length()
    if distance < 0.001 then return true end
    local hit = physics:RaycastSingle(Ray(Vector3(origin.x, 0.55, origin.z), delta:Normalized()), distance, 1)
    return not hit.body or hit.distance >= distance - 0.02
end

local function CreateItems()
    local world = assert(scene)
    local actor = assert(player)
    items = ItemService.New({
        createGround = function(itemType, position)
            local color = ItemService.Definitions[itemType].color
            return MakeBox(world, "Item_" .. itemType, position, Vector3(0.30, 0.20, 0.30), Color(assert(color[1]), assert(color[2]), assert(color[3])), false)
        end,
        createHeld = function(itemType)
            local color = ItemService.Definitions[itemType].color
            return MakeBox(actor, "Held_" .. itemType, facing * 0.45 + Vector3(0, 0.75, 0), Vector3(0.30, 0.20, 0.30), Color(assert(color[1]), assert(color[2]), assert(color[3])), false)
        end,
        isSpotFree = IsWorldSpotFree,
        isLineClear = IsLineClear,
        -- Item names now use a single screen-space aim label, not world projections.
        onAdded = function(item) end,
        onRemoved = function(item) end,
    })
end

-- Rebuild visible contents only when ownership/type changes, never every frame.
local function UpdateProductionVisuals()
    if not manual or not scene then return end
    local signature = (manual.grillItem or "empty") .. tostring(manual.burgerReady)
        .. tostring(manual.materials.bun) .. tostring(manual.materials.cooked_beef) .. tostring(manual.materials.lettuce)
        .. tostring(orders and orders.stock or 0)
    for _, station in ipairs(stations) do
        local machine = automatics[station.id]
        if machine then
            signature = signature .. station.id .. station.x .. ":" .. station.z .. ":" .. (station.quarter or 0) .. tostring(machine.burgerReady)
                .. tostring(machine.materials.bun) .. tostring(machine.materials.raw_beef)
                .. tostring(machine.materials.cooked_beef) .. tostring(machine.materials.lettuce)
            for index = 1, 3 do
                local slot = machine.slots[index]
                signature = signature .. (slot and slot.itemType or "empty")
            end
        end
    end
    if signature == contentsSignature then return end
    contentsSignature = signature
    for _, node in ipairs(stationContents) do node:Remove() end
    stationContents = {}
    local function add(itemType, x, z)
        local color = ItemService.Definitions[itemType].color
        table.insert(stationContents, MakeBox(assert(scene), "StationItem_" .. itemType, Vector3(x, 1.18, z),
            Vector3(0.38, 0.22, 0.38), Color(assert(color[1]), assert(color[2]), assert(color[3])), false))
    end
    if manual.grillItem then add(manual.grillItem, 2.7, 5.55) end
    if manual.burgerReady then add("burger", -0.9, 5.55)
    else
        for index, itemType in ipairs(ManualService.Recipe) do
            if manual.materials[itemType] then add(itemType, -0.9 + (index - 2) * 0.65, 5.55) end
        end
    end
    for _, station in ipairs(stations) do
        local machine = automatics[station.id]
        if machine then
            local function placeItem(itemType, dx, dz)
                local quarter = station.quarter or 0
                if quarter == 1 then dx, dz = -dz, dx
                elseif quarter == 2 then dx, dz = -dx, -dz
                elseif quarter == 3 then dx, dz = dz, -dx end
                add(itemType, station.x + dx, station.z + dz)
            end
            if machine.kind == "cooker" then
                for index = 1, 3 do
                    local slot = machine.slots[index]
                    if slot then placeItem(slot.itemType, (index - 2) * 0.65, -0.2) end
                end
            else
                for index, ingredient in ipairs(ManualService.Recipe) do
                    local itemType = ingredient
                    if itemType == "cooked_beef" and machine.materials.raw_beef then itemType = "raw_beef" end
                    if machine.materials[itemType] then placeItem(itemType, (index - 2) * 0.65, -0.25) end
                end
                if machine.burgerReady then placeItem("burger", 0, 0.35) end
            end
        end
    end
    if orders then
        for index = 1, orders.stock do
            add("burger", 2.95 + (index - 3) * 0.8, -2.75)
        end
    end
end

local function Feedback(message)
    if uiController then uiController:Notify(message) end
    if feedbackLabel then feedbackLabel:SetText(message) end
    messageUntil = elapsed + 3
end

---@param destination string
---@return boolean,string
local function SwitchArea(destination)
    if not player or not playerBody or not cameraNode or not items then return false, "区域尚未就绪。" end
    local x, z = destination == "workshop" and -33.5 or -6.7, destination == "workshop" and -4.5 or 4.2
    -- Buildings reserve portal footprints. Ground items may still occupy them:
    -- find a free arrival before changing any player or camera state.
    ---@type Vector3?
    local arrival = nil
    for _, offset in ipairs({ { 0, 0 }, { 0.7, 0 }, { -0.7, 0 }, { 0, 0.7 }, { 0, -0.7 }, { -1, -1 }, { 1, 1 } }) do
        local spot = Vector3(x + offset[1], 0.55, z + offset[2])
        if IsWorldSpotFree(spot, CONFIG.playerRadius) and items:IsSpotFree(spot) then arrival = spot; break end
    end
    if not arrival then return false, "入口落点被物品占满，请先清理后再进入。" end
    currentArea, cashierOpen = destination, false
    if logistics then logistics:Cancel() end
    if automation then automation:Close() end
    if buildings then buildings:Cancel() end
    player.position, playerBody.position, playerBody.linearVelocity = arrival, arrival, Vector3.ZERO
    cameraNode.position = Vector3(AreaService.Center(destination), 30.2, 0)
    target, groundTarget, worldMousePending, worldMouseMoved = nil, nil, false, false
    facing = screenForward
    return true, destination == "workshop" and "进入自动化车间：B 建筑 → 传送带布置；成品送入缓存台。"
        or "返回汉堡店；车间继续运行，成品保存在缓存台，携带汉堡到店内交付。"
end

local function SetupBuildings()
    buildings = BuildingService.New({
        valid = function(x,z,width,depth,ignore)
            if AreaService.At(x,z,width,depth)~=currentArea then return false,"建筑占地超出当前区域。" end
            for _,station in ipairs(stations) do
                if station~=ignore and Grid.Overlap(x,z,width,depth,station.x,station.z,station.width,station.depth) then return false,"与建筑或入口禁止区域重叠。" end
            end
            if logistics and not logistics.network:Clear(x,z,width,depth) then return false,"建筑与传送带重叠；请先拆带。" end
            if player then
                local dx,dz=math.max(0,math.abs(player.position.x-x)-width/2),math.max(0,math.abs(player.position.z-z)-depth/2)
                if dx*dx+dz*dz<=CONFIG.playerRadius^2 then return false,"建筑占据玩家位置。" end
            end
            for _,item in pairs(assert(items).ground) do
                if Grid.Overlap(x,z,width,depth,item.position.x,item.position.z,0.36,0.36) then return false,"建筑占据地面物品。" end
            end
            return true,"可放置"
        end,
        create = function(kind,x,z,quarter)
            local definition=BuildingService.Definitions[kind] --[[@as {name:string,width:number,depth:number}]]
            local width,depth=definition.width,definition.depth
            if quarter%2==1 then width,depth=depth,width end
            local record={id="building_"..nextBuildingId,name=definition.name,x=x,z=z,quarter=quarter,
                width=width,depth=depth,color=Color(0.40,0.51,0.54),buildingKind=kind} --[[@as FactoryStation]]
            nextBuildingId=nextBuildingId+1
            if kind=="cooker" or kind=="assembler" then
                local automaticKind=kind --[[@as FactoryAutomaticKind]]
                record.automaticKind=automaticKind; automatics[record.id]=NewAutomatic(automaticKind)
            end
            table.insert(stations,record); CreateStation(record)
            if logistics then
                if kind=="buffer" or kind=="storage" then logistics.buffers[record.id]=BufferService.New(kind=="storage" and 24 or 6) end
                if automation then automation.cables.revision=automation.cables.revision+1 end
                logistics.network:Reattach(assert(logistics:Endpoint(record.id)))
            end
            return record
        end,
        update = function(record,x,z,quarter)
            local definition=BuildingService.Definitions[assert(record.buildingKind or record.automaticKind)] --[[@as {name:string,width:number,depth:number}]]
            local width,depth=definition.width,definition.depth
            if quarter%2==1 then width,depth=depth,width end
            record.x,record.z,record.quarter,record.width,record.depth=x,z,quarter,width,depth
            assert(record.node).position=Vector3(x,0.5,z); assert(record.body).position=Vector3(x,0.5,z)
            assert(record.visual).scale=Vector3(width,1,depth)
            local shape=assert(record.node):GetComponent("CollisionShape") --[[@as CollisionShape]]
            shape:SetBox(Vector3(width,1,depth))
            if record.highlight then record.highlight.scale=Vector3(width+0.06,0.04,depth+0.06) end
            if record.nameNode then record.nameNode.position=Vector3(0,0.65,depth/2+0.1) end
            if record.nameBackground then record.nameBackground.position=Vector3(0,0.62,depth/2+0.24) end
        end,
        processing=function(record)
            local machine=automatics[record.id]
            local storage=logistics and logistics.buffers[record.id]
            return (machine~=nil and (machine:IsProcessing() or machine.automationOwner~=nil)) or (storage~=nil and storage:Reserved()>0)
        end,
        attached=function(record) return (logistics~=nil and logistics.network:HasAttached(record.id)) or (automation~=nil and automation.cables:HasAttached(record.id)) end,
        remove=function(record)
            if automation then automation.service:RemoveBuilding(record.id) end
            local machine=automatics[record.id]
            ---@type FactoryItemType[]
            local contents={}
            if machine then
                local slots={}; for _,slot in pairs(machine.slots) do table.insert(slots,slot) end
                table.sort(slots,function(a,b) return a.order<b.order end)
                for _,slot in ipairs(slots) do table.insert(contents,slot.itemType) end
                for _,kind in ipairs(AutomaticService.RetrievalOrder) do if machine.materials[kind] then table.insert(contents,kind) end end
                if machine.burgerReady then table.insert(contents,"burger") end
                machine:Reset()
            elseif logistics and logistics.buffers[record.id] then contents=logistics.buffers[record.id]:Contents() end
            automatics[record.id]=nil
            if logistics then logistics.buffers[record.id]=nil end
            assert(record.node):Remove()
            for index,value in ipairs(stations) do if value==record then table.remove(stations,index); break end end
            return true,assert(logistics):Spill(contents,record.x,record.z)
        end,
    })
    for _,station in ipairs(stations) do if station.automaticKind or station.buildingKind then buildings:Register(station) end end
end

local function UpdateBuildingGhost()
    if not buildings or not player then return end
    local active = buildings.mode == "preview" or buildings.mode == "move"
    if not active then
        if buildingGhost then buildingGhost:Remove(); buildingGhost = nil end
        ghostSignature = ""
        return
    end
    local width, depth = buildings:Dimensions()
    local valid = buildings:Validate(player.position)
    local signature = buildings.kind .. ":" .. buildings.x .. ":" .. buildings.z .. ":" .. buildings.quarter .. tostring(valid)..tostring(buildings.previewPinned)
    if signature ~= ghostSignature then
        if buildingGhost then buildingGhost:Remove() end
        local alpha=buildings.previewPinned and 0.5 or 0.25
        local color = valid and Color(0.35, 0.8, 0.5, alpha) or Color(0.95, 0.2, 0.2, alpha)
        buildingGhost = MakeBox(assert(scene), "BuildingProjection", Vector3(buildings.x, 0.53, buildings.z), Vector3(width, 1.02, depth), color, false)
        local model = buildingGhost:GetComponent("StaticModel") --[[@as StaticModel]]
        local material = Material:new()
        material:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        material:SetShaderParameter("MatDiffColor", Variant(color))
        model:SetMaterial(material)
        if buildings.previewPinned then
            for _,edge in ipairs({{0,0.52,-0.5,1,0.02,0.025},{0,0.52,0.5,1,0.02,0.025},{-0.5,0.52,0,0.025,0.02,1},{0.5,0.52,0,0.025,0.02,1}}) do
                MakeBox(buildingGhost,"PinnedOutline",Vector3(edge[1],edge[2],edge[3]),Vector3(edge[4],edge[5],edge[6]),Color(0.95,0.95,0.95),false)
            end
        end
        ghostSignature = signature
    end
end

---@return boolean, string
local function Interact()
    if not items then return false, "" end
    if groundTarget then return items:Pickup(groundTarget.id) end
    if target then
        if target.destination then return SwitchArea(target.destination) end
        local itemType = SOURCE_TYPES[target.id]
        if itemType and player then return items:TakeSource(itemType, player.position, facing) end
        if manual and target.id == "grill" then return manual:InteractGrill() end
        if manual and target.id == "assembly" then return manual:InteractAssembly() end
        local machine = automatics[target.id]
        if machine then return machine:Interact() end
        if target.buildingKind=="terminal" and automation then return automation:OpenTerminal(target.id) end
        if target.component=='order' and automation then return automation:OpenTerminal(target.id) end
        if target.buildingKind=="storage" and logistics and logistics.buffers[target.id] then return logistics.buffers[target.id]:InteractStack(items) end
        if logistics and logistics.buffers[target.id] then return logistics:OpenBuffer(target.id) end
        if target.id == "trash" then
            local held = items.held
            if not held then return false, "垃圾桶：空手，无需销毁。" end
            if items:ConsumeHeld(held) then return true, "已销毁 " .. ItemService.Definitions[held].name .. " ×1。" end
            return false, "手持物已变化，未销毁。"
        end
        if orders and target.id == "delivery" then return orders:InteractDepot() end
        if orders and target.id == "cashier" then
            cashierOpen = true
            orders:Select(orders.selectedId)
            return true, "收银台已打开，请选择订单后交付。"
        end
        return false, target.name .. "的生产或交付功能将在后续阶段加入。"
    end
    return false, "前方没有范围内的有效交互对象。"
end

---@param position Vector3
---@param direction Vector3
---@return FactoryStation?
---@return number
local function FindTarget(position, direction, preferredId)
    if not physics then return nil, math.huge end
    local nearestDistance = CONFIG.interactionRange + 0.001
    ---@type FactoryStation?
    local nearest = nil
    for _, station in ipairs(stations) do
        local px = math.max(station.x - station.width / 2, math.min(position.x, station.x + station.width / 2))
        local pz = math.max(station.z - station.depth / 2, math.min(position.z, station.z + station.depth / 2))
        local delta = Vector3(px - position.x, 0, pz - position.z)
        local distance = delta:Length()
        if station.marker and station.destination and distance < (station.id==preferredId and CONFIG.interactionRange+0.001 or nearestDistance)
            and (distance <= 0.001 or delta:Normalized():DotProduct(direction) >= 0.5) then
            if station.id==preferredId then return station,distance end
            nearest, nearestDistance = station, distance
        elseif station.interactive ~= false and distance > 0.001 and distance < (station.id==preferredId and CONFIG.interactionRange+0.001 or nearestDistance) and delta:Normalized():DotProduct(direction) >= 0.5 then
            local hit = physics:RaycastSingle(Ray(Vector3(position.x, 0.55, position.z), delta:Normalized()), distance + 0.02, 1)
            if hit.body and hit.body:GetNode() == station.node then
                if station.id==preferredId then return station,distance end
                nearest = station
                nearestDistance = distance
            end
        end
    end
    return nearest, nearestDistance
end

local function ResolveInteractionTarget()
    if not player or not items then return end
    local stationDistance
    target, stationDistance = FindTarget(player.position, facing, uiController and uiController.inspectId or nil)
    if uiController and uiController.inspectId and (not target or target.id~=uiController.inspectId) then uiController.inspectId=nil end
    local groundDistance
    groundTarget, groundDistance = items:FindGround(player.position, facing, CONFIG.interactionRange)
    -- Walkable portals must not prevent retrieving items dropped inside them.
    if groundTarget and (groundDistance < stationDistance or (target and target.destination)) then target = nil else groundTarget = nil end
end

local function RefreshLifecycle()
    if not gameLoop then return end
    if physics then physics.updateEnabled = gameLoop:IsRunning() end
    if not gameLoop:IsRunning() and playerBody then
        playerBody.linearVelocity = Vector3.ZERO
        worldMousePending, worldMouseMoved = false, false
    end
    if interface then InterfaceService.RefreshLoop(interface, gameLoop, lifecycleSelection) end
end

---@param command string
---@return boolean
local function LifecycleCommand(command)
    if not gameLoop then return false end
    if command == "escape" then
        if gameLoop.state == "paused" then gameLoop:Resume()
        elseif gameLoop:IsRunning() then
            if logistics and logistics.bufferId then logistics.bufferId,logistics.selectedToken=nil,nil
            elseif logistics and logistics.builder.mode~="idle" then logistics.builder:Cancel(); if buildings then buildings:Menu() end
            elseif buildings and buildings.mode ~= "idle" then buildings:Escape()
            elseif cashierOpen then cashierOpen = false; if orders then orders:Select(nil) end
            else gameLoop:Pause(); lifecycleSelection = 1 end
        end
    elseif command == "pause" then
        if buildings and buildings.mode == "idle" and not cashierOpen and (not logistics or logistics.builder.mode=="idle") then gameLoop:Pause(); lifecycleSelection = 1 end
    elseif command == "resume" then gameLoop:Resume()
    elseif command == "pauseEnd" then
        local _, message = gameLoop:EndDay("pause"); Feedback(message)
    elseif command == "cashierEnd" and cashierOpen then
        local ok, message = gameLoop:EndDay("cashier"); Feedback(message)
        if ok then cashierOpen = false end
    elseif command == "nextDay" then gameLoop:Continue(); lifecycleSelection = 1
    elseif command == "restart" then
        if gameLoop.state == "complete" then restartPending = true end
    elseif command == "exitGame" then
        if gameLoop.state == "paused" or gameLoop.state == "complete" then engine:Exit() end
    else return false end
    RefreshLifecycle()
    return true
end

-- Both normal Update and runtime checks use this same simulation gate.
---@param dt number
---@return string
local function StepSimulation(dt)
    if not gameLoop or not gameLoop:IsRunning() then return "" end
    gameLoop:Update(dt)
    local automaticMessage = ""
    local remaining = math.max(0, dt)
    while remaining > 0.000001 do
        local step = math.min(0.05, remaining)
        for _, station in ipairs(stations) do
            local machine = automatics[station.id]
            if machine then
                local completed, message = machine:Update(step)
                if completed then automaticMessage = message end
            end
        end
        if automation then automation.service:Update(step) end
        if logistics then logistics.network:Update(step) end
        remaining = remaining - step
    end
    return automaticMessage
end

-- All UI buttons enqueue commands, preventing a click from also confirming a
-- world action in the same input frame.
local function HandleInterfaceInputs()
    if not buildings or not orders or not player then return false end
    local consumed = #uiCommands > 0
    for _, action in ipairs(uiCommands) do
        if uiController and uiController:Command(action.command, action.value) then
            -- V0.3 shares commands across touch, mouse and keyboard.
        elseif LifecycleCommand(action.command) then
            -- Lifecycle owns this command, with state validation above.
        elseif gameLoop and not gameLoop:IsRunning() then
            -- Ignore stale queued gameplay callbacks while a modal owns input.
        elseif action.command=="openConveyor" and not cashierOpen and logistics then logistics:Open()
        elseif action.command=="placementButton" and logistics then logistics:Button(action.value)
        elseif action.command=="hoverKind" and buildings.mode=="menu" and BuildingService.Definitions[action.value] then buildings.kind=action.value
        elseif action.command=="choose" and BuildingService.Definitions[action.value] then
            if currentArea~="workshop" and action.value~="cooker" and action.value~="assembler" then Feedback("接口与缓存台仅在自动化车间建造。")
            else buildings:Choose(action.value,player.position,facing) end
        elseif action.command == "manage" then buildings:Manage()
        elseif action.command == "buildMenu" then buildings:Menu()
        elseif action.command == "closeBuild" then buildings:Cancel()
        elseif action.command == "closeCashier" then cashierOpen = false; orders:Select(nil)
        elseif action.command == "selectRow" and cashierOpen then
            local order = orders.active[action.value]; if order then orders:Select(order.id) end
        elseif action.command == "deliver" and cashierOpen then local _, message = orders:Deliver(); Feedback(message) end
    end
    uiCommands = {}
    if consumed then return true end
    if uiController then return uiController:Keyboard() end
    if input:GetKeyPress(KEY_ESCAPE) then LifecycleCommand("escape"); return true end
    if gameLoop and not gameLoop:IsRunning() then
        if gameLoop.state == "paused" and input:GetKeyPress(KEY_ESCAPE) then LifecycleCommand("resume")
        else
            local maxSelection = gameLoop.state == "paused" and 3 or (gameLoop.state == "complete" and 2 or 1)
            local delta = (input:GetKeyPress(KEY_S) and 1 or 0) - (input:GetKeyPress(KEY_W) and 1 or 0)
            lifecycleSelection = (lifecycleSelection - 1 + delta) % maxSelection + 1
            if input:GetKeyPress(KEY_F) or input:GetKeyPress(KEY_RETURN) then
                ---@type string[]
                local pauseCommands = { "resume", "pauseEnd", "exitGame" }
                local command = gameLoop.state == "settlement" and "nextDay"
                    or (gameLoop.state == "complete" and (lifecycleSelection == 1 and "restart" or "exitGame")
                    or pauseCommands[lifecycleSelection])
                LifecycleCommand(assert(command))
            end
        end
        return true
    end
    if logistics and logistics:Keyboard() then return true end
    if cashierOpen then
        if input:GetKeyPress(KEY_ESCAPE) or input:GetMouseButtonPress(MOUSEB_RIGHT) then cashierOpen = false; orders:Select(nil)
        elseif input:GetKeyPress(KEY_E) then LifecycleCommand("cashierEnd")
        elseif input:GetKeyPress(KEY_F) then local _, message = orders:Deliver(); Feedback(message)
        else
            local delta = ((input:GetKeyPress(KEY_S) or input:GetKeyPress(KEY_D)) and 1 or 0)
                - ((input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_A)) and 1 or 0)
            if delta ~= 0 and #orders.active > 0 then
                local _, index = orders:Find(orders.selectedId)
                local nextIndex = index and ((index - 1 + delta) % #orders.active + 1) or (delta > 0 and 1 or #orders.active)
                orders:Select(assert(orders.active[nextIndex]).id)
            end
        end
        return true
    end
    if buildings.mode == "idle" then
        if input:GetKeyPress(KEY_ESCAPE) and gameLoop then LifecycleCommand("pause"); return true
        elseif input:GetKeyPress(KEY_B) then buildings:Menu(); return true
        end
        return false
    end
    if input:GetMouseButtonPress(MOUSEB_RIGHT) then
        if logistics and logistics.selectedBelt then logistics.selectedBelt=nil else buildings:Back() end; return true
    end
    if buildings.mode == "menu" then
        local delta=(input:GetKeyPress(KEY_D) and 1 or 0)-(input:GetKeyPress(KEY_A) and 1 or 0)
        if delta~=0 then
            local index=1; for i,kind in ipairs(BuildingService.Order) do if kind==buildings.kind then index=i end end
            buildings.kind=BuildingService.Order[(index-1+delta)%#BuildingService.Order+1]
        end
        if input:GetKeyPress(KEY_TAB) then buildings:Manage()
        elseif input:GetKeyPress(KEY_E) and logistics then logistics:Open()
        elseif input:GetKeyPress(KEY_F) then
            if currentArea~="workshop" and buildings.kind~="cooker" and buildings.kind~="assembler" then Feedback("接口与缓存台仅在车间建造。")
            else buildings:Choose(buildings.kind,player.position,facing) end
        end
    elseif buildings.mode == "manage" then
        if input:GetKeyPress(KEY_Q) and logistics and logistics:DeleteBelt() then return true end
        if input:GetKeyPress(KEY_F) then
            ResolveInteractionTarget()
            if target and (target.automaticKind or target.buildingKind) then local _, message = buildings:BeginMove(target, player.position); Feedback(message)
            else Feedback("前方没有可管理的普通建筑。") end
        end
        if input:GetMouseButtonPress(MOUSEB_LEFT) and not UI.IsPointerOverUI() then worldMousePending = true end
    else
        local dx = (input:GetKeyPress(KEY_D) and 1 or 0) - (input:GetKeyPress(KEY_A) and 1 or 0)
        local dz = (input:GetKeyPress(KEY_W) and 1 or 0) - (input:GetKeyPress(KEY_S) and 1 or 0)
        if input:GetKeyPress(KEY_TAB) then buildings.confirmFocus=not buildings.confirmFocus end
        if dx ~= 0 or dz ~= 0 then buildings:Move(dx, dz); buildings.confirmFocus=false end
        if input:GetKeyPress(KEY_R) then buildings:Rotate(); buildings.confirmFocus=false end
        local wheel = input:GetMouseMoveWheel()
        if wheel ~= 0 then buildings:Rotate(wheel); buildings.confirmFocus=false end
        if input:GetKeyPress(KEY_Q) and buildings.mode == "move" then local _, message = buildings:DeleteSelected(player.position); Feedback(message)
        elseif input:GetKeyPress(KEY_F) then local _, message = buildings:Confirm(player.position); Feedback(message) end
        local mouseMove = input:GetMouseMove()
        worldMouseMoved = mouseMove.x ~= 0 or mouseMove.y ~= 0
        if input:GetMouseButtonPress(MOUSEB_LEFT) and not UI.IsPointerOverUI() then worldMousePending = true end
    end
    return true
end

-- Read cursor rays after the scene renderer has selected its viewport. The
-- camera's aspect policy stays untouched; this uses what was actually rendered.
function Phase1.WorldMouse()
    if uiController then uiController:WorldEndFrame(); return end
    if not buildings or not camera or not player or not physics then return end
    if (gameLoop and not gameLoop:IsRunning()) or worldUICommand then
        worldMousePending,worldMouseMoved,worldPressX,worldPressY=false,false,nil,nil; worldUICommand=false; return
    end
    local mouse=input:GetMousePosition()
    local ray=camera:GetScreenRay(mouse.x/math.max(1,graphics:GetWidth()),mouse.y/math.max(1,graphics:GetHeight()))
    ---@type Ray?
    local pressRay=nil
    if worldPressX and worldPressY then
        pressRay=camera:GetScreenRay(worldPressX/math.max(1,graphics:GetWidth()),worldPressY/math.max(1,graphics:GetHeight()))
        worldMousePending=true
    end
    worldPressX,worldPressY=nil,nil
    if logistics and logistics:Mouse(ray,pressRay) then worldMousePending,worldMouseMoved=false,false; return end
    if UI.IsPointerOverUI() then worldMousePending,worldMouseMoved=false,false; return end
    local mode=buildings.mode
    if mode~="manage" and mode~="preview" and mode~="move" then worldMousePending,worldMouseMoved=false,false; return end
    if not worldMousePending and not worldMouseMoved then return end
    if pressRay then ray=pressRay end
    if mode=="manage" and worldMousePending then
        local hit=physics:RaycastSingle(ray,100,1)
        if hit.body then for _,record in ipairs(buildings.records) do
            if record.node==hit.body:GetNode() then local _,message=buildings:BeginMove(record,player.position); Feedback(message); break end
        end end
    elseif math.abs(ray.direction.y)>0.00001 then
        local t=-ray.origin.y/ray.direction.y
        if t>=0 then
            local point=ray.origin+ray.direction*t
            local width,depth=buildings:Dimensions()
            local blank=not Grid.Overlap(point.x,point.z,0.02,0.02,buildings.x,buildings.z,width,depth)
            for _,record in ipairs(stations) do
                if Grid.Overlap(point.x,point.z,0.02,0.02,record.x,record.z,record.width,record.depth) then blank=false; break end
            end
            if logistics and not logistics.network:Clear(point.x,point.z,0.02,0.02) then blank=false end
            buildings:Pointer(point.x,point.z,worldMouseMoved,worldMousePending,blank)
        end
    end
    worldMousePending,worldMouseMoved=false,false
end

-- Exercises the same target resolver and F dispatch used by gameplay; this is
-- a runtime state driver, not OS keyboard/screenshot automation.
local function RunManualRouteChecks()
    if not playerBody or not player or not items or not manual then return end
    local count, failures = 0, 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase3 Route QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local function aim(id)
        for _, station in ipairs(stations) do
            if station.id == id then
                local spot = Vector3(station.x, 0.55, station.z - station.depth / 2 - 0.6)
                -- Physics interpolation updates the node on a later frame; the
                -- same-frame test driver must explicitly synchronize both.
                player.position = spot
                playerBody.position = spot
                playerBody.linearVelocity = Vector3.ZERO
                facing = Vector3.FORWARD
                ResolveInteractionTarget()
                return target ~= nil and target.id == id and groundTarget == nil
            end
        end
        return false
    end
    manual:Reset()
    items:Reset()
    check("front source resolves and dispatches raw acquisition", aim("raw") and Interact() and items.held == "raw_beef")
    check("front grill dispatches raw insertion", aim("grill") and Interact() and manual.grillItem == "raw_beef" and items.held == nil)
    manual:UpdateGrill(0, true, false, false)
    manual:UpdateGrill(1.5, target ~= nil and target.id == "grill", true, false)
    aim("assembly")
    manual:UpdateGrill(0.1, target ~= nil and target.id == "grill", true, false)
    check("aiming another workstation resets real grill progress", manual.grillProgress == 0 and manual.grillItem == "raw_beef")
    aim("grill")
    manual:UpdateGrill(3, target ~= nil and target.id == "grill", true, false)
    UpdateProductionVisuals()
    check("cooked meat has visible station entity", manual.grillItem == "cooked_beef" and #stationContents == 1
        and stationContents[1].name == "StationItem_cooked_beef")
    check("grill dispatches cooked output", Interact() and items.held == "cooked_beef")
    check("assembly dispatches cooked input", aim("assembly") and Interact() and manual.materials.cooked_beef and items.held == nil)
    check("source to assembly routes bun", aim("bun") and Interact() and aim("assembly") and Interact() and manual.materials.bun)
    check("third material generates burger through F dispatcher", aim("lettuce") and Interact() and aim("assembly") and Interact()
        and manual.burgerReady and items.held == nil)
    UpdateProductionVisuals()
    check("recipe replaces three inputs with one visible burger", #stationContents == 1 and stationContents[1].name == "StationItem_burger")
    check("assembly output dispatches real held burger", Interact() and items.held == "burger" and not manual.burgerReady)
    manual:Reset()
    items:Reset()
    UpdateProductionVisuals()
    check("route fixtures clean up without leftover station contents", #stationContents == 0 and next(items.ground) == nil and items.held == nil)
    -- Leave a valid target briefly so the following UI layout check has evidence.
    aim("raw")
    manualRouteChecked = true
    print("[Phase3 Route QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end

---@param name string
---@param passed boolean
local function Check(name, passed)
    print("[Phase1 QA] " .. (passed and "PASS " or "FAIL ") .. name)
    if not passed then qaFailures = qaFailures + 1 end
end

local function RunAutomaticRouteChecks()
    if not player or not playerBody or not items or not manual then return end
    local cooker, assembler = assert(automatics.ws_cooker), assert(automatics.ws_assembler)
    local count, failures = 0, 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase4 Route QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local function aim(id)
        for _, station in ipairs(stations) do
            if station.id == id then
                local spot = Vector3(station.x, 0.55, station.z - station.depth / 2 - 0.6)
                player.position, playerBody.position = spot, spot
                playerBody.linearVelocity = Vector3.ZERO
                facing = Vector3.FORWARD
                ResolveInteractionTarget()
                return target ~= nil and target.id == id and groundTarget == nil
            end
        end
        return false
    end
    local function visibleType(itemType)
        local total = 0
        for _, node in ipairs(stationContents) do if node.name == "StationItem_" .. itemType then total = total + 1 end end
        return total
    end
    manual:Reset()
    items:Reset()
    cooker:Reset()
    assembler:Reset()
    check("fixture footprints block item placement", not IsWorldSpotFree(Vector3(-46, 0.14, 1), 0.18)
        and not IsWorldSpotFree(Vector3(-40, 0.14, 1), 0.18))
    check("front source to automatic cooker dispatches first raw input", aim("raw") and Interact() and aim("ws_cooker") and Interact()
        and cooker.slots[1] ~= nil and items.held == nil)
    cooker:Update(1)
    check("second source trip dispatches to another slot", aim("raw") and Interact() and aim("ws_cooker") and Interact() and cooker.slots[2] ~= nil)
    cooker:Update(1)
    check("third source trip fills three independent slots", aim("raw") and Interact() and aim("ws_cooker") and Interact()
        and cooker.slots[1].progress == 2 and cooker.slots[2].progress == 1 and cooker.slots[3].progress == 0)
    UpdateProductionVisuals()
    check("three raw inputs produce three visible machine entities", visibleType("raw_beef") == 3 and #stationContents == 3)
    cooker:Update(1)
    UpdateProductionVisuals()
    check("independent completion changes only one visible meat", visibleType("cooked_beef") == 1 and visibleType("raw_beef") == 2)
    check("automatic cooker output dispatches cooked meat", aim("ws_cooker") and Interact() and items.held == "cooked_beef")
    check("automatic assembler accepts cooked output through F route", aim("ws_assembler") and Interact() and assembler.materials.cooked_beef)
    check("bun source and assembler dispatch route succeeds", aim("bun") and Interact() and aim("ws_assembler") and Interact() and assembler.materials.bun)
    check("lettuce route starts automatic assembly", aim("lettuce") and Interact() and aim("ws_assembler") and Interact()
        and assembler.processing and items.held == nil)
    check("F route cannot take materials while processing", not Interact() and items.held == nil)
    assembler:Update(2)
    UpdateProductionVisuals()
    check("completed assembly replaces recipe with one visible burger", visibleType("burger") == 1
        and visibleType("cooked_beef") == 0 and next(assembler.materials) == nil)
    check("assembler output route creates real held burger", Interact() and items.held == "burger" and items.heldNode ~= nil
        and not assembler.burgerReady and assembler.burgersProduced == 1)
    items:Reset()
    cooker:Reset()
    assembler:Reset()
    UpdateProductionVisuals()
    check("automatic route leaves empty machines and no fixture items", #stationContents == 0 and next(items.ground) == nil and items.held == nil)
    local spot = Vector3(0, 0.55, 1)
    player.position, playerBody.position = spot, spot
    facing = Vector3.FORWARD
    automaticRouteChecked = true
    print("[Phase4 Route QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end

---@param dt number
local function RunSmokeChecks(dt)
    if not player or not playerBody or not camera then return end
    local raw = assert(stations[2])
    local bun = assert(stations[1])
    local lettuce = assert(stations[3])
    local grill = assert(stations[4])
    local assembly = assert(stations[5])
    local cashier = assert(stations[6])
    local delivery = assert(stations[7])
    qaTime = qaTime + dt
    if qaStage == 0 then
        local center = camera:WorldToScreenPoint(Vector3.ZERO)
        local up = camera:WorldToScreenPoint(screenForward)
        local right = camera:WorldToScreenPoint(screenRight)
        Check("W projects upwards / D projects rightwards", up.y < center.y and right.x > center.x)
        local front = Vector3(raw.x, 0.55, raw.z - raw.depth / 2 - 0.8)
        local found = FindTarget(front, Vector3(0, 0, 1))
        Check("front raw station found", found ~= nil and found.id == "raw")
        Check("behind station excluded", FindTarget(front, Vector3(0, 0, -1)) == nil)
        Check("out-of-range station excluded", FindTarget(front - Vector3(0, 0, 0.9), Vector3(0, 0, 1)) == nil)
        Check("camera is vertical, orthographic and unrotated", camera.orthographic and cameraNode ~= nil and cameraNode.direction.y < -0.999)
        Check("assembly/grill/sources ordered left to right", assembly.x < grill.x and grill.x < bun.x and bun.x < raw.x and raw.x < lettuce.x)
        Check("cashier left of delivery and below work row", cashier.x < delivery.x and cashier.z < assembly.z)
        playerBody.position = Vector3(0, 0.55, 0)
        playerBody.linearVelocity = (screenForward + screenRight):Normalized() * CONFIG.moveSpeed
        qaMotionTime = 0
        qaStage = 1
        qaTime = 0
    elseif qaStage == 1 then
        playerBody.linearVelocity = (screenForward + screenRight):Normalized() * CONFIG.moveSpeed
        if qaTime >= 0.5 then
            local distance = player.position:Length() -- subtract fixed height below
            distance = math.sqrt(math.max(0, distance * distance - 0.55 * 0.55))
            local expected = CONFIG.moveSpeed * qaMotionTime
            Check("diagonal travel uses normalized speed", expected > 0 and math.abs(distance - expected) < 0.12)
            playerBody.position = Vector3(raw.x, 0.55, raw.z - 2.5)
            qaStage = 2
            qaTime = 0
        end
    elseif qaStage == 2 then
        playerBody.linearVelocity = Vector3(0, 0, CONFIG.moveSpeed)
        if qaTime >= 1 then
            local frontEdge = raw.z - raw.depth / 2
            Check("station physically blocks movement", player.position.z > frontEdge - 0.4 and player.position.z < frontEdge - 0.15)
            playerBody.position = Vector3(8, 0.55, -5)
            qaStage = 3
            qaTime = 0
        end
    elseif qaStage == 3 then
        playerBody.linearVelocity = Vector3(CONFIG.moveSpeed, 0, 0)
        if qaTime >= 1 then
            Check("room boundary physically blocks movement", player.position.x > 8.5 and player.position.x < 8.82)
            playerBody.linearVelocity = Vector3.ZERO
            playerBody.position = Vector3(0, 0.55, 1)
            qaStage = 4
            print("[Phase1 QA] COMPLETE failures=" .. qaFailures)
        end
    end
end

---@param horizontal number
---@param vertical number
---@param running boolean
---@param blocked boolean
---@return Vector3
function Phase1.MovementVelocity(horizontal, vertical, running, blocked)
    if blocked then return Vector3.ZERO end
    local direction = screenRight * horizontal + screenForward * vertical
    if direction:LengthSquared() == 0 then return Vector3.ZERO end
    return direction:Normalized() * CONFIG.moveSpeed * (running and 2 or 1)
end

---@param eventType string
---@param eventData UpdateEventData
function Phase1.Update(eventType, eventData)
    if not player or not playerBody or not facingMarker or not camera or not promptLabel or not feedbackLabel or not items or not heldLabel then return end
    local dt = eventData:GetFloat("TimeStep")
    if RUN_UI_V3_CHECKS and not uiV3ChecksDone and elapsed>1 then
        uiV3ChecksDone=true
        Phase1.RunUIV3Checks()
        return
    end
    local wasRunning = gameLoop ~= nil and gameLoop:IsRunning()
    -- Expiry wins over delivery commands in the same frame.
    if gameLoop and gameLoop:IsRunning() and gameLoop.remaining > 0 and gameLoop.remaining <= dt then gameLoop:Expire() end
    elapsed = elapsed + dt
    worldUICommand=#uiCommands>0
    local inputConsumed = HandleInterfaceInputs()
    if restartPending then Phase1.Restart(); return end
    RefreshLifecycle()
    if uiController then uiController:Update(dt) end
    if gameLoop and not gameLoop:IsRunning() then return end
    -- Resume/next-day clicks own this frame. Do not reset saved manual progress
    -- or advance the new day's clock merely because their F/UI input was used.
    if not wasRunning then return end
    local horizontal = (input:GetKeyDown(KEY_D) and 1 or 0) - (input:GetKeyDown(KEY_A) and 1 or 0)
    local vertical = (input:GetKeyDown(KEY_W) and 1 or 0) - (input:GetKeyDown(KEY_S) and 1 or 0)
    local touchRunning = false
    if uiController and uiController.touch.joystickId then
        horizontal, vertical, touchRunning = uiController.touch.x, uiController.touch.z, uiController.touch.running
    end
    local movement = screenRight * horizontal + screenForward * vertical
    if (uiController and uiController:Phase()=="orders") or (automation and (automation.terminal~=nil or automation.mode~="idle")) or cashierOpen or (logistics and (logistics.builder.mode~="idle" or logistics.bufferId~=nil)) or (buildings and buildings.mode ~= "idle") then movement = Vector3.ZERO end
    if movement:LengthSquared() > 0 then
        movement = movement:Normalized()
        if uiController then uiController.inspectId=nil end
        facing = movement
        facingMarker.position = facing * 0.40 + Vector3(0, 0.40, 0)
    end
    playerBody.linearVelocity = Phase1.MovementVelocity(horizontal, vertical,
        touchRunning or input:GetKeyDown(KEY_LSHIFT) or input:GetKeyDown(KEY_RSHIFT), (uiController and uiController:Phase()=="orders") or (automation and (automation.terminal~=nil or automation.mode~="idle")) or cashierOpen or (logistics and (logistics.builder.mode~="idle" or logistics.bufferId~=nil)) or (buildings ~= nil and buildings.mode ~= "idle"))
    if RUN_SMOKE_CHECKS and not loopChecksDone and qaStage < 4 then RunSmokeChecks(dt) end
    if RUN_ITEM_CHECKS and not loopChecksDone and not itemChecksDone and qaStage == 4 then
        ItemChecks.Run(items)
        itemChecksDone = true
        if RUN_MANUAL_CHECKS and manual then ManualChecks.Run(manual, items) end
        if RUN_AUTOMATIC_CHECKS then AutomaticChecks.Run(items, assert(automatics.ws_cooker), assert(automatics.ws_assembler)) end
    end
    if RUN_MANUAL_CHECKS and not loopChecksDone and itemChecksDone and not manualRouteChecked and elapsed > 4 then RunManualRouteChecks() end
    if RUN_AUTOMATIC_CHECKS and not loopChecksDone and manualRouteChecked and not automaticRouteChecked then RunAutomaticRouteChecks() end
    if RUN_STAGE_CHECKS and not loopChecksDone and automaticRouteChecked and not stageChecksDone and buildings and orders and interface then
        CommerceChecks.Run(items)
        StageChecks.Run(items, buildings, orders, interface, automatics, {
            ui=assert(uiController),switch=SwitchArea,command=function(command,value) table.insert(uiCommands,{command=command,value=value}) end,
            placePlayer = function(x, z) local spot = Vector3(x, 0.55, z); player.position, playerBody.position = spot, spot; playerBody.linearVelocity = Vector3.ZERO end,
            aim = function(id)
                for _, station in ipairs(stations) do if station.id == id then
                    local spot = Vector3(station.x, 0.55, station.z - station.depth / 2 - 0.6)
                    player.position, playerBody.position, facing = spot, spot, Vector3.FORWARD
                    ResolveInteractionTarget()
                    return target ~= nil and target.id == id and groundTarget == nil
                end end
                return false
            end,
            interact = Interact, refresh = UpdateProductionVisuals, names = Phase1.UpdateBuildingLabels,
            controls = HandleInterfaceInputs, closeCashier = function() cashierOpen = false; orders:Select(nil) end,
            velocity = Phase1.MovementVelocity,
            camera = camera, cameraNode = assert(cameraNode),
        })
        stageChecksDone = true
    end
    playerBody.active = true
    ResolveInteractionTarget()
    local qPressed = input:GetKeyPress(KEY_Q)
    local cooked, cookingMessage = false, ""
    if manual then
        cooked, cookingMessage = manual:UpdateGrill(dt, target ~= nil and target.id == "grill",
            input:GetKeyDown(KEY_F) or (uiController and uiController.holdingInteraction) or false,
            qPressed or not input.focus or (inputConsumed and not (uiController and uiController.holdingInteraction)))
    end
    local automaticMessage = StepSimulation(dt)
    for _, station in ipairs(stations) do
        if station.highlight then station.highlight.enabled = station == target end
    end
    local prompt = "靠近并面向原料点、地面物品或工作台（约 1 格）。"
    if groundTarget then
        prompt = (items.held and "F：交换为 " or "F：拾取 ") .. ItemService.Definitions[groundTarget.itemType].name
    elseif target then
        local itemType = SOURCE_TYPES[target.id]
        prompt = itemType and ((items.held and "F：交换为 " or "F：获取 ") .. ItemService.Definitions[itemType].name) or ("F：检查 " .. target.name)
        if manual and (target.id == "grill" or target.id == "assembly") then prompt = manual:Prompt(target.id) end
        local machine = automatics[target.id]
        if machine then prompt = machine:Prompt() end
        if target.id == "trash" then prompt = items.held and "F：销毁手持物品（含汉堡）" or "垃圾桶：空手" end
        if target.destination then prompt = target.destination == "workshop" and "F：进入自动化车间（可携带物品）" or "F：返回汉堡店（产线继续运行）" end
        if logistics and logistics.buffers[target.id] then prompt=target.component=='order' and 'F：打开下单终端（下单 / 本机库存 / 网络 / 任务）' or target.buildingKind=="storage" and "F：空手取出栈顶；禁止手动存入或交换" or "F：选择缓存槽，取出/交换/存入空槽" end
        if target.buildingKind=="terminal" then prompt="F：打开下单组件（网络信息 / 生产下单 / 任务）" end
    end
    if buildings and buildings.mode ~= "idle" then
        local valid, reason = buildings:Validate(player.position)
        prompt = buildings.mode == "menu" and "A/D 选型 · F 选择 · E传送带布置 · Tab管理"
            or (buildings.mode == "manage" and "F/左键选择已有建筑；右键/ESC 返回建筑页面"
            or ("WASD调整 · "..(buildings.previewPinned and "投影已固定，空白处左键解除" or "鼠标定位，左键固定投影").." · R旋转 · Tab选确认/F放置 · Q删除 · 右键回退 · ESC回首页 · " .. (valid and "可放置" or reason)))
    elseif cashierOpen then prompt = "收银：W/S 或 A/D 选单，F 交付；E 计时归零后结束；ESC/右键关闭"
    end
    if logistics then local extra=logistics:Prompt(); if extra then prompt=extra end end
    promptLabel:SetText(prompt)
    if aimNameLabel then
        local name = ""
        if groundTarget then name = ItemService.Definitions[groundTarget.itemType].name
        end
        aimNameLabel:SetText(name)
        aimNameLabel:SetStyle({ left = graphics:GetWidth() / UI.GetScale() / 2 - 160 })
        aimNameLabel:SetVisible(name ~= "")
        if RUN_ITEM_CHECKS and not loopChecksDone and itemChecksDone and not aimLabelChecked and elapsed > 4 and name ~= ""
            and aimNameLabel:GetAbsoluteLayout().w > 0 then
            local layout = aimNameLabel:GetAbsoluteLayout()
            local expectedCenter = graphics:GetWidth() / UI.Scale.DEFAULT() / 2
            local centered = math.abs(layout.x + layout.w / 2 - expectedCenter) < 2
            print("[Phase2 UI QA] " .. (centered and "PASS " or "FAIL ") .. "aim nickname horizontally centered")
            print("[Phase2 UI QA] " .. (layout.y < 80 and "PASS " or "FAIL ") .. "aim nickname is at top of screen")
            aimLabelChecked = true
        end
    end
    local acted = cooked
    local text = cookingMessage
    -- Automatic completions update the target card and statistics without a global offscreen toast.
    if inputConsumed then
        -- UI/build commands own this input frame; Q cannot also drop held items.
    elseif qPressed then
        local ignored
        ignored, text = items:Drop(player.position, facing)
        acted = text ~= ""
    elseif not cooked and input:GetKeyPress(KEY_F) then
        local ignored
        ignored, text = Interact()
        acted = true
    end
    if acted then
        Feedback(text)
        print("[Factory] " .. text)
    elseif elapsed > messageUntil then
        feedbackLabel:SetText("配方：汉堡胚 + 熟牛肉饼 + 生菜片；工作台取出需空手。原料点/地面仍支持持物交换。")
    end
    heldLabel:SetText(items.held and ("手持：" .. ItemService.Definitions[items.held].name .. " ×1") or "手持：空")
    if items.heldNode then items.heldNode.position = facing * 0.45 + Vector3(0, 0.75, 0) end
    if manual then
        if grillStatusLabel then grillStatusLabel:SetText(manual:GrillStatus()) end
        if assemblyStatusLabel then assemblyStatusLabel:SetText(manual:AssemblyStatus()) end
        UpdateProductionVisuals()
    end
    if interface then InterfaceService.RefreshAutomatic(interface, target and automatics[target.id] or nil) end
    if interface and buildings and orders then
        InterfaceService.RefreshOrders(interface, orders)
        InterfaceService.RefreshBuild(interface, buildings.mode, buildings.kind)
        if not uiController then interface.cashierPanel:SetVisible(cashierOpen) end
        InterfaceService.RefreshLoop(interface, assert(gameLoop), lifecycleSelection)
    end
    UpdateBuildingGhost()
    if logistics then logistics:Refresh() end
    if automation then automation:RefreshWorld(currentArea=="workshop" and gameLoop:IsRunning() and (automation.mode~="idle" or automation.managing)) end
    if areaLabel and logistics then areaLabel:SetText(string.format("%s · B建筑 · 实体带 %d · 交接 %d 件",
        currentArea=="workshop" and "自动化车间" or "汉堡店（左上F进入车间）",#logistics.network.belts,logistics.network.total)) end
    -- Only zoom/pan are allowed: rotation is never changed by input.
    local aspect = graphics:GetWidth() / math.max(1, graphics:GetHeight())
    if (not uiController or uiController:WorldMouseAvailable()) and (not logistics or logistics.builder.mode=="idle") and (not buildings or (buildings.mode ~= "preview" and buildings.mode ~= "move")) then
        zoom = math.max(0.8, math.min(2.5, zoom * (1.12 ^ (input:GetMouseMoveWheel() * (uiController and uiController.preferences.sensitivity or 1)))))
    end
    camera.orthoSize = math.max(19, 22 / aspect)
    camera.zoom = zoom
    if cameraNode and input:GetMouseButtonDown(MOUSEB_MIDDLE) and (not uiController or uiController:WorldMouseAvailable()) then
        local delta = input:GetMouseMove()
        local units = camera.orthoSize / zoom / math.max(1, graphics:GetHeight()) * (uiController and uiController.preferences.sensitivity or 1)
        local position = cameraNode.position
        local center = AreaService.Center(currentArea)
        position.x = math.max(center - 7, math.min(center + 7, position.x - delta.x * units))
        position.z = math.max(-5, math.min(5, position.z + delta.y * units))
        cameraNode.position = position
    end
    if uiController then uiController:Update(0) end
    if RUN_LOOP_CHECKS and not loopChecksDone and elapsed > 6 and (not RUN_STAGE_CHECKS or stageChecksDone) then
        if RUN_HUD_DIAGNOSIS and interface then HudDiagnostics.Capture("pre_loop_suite", interface) end
        loopChecksDone = true
        LoopChecks.Run({
            ui=assert(uiController),
            snapshot = function()
                return { loop = assert(gameLoop), orders = assert(orders), items = assert(items), manual = assert(manual),
                    machines = automatics, buildings = assert(buildings), view = assert(interface), player = assert(player),
                    body = assert(playerBody), physics = assert(physics), camera = assert(camera), cashier = cashierOpen }
            end,
            step = StepSimulation, controls = HandleInterfaceInputs,
            frame = function(dt)
                local data = VariantMap()
                data["TimeStep"] = Variant(dt)
                Phase1.Update("Update", data --[[@as UpdateEventData]])
            end,
            command = function(command) table.insert(uiCommands, { command = command }) end,
            refresh = RefreshLifecycle,
            openCashier = function() cashierOpen = true; assert(orders):Select(nil) end,
            restart = function() assert(restartPending, "Restart button did not enqueue restart"); Phase1.Restart() end,
        })
    end
end

-- World text is a building child; only proximity visibility changes per frame.
function Phase1.UpdateBuildingLabels()
    if not player then return end
    for _, station in ipairs(stations) do
        if station.nameNode then
            local dx = math.max(0, math.abs(player.position.x - station.x) - station.width / 2)
            local dz = math.max(0, math.abs(player.position.z - station.z) - station.depth / 2)
            local phase=uiController and uiController:Phase() or "normal"
            local isSource=logistics and station.id==logistics.builder.sourceId and (phase=="destination" or phase=="adjust")
            station.nameNode.enabled = isSource or (not uiController and dx * dx + dz * dz <= CONFIG.interactionRange * CONFIG.interactionRange)
            if station.nameText then
                local sourceType=SOURCE_TYPES[station.id]
                station.nameText:SetText((isSource and "A · " or "")..(sourceType and ItemService.Definitions[sourceType].name or station.name))
            end
            if station.nameBackground then station.nameBackground.enabled = station.nameNode.enabled end
        end
    end
end

-- Development-only integration suite uses live scene, gameplay dispatch and UI queue.
function Phase1.RunConveyorChecks()
    local control,loop,build=assert(logistics),assert(gameLoop),assert(buildings)
    local count,failed=0,0
    local function check(name,ok)
        count=count+1; if not ok then failed=failed+1 end
        print("[Conveyor Runtime QA] "..(ok and "PASS " or "FAIL ")..name)
    end
    local function command(name,value)
        table.insert(uiCommands,{command=name,value=value}); HandleInterfaceInputs()
    end
    check("sample contains five physical directed routes",#control.network.belts==5)
    local valid=true
    for _,belt in ipairs(control.network.belts) do valid=valid and control.network:Validate(belt,belt) end
    check("full sample footprint and ports validate",valid)
    check("workshop shared delivery station removed",control:Endpoint("ws_delivery")==nil)
    StepSimulation(150); control:Refresh()
    local storage=assert(control.buffers.ws_buffer)
    check("offscreen complete production chain fills buffer",storage:Count()==6 and loop.automatic>=6 and currentArea=="shop")
    local burgers=true; for _,item in pairs(storage.slots) do burgers=burgers and item.itemType=="burger" end
    check("sample only delivers finished burgers",burgers and assert(orders).stock==0)
    local hidden=true; for _,node in pairs(control.world.cargo) do hidden=hidden and not node.enabled end
    check("offscreen cargo animation is disabled",hidden and not assert(control.world.static).enabled)
    local first=control.network.belts[1]; local distance=first.cargo[1].distance
    local clock=automatics.ws_cooker.clock; local transfers=control.network.total
    assert(loop:Pause()); StepSimulation(10)
    check("pause freezes cargo machine clock and transfers",first.cargo[1].distance==distance and automatics.ws_cooker.clock==clock and control.network.total==transfers)
    assert(loop:EndDay("pause")); StepSimulation(10)
    check("settlement retains buffers belts and queued items",storage:Count()==6 and #control.network.belts==5 and first.cargo[1].distance==distance)
    assert(loop:Continue())
    check("next day retains production state",loop.day==2 and storage:Count()==6 and automatics.ws_cooker.clock==clock)
    local switched=SwitchArea("workshop"); control:Refresh()
    check("workshop portal recenters accepted camera",switched and assert(cameraNode).position.x==-40 and assert(cameraNode).rotation==Quaternion(90,0,0))
    check("workshop physical belts become visible",assert(control.world.static).enabled)
    control:OpenBuffer("ws_buffer"); control:SelectSlot(2)
    check("first buffer interaction enters selection without taking",control.bufferId=="ws_buffer" and assert(items).held==nil and storage:Count()==6)
    control:ConfirmBuffer()
    check("buffer F retrieves selected burger and exits",assert(items).held=="burger" and storage:Count()==5 and control.bufferId==nil)
    control:OpenBuffer("ws_buffer"); control:SelectSlot(2); control:ConfirmBuffer()
    check("empty selected buffer slot accepts manual deposit",assert(items).held==nil and storage:Count()==6)
    assert(assert(items):Give("bun")); control:OpenBuffer("ws_buffer"); control:SelectSlot(1); control:ConfirmBuffer()
    check("held item exchanges selected stored item",assert(items).held=="burger" and storage.slots[1].itemType=="bun")
    assert(items):Reset()
    control:OpenBuffer("ws_buffer"); control:SelectSlot(1)
    local kind,token=storage:PeekOutput(); assert(storage:TakeOutput(assert(kind),token)); control:Refresh()
    check("concurrent output invalidates stable selection",control.selectedToken==nil)
    local saved=storage:Count(); control:ConfirmBuffer()
    check("stale buffer confirmation cannot duplicate items",storage:Count()==saved and assert(items).held==nil)
    control.bufferId=nil
    build:Choose("junction",assert(player).position,facing); build:SetPosition(-46,-4)
    local records=#build.records
    check("unfocused placement F cannot create a building",not build:Confirm(assert(player).position) and #build.records==records)
    command("placementButton",1)
    check("UI confirm creates exactly one building",#build.records==records+1 and build.mode=="preview" and not build.confirmFocus)
    local junction=build.records[#build.records]
    build:Manage(); assert(build:BeginMove(junction,assert(player).position)); build.confirmFocus=true
    local deleted=build:DeleteSelected(assert(player).position)
    check("deletion returns to persistent management mode",deleted and build.mode=="manage" and #build.records==records)
    local extra={}
    for _,x in ipairs({-45,-39}) do
        build:Choose("buffer",assert(player).position,facing); build:SetPosition(x,-4); build.confirmFocus=true
        assert(build:Confirm(assert(player).position)); table.insert(extra,build.records[#build.records])
    end
    command("openConveyor"); assert(control.builder:Select(extra[1].id)); control.builder:SetCursor(extra[2].x,extra[2].z)
    control:Refresh()
    check("destination selection renders provisional A-to-hovered-B belt",control.builder.mode=="destination" and control.builder.hoverPlan~=nil
        and control.builder.hoverPlan.from.id==extra[1].id and control.builder.hoverPlan.to.id==extra[2].id and assert(control.world.preview).enabled)
    assert(control.builder:Select(extra[2].id)); local beltCount=#control.network.belts
    command("placementButton",1)
    check("UI belt confirmation continues directly to fresh source selection",control.builder.mode=="source" and build.mode=="idle" and #control.network.belts==beltCount+1)
    control.network:Remove(control.network.belts[#control.network.belts].id); control.builder:Cancel()
    for _,record in ipairs(extra) do assert(build:BeginMove(record,assert(player).position)); assert(build:DeleteSelected(assert(player).position)) end
    local attached
    for _,record in ipairs(build.records) do if record.id=="ws_buffer" then attached=record end end
    assert(build:BeginMove(assert(attached),assert(player).position)); build.confirmFocus=true
    local moved,message=build:Confirm(assert(player).position)
    check("connected building requires removing belts before move",not moved and message:find("拆除",1,true)~=nil)
    build:Menu(); command("openConveyor")
    check("building UI opens world endpoint selection",control.builder.mode=="source" and build.mode=="idle")
    command("placementButton",4)
    check("cancel button works before choosing either endpoint",control.builder.mode=="idle" and build.mode=="menu")
    command("openConveyor")
    LifecycleCommand("escape")
    check("ESC returns conveyor substate to building home",control.builder.mode=="idle" and build.mode=="menu" and loop:IsRunning())
    build:Cancel(); local heldBefore=assert(items).held
    local originalFree=assert(items).context.isSpotFree
    assert(items).context.isSpotFree=function() return false end
    local text,lost,placed=control:Spill({"bun","burger","bun"},-40,-4)
    assert(items).context.isSpotFree=originalFree
    check("spill overflow continues and reports exact types and counts",placed==0 and lost.bun==2 and lost.burger==1 and text:find("×2",1,true)~=nil and assert(items).held==heldBefore)
    local id=control.network.belts[1].id
    control.selectedBelt=id; build:Manage(); control:DeleteBelt()
    check("loaded belt demolition removes whole route and keeps management",#control.network.belts==4 and build.mode=="manage")
    local consistent=true
    for _,belt in ipairs(control.network.belts) do
        consistent=consistent and #belt.cargo<=#belt.cells
        for i=2,#belt.cargo do consistent=consistent and belt.cargo[i-1].distance-belt.cargo[i].distance>=1-0.000001 end
    end
    check("remaining belt cargo is ordered and capacity bounded",consistent)
    check("top down camera and accepted player speed preserved",assert(camera).orthographic and Phase1.MovementVelocity(1,0,true,false):Length()==8)
    ItemChecks.Run(assert(items)); ManualChecks.Run(assert(manual),assert(items)); CommerceChecks.Run(assert(items))
    AutomaticChecks.Run(assert(items),assert(automatics.ws_cooker),assert(automatics.ws_assembler))
    print("[Conveyor Runtime QA] COMPLETE checks="..count.." failures="..failed)
end

-- Native integration entry point; all state is reset by the normal restart flow.
function Phase1.RunUIV3Checks()
    local function snapshot()
        return {loop=assert(gameLoop),orders=assert(orders),items=assert(items),manual=assert(manual),machines=automatics,
            buildings=assert(buildings),view=assert(interface),player=assert(player),body=assert(playerBody),physics=assert(physics),
            camera=assert(camera),cashier=cashierOpen}
    end
    local function aim(id)
        for _,station in ipairs(stations) do if station.id==id then
            local spot=Vector3(station.x,0.55,station.z-station.depth/2-0.6)
            assert(player).position=spot; assert(playerBody).position=spot; assert(playerBody).linearVelocity=Vector3.ZERO
            facing=Vector3.FORWARD; ResolveInteractionTarget()
            return target~=nil and target.id==id and groundTarget==nil
        end end
        return false
    end
    Phase1.RunConveyorChecks()
    Phase1.Restart()
    require("Factory/UIChecks").Run()
    require("Factory/ReviewFixChecks").Run()
    ConveyorChecks.Run(); ConveyorEditingChecks.Run()
    ItemChecks.Run(assert(items)); ManualChecks.Run(assert(manual),assert(items))
    AutomaticChecks.Run(assert(items),assert(automatics.ws_cooker),assert(automatics.ws_assembler))
    CommerceChecks.Run(assert(items))
    StageChecks.Run(assert(items),assert(buildings),assert(orders),assert(interface),automatics,{
        ui=assert(uiController),switch=SwitchArea,aim=aim,interact=Interact,controls=HandleInterfaceInputs,
        velocity=Phase1.MovementVelocity,command=function(command,value) table.insert(uiCommands,{command=command,value=value}) end,
    })
    LoopChecks.Run({ui=assert(uiController),snapshot=snapshot,step=StepSimulation,controls=HandleInterfaceInputs,
        refresh=RefreshLifecycle,command=function(command) table.insert(uiCommands,{command=command}) end,
        openCashier=function() cashierOpen=true end,
        restart=function() assert(restartPending); Phase1.Restart() end,
    })
    print("[UI V0.3 Native QA] COMPLETE restored ordinary playable world")
end

function Phase1.Start()
    hudDiagnosisFrames = 0
    stations = {}
    for _, definition in ipairs(initialStations) do
        local copy = {}
        for key, value in pairs(definition) do copy[key] = value end
        table.insert(stations, copy)
    end
    elapsed, messageUntil, qaTime, qaMotionTime, qaStage, qaFailures = 0, 0, 0, 0, 0, 0
    facing = screenForward
    zoom = 1
    presentationEditing=false
    target = nil
    groundTarget = nil
    itemChecksDone = false
    aimLabelChecked = false
    manualRouteChecked = false
    automaticRouteChecked = false
    stageChecksDone = false
    labelCheckStage, labelCheckCount, labelCheckFailures = 0, 0, 0
    graphics.windowTitle = "自动化汉堡工厂 · Demo V0.5 · 下单式自动化"
    currentArea = "shop"
    restartPending, lifecycleSelection = false, 1
    uiCommands, cashierOpen, nextBuildingId = {}, false, 1
    worldPressX,worldPressY,worldUICommand=nil,nil,false
    input.mouseMode = MM_ABSOLUTE
    input.mouseVisible = true
    CreateScene()
    CreateCharacter()
    SetupCamera()
    CreateUI()
    CreateItems()
    manual = ManualService.New(assert(items))
    manual.onProduced = function() if gameLoop then gameLoop:RecordBurger("manual") end end
    automatics = {}
    for _, station in ipairs(stations) do
        if station.automaticKind then automatics[station.id] = NewAutomatic(station.automaticKind) end
    end
    orders = OrderService.New(assert(items))
    gameLoop = LoopService.New(orders)
    SetupBuildings()
    logistics=ConveyorControl.New({scene=assert(scene),makeBox=MakeBox,items=assert(items),player=assert(player),
        buildings=assert(buildings),stations=function() return stations end,machines=automatics,sources=SOURCE_TYPES,
        area=function() return currentArea end,feedback=Feedback,
        action=function(command,value) table.insert(uiCommands,{command=command,value=value}) end})
    logistics.v3=true
    logistics:Sample(); logistics:Refresh()
    automation=OrderAutomationControl.New({scene=assert(scene),makeBox=MakeBox,player=assert(player),items=assert(items),facing=function() return facing end,
        area=function() return currentArea end,resolve=function(id) return assert(logistics):Endpoint(id) end,
        endpoints=function() local list={}; for _,station in ipairs(stations) do local ep=assert(logistics):Endpoint(station.id); if ep then table.insert(list,ep) end end; return list end})
    automation:Sample()
    components=AttachedComponents.New({stations=function() return stations end,storage=function(id) return assert(logistics).buffers[id] end,automation=function() return assert(automation) end})
    assert(orders).deliveryStores=function() return assert(components):DeliveryStores() end
    uiController = UIController.New({
        get=function() return {loop=assert(gameLoop),orders=assert(orders),items=assert(items),manual=assert(manual),
            buildings=assert(buildings),logistics=assert(logistics),automation=automation,components=components,machines=automatics,stations=stations,
            player=assert(player),camera=assert(camera),cameraNode=assert(cameraNode),zoom=zoom,
            target=target,ground=groundTarget,facing=facing,area=currentArea,cashier=cashierOpen} end,
        resolve=ResolveInteractionTarget,interact=Interact,
        cashier=function(open) cashierOpen=open end,
        zoom=function(value) zoom=value; assert(camera).zoom=value end,
        restart=function() restartPending=true end,
        freeze=function() if physics then physics.updateEnabled=false end; if playerBody then playerBody.linearVelocity=Vector3.ZERO end end,
        presentation=function(grid,editing)
            for _,node in ipairs(gridNodes) do node.enabled=grid end
            if playerVisual and editing~=presentationEditing then
                local model=playerVisual:GetComponent("StaticModel") --[[@as StaticModel]]
                local material=Material:new()
                material:SetTechnique(0,cache:GetResource("Technique",editing and "Techniques/PBR/PBRNoTextureAlpha.xml" or "Techniques/PBR/PBRNoTexture.xml"))
                material:SetShaderParameter("MatDiffColor",Variant(Color(0.20,0.37,0.56,editing and 0.25 or 1)))
                model:SetMaterial(material)
            end
            presentationEditing=editing
        end,
    },assert(interface))
    uiController:Update(0)
    stationContents, contentsSignature = {}, ""
    UpdateProductionVisuals()
    RefreshLifecycle()
    SubscribeToEvent("Update", "FactoryPhase1Update")
    SubscribeToEvent("PostUpdate", "FactoryBuildingLabelsUpdate")
    SubscribeToEvent("EndFrame", "FactoryWorldMouse")
    SubscribeToEvent("MouseButtonDown", "FactoryWorldPointerDown")
    SubscribeToEvent("InputFocus", "FactoryUIFocus")
    SubscribeToEvent(assert(physics), "PhysicsPostStep", "FactorySmokePhysicsStep")

    print("[Phase1] READY: room=18x14, grid=1m, orthographic=top-down90, collision=Bullet, targets=7, layout=reference2")
    print("[Phase2] READY: item_types=5, hand_capacity=1, sources=3, F=take/pickup, Q=drop")
    print("[Phase3] READY: manual_cook=3s_continuous, assembly=instant, fixtures=removed")
    print("[Phase4] READY: auto_cooker=3_independent_slots_3s, auto_assembler=2s, shop_auto_fixtures=0, camera_aspect=original")
    print("[Phase7] READY: buildings=free, orders=max5_interval5to15, depot=5, cashier=keyboard_mouse, labels=world_children")
    print("[Phase8] READY: day=300s, days=3, pause=all_simulation, settlement=production_events, restart=clean_world")
    print("[Conveyor] READY: speed=0.5m/s, sample=5_physical_belts, buffer=6_LIFO, offscreen=true")
    print("[V05] READY: cable=undirected_ceiling, bandwidth=2_per_second_per_network, terminal=attached_storage, delivery=attached, receipt=storage_event, storage=24_LIFO, buffer=2x2_6")
    if RUN_V05_VISUAL then
        assert(SwitchArea('workshop'))
        local spot=Vector3(-37,0.55,-1.5)
        assert(player).position=spot; assert(playerBody).position=spot; assert(playerBody).linearVelocity=Vector3.ZERO
        assert(automation):OpenTerminal('ws_inventory')
        assert(uiController):Update(0)
        print('[V05 Native QA] terminal opened through development setup; ordinary spawn restored when flag=false')
    end
    if RUN_CONVEYOR_CHECKS and not conveyorChecksDone then
        conveyorChecksDone=true
        ConveyorChecks.Run()
        ConveyorEditingChecks.Run()
        Phase1.RunConveyorChecks()
        conveyorRestarting = true
        Phase1.Restart()
        conveyorRestarting = false
        print("[Conveyor Runtime QA] "..((#assert(logistics).network.belts==5 and #assert(buildings).records==4
            and assert(logistics).network.total==0 and currentArea=="shop") and "PASS " or "FAIL ").."restart restores physical sample")
    end
    if RUN_V05_RUNTIME and not v05RuntimeChecked then
        v05RuntimeChecked=true
        require('Factory/V05RuntimeChecks').Run({automation=assert(automation),loop=assert(gameLoop),logistics=assert(logistics),
            ui=assert(uiController),view=assert(interface),orders=assert(orders),machines=automatics,step=StepSimulation,switch=SwitchArea})
        Phase1.Restart()
        print('[V05 Runtime QA] '..((#assert(buildings).records==4 and #assert(automation).service.history==0 and assert(logistics).buffers.ws_inventory:Count()==0 and assert(gameLoop).day==1) and 'PASS ' or 'FAIL ')..'restart clears tasks reservations and inventory; restores sample')
        return
    end
    if RUN_CONVEYOR_VISUAL and not conveyorRestarting then
        SwitchArea("workshop")
        -- Isolated visual reproduction of the reported U-turn. This branch is
        -- development-only and all original fixtures return on normal restart.
        local control,build=assert(logistics),assert(buildings)
        while #control.network.belts>0 do control.network:Remove(control.network.belts[1].id) end
        local old={}
        for _,record in ipairs(build.records) do if AreaService.At(record.x,record.z)=="workshop" then table.insert(old,record) end end
        for _,record in ipairs(old) do assert(build:BeginMove(record,assert(player).position)); assert(build:DeleteSelected(assert(player).position)) end
        local added={}
        for _,spot in ipairs({{-45,-4},{-40,2}}) do
            build:Choose("buffer",assert(player).position,facing); build:SetPosition(spot[1],spot[2]); build.confirmFocus=true
            assert(build:Confirm(assert(player).position)); table.insert(added,build.records[#build.records])
        end
        local function port(id,side,tangent)
            for _,p in ipairs(Grid.Ports(assert(control:Endpoint(id)))) do if p.side==side and (side%2==0 and p.x or p.z)==tangent then return p end end
            error("visual port")
        end
        control:Open(); control.builder:Select(added[1].id); control.builder:Select(added[2].id)
        control.builder.plan=control.network:MakePlan(port(added[1].id,1,-4),port(added[2].id,2,-40),
            assert(Grid.Cells({{x=-43,z=-4},{x=-37,z=-4},{x=-37,z=-2},{x=-40,z=-2},{x=-40,z=-1}})))
        control.builder.selected,control.builder.handle=2,true
        control.builder.revision=control.builder.revision+1; control:Refresh()
    end
end

function Phase1.Restart()
    if RUN_HUD_DIAGNOSIS and interface then HudDiagnostics.Capture("before_restart", interface) end
    hudDiagnosisRestarts = hudDiagnosisRestarts + 1
    Phase1.Stop()
    if scene then scene:RemoveAllChildren() end
    Phase1.Start()
end

function Phase1.Stop()
    if uiController then uiController:Stop(); uiController=nil end
    UnsubscribeFromEvent("InputFocus")
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("PostUpdate")
    UnsubscribeFromEvent("EndFrame")
    UnsubscribeFromEvent("MouseButtonDown")
    if physics then UnsubscribeFromEvent(physics, "PhysicsPostStep") end
    if manual then manual:Reset(); manual = nil end
    for _, machine in pairs(automatics) do machine:Reset() end
    automatics = {}
    if automation then automation:Stop(); automation=nil end
    if logistics then logistics:Stop(); logistics=nil end
    areaLabel = nil
    if buildingGhost then buildingGhost:Remove(); buildingGhost = nil end
    buildings, orders, interface, gameLoop = nil, nil, nil, nil
    for _, node in ipairs(stationContents) do node:Remove() end
    stationContents = {}
    if items then items:Reset(); items = nil end
    UI.Shutdown()
end

-- Global event bridge required by UrhoX's string callback interface.
function FactoryPhase1Update(eventType, eventData)
    Phase1.Update(eventType, eventData)
end

function FactoryBuildingLabelsUpdate()
    Phase1.UpdateBuildingLabels()
end

function FactoryWorldMouse()
    Phase1.WorldMouse()
    if RUN_HUD_DIAGNOSIS and interface then
        hudDiagnosisFrames = hudDiagnosisFrames + 1
        if hudDiagnosisFrames == 5 then HudDiagnostics.Capture(hudDiagnosisRestarts == 0 and "initial" or "after_restart", interface) end
    end
end

---@param eventType StringHash
---@param eventData MouseButtonDownEventData
function FactoryWorldPointerDown(eventType,eventData)
    if uiController then return end
    if eventData:GetInt("Button")==MOUSEB_LEFT and not UI.IsPointerOverUI() then
        worldPressX,worldPressY=eventData:GetInt("X"),eventData:GetInt("Y")
    end
end

function FactoryUIFocus(eventType,eventData)
    if uiController and (not eventData:GetBool("Focus") or eventData:GetBool("Minimized")) then uiController:FocusLost() end
end

function FactorySmokePhysicsStep(eventType, eventData)
    if RUN_SMOKE_CHECKS and not loopChecksDone and qaStage == 1 then qaMotionTime = qaMotionTime + eventData:GetFloat("TimeStep") end
end

return Phase1
