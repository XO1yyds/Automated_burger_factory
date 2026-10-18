local UI = require("urhox-libs/UI")
local View = {}

---@class FactoryInterface
---@field prompt Label
---@field feedback Label
---@field held Label
---@field grill Label
---@field assembly Label
---@field cooker Label
---@field automaticAssembly Label
---@field depot Label
---@field orderLabels Label[]
---@field orderButtons Button[]
---@field buildPanel Panel
---@field managePanel Panel
---@field cashierPanel Panel
---@field cookerButton Button
---@field assemblerButton Button
---@field buildButtons table<string,Button>
---@field selectedLabel Label
---@field deliverButton Button
---@field clock Label
---@field dayStats Label
---@field cashierEndButton Button
---@field lifecyclePanel Panel
---@field lifecycleTitle Label
---@field lifecycleHint Label
---@field summaryLabels Label[]
---@field pauseButtons Button[]
---@field summaryButton Button
---@field restartButton Button
---@field exitButton Button

---@param action fun(command:string,value?:string|integer)
---@return FactoryInterface
function View.New(action)
    local self = {
        prompt = UI.Label { text = "", fontSize = 18 }, feedback = UI.Label { text = "", fontSize = 14 },
        held = UI.Label { text = "手持：空", fontSize = 16 }, grill = UI.Label { text = "", fontSize = 14 },
        assembly = UI.Label { text = "", fontSize = 14 }, cooker = UI.Label { text = "当前没有自动化设备", fontSize = 14 },
        automaticAssembly = UI.Label { text = "", fontSize = 14 }, depot = UI.Label { text = "交付区 0/5", fontSize = 14 },
        orderLabels = {}, orderButtons = {},
        clock = UI.Label { text = "Day 1/3 · 05:00", fontSize = 18 },
        dayStats = UI.Label { text = "", fontSize = 14 }, summaryLabels = {}, pauseButtons = {},
    } --[[@as FactoryInterface]]
    self.buildButtons = {}
    local buildChildren = {
        UI.Label { text = "建筑选择 · 免费 / 无数量上限", fontSize = 20 },
        UI.Label { text = "A/D选型 · F选择 · E传送带 · Tab管理 · ESC退出", fontSize = 14 },
    }
    local Buildings = require("Factory/Buildings")
    for _,kind in ipairs(Buildings.Order) do
        local button=UI.Button { text=Buildings.Definitions[kind].name,
            onPointerEnter=function() action("hoverKind",kind) end,
            onClick=function() action("choose",kind) end }
        self.buildButtons[kind]=button; table.insert(buildChildren,button)
    end
    self.cookerButton,self.assemblerButton=self.buildButtons.cooker,self.buildButtons.assembler
    table.insert(buildChildren,UI.Button { text="传送带布置（仅车间，E）",onClick=function() action("openConveyor") end })
    table.insert(buildChildren,UI.Button { text="管理已有建筑 / 传送带",onClick=function() action("manage") end })
    table.insert(buildChildren,UI.Button { text="退出建筑模式",onClick=function() action("closeBuild") end })
    self.buildPanel = UI.Panel {
        position="absolute",left="28%",top="10%",width="44%",padding=14,gap=5,
        backgroundColor={28,31,35,248},children=buildChildren,
    }
    self.managePanel = UI.Panel {
        position = "absolute", left = 14, bottom = 122, width = 380, padding = 12, gap = 6,
        backgroundColor = { 28, 31, 35, 235 }, children = {
            UI.Label { text = "管理：F 选前方建筑 / 左键选建筑", fontSize = 14 },
            UI.Label { text = "选中后 Q 删除；右键逐层返回，ESC 回建筑页面", fontSize = 14 },
            UI.Button { text = "返回选型", onClick = function() action("buildMenu") end },
            UI.Button { text = "退出", onClick = function() action("closeBuild") end },
        },
    }
    self.selectedLabel = UI.Label { text = "未选择订单", fontSize = 16 }
    self.deliverButton = UI.Button { text = "交付所选订单（F）", disabled = true, onClick = function() action("deliver") end }
    local cashierChildren = {
        UI.Label { text = "收银台", fontSize = 20 },
        UI.Label { text = "W/S 或 A/D 选单 · F 交付 · ESC/右键关闭", fontSize = 14 },
        self.selectedLabel,
    }
    local hudChildren = { UI.Label { text = "当前未完成订单", fontSize = 16 } }
    for index = 1, 5 do
        self.orderLabels[index] = UI.Label { text = "", fontSize = 14 }
        table.insert(hudChildren, self.orderLabels[index])
        self.orderButtons[index] = UI.Button { text = "", onClick = function() action("selectRow", index) end }
        table.insert(cashierChildren, self.orderButtons[index])
    end
    table.insert(cashierChildren, self.deliverButton)
    self.cashierEndButton = UI.Button { text = "结束当天（计时归零后可用，E）", disabled = true,
        onClick = function() action("cashierEnd") end }
    table.insert(cashierChildren, self.cashierEndButton)
    table.insert(cashierChildren, UI.Button { text = "关闭收银台", onClick = function() action("closeCashier") end })
    self.cashierPanel = UI.Panel {
        position = "absolute", left = "25%", top = "15%", width = "50%", padding = 18, gap = 8,
        backgroundColor = { 28, 31, 35, 248 }, children = cashierChildren,
    }
    self.buildPanel:SetVisible(false); self.managePanel:SetVisible(false); self.cashierPanel:SetVisible(false)
    self.automaticAssembly:SetVisible(false)
    self.lifecycleTitle = UI.Label { text = "暂停", fontSize = 24 }
    self.lifecycleHint = UI.Label { text = "W/S 选择 · F/Enter 确认 · ESC 继续", fontSize = 14 }
    local lifecycleChildren = { self.lifecycleTitle, self.lifecycleHint }
    for index = 1, 4 do
        self.summaryLabels[index] = UI.Label { text = "", fontSize = 16 }
        table.insert(lifecycleChildren, self.summaryLabels[index])
    end
    self.pauseButtons = {
        UI.Button { text = "继续游戏", onClick = function() action("resume") end },
        UI.Button { text = "结束当天并结算", onClick = function() action("pauseEnd") end },
        UI.Button { text = "退出游戏", onClick = function() action("exitGame") end },
    }
    for _, button in ipairs(self.pauseButtons) do table.insert(lifecycleChildren, button) end
    self.summaryButton = UI.Button { text = "进入下一天", onClick = function() action("nextDay") end }
    self.restartButton = UI.Button { text = "重新开始", onClick = function() action("restart") end }
    self.exitButton = UI.Button { text = "退出游戏", onClick = function() action("exitGame") end }
    table.insert(lifecycleChildren, self.summaryButton)
    table.insert(lifecycleChildren, self.restartButton)
    table.insert(lifecycleChildren, self.exitButton)
    self.lifecyclePanel = UI.Panel {
        position = "absolute", left = 0, top = 0, width = "100%", height = "100%", zIndex = 100,
        backgroundColor = { 0, 0, 0, 155 }, justifyContent = "center", alignItems = "center", children = {
            UI.Panel { width = "60%", maxWidth = 660, padding = 24, gap = 10,
                backgroundColor = { 28, 31, 35, 255 }, children = lifecycleChildren },
        },
    }
    self.lifecyclePanel:SetVisible(false)
    UI.SetRoot(UI.SafeAreaView {
        width = "100%", height = "100%", pointerEvents = "box-none", children = {
            UI.Panel { id = "factory_info", position = "absolute", left = 14, top = 18, padding = 12, gap = 4, pointerEvents = "none",
                backgroundColor = { 28, 31, 35, 220 }, children = {
                    UI.Label { text = "自动化汉堡工厂 · Demo V0.2", fontSize = 18 },
                    self.clock, self.dayStats,
                    UI.Label { text = "WASD 移动 · Shift 奔跑 · F 交互 · Q 放下 · B 建筑 · ESC 暂停", fontSize = 14 },
                    self.held, self.grill, self.assembly, self.cooker, self.automaticAssembly, self.depot,
                } },
            UI.Panel { position = "absolute", right = 14, top = 18, width = 250, padding = 12, gap = 6,
                pointerEvents = "none", backgroundColor = { 28, 31, 35, 220 }, children = hudChildren },
            UI.Panel { position = "absolute", bottom = 18, left = 18, right = 18, padding = 12, gap = 6,
                pointerEvents = "none", backgroundColor = { 28, 31, 35, 220 }, children = { self.prompt, self.feedback } },
            self.buildPanel, self.managePanel, self.cashierPanel, self.lifecyclePanel,
        },
    })
    return self
end

---@param self FactoryInterface
---@param machine FactoryAutomaticWorkstation?
function View.RefreshAutomatic(self, machine)
    local cooker = machine == nil or machine.kind == "cooker"
    self.cooker:SetVisible(cooker)
    self.automaticAssembly:SetVisible(not cooker)
    if not machine then self.cooker:SetText("当前没有自动化设备")
    elseif cooker then self.cooker:SetText(machine:Status())
    else self.automaticAssembly:SetText(machine:Status()) end
end

---@param self FactoryInterface
---@param loop FactoryGameLoop
---@param selected integer
function View.RefreshLoop(self, loop, selected)
    self.clock:SetText(loop:ClockText())
    self.dayStats:SetText(string.format("今日订单 %d · 汉堡 %d（手工 %d / 自动 %d）", loop.orders.completed,
        loop.manual + loop.automatic, loop.manual, loop.automatic))
    self.cashierEndButton:SetDisabled(not loop:CanCashierEnd())
    self.lifecyclePanel:SetVisible(not loop:IsRunning())
    local paused, settlement, complete = loop.state == "paused", loop.state == "settlement", loop.state == "complete"
    self.lifecycleTitle:SetText(paused and "暂停" or (settlement and ("Day " .. loop.day .. " · 每日结算") or "Demo 完成 · 三天结束"))
    self.lifecycleHint:SetText(paused and "W/S 选择 · F/Enter 确认 · ESC 继续；模拟已冻结"
        or (settlement and "F/Enter 继续；场景物品及加工进度保留" or "W/S 选择 · F/Enter 确认；重新开始会清空本轮动态状态"))
    local pauseTexts = { "继续游戏", "结束当天并结算", "退出游戏" }
    for index, button in ipairs(self.pauseButtons) do
        button:SetVisible(paused)
        button:SetText((index == selected and "已选 · " or "") .. pauseTexts[index])
    end
    self.summaryButton:SetVisible(settlement)
    self.summaryButton:SetText(loop.day < 3 and "进入下一天（F/Enter）" or "查看 Demo 完成（F/Enter）")
    self.restartButton:SetVisible(complete); self.exitButton:SetVisible(complete)
    self.restartButton:SetText((selected == 1 and "已选 · " or "") .. "重新开始")
    self.exitButton:SetText((selected == 2 and "已选 · " or "") .. "退出游戏")
    for index, label in ipairs(self.summaryLabels) do
        label:SetVisible(not paused)
        local summary = settlement and loop.history[#loop.history] or loop.history[index]
        if settlement then
            local stats = summary
            local lines = stats and {
                "当日完成订单：" .. stats.orders,
                "当日制作汉堡：" .. stats.total,
                string.format("手工 %d · 自动 %d", stats.manual, stats.automatic),
                stats.early and "提前结束；未完成订单已清除，无惩罚。" or "计时结束；未完成订单已清除，无惩罚。",
            } or {}
            label:SetText(lines[index] or "")
        elseif complete then
            label:SetVisible(summary ~= nil)
            label:SetText(summary and string.format("Day %d · 订单 %d · 汉堡 %d（手工 %d / 自动 %d）",
                summary.day, summary.orders, summary.total, summary.manual, summary.automatic) or "")
        end
    end
end

---@param self FactoryInterface
---@param book FactoryOrders
function View.RefreshOrders(self, book)
    self.depot:SetText("交付区域：汉堡 " .. book.stock .. "/5")
    for index = 1, 5 do
        local order = book.active[index]
        local text = order and string.format("订单 %02d：%d/%d", order.id, order.delivered, order.required) or ""
        self.orderLabels[index]:SetText(text)
        self.orderLabels[index]:SetVisible(order ~= nil)
        self.orderButtons[index]:SetText(order and ((order.id == book.selectedId and "已选 · " or "") .. text) or "")
        self.orderButtons[index]:SetVisible(order ~= nil)
    end
    local selected = book:Find(book.selectedId)
    self.selectedLabel:SetText(selected and string.format("所选订单 %02d · 交付区 %d/5", selected.id, book.stock) or ("未选择订单 · 交付区 " .. book.stock .. "/5"))
    self.deliverButton:SetDisabled(not book:CanDeliver())
end

---@param self FactoryInterface
---@param mode string
---@param kind FactoryBuildingKind
function View.RefreshBuild(self, mode, kind)
    self.buildPanel:SetVisible(mode == "menu")
    self.managePanel:SetVisible(mode == "manage")
    local Buildings = require("Factory/Buildings")
    for value,button in pairs(self.buildButtons) do
        button:SetText((kind==value and "已选 · " or "")..Buildings.Definitions[value].name)
    end
end

return View
