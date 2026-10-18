local OrderService = require("Factory/Orders")
local Checks = {}
---@param items FactoryItemService
function Checks.Run(items)
    local count, failures = 0, 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase6-7 QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    items:Reset()
    local book = OrderService.New(items, function(low, high) return low end)
    book:Update(4.9)
    check("first order waits at least five seconds", #book.active == 0)
    book:Update(0.1)
    check("day one creates a one-burger order", #book.active == 1 and book.active[1].required == 1)
    book:Update(100)
    check("active orders stop at five and suspend countdown", #book.active == 5 and book.wait == nil)
    local latest = book.nextId
    book:Update(1000)
    check("full queue does not generate hidden orders", #book.active == 5 and book.nextId == latest)
    book.stock = 1
    check("delivery requires an explicit selection", not book:Deliver() and book.stock == 1 and #book.active == 5)
    book:Select(book.active[1].id)
    check("complete order is removed and selection cleared", book:Deliver() and #book.active == 4 and book.selectedId == nil and book.completed == 1)
    check("freed full queue restarts fresh random wait", book.wait == 5)
    book:Update(4.9)
    check("new order is not immediate after queue frees", #book.active == 4)
    book:Update(0.1)
    check("queue resumes with a new unique order id", #book.active == 5 and book.nextId == latest + 1)
    book:Select(999)
    check("stale selection cannot deliver", book.selectedId == nil and not book:CanDeliver())
    local bigger = OrderService.New(items, function(low, high) return high end)
    bigger:Update(14.9)
    check("random interval can wait fifteen seconds", #bigger.active == 0)
    bigger:Update(0.1)
    check("fifteen-second boundary produces first order", #bigger.active == 1)
    bigger:SetDay(2); bigger:Update(15)
    check("day two quantity is capped at two", bigger.active[1].required == 2)
    bigger:SetDay(3); bigger:Update(15)
    check("day three quantity is capped at three", bigger.active[1].required == 3)
    bigger.stock = 1
    bigger:Select(bigger.active[1].id)
    check("partial delivery consumes only available stock", bigger:Deliver() and bigger.active[1].delivered == 1 and bigger.stock == 0 and bigger.completed == 0)
    bigger.stock = 5
    check("delivery retains burgers beyond remaining need", bigger:Deliver() and bigger.stock == 3 and #bigger.active == 0 and bigger.completed == 1)
    check("completed order cannot receive extra delivery", not bigger:Deliver() and bigger.stock == 3)
    bigger.stock = 0
    assert(items:Give("bun"))
    check("depot rejects non-burger without destroying hand", not bigger:InteractDepot() and items.held == "bun")
    items:Reset()
    for _ = 1, 5 do assert(items:Give("burger")); assert(bigger:InteractDepot()) end
    check("depot holds exactly five burger entities", bigger.stock == 5 and items.held == nil)
    assert(items:Give("burger"))
    check("sixth depot input preserves hand", not bigger:InteractDepot() and bigger.stock == 5 and items.held == "burger")
    items:Reset()
    check("empty hand can retrieve a deposited burger", bigger:InteractDepot() and bigger.stock == 4 and items.held == "burger" and items.heldNode ~= nil)
    items:Reset()
    for _ = 1, 4 do assert(bigger:InteractDepot()); items:Reset() end
    check("empty depot cannot duplicate output", not bigger:InteractDepot() and bigger.stock == 0 and items.held == nil)
    bigger:SetDay(3); bigger:Update(15)
    bigger.stock = 2; bigger:Select(bigger.active[1].id)
    bigger:EndDay()
    check("day-end hook clears orders and selection but preserves stock", #bigger.active == 0 and bigger.selectedId == nil and bigger.stock == 2 and not bigger.enabled)
    bigger:Update(100)
    check("closed day hook stops generation", #bigger.active == 0)
    items:Reset()
    print("[Phase6-7 QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end
return Checks
