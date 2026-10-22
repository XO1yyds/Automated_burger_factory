-- Compact terminal presentation. Detailed diagnostics are opt-in, never removed from services.
local Definitions=require('Factory/Items').Definitions
local Model={}
local function action(text,command,value,disabled) return {text=text,command=command,value=value,disabled=disabled} end
local function title(kind) return Definitions[kind].name end
local function tool(m,text,command,value,disabled) table.insert(m.tools,action(text,command,value,disabled)) end
local function row(m,text,detail,button) table.insert(m.entries,{text=text,detail=detail,action=button}) end
---@return table?
function Model.Build(c)
    if not c.terminal then return nil end
    local host=c.context.resolve(c.terminal); local bound=host and host.terminal and host.storage
    local m={title=bound and '下单终端' or '下单组件',back=c.inventoryKind and '返回库存' or c.choosingTarget and '返回下单' or c.product and '返回产品' or '关闭',lines={},entries={},tabs={},tools={},buttons={},
        scrollKey=c.tab..':'..tostring(c.product)..':'..c.page..':'..tostring(c.details)..':'..tostring(c.choosingTarget)..':'..tostring(c.showHistory)..':'..tostring(c.inventoryKind)}
    local tabs=bound and {{'products','下单'},{'inventory','本机库存'},{'network','网络'},{'tasks','任务'}} or {{'products','下单'},{'network','网络'},{'tasks','任务'}}
    for _,tab in ipairs(tabs) do
        table.insert(m.tabs,action((c.tab==tab[1] and '● ' or '')..tab[2],'terminalTab',tab[1]))
    end
    local endpoints=c.service:Endpoints(c.terminal)
    if c.tab=='products' then
        if not c.product then
            m.summary=bound and '选择要下单的物品' or '选择要制作的物品'
            local kinds={}; for _,ep in ipairs(endpoints) do if ep.machine then kinds[ep.machine.kind]=true end end
            if kinds.assembler then row(m,'汉堡','汉堡胚 + 熟牛肉 + 生菜',action('选择','terminalProduct','burger')) end
            if kinds.cooker then row(m,'熟牛肉','生牛肉加工 · 3秒',action('选择','terminalProduct','cooked_beef')) end
            if not next(kinds) then m.lines={'还没有可用的生产设备。请连接车间烹饪台或组合台。'} end
        elseif c.choosingTarget then
            m.summary='选择成品存放位置'
            local targets=c:Targets(); local pages=math.max(1,math.ceil(#targets/8)); c.page=math.min(c.page,pages)
            for i=(c.page-1)*8+1,math.min(#targets,c.page*8) do local ep=targets[i]
                row(m,ep.name,ep.storage:LoadText(),action(c.target==ep.id and '已选' or '选用','terminalTarget',ep.id))
            end
            if #targets==0 then m.lines={'没有已连接的库存或缓存台。'} end
            if pages>1 then tool(m,'上一页','terminalPage',-1,c.page==1); tool(m,'下一页','terminalPage',1,c.page==pages) end
        else
            local ok,message=c.service:Check(c.terminal,c.product,c.quantity,c.target)
            local destination=c.context.resolve(c.target or '')
            m.summary=title(c.product)..' ×'..c.quantity
            m.quantity={value=c.quantity,actions={action('−10','terminalQuantity',-10,c.quantity==1),action('−','terminalQuantity',-1,c.quantity==1),action('+','terminalQuantity',1,c.quantity==99),action('+10','terminalQuantity',10,c.quantity==99)}}
            m.lines={destination and ('成品 → '..destination.name..'  '..destination.storage:Count()..'/'..destination.storage.capacity) or '请连接库存或缓存台',ok and '可以生产' or message}
            if not bound then tool(m,'更换存放位置','terminalChooseTarget') end
            tool(m,c.details and '收起配方与材料' or '查看配方与材料','terminalDetails')
            if c.details then
                row(m,'单件配方',c.product=='burger' and '汉堡胚×1 + 熟牛肉×1 + 生菜×1；组装2秒' or '生牛肉×1；烹饪3秒')
                local info=c.service:Snapshot(c.terminal); local sources={}
                for _,ep in ipairs(endpoints) do if ep.source then sources[ep.source]=true end end
                local kinds=c.product=='burger' and {'bun','cooked_beef','lettuce','raw_beef'} or {'raw_beef'}
                for _,kind in ipairs(kinds) do row(m,title(kind),string.format('现有%d · 栈顶可取%d%s',info.total[kind] or 0,info.available[kind] or 0,sources[kind] and ' · 无限来源' or '')) end
            end
            m.buttons={action((bound and '下单 ' or '制作 ')..c.quantity..' 件','terminalSubmit',nil,not ok)}
        end
    elseif c.tab=='inventory' and bound then
        m.summary='本机库存 '..bound:Count()..'/'..bound.capacity
        if c.inventoryKind then
            local n=bound:CountKind(c.inventoryKind)
            row(m,title(c.inventoryKind),'可取 '..n..' 件；每次取出1件')
            m.lines={'空手时放入手中；手满时取出的物品落在附近地面。','地面无合法空位则不可取出，原手持与库存保持不变。'}
            m.buttons={action('取出1件','terminalWithdraw',nil,n==0)}
        else
            for _,kind in ipairs({'burger','cooked_beef','raw_beef','bun','lettuce'}) do
                local total=0; for _,v in pairs(bound.slots) do if v.itemType==kind then total=total+1 end end
                if total>0 then row(m,title(kind)..' ×'..total,'可取 '..bound:CountKind(kind),action('查看','terminalInventoryKind',kind)) end
            end
            if bound:Count()==0 then m.lines={'库存为空。传送带或电缆输入后在这里显示。'} end
        end
    elseif c.tab=='network' then
        local info=c.service:Snapshot(c.terminal)
        m.summary='已连接 '..#endpoints..' 个建筑 · 传输 2件/秒'
        local any=false; local sources={}
        for _,ep in ipairs(endpoints) do if ep.source then sources[ep.source]=true end end
        for _,kind in ipairs({'burger','cooked_beef','bun','raw_beef','lettuce'}) do
            local count=info.total[kind] or 0
            if count>0 or sources[kind] then
                any=true
                local detail=sources[kind] and '无限供料' or ('可取 '..(info.available[kind] or 0))
                if c.details then detail=string.format('可取%d · 预约%d · 加工%d · 受阻%d%s',info.available[kind] or 0,info.locked[kind] or 0,info.processing[kind] or 0,math.max(0,count-(info.available[kind] or 0)-(info.locked[kind] or 0)-(info.processing[kind] or 0)),sources[kind] and ' · ∞' or '') end
                row(m,title(kind)..'  '..count,detail)
            end
        end
        if not any then m.lines={'暂无物品或原料来源。'} end
        tool(m,c.details and '收起设备与库存明细' or '查看设备与库存明细','terminalDetails')
        if c.details then
            local pages=math.max(1,math.ceil(#info.lines/8)); c.page=math.min(c.page,pages)
            for i=(c.page-1)*8+1,math.min(#info.lines,c.page*8) do row(m,info.lines[i],'') end
            if pages>1 then tool(m,'上一页','terminalPage',-1,c.page==1); tool(m,'下一页','terminalPage',1,c.page==pages) end
        end
    else
        local queue=c.service.queues[c.terminal] or {}
        m.summary=#queue==0 and '暂无进行中的任务' or ('生产队列 '..#queue..'/10')
        for _,job in ipairs(queue) do
            local detail=job.state..(job.reason~='' and (' · '..job.reason) or '')
            row(m,title(job.product)..'  '..(job.arrivalBased and '到货 ' or '')..job.delivered..'/'..job.quantity,detail,action(job.cancelled and '收尾中' or '取消','terminalCancel',job.id,job.cancelled))
        end
        local history={}; for i=#c.service.history,1,-1 do local job=c.service.history[i]; if job.terminal==c.terminal then table.insert(history,job) end end
        if #history>0 then
            tool(m,c.showHistory and '收起已结束任务' or ('已结束任务 '..#history),'terminalHistory')
            if c.showHistory then for i=1,math.min(4,#history) do local job=history[i]; row(m,title(job.product)..'  '..job.delivered..'/'..job.quantity,job.state) end end
        end
    end
    -- Presentation metadata only; inventory/task services remain authoritative.
    for _,entry in ipairs(m.entries) do
        for _,kind in ipairs({'cooked_beef','raw_beef','lettuce','bun','burger'}) do
            local name=Definitions[kind].name
            if entry.text:sub(1,#name)==name then entry.itemType=kind; break end
        end
        if entry.action and entry.action.command=='terminalProduct' then entry.itemType=entry.action.value end
    end
    return m
end
return Model
