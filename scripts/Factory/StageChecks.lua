---@class FactoryStageContext
---@field placePlayer fun(x:number,z:number)
---@field aim fun(id:string):boolean
---@field interact fun():boolean,string
---@field refresh fun()
---@field names fun()
---@field controls fun():boolean
---@field closeCashier fun()
---@field velocity fun(horizontal:number,vertical:number,running:boolean,blocked:boolean):Vector3
---@field camera Camera
---@field cameraNode Node
local Context = {}
---@class FactoryStageChecks
local Checks = { Context = Context }
local View = require("Factory/Interface")

---@param items FactoryItemService
---@param buildings FactoryBuildingController
---@param orders FactoryOrders
---@param view FactoryInterface
---@param machines table<string,FactoryAutomaticWorkstation>
---@param context FactoryStageContext
function Checks.Run(items, buildings, orders, view, machines, context)
    local count, failures = 0, 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase5-7 Route QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local function groundCount(itemType)
        local total = 0
        for _, item in pairs(items.ground) do if not itemType or item.itemType == itemType then total = total + 1 end end
        return total
    end
    items:Reset()
    context.placePlayer(0, 1)
    local origin = Vector3(0, 0.55, 1)
    local baseline = #buildings.records
    check("ordinary movement speed is four meters per second", math.abs(context.velocity(1, 0, false, false):Length() - 4) < 0.000001)
    check("held shift doubles movement speed", math.abs(context.velocity(1, 0, true, false):Length() - 8) < 0.000001)
    check("diagonal sprint is normalized", math.abs(context.velocity(1, 1, true, false):Length() - 8) < 0.000001)
    check("release shift restores ordinary speed", context.velocity(1, 1, false, false):Length() < 4.000001)
    check("sprint does not move player in building or cashier state", context.velocity(1, 1, true, true):LengthSquared() == 0)
    View.RefreshAutomatic(view, nil)
    check("no aimed device displays exact empty-device message", view.cooker.props.text == "当前没有自动化设备" and view.cooker:IsVisible() and not view.automaticAssembly:IsVisible())
    View.RefreshAutomatic(view, machines.auto_grill)
    check("aimed cooker displays only cooker information", view.cooker:IsVisible() and not view.automaticAssembly:IsVisible() and (view.cooker.props.text or ""):find("自动烹饪台", 1, true) ~= nil)
    View.RefreshAutomatic(view, machines.auto_assembly)
    check("aimed assembler displays only assembler information", not view.cooker:IsVisible() and view.automaticAssembly:IsVisible())
    buildings:Menu()
    assert(view.assemblerButton.props.onPointerEnter)({ type = "enter", x = 0, y = 0, pointerId = 0, pointerType = "mouse" } --[[@as PointerEvent]], view.assemblerButton)
    context.controls()
    check("hover selects building type without advancing preview", buildings.kind == "assembler" and buildings.mode == "menu")
    assert(view.assemblerButton.props.onClick)(view.assemblerButton)
    context.controls()
    check("building button callback enters preview without placing", buildings.mode == "preview" and #buildings.records == baseline)
    buildings:Choose("cooker", origin, Vector3.FORWARD)
    buildings:Back()
    check("right back from preview reaches building home", buildings.mode == "menu")
    buildings:Back()
    check("right back from building home exits", buildings.mode == "idle")
    buildings:Choose("cooker", origin, Vector3.FORWARD)
    buildings:Escape()
    check("escape from preview reaches building home", buildings.mode == "menu")
    buildings:Escape()
    check("second escape from building home exits", buildings.mode == "idle")
    buildings:Choose("cooker", origin, Vector3.FORWARD)
    buildings:SetPosition(5, 1)
    check("near candidate with legal footprint is allowed", buildings:Validate(origin))
    buildings:SetPosition(6, 1)
    check("beyond five-grid candidate is allowed", buildings:Validate(origin))
    check("whole rotated footprint must stay inside map", not buildings.context.valid(8.5, 0, 1.5, 2.4, nil))
    check("fixed buildings and entry zone reject overlap", not buildings.context.valid(-1.2, -2.5, 2.4, 1.5, nil)
        and not buildings.context.valid(-6, 4, 2.4, 1.5, nil))
    check("player footprint blocks construction", not buildings.context.valid(0, 1, 2.4, 1.5, nil))
    assert(items:SpawnGround("bun", Vector3(0, 0.14, -5)))
    check("ground items block construction", not buildings.context.valid(0, -5, 2.4, 1.5, nil))
    items:Reset()
    buildings:SetPosition(2.2, 1.1)
    check("candidate snaps to a one-meter grid", buildings.x == 2 and buildings.z == 1)
    buildings:Rotate()
    local width, depth = buildings:Dimensions()
    check("ninety-degree rotation swaps nonsquare footprint", width == 1.5 and depth == 2.4)
    check("merged preview can move and rotate without creating a building", buildings.mode == "preview" and #buildings.records == baseline)
    check("construction creates real free workstation and collision", buildings:Confirm(origin) and #buildings.records == baseline + 1)
    local record = assert(buildings.records[#buildings.records])
    local machine = assert(machines[record.id])
    check("confirmation returns to continuous preview", buildings.mode == "preview")
    check("new building background belongs to world root", record.nameBackground ~= nil and record.nameBackground.parent == record.node)
    check("world name uses stronger stroke and a noncolliding backdrop", record.nameText ~= nil and record.nameText.effectStrokeThickness == 2
        and record.nameBackground ~= nil and record.nameBackground:GetComponent("RigidBody") == nil)
    check("created building has a world text child", record.nameNode ~= nil and record.nameNode.parent == record.node
        and record.nameText ~= nil and record.nameText:GetNumChars() > 0 and not record.nameText.fixedScreenSize)
    local labelNode = assert(record.nameNode)
    local namePosition, cameraPosition, originalZoom = labelNode.worldPosition, context.cameraNode.position, context.camera.zoom
    context.cameraNode.position = cameraPosition + Vector3(1, 0, 0.7)
    context.camera.zoom = 2
    check("camera pan and zoom do not move world-name anchor", labelNode.worldPosition == namePosition)
    context.cameraNode.position, context.camera.zoom = cameraPosition, originalZoom
    context.placePlayer(2, -0.8); context.names()
    check("nearby building world name becomes visible", labelNode.enabled)
    context.placePlayer(0, -5); context.names()
    check("world name hides when player leaves", not labelNode.enabled)
    context.placePlayer(0, 1)
    assert(items:Give("raw_beef")); assert(machine:Interact())
    check("processing machine cannot enter move mode", not buildings:BeginMove(record, origin))
    buildings.selected, buildings.mode = record, "move"
    check("processing machine cannot be deleted", not buildings:DeleteSelected(origin) and machines[record.id] == machine)
    machine:Update(3)
    local originalX, originalZ, originalQuarter = record.x, record.z, record.quarter
    assert(buildings:BeginMove(record, origin))
    buildings:SetPosition(-2, 1); buildings:Rotate(); buildings:Back()
    check("cancel move preserves original pose and completed contents", record.x == originalX and record.z == originalZ
        and record.quarter == originalQuarter and machine.slots[1].itemType == "cooked_beef")
    check("right back from editing returns to management", buildings.mode == "manage" and buildings.selected == nil)
    assert(buildings:BeginMove(record, origin)); buildings:Escape()
    check("escape from editing skips to building home", buildings.mode == "menu" and buildings.selected == nil)
    assert(buildings:BeginMove(record, origin))
    buildings:SetPosition(-2, 1); buildings:Rotate()
    check("confirm move preserves real machine contents", buildings:Confirm(origin) and record.x == -2 and machine.slots[1].itemType == "cooked_beef")
    check("moving a building returns to management", buildings.mode == "manage")
    check("world nickname travels with building parent", labelNode.parent == record.node and math.abs(labelNode.worldPosition.x - record.x) < 0.001)
    local farOrigin = Vector3(8, 0.55, -6)
    check("distant building can be selected for editing", buildings:BeginMove(record, farOrigin))
    local originalFree = items.context.isSpotFree
    items.context.isSpotFree = function() return false end
    check("failed content spill cancels deletion without loss", not buildings:DeleteSelected(origin) and machines[record.id] == machine
        and machine.slots[1].itemType == "cooked_beef")
    items.context.isSpotFree = originalFree
    assert(items:Give("bun"))
    check("distant deletion releases cached contents and retains hand", buildings:DeleteSelected(farOrigin) and machines[record.id] == nil
        and groundCount("cooked_beef") == 1 and items.held == "bun" and #buildings.records == baseline)
    check("deletion returns to management for another selection", buildings.mode == "manage")
    items:Reset()
    buildings:Cancel()
    local function produce()
        assert(context.aim("raw") and context.interact())
        assert(context.aim("auto_grill") and context.interact())
        machines.auto_grill:Update(3)
        assert(context.interact())
        assert(context.aim("auto_assembly") and context.interact())
        assert(context.aim("bun") and context.interact())
        assert(context.aim("auto_assembly") and context.interact())
        assert(context.aim("lettuce") and context.interact())
        assert(context.aim("auto_assembly") and context.interact())
        machines.auto_assembly:Update(2)
        assert(context.interact())
        assert(context.aim("delivery") and context.interact())
    end
    orders.active = { { id = 101, required = 3, delivered = 0 }, { id = 102, required = 1, delivered = 0 } }
    orders.selectedId, orders.stock, orders.wait, orders.completed = nil, 0, 999, 0
    produce()
    check("full production route deposits one real burger", orders.stock == 1 and items.held == nil)
    assert(context.aim("cashier") and context.interact())
    require("Factory/Interface").RefreshOrders(view, orders)
    check("opening cashier does not auto-select an order", orders.selectedId == nil and view.deliverButton:IsDisabled())
    assert(view.orderButtons[1].props.onClick)(assert(view.orderButtons[1]))
    context.controls()
    require("Factory/Interface").RefreshOrders(view, orders)
    check("actual order-row callback selects intended order", orders.selectedId == 101 and not view.deliverButton:IsDisabled())
    assert(view.deliverButton.props.onClick)(view.deliverButton)
    context.controls()
    check("actual delivery-button callback applies partial delivery", orders.active[1].delivered == 1 and orders.stock == 0 and orders.completed == 0)
    context.closeCashier()
    for _ = 1, 3 do produce() end
    assert(context.aim("cashier") and context.interact())
    require("Factory/Interface").RefreshOrders(view, orders)
    assert(view.orderButtons[1].props.onClick)(assert(view.orderButtons[1])); context.controls()
    assert(view.deliverButton.props.onClick)(view.deliverButton); context.controls()
    check("complete route removes order and retains excess burger", #orders.active == 1 and orders.active[1].id == 102 and orders.stock == 1
        and orders.completed == 1 and orders.selectedId == nil)
    require("Factory/Interface").RefreshOrders(view, orders)
    check("completion does not auto-select or deliver another order", view.deliverButton:IsDisabled() and orders.active[1].delivered == 0)
    context.closeCashier()
    assert(context.aim("delivery"))
    check("depot F route can recover leftover burger", context.interact() and items.held == "burger" and orders.stock == 0)
    items:Reset()
    machines.auto_grill:Reset(); machines.auto_assembly:Reset()
    orders:SetDay(1); orders.stock = 0
    buildings:Cancel(); context.closeCashier(); context.placePlayer(0, 1); context.refresh()
    check("acceptance fixtures clean up for ordinary gameplay", #buildings.records == baseline and groundCount() == 0 and items.held == nil
        and orders.selectedId == nil and #orders.active == 0 and orders.stock == 0)
    check("empty trash interaction does not invent or delete items", context.aim("trash") and not context.interact() and items.held == nil)
    ---@type FactoryItemType[]
    local trashTypes = { "bun", "raw_beef", "cooked_beef", "lettuce", "burger" }
    for _, kind in ipairs(trashTypes) do
        assert(items:Give(kind))
        check("trash F destroys held " .. kind, context.aim("trash") and context.interact() and items.held == nil and items.heldNode == nil)
    end
    assert(items:SpawnGround("bun", Vector3(0, 0.14, -5)))
    check("trash leaves unrelated ground items", context.aim("trash") and not context.interact() and groundCount("bun") == 1)
    items:Reset(); View.RefreshAutomatic(view, nil); context.placePlayer(0, 1)
    print("[Phase5-7 Route QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end
return Checks
