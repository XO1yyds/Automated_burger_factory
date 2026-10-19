-- Pure, non-mutating preflight. Strict stacks are virtually popped, never indexed out of order.
local Names=require('Factory/Items').Definitions
local Planner={}
Planner.Recipes={cooked_beef={machine='cooker',inputs={raw_beef=1}},burger={machine='assembler',inputs={bun=1,cooked_beef=1,lettuce=1}}}
local function title(kind) return Names[kind] and Names[kind].name or kind end
function Planner.Check(endpoints,product,quantity,targetId)
    local recipe=Planner.Recipes[product]
    if not recipe or type(quantity)~='number' or quantity%1~=0 or quantity<1 or quantity>99 then return false,'数量须为1～99的整数。' end
    local machines,sources,stacks,outputs={}, {}, {}, {}
    local target=false; local demand={}; local candidates={}
    for kind,n in pairs(recipe.inputs) do demand[kind]=n*quantity end
    for _,ep in ipairs(endpoints or {}) do
        if ep.id==targetId and ep.storage then target=true end
        if ep.source then sources[ep.source]=true end
        if ep.storage then
            local stack={}
            for _,v in pairs(ep.storage.slots) do table.insert(stack,v) end
            table.sort(stack,function(a,b) return a.order<b.order end)
            table.insert(stacks,{items=stack,storage=ep.storage})
        end
        if ep.machine then
            local m=ep.machine; machines[m.kind]=true
            if not m.automationOwner then
                if m.kind=='cooker' then for _,slot in pairs(m.slots) do if slot.itemType=='cooked_beef' then outputs.cooked_beef=(outputs.cooked_beef or 0)+1 end end end
                if m.kind==recipe.machine and not m:IsProcessing() and not m.burgerReady and not m.materials.raw_beef then
                    table.insert(candidates,ep)
                end
            end
        end
    end
    -- Reuse materials only on machines this batch can actually allocate. Combining
    -- partial inputs from unrelated assemblers would invent a complete recipe.
    table.sort(candidates,function(a,b)
        local function filled(ep) local n=0; for _ in pairs(ep.machine.materials) do n=n+1 end; return n end
        local x,y=filled(a),filled(b); return x==y and a.id<b.id or x>y
    end)
    for i=1,math.min(quantity,#candidates) do
        for kind in pairs(recipe.inputs) do if candidates[i].machine.materials[kind] then demand[kind]=math.max(0,demand[kind]-1) end end
    end
    if not target then return false,'请选择同网库存或缓存台作为成品去向。' end
    if not machines[recipe.machine] then return false,'缺少'..(recipe.machine=='cooker' and '自动烹饪台' or '自动汉堡组合台')..'。' end
    local used,expanded={},{}; local guard=0
    while guard<128 do
        guard=guard+1; local progress=false
        for _,stack in ipairs(stacks) do
            while #stack.items>0 do
                local top=stack.items[#stack.items]; local kind=top.itemType
                if (demand[kind] or 0)<=0 or stack.storage.locks[top.id] then break end
                demand[kind]=demand[kind]-1; used[kind]=(used[kind] or 0)+1; table.remove(stack.items); progress=true
            end
        end
        for kind,n in pairs(outputs) do
            local take=math.min(n,demand[kind] or 0)
            if take>0 then demand[kind]=demand[kind]-take; outputs[kind]=n-take; used[kind]=(used[kind] or 0)+take; progress=true end
        end
        if not progress then
            local expandedOne=false
            for kind,n in pairs(demand) do if n>0 and Planner.Recipes[kind] then
                local upstream=Planner.Recipes[kind]
                if not machines[upstream.machine] then return false,'缺少'..title(kind)..' ×'..n..'，且网络无'..(upstream.machine=='cooker' and '自动烹饪台' or '组合台')..'。' end
                if expanded[kind] then return false,'配方依赖无法继续展开。' end
                expanded[kind]=true; demand[kind]=0
                for input,count in pairs(upstream.inputs) do demand[input]=(demand[input] or 0)+n*count end
                expandedOne=true; break
            end end
            if not expandedOne then break end
        end
    end
    for kind,n in pairs(demand) do if n>0 and not sources[kind] then
        local blocked=false
        for _,stack in ipairs(stacks) do for _,v in ipairs(stack.items) do if v.itemType==kind then blocked=true end end end
        return false,blocked and (title(kind)..' ×'..n..'被库存栈顶或预约阻挡，请整理对应库存。') or ('缺少'..title(kind)..' ×'..n..'，且无同网原料来源。')
    end end
    return true,'材料与设备可规划；按整网2件/秒逐件执行。',{demand=demand,used=used}
end
return Planner
