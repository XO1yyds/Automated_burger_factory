-- Runtime tests use real held/ground nodes. Disabled in the delivered game.
local Checks = {}

---@param manual FactoryManualProduction
---@param items FactoryItemService
function Checks.Run(manual, items)
    local count, failures = 0, 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase3 QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local function reset()
        manual:Reset()
        items:Reset()
    end
    local function put(itemType)
        assert(items:Give(itemType))
        return manual:InteractAssembly()
    end
    reset()
    check("no Phase2 ground fixtures at start", next(items.ground) == nil)
    check("empty grill rejects empty hand", not manual:InteractGrill() and manual.grillItem == nil)
    assert(items:Give("bun"))
    local heldNode = items.heldNode
    check("consume validates type without losing held node", not items:ConsumeHeld("raw_beef") and items.heldNode == heldNode)
    check("grill rejects wrong material without loss", not manual:InteractGrill() and items.held == "bun" and manual.grillItem == nil)
    items:Reset()
    assert(items:TakeSource("raw_beef"))
    check("raw insertion transfers one entity out of hand", manual:InteractGrill() and manual.grillItem == "raw_beef" and items.held == nil and items.heldNode == nil)
    manual:UpdateGrill(4, true, true, false)
    check("placement hold cannot begin cooking before release", manual.grillProgress == 0 and manual.grillItem == "raw_beef")
    assert(items:Give("raw_beef"))
    check("single grill slot rejects second meat without loss", not manual:InteractGrill() and items.held == "raw_beef")
    items:Reset()
    check("raw grill cannot be taken out", not manual:InteractGrill() and items.held == nil and manual.grillItem == "raw_beef")
    manual:UpdateGrill(0, true, false, false)
    manual:UpdateGrill(2.5, true, true, false)
    check("less than three seconds keeps raw meat", manual.grillItem == "raw_beef" and manual.grillProgress == 2.5)
    manual:UpdateGrill(0.01, true, false, false)
    check("F release resets progress and retains meat", manual.grillProgress == 0 and manual.grillItem == "raw_beef")
    manual:UpdateGrill(1, true, true, false)
    manual:UpdateGrill(0.01, false, true, false)
    check("lost interaction target resets progress", manual.grillProgress == 0 and manual.grillItem == "raw_beef")
    manual:UpdateGrill(1, true, true, false)
    manual:UpdateGrill(0.01, true, true, true)
    check("blocked input resets progress", manual.grillProgress == 0)
    assert(items:Give("lettuce"))
    manual:UpdateGrill(4, true, true, false)
    check("occupied hand cannot cook", manual.grillItem == "raw_beef" and manual.grillProgress == 0)
    items:Reset()
    for _ = 1, 100 do manual:UpdateGrill(0.03, true, true, false) end
    check("three continuous seconds converts raw to cooked", manual.grillItem == "cooked_beef" and manual.grillProgress == 3)
    manual:UpdateGrill(100, false, false, true)
    check("cooked meat is stable after release and leaving", manual.grillItem == "cooked_beef")
    assert(items:Give("lettuce"))
    check("cooked output requires empty hand", not manual:InteractGrill() and items.held == "lettuce" and manual.grillItem == "cooked_beef")
    items:Reset()
    check("empty hand collects cooked output once", manual:InteractGrill() and items.held == "cooked_beef" and manual.grillItem == nil)
    check("second output collection does not duplicate", not manual:InteractGrill() and items.held == "cooked_beef")
    check("cooked meat enters assembly slot", manual:InteractAssembly() and manual.materials.cooked_beef and items.held == nil)
    check("bun input alone does not complete recipe", put("bun") and not manual.burgerReady and manual.materials.bun)
    assert(items:Give("bun"))
    check("duplicate material preserves held item", not manual:InteractAssembly() and items.held == "bun" and manual.materials.bun)
    items:Reset()
    check("final ingredient generates one burger immediately", put("lettuce") and manual.burgerReady and next(manual.materials) == nil
        and items.held == nil and manual.burgersProduced == 1)
    assert(items:Give("bun"))
    check("uncollected burger blocks new input", not manual:InteractAssembly() and manual.burgerReady and items.held == "bun")
    items:Reset()
    check("burger output transfers to real held entity", manual:InteractAssembly() and items.held == "burger" and items.heldNode ~= nil and not manual.burgerReady)
    check("repeated output action does not duplicate burger", not manual:InteractAssembly() and items.held == "burger" and manual.burgersProduced == 1)
    check("crafted burger can be dropped and picked up", items:Drop(Vector3(0, 0.55, 1), Vector3.FORWARD)
        and items:Pickup(assert(next(items.ground))) and items.held == "burger")
    reset()
    assert(put("bun"))
    assert(put("lettuce"))
    assert(items:Give("raw_beef"))
    local rejected, message = manual:InteractAssembly()
    check("raw meat cannot substitute for cooked recipe", not rejected and message:find("缺少熟牛肉饼", 1, true) ~= nil
        and items.held == "raw_beef" and not manual.burgerReady and not manual.materials.raw_beef)
    items:Reset()
    check("partial inputs can be retrieved in stable order", manual:InteractAssembly() and items.held == "bun" and not manual.materials.bun and manual.materials.lettuce)
    items:Reset()
    check("remaining partial material is recoverable", manual:InteractAssembly() and items.held == "lettuce" and next(manual.materials) == nil)
    items:Reset()
    check("empty assembly gives no phantom item", not manual:InteractAssembly() and items.held == nil)
    for _, sequence in ipairs({
        { "lettuce", "bun", "cooked_beef" }, { "cooked_beef", "lettuce", "bun" },
        { "bun", "cooked_beef", "lettuce" }, { "bun", "lettuce", "cooked_beef" },
        { "lettuce", "cooked_beef", "bun" }, { "cooked_beef", "bun", "lettuce" },
    }) do
        reset()
        for _, itemType in ipairs(sequence) do assert(put(itemType)) end
        check("recipe works in order " .. table.concat(sequence, "/"), manual.burgerReady and manual.burgersProduced == 1 and next(manual.materials) == nil)
    end
    reset()
    check("reset clears both workstations and item ownership", manual.grillItem == nil and manual.grillProgress == 0
        and not manual.burgerReady and next(manual.materials) == nil and items.held == nil and next(items.ground) == nil)
    print("[Phase3 QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end

return Checks
