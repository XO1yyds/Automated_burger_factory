local Automatic = require("Factory/AutomaticWorkstation")
local Checks = {}

---@param items FactoryItemService
---@param cooker FactoryAutomaticWorkstation
---@param assembler FactoryAutomaticWorkstation
function Checks.Run(items, cooker, assembler)
    local count, failures = 0, 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase4 QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local function reset()
        items:Reset()
        cooker:Reset()
        assembler:Reset()
    end
    ---@param machine FactoryAutomaticWorkstation
    ---@param itemType FactoryItemType
    local function put(machine, itemType)
        assert(items:Give(itemType))
        return machine:Interact()
    end
    reset()
    check("empty cooker returns no item", not cooker:Interact() and items.held == nil)
    check("wrong cooker input retains real held entity", not put(cooker, "lettuce") and items.held == "lettuce" and items.heldNode ~= nil)
    items:Reset()
    check("first raw input occupies one slot and empties hand", put(cooker, "raw_beef") and cooker.slots[1] ~= nil and items.held == nil)
    cooker:Update(1)
    assert(put(cooker, "raw_beef"))
    cooker:Update(1)
    assert(put(cooker, "raw_beef"))
    check("three inputs have independent start times", cooker.slots[1].progress == 2 and cooker.slots[2].progress == 1 and cooker.slots[3].progress == 0)
    check("full cooker rejects fourth input without loss", not put(cooker, "raw_beef") and items.held == "raw_beef")
    items:Reset()
    cooker:Update(1)
    check("only earliest slot finishes at its three-second boundary", cooker.slots[1].itemType == "cooked_beef"
        and cooker.slots[2].itemType == "raw_beef" and cooker.slots[3].itemType == "raw_beef")
    check("cooked slot still blocks fourth input", not put(cooker, "raw_beef") and items.held == "raw_beef")
    items:Reset()
    check("empty hand takes cooked meat before raw", cooker:Interact() and items.held == "cooked_beef" and cooker.slots[1] == nil)
    items:Reset()
    check("without cooked meat latest raw input is retrieved", cooker:Interact() and items.held == "raw_beef" and cooker.slots[3] == nil)
    check("reinserting early raw starts from zero", cooker:Interact() and cooker.slots[1].progress == 0 and cooker.slots[1].order == 4)
    cooker:Update(2)
    check("older second slot finishes before reinserted first slot", cooker.slots[2].itemType == "cooked_beef" and cooker.slots[1].itemType == "raw_beef")
    check("cooked retrieval ignores slot index", cooker:Interact() and items.held == "cooked_beef" and cooker.slots[2] == nil)
    reset()
    for _ = 1, 3 do assert(put(cooker, "raw_beef")) end
    for _ = 1, 100 do cooker:Update(0.03) end
    check("all three slots finish independently without F", cooker.slots[1].itemType == "cooked_beef"
        and cooker.slots[2].itemType == "cooked_beef" and cooker.slots[3].itemType == "cooked_beef" and not cooker:IsProcessing())
    check("equal completion times use insertion order", cooker:Interact() and cooker.slots[1] == nil)
    items:Reset()
    assert(put(cooker, "raw_beef"))
    cooker:Update(3)
    check("old completed slot is taken before a newly completed low-index slot", cooker:Interact() and cooker.slots[2] == nil and cooker.slots[1] ~= nil)
    reset()
    assert(put(cooker, "raw_beef"))
    cooker:Update(2.1)
    check("HUD reports each slot remaining time", cooker:Status():find("0.9s", 1, true) ~= nil and cooker:Status():find("2：空", 1, true) ~= nil)
    local before = cooker.slots[1].progress
    cooker:Update(-1)
    check("negative timestep cannot reverse cooking", cooker.slots[1].progress == before)
    local other = Automatic.New("cooker", items)
    check("separate machines own separate slots", next(other.slots) == nil and other.slots ~= cooker.slots and other.clock == 0)
    reset()
    check("empty assembler creates no output", not assembler:Interact() and not assembler.burgerReady)
    check("burger is rejected as assembler ingredient", not put(assembler, "burger") and items.held == "burger")
    items:Reset()
    check("wrong raw meat is stored in the single meat slot", put(assembler, "raw_beef") and assembler.materials.raw_beef and items.held == nil)
    assert(put(assembler, "bun"))
    assert(put(assembler, "lettuce"))
    assembler:Update(100)
    check("raw meat recipe never starts or generates burger", not assembler.processing and not assembler.burgerReady
        and assembler.materials.raw_beef and assembler:Status():find("缺少熟牛肉饼", 1, true) ~= nil)
    check("raw and cooked meat cannot occupy two meat slots", not put(assembler, "cooked_beef") and items.held == "cooked_beef")
    items:Reset()
    check("idle retrieval prioritizes wrong raw meat", assembler:Interact() and items.held == "raw_beef" and not assembler.materials.raw_beef and assembler.materials.bun)
    items:Reset()
    check("corrected recipe starts automatic two-second processing", put(assembler, "cooked_beef") and assembler.processing and assembler.progress == 0)
    assembler:Update(1.99)
    check("recipe is not finished before two seconds", assembler.processing and not assembler.burgerReady and assembler.materials.bun)
    check("processing blocks empty-hand retrieval", not assembler:Interact() and items.held == nil and assembler.materials.cooked_beef)
    check("processing blocks input and retains held entity", not put(assembler, "bun") and items.held == "bun" and items.heldNode ~= nil)
    items:Reset()
    assembler:Update(0.01)
    check("two seconds consumes recipe and creates exactly one cached burger", assembler.burgerReady and not assembler.processing
        and next(assembler.materials) == nil and assembler.burgersProduced == 1)
    assembler:Update(100)
    check("cached output does not disappear or duplicate", assembler.burgerReady and assembler.burgersProduced == 1)
    check("output cannot swap with occupied hand", not put(assembler, "burger") and items.held == "burger" and assembler.burgerReady)
    items:Reset()
    assert(put(assembler, "bun"))
    check("duplicate next-batch material is rejected without loss", not put(assembler, "bun") and items.held == "bun")
    items:Reset()
    assert(put(assembler, "cooked_beef"))
    assert(put(assembler, "lettuce"))
    assembler:Update(100)
    check("full next recipe waits while cached output occupies capacity", not assembler.processing and assembler.progress == 0
        and assembler.burgerReady and assembler.burgersProduced == 1 and assembler.materials.lettuce)
    check("cached burger is taken before next-batch ingredients", assembler:Interact() and items.held == "burger" and not assembler.burgerReady
        and assembler.processing and assembler.materials.bun)
    items:Reset()
    assembler:Update(2)
    check("collecting output permits next batch to finish once", assembler.burgerReady and assembler.burgersProduced == 2 and next(assembler.materials) == nil)
    reset()
    assert(put(assembler, "lettuce"))
    assert(put(assembler, "bun"))
    check("incomplete recipe permits material recovery", assembler:Interact() and items.held == "bun" and not assembler.materials.bun and assembler.materials.lettuce)
    items:Reset()
    check("last incomplete ingredient is recoverable", assembler:Interact() and items.held == "lettuce" and next(assembler.materials) == nil)
    reset()
    for _, sequence in ipairs({ { "bun", "cooked_beef", "lettuce" }, { "lettuce", "cooked_beef", "bun" } }) do
        for _, itemType in ipairs(sequence) do assert(put(assembler, itemType)) end
        assembler:Update(2)
        check("automatic recipe accepts order " .. table.concat(sequence, "/"), assembler.burgerReady and assembler.burgersProduced == 1)
        reset()
    end
    check("reset removes all machine contents and processing", next(cooker.slots) == nil and next(assembler.materials) == nil
        and not assembler.processing and not assembler.burgerReady and assembler.burgersProduced == 0 and items.held == nil)
    print("[Phase4 QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end

return Checks
