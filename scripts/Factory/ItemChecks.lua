local Definitions = require("Factory/Items").Definitions
local Checks = {}

---@param items FactoryItemService
function Checks.Run(items)
    local failures = 0
    local count = 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase2 QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local function groundCount()
        local total = 0
        for _ in pairs(items.ground) do total = total + 1 end
        return total
    end
    items:Reset()
    local definitionCount = 0
    for _ in pairs(Definitions) do definitionCount = definitionCount + 1 end
    check("five independent item types", definitionCount == 5 and Definitions.raw_beef ~= Definitions.cooked_beef)
    check("empty-hand Q has no effect", not items:Drop(Vector3(0, 0.55, 1), Vector3.FORWARD) and groundCount() == 0)
    check("cooked meat cannot be obtained at a raw source", not items:TakeSource("cooked_beef") and items.held == nil)
    check("empty hand takes one bun", items:TakeSource("bun") and items.held == "bun" and items.heldNode ~= nil)
    check("source swap rejects missing placement context", not items:TakeSource("raw_beef") and items.held == "bun")
    check("full hand swaps at unlimited source", items:TakeSource("raw_beef", Vector3(0, 0.55, 1), Vector3.FORWARD)
        and items.held == "raw_beef" and groundCount() == 1)
    local returned = items:FindGround(Vector3(0, 0.55, 1), Vector3.FORWARD, 1)
    check("source swap leaves old held item on valid nearby ground", returned ~= nil and returned.itemType == "bun")
    local originalHeld = items.heldNode
    local originalFree = items.context.isSpotFree
    items.context.isSpotFree = function() return false end
    check("source swap with no free ground retains original hand", not items:TakeSource("lettuce", Vector3(0, 0.55, 1), Vector3.FORWARD)
        and items.held == "raw_beef" and items.heldNode == originalHeld and groundCount() == 1)
    items.context.isSpotFree = originalFree
    items:Reset()
    assert(items:TakeSource("bun"))
    local loose = assert(items:SpawnGround("raw_beef", Vector3(-1, 0.14, 1.8)))
    local originalPosition = loose.position
    check("full hand swaps with ground item", items:Pickup(loose.id) and items.held == "raw_beef"
        and loose.itemType == "bun" and groundCount() == 1 and items.heldNode ~= nil)
    check("ground swap preserves exact position", loose.position == originalPosition and loose.node.position == originalPosition)
    check("repeated ground swap reverses without duplication", items:Pickup(loose.id) and items.held == "bun"
        and loose.itemType == "raw_beef" and groundCount() == 1)
    local before = groundCount()
    local freeCallback = items.context.isSpotFree
    items.context.isSpotFree = function() return false end
    check("blocked drop retains hand and all ground items", not items:Drop(Vector3(0, 0.55, 1), Vector3.FORWARD)
        and items.held == "bun" and items.heldNode ~= nil and groundCount() == before)
    items.context.isSpotFree = freeCallback
    check("Q creates one entity and empties hand", items:Drop(Vector3(0, 0.55, 1), Vector3.FORWARD)
        and items.held == nil and items.heldNode == nil and groundCount() == before + 1)
    check("empty hand picks ground raw meat", items:Pickup(loose.id) and items.held == "raw_beef" and items.ground[loose.id] == nil)
    check("same ground entity cannot be picked twice", not items:Pickup(loose.id) and items.held == "raw_beef")
    items:Reset()
    for itemType in pairs(Definitions) do
        local item = assert(items:SpawnGround(itemType, Vector3(0, 0.14, 1.8)))
        local ok = items:Pickup(item.id)
        local heldCorrect = items.held == itemType and items.heldNode ~= nil
        local dropped = items:Drop(Vector3(0, 0.55, 1), Vector3.FORWARD)
        local found = items:FindGround(Vector3(0, 0.55, 1), Vector3.FORWARD, 1)
        check("entity/hand/drop round trip: " .. itemType, ok and heldCorrect and dropped and found ~= nil and found.itemType == itemType)
        items:Reset()
    end
    local infinite = true
    for _ = 1, 8 do
        if not items:TakeSource("lettuce") then infinite = false end
        items:Reset()
    end
    check("source has no depletion or stock limit", infinite)
    check("drop positions reject outside room", not items:IsSpotFree(Vector3(9.1, 0.14, 0)))
    check("drop positions reject workstations", not items:IsSpotFree(Vector3(2.7, 0.14, 5.8)))
    check("square items do not cut workstation corners", not items:IsSpotFree(Vector3(4.33, 0.14, 4.77)))
    local front = assert(items:SpawnGround("bun", Vector3(0, 0.14, 1.7)))
    check("square ground items cannot overlap diagonally", not items:IsSpotFree(Vector3(0.26, 0.14, 1.96)))
    assert(items:SpawnGround("lettuce", Vector3(0, 0.14, 0.3)))
    local found = items:FindGround(Vector3(0, 0.55, 1), Vector3.FORWARD, 1)
    check("ground detection selects front and excludes rear", found ~= nil and found.id == front.id)
    check("ground detection rejects far-away targets", items:FindGround(Vector3(0, 0.55, -1), Vector3(0, 0, -1), 1) == nil)
    items:Reset()
    assert(items:SpawnGround("burger", Vector3(0, 0.14, -4.2)))
    check("ground interaction cannot pass through cashier", items:FindGround(Vector3(0, 0.55, -1), Vector3(0, 0, -1), 5) == nil)
    items:Reset()
    check("reset releases all held and ground entities", items.held == nil and items.heldNode == nil and groundCount() == 0)
    print("[Phase2 QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end

return Checks
