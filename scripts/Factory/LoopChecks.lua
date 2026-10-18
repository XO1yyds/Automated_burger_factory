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
---@field frame fun(dt:number)
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

    -- Actual scene/UI integration. All modifications are discarded by the same
    -- complete-page restart button used by the player at the end of this suite.
    root.items:Reset(); root.manual:Reset()
    for _, machine in pairs(root.machines) do machine:Reset() end
    root.loop.state, root.loop.day, root.loop.remaining = "running", 1, 300
    root.loop.manual, root.loop.automatic, root.loop.history = 0, 0, {}
    root.orders:SetDay(1); root.orders.stock = 0
    root.items:Give("raw_beef"); root.machines.auto_grill:Interact(); context.step(1)
    root.items:Give("bun"); root.items:Drop(Vector3(0, 0.55, 1), Vector3.RIGHT)
    root.items:Give("lettuce")
    root.manual.grillItem, root.manual.grillProgress, root.manual.grillArmed = "raw_beef", 1, true
    local savedGround, savedHeld, savedWait = root.items.ground, root.items.held, root.orders.wait
    local slot = assert(root.machines.auto_grill.slots[1])
    context.command("pause"); context.controls(); context.refresh()
    local savedPosition = root.player.position
    local savedTime, savedSlot = root.loop.remaining, slot.progress
    context.frame(100)
    check("actual pause command displays modal and disables physics", root.loop.state == "paused" and root.view.lifecyclePanel:IsVisible() and not root.physics.updateEnabled and root.body.linearVelocity:LengthSquared() == 0)
    check("scene pause freezes machine manual time order and player", slot.progress == savedSlot and root.manual.grillProgress == 1 and root.loop.remaining == savedTime and root.orders.wait == savedWait and (root.player.position - savedPosition):LengthSquared() == 0)
    assert(root.view.pauseButtons[1].props.onClick)(assert(root.view.pauseButtons[1])); context.frame(0.2)
    check("actual resume callback restores physics", root.loop:IsRunning() and root.physics.updateEnabled)
    check("resume frame preserves manual progress and paused time", root.manual.grillProgress == 1 and root.loop.remaining == savedTime)
    context.step(1)
    check("automatic processing resumes original progress", math.abs(slot.progress - (savedSlot + 1)) < 0.000001)

    root.items:Reset()
    local function makeManual()
        for _, kind in ipairs({ "bun", "cooked_beef", "lettuce" }) do root.items:Give(kind); root.manual:InteractAssembly() end
    end
    makeManual()
    check("actual hand assembly records at creation", root.loop.manual == 1 and root.manual.burgerReady)
    root.manual:InteractAssembly(); root.items:ConsumeHeld("burger")
    check("collecting burger does not count twice", root.loop.manual == 1)
    local assembler = root.machines.auto_assembly
    for _, kind in ipairs({ "bun", "cooked_beef", "lettuce" }) do root.items:Give(kind); assembler:Interact() end
    context.step(1)
    local assemblyProgress = assembler.progress
    context.command("pause"); context.controls(); context.step(50)
    check("assembly freezes without completing during pause", assembler.processing and assembler.progress == assemblyProgress and root.loop.automatic == 0)
    assert(root.view.pauseButtons[1].props.onClick)(assert(root.view.pauseButtons[1])); context.controls(); context.step(1)
    check("actual automatic assembly counted at completion", root.loop.automatic == 1 and assembler.burgerReady)
    root.buildings.mode, root.buildings.selected = "move", root.buildings.records[1]
    local toDelete = root.buildings.records[2]
    root.buildings.context.remove(toDelete)
    for index, record in ipairs(root.buildings.records) do if record == toDelete then table.remove(root.buildings.records, index); break end end
    check("deleting output does not subtract production stats", root.loop.automatic == 1)
    root.buildings:Cancel()
    local record = root.buildings.records[1]
    root.buildings.context.update(record, -4, 0, 1)
    root.items:Give("bun"); root.items:Drop(Vector3(0, 0.55, 1), Vector3.RIGHT); root.items:Give("lettuce")
    savedGround, savedHeld = root.items.ground, root.items.held
    root.orders.stock = 2
    context.openCashier(); context.refresh()
    assert(root.view.cashierEndButton.props.onClick)(root.view.cashierEndButton); context.controls()
    check("actual cashier button cannot end early", root.loop.state == "running" and root.view.cashierEndButton.props.disabled)
    -- Building/cashier states lock player only; shared simulation still ticks.
    local before = root.loop.remaining
    context.step(1)
    check("cashier keeps daily time running", root.loop.remaining == before - 1)
    context.command("closeCashier"); context.controls(); root.buildings:Menu()
    before = root.loop.remaining; context.step(1)
    check("building menu keeps daily time running", root.loop.remaining == before - 1)
    root.buildings:Cancel()
    root.items:ConsumeHeld("lettuce"); root.items:Give("raw_beef"); root.machines.auto_grill:Interact(); context.step(1.2)
    local unfinishedSlot = root.machines.auto_grill.slots[2]
    root.items:Give("lettuce")
    savedHeld = root.items.held
    root.manual.grillProgress = 0.7
    context.command("pause"); context.controls()
    assert(root.view.pauseButtons[2].props.onClick)(assert(root.view.pauseButtons[2])); context.controls(); context.refresh()
    check("actual early-end callback displays frozen settlement", root.loop.state == "settlement" and root.view.summaryButton:IsVisible() and not root.physics.updateEnabled)
    local day1 = root.loop.history[1]
    check("actual settlement has manual1 automatic1 total2", day1.manual == 1 and day1.automatic == 1 and day1.total == 2)
    local retainedSlot = root.machines.auto_grill.slots[1]
    assert(root.view.summaryButton.props.onClick)(root.view.summaryButton); context.frame(0.2); context.refresh()
    check("next-day callback retains scene contents and building pose", root.loop.day == 2 and root.items.ground == savedGround and root.items.held == savedHeld and root.orders.stock == 2 and root.machines.auto_grill.slots[1] == retainedSlot and record.x == -4 and record.quarter == 1)
    check("next-day resets daily counts and restores physics", root.loop.manual == 0 and root.loop.automatic == 0 and root.orders.completed == 0 and root.loop.remaining == 300 and root.physics.updateEnabled)
    check("next-day transition retains unfinished machine and manual progress", unfinishedSlot ~= nil and unfinishedSlot.itemType == "raw_beef" and math.abs(unfinishedSlot.progress - 1.2) < 0.00001 and root.manual.grillProgress == 0.7)
    context.openCashier()
    root.orders.active = { { id = 100, required = 2, delivered = 1 } }; root.orders:Select(100)
    root.loop.remaining = 0.1; context.command("deliver"); context.frame(0.1); context.refresh()
    check("actual expiry clears selected order and unlocks end button", root.orders.selectedId == nil and #root.orders.active == 0 and not root.view.cashierEndButton.props.disabled)
    check("expiry wins over delivery on the same frame", root.orders.stock == 2 and root.orders.completed == 0)
    assert(root.view.cashierEndButton.props.onClick)(root.view.cashierEndButton); context.controls()
    check("actual cashier end goes to settlement", root.loop.state == "settlement")
    assert(root.view.summaryButton.props.onClick)(root.view.summaryButton); context.controls()
    check("Day3 callback enters third day only", root.loop.day == 3 and root.loop.remaining == 300)
    context.command("pause"); context.controls()
    assert(root.view.pauseButtons[2].props.onClick)(assert(root.view.pauseButtons[2])); context.controls()
    assert(root.view.summaryButton.props.onClick)(root.view.summaryButton); context.controls(); context.refresh()
    check("completion page shows all three summaries and restart", root.loop.state == "complete" and root.view.restartButton:IsVisible() and #root.loop.history == 3)
    local oldPlayer, oldCamera = root.player, root.camera
    assert(root.view.restartButton.props.onClick)(root.view.restartButton); context.controls(); context.restart()
    local fresh = context.snapshot()
    check("restart callback recreates scene player camera and Day1", fresh.loop.day == 1 and fresh.loop.remaining == 300 and fresh.loop:IsRunning() and fresh.player ~= oldPlayer and fresh.camera ~= oldCamera)
    check("restart clears hand floor stock orders summaries stats", fresh.items.held == nil and next(fresh.items.ground) == nil and fresh.orders.stock == 0 and #fresh.orders.active == 0 and #fresh.loop.history == 0 and fresh.loop.manual == 0 and fresh.loop.automatic == 0)
    check("restart restores original shop and workshop machines and pose", #fresh.buildings.records == 4 and fresh.buildings.records[1].x == -5 and fresh.buildings.records[1].z == 0 and (fresh.buildings.records[1].quarter or 0) == 0 and next(fresh.machines.auto_grill.slots) == nil and not fresh.machines.auto_assembly.burgerReady and not fresh.machines.auto_assembly.processing and next(fresh.machines.ws_cooker.slots) == nil and not fresh.machines.ws_assembler.burgerReady)
    check("restart restores input physics and closes modal cashier", fresh.physics.updateEnabled and not fresh.cashier and not fresh.view.lifecyclePanel:IsVisible() and fresh.buildings.mode == "idle")
    fresh.buildings:Menu(); context.command("escape"); context.controls()
    check("escape from building home closes mode before pause", fresh.buildings.mode == "idle" and fresh.loop:IsRunning())
    context.command("escape"); context.controls()
    check("next escape opens pause", fresh.loop.state == "paused" and not fresh.physics.updateEnabled)
    context.command("escape"); context.controls()
    check("escape in pause resumes", fresh.loop:IsRunning() and fresh.physics.updateEnabled)
    context.openCashier(); context.command("escape"); context.controls()
    check("escape closes cashier before pause", not context.snapshot().cashier and fresh.loop:IsRunning())
    print("[Phase8 QA] COMPLETE checks=" .. count .. " failures=" .. failures)
end

return Checks
