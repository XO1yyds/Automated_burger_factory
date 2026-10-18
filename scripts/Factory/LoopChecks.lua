local Orders = require("Factory/Orders")
local Loop = require("Factory/GameLoop")

---@class FactoryLoopCheckSnapshot
---@field loop FactoryGameLoop
---@field orders FactoryOrders
---@field items FactoryItemService
---@field manual FactoryManualProduction
---@field machines table<string, FactoryAutomaticWorkstation>
---@field buildings FactoryBuildingController
---@field view FactoryInterface
---@field player Node
---@field body RigidBody
---@field physics PhysicsWorld
---@field camera Camera
---@field cashier boolean

---@class FactoryLoopCheckContext
---@field snapshot fun():FactoryLoopCheckSnapshot
---@field step fun(dt:number):string
---@field ui FactoryUIController
---@field controls fun():boolean
---@field command fun(command:string)
---@field refresh fun()
---@field openCashier fun()
---@field restart fun()
local Context = {}
---@class FactoryLoopChecks
local Checks = { Context = Context }

---@param context FactoryLoopCheckContext
function Checks.Run(context)
    local count, failures = 0, 0
    local function check(name, passed)
        count = count + 1
        if not passed then failures = failures + 1 end
        print("[Phase8 QA] " .. (passed and "PASS " or "FAIL ") .. name)
    end
    local root = context.snapshot()
    local book = Orders.New(root.items, function(minimum, maximum) return maximum end)
    local loop = Loop.New(book)
    check("default day lasts 300 seconds across three days", loop.remaining == 300 and Loop.DayCount == 3)
    loop:Update(14)
    check("first order waits random interval", #book.active == 0)
    loop:Update(1)
    check("Day1 needs exactly one burger", #book.active == 1 and book.active[1].required == 1)
    book.stock = 1; book:Select(book.active[1].id); book:Deliver()
    loop:RecordBurger("manual"); loop:RecordBurger("automatic")
    loop:Pause(); local time, wait = loop.remaining, book.wait
    loop:Update(500); loop:RecordBurger("automatic")
    check("paused time orders and production counters freeze", loop.remaining == time and book.wait == wait and loop.automatic == 1)
    check("cashier cannot end before zero even when paused", not loop:EndDay("cashier"))
    check("pause can end early", loop:EndDay("pause") and loop.state == "settlement")
    local summary = loop.history[1]
    check("summary snapshots completions and production split", summary.orders == 1 and summary.total == 2 and summary.manual == 1 and summary.automatic == 1 and summary.early)
    loop:Update(500)
    check("settlement simulation freezes", loop.remaining == time and #book.active == 0)
    check("repeated end cannot add a duplicate summary", not loop:EndDay("pause") and #loop.history == 1)
    book.stock = 2
    loop:Continue()
    check("Day2 resets clock wait and daily statistics retains depot", loop.day == 2 and loop.remaining == 300 and loop.manual == 0 and loop.automatic == 0 and book.completed == 0 and book.wait == 15 and book.stock == 2)
    loop:Update(15)
    check("Day2 supports two-burger orders", book.active[1].required == 2)
    book.stock = 1; book:Select(book.active[1].id); book:Deliver()
    check("partial delivery does not count as complete", book.completed == 0 and book.active[1].delivered == 1)
    loop:Update(284.9)
    check("positive fractional last second remains active", loop.remaining > 0 and book.enabled)
    loop:Update(0.1)
    check("exact expiry clears all orders and selection", loop.remaining == 0 and #book.active == 0 and book.selectedId == nil and not book.enabled and book.wait == nil)
    loop:Update(1000)
    check("post expiry never generates orders and no false completion", #book.active == 0 and book.completed == 0)
    loop:RecordBurger("automatic")
    check("production after zero still belongs to current day", loop.automatic == 1)
    check("cashier ending allowed only after zero", loop:EndDay("cashier"))
    check("prior summary remains unchanged", loop.history[1].total == 2 and loop.history[2].automatic == 1)
    loop:Continue(); loop:Update(15)
    check("Day3 supports three-burger orders", loop.day == 3 and book.active[1].required == 3)
    loop:Pause(); loop:EndDay("pause"); loop:Continue()
    check("third settlement leads to completion without Day4", loop.state == "complete" and loop.day == 3 and #loop.history == 3 and not book.enabled)
    loop:Update(500); check("completed demo cannot continue or simulate", not loop:Continue() and #book.active == 0)

    -- V0.3 scene integration uses the same public action dispatcher as touch.
    local ui=context.ui
    local function refresh() context.refresh(); ui:Update(0) end
    local function command(cmd) context.command(cmd); context.controls(); refresh() end
    root=context.snapshot()
    root.loop.state,root.loop.day,root.loop.remaining="running",1,300
    root.loop.history,root.loop.manual,root.loop.automatic={},0,0
    root.orders:SetDay(1)
    root.items:Reset(); root.manual:Reset()
    for _,machine in pairs(root.machines) do machine:Reset() end
    root.items:Give("raw_beef"); root.machines.ws_cooker:Interact(); context.step(1)
    local slot=assert(root.machines.ws_cooker.slots[1]); local progress=slot.progress; local remaining=root.loop.remaining
    command("pause"); context.step(100)
    check("pause action freezes simulation and renders modal",root.loop.state=="paused" and root.view.model.phase=="paused" and not root.physics.updateEnabled and slot.progress==progress and root.loop.remaining==remaining)
    command("statistics"); check("statistics remains paused",root.loop.state=="paused" and root.view.model.phase=="statistics")
    ui:Back(false); command("settings"); check("settings remains paused",root.loop.state=="paused" and root.view.model.phase=="settings")
    ui:Back(false); command("pauseEnd")
    check("early end first requests concrete confirmation",root.loop.state=="paused" and root.view.model.phase=="confirm" and #root.loop.history==0)
    ui:Back(false); refresh(); check("cancel early end preserves day",root.loop.state=="paused" and #root.loop.history==0)
    command("pauseEnd"); command("confirmYes")
    check("confirmed early end creates one settlement",root.loop.state=="settlement" and #root.loop.history==1 and root.loop.history[1].early)
    context.step(10); check("settlement freezes machines",slot.progress==progress)
    command("nextDay"); check("next day preserves machine contents",root.loop.day==2 and root.loop.state=="running" and root.machines.ws_cooker.slots[1]==slot)
    root.orders.active={{id=901,required=2,delivered=0}}; root.orders.selectedId=901
    root.loop:Expire(); refresh()
    check("expiry clears pending orders but allows organizing",#root.orders.active==0 and root.orders.selectedId==nil and root.loop.state=="running")
    context.openCashier(); refresh(); command("cashierEnd")
    check("cashier ends only expired day",root.loop.state=="settlement" and #root.loop.history==2 and not root.loop.history[2].early)
    command("nextDay"); command("pause"); command("pauseEnd"); command("confirmYes"); command("nextDay")
    check("third settlement renders complete page",root.loop.state=="complete" and root.view.model.phase=="complete" and #root.loop.history==3)
    command("restart"); check("restart requires confirmation",root.loop.state=="complete" and root.view.model.phase=="confirm")
    ui:Back(false); refresh(); check("restart cancellation retains completion",root.loop.state=="complete" and root.view.model.phase=="complete")
    command("restart"); command("confirmYes"); context.restart()
    root=context.snapshot()
    check("restart reconstructs accepted V0.3 map",root.loop.day==1 and root.loop.state=="running" and root.machines.auto_grill==nil and root.machines.auto_assembly==nil and root.machines.ws_cooker~=nil and #root.buildings.records==3)
    check("restart clears production orders hand and history",root.loop.manual==0 and root.loop.automatic==0 and #root.loop.history==0 and #root.orders.active==0 and root.orders.stock==0 and root.items.held==nil)
    print("[Phase8 QA] COMPLETE checks="..count.." failures="..failures)
    return {passed=count-failures,failed=failures}
end
return Checks
