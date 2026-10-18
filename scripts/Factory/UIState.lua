-- Engine-independent UI policy. Recommendations are implemented in one place.
local State = {}
State.Version = "Demo V0.3"
State.Categories = {"生产", "接口", "物流", "储存", "管理"}
---@type string[][]
State.Kinds = {{"cooker","assembler"},{"junction","isolator_straight","isolator_corner"},{"conveyor"},{"buffer"},{"manage"}}

function State.Clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end

function State.Phase(s)
    if s.loop ~= "running" then return s.overlay or s.loop end
    if s.ordersOpen then return "orders" end
    if s.buffer then return "buffer" end
    if s.conveyor and s.conveyor ~= "idle" then return s.conveyor end
    if s.build == "menu" then return "menu" end
    if s.build == "manage" then return s.selected and "selected" or "manage" end
    if s.build == "preview" then return "preview" end
    if s.build == "move" then return "move" end
    return "normal"
end

State.Titles = {normal="",orders="订单",buffer="缓存台 · 选择物品",menu="建造模式",manage="建筑管理 · 选择对象",
    selected="建筑管理 · 已选中",preview="正在放置",move="正在编辑建筑",source="传送带 · 1/3 选择输出 A",
    destination="传送带 · 2/3 选择输入 B",adjust="传送带 · 3/3 调整路径",paused="暂停",statistics="统计",
    settings="设置",confirm="确认操作",settlement="每日结算",complete="Demo 完成"}

function State.Grid(phase)
    return phase=="preview" or phase=="move" or phase=="selected" or phase=="source" or phase=="destination" or phase=="adjust"
end

function State.IsBuild(phase)
    return phase=="menu" or phase=="manage" or phase=="selected" or phase=="preview" or phase=="move"
        or phase=="source" or phase=="destination" or phase=="adjust"
end

function State.BufferAction(held,item,valid)
    if not valid then return "请重新选择",false end
    if held and item then return "交换",true end
    if held then return "存入",true end
    if item then return "取出",true end
    return "空槽",false
end

function State.Layout(w,h)
    local compact=h<540
    return {compact=compact,header=48,margin=12,button=48,cardWidth=math.min(280,math.max(210,w*0.24)),
        selectorHeight=compact and 128 or 148,modalWidth=math.min(640,w-48),modalHeight=math.max(180,h-100),
        actionBottom=16,joystickSize=112,toastBottom=compact and 120 or 150}
end

function State.OrderSummary(count) return "待处理 "..count.."/5" end

function State.DefaultPreferences()
    return {display="both",joystick="fixed",uiScale=1,sensitivity=1,tutorials={}}
end

function State.SanitizePreferences(data)
    local result=State.DefaultPreferences()
    if type(data)~="table" then return result end
    if data.display=="both" or data.display=="keyboard" or data.display=="touch" then result.display=data.display end
    if data.joystick=="fixed" or data.joystick=="floating" then result.joystick=data.joystick end
    if type(data.uiScale)=="number" and data.uiScale==data.uiScale then result.uiScale=State.Clamp(data.uiScale,0.9,1.2) end
    if type(data.sensitivity)=="number" and data.sensitivity==data.sensitivity then result.sensitivity=State.Clamp(data.sensitivity,0.5,1.5) end
    if type(data.tutorials)=="table" then
        for _,key in ipairs({"normal","preview","adjust"}) do result.tutorials[key]=data.tutorials[key]==true end
    end
    return result
end

function State.PreferenceText(p)
    return table.concat({"操作显示："..({both="双端",keyboard="键鼠",touch="触屏"})[p.display],
        "摇杆："..(p.joystick=="fixed" and "固定" or "浮动"),string.format("UI %.1f · 镜头灵敏度 %.1f",p.uiScale,p.sensitivity)},"\n")
end

return State
