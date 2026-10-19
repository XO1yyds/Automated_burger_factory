-- Undirected unit-grid graph. Crossings/T joins share nodes; cables own no cargo.
---@class FactoryCableNetwork
---@field context table
---@field edges table<string,table>
---@field bindings table<string,string>
---@field revision integer
local Cable={}
Cable.__index=Cable
function Cable.Key(x,z) return math.floor(x+0.5)..":"..math.floor(z+0.5) end
function Cable.Point(key)
    local x,z=key:match("^(-?%d+):(-?%d+)$")
    return {x=tonumber(x),z=tonumber(z)}
end
local function edge(a,b) return a<b and a.."|"..b or b.."|"..a end
local function copy(t) local r={}; for k,v in pairs(t) do r[k]=v end; return r end
---@return FactoryCableNetwork
function Cable.New(context)
    return setmetatable({context=context,edges={},bindings={},revision=0},Cable)
end
function Cable.Supported(ep)
    return ep and (ep.source or ep.machine or ep.storage or (ep.terminal or ep.kind=="terminal")) and ep.area=="workshop"
end
function Cable:Anchor(ep) return Cable.Key(ep.x,ep.z) end
function Cable:Adjacency(edges,bindings)
    local graph={}
    local function node(k) graph[k]=graph[k] or {} end
    for _,e in pairs(edges or self.edges) do node(e.a); node(e.b); graph[e.a][e.b]=true; graph[e.b][e.a]=true end
    for id,k in pairs(bindings or self.bindings) do if self.context.resolve(id) then node(k) end end
    for _,ep in ipairs(self.context.endpoints()) do if (ep.terminal or ep.kind=="terminal") then node((bindings or self.bindings)[ep.id] or ("terminal@"..ep.id)) end end
    return graph
end
function Cable:Components(edges,bindings)
    bindings=bindings or self.bindings
    local graph=self:Adjacency(edges,bindings); local seen,components,byNode={},{},{}
    local roots={}; for k in pairs(graph) do table.insert(roots,k) end; table.sort(roots)
    for _,root in ipairs(roots) do if not seen[root] then
        local component={id=root,nodes={},endpoints={},terminals={}}; local queue={root}; seen[root]=true
        for _,k in ipairs(queue) do
            component.nodes[k]=true; byNode[k]=component
            for nextKey in pairs(graph[k]) do if not seen[nextKey] then seen[nextKey]=true; table.insert(queue,nextKey) end end
        end
        for _,ep in ipairs(self.context.endpoints()) do
            local k=bindings[ep.id] or ((ep.terminal or ep.kind=="terminal") and ("terminal@"..ep.id))
            if k and component.nodes[k] and Cable.Supported(ep) then
                table.insert(component.endpoints,ep)
                if (ep.terminal or ep.kind=="terminal") then table.insert(component.terminals,ep.id) end
            end
        end
        table.sort(component.endpoints,function(a,b) return a.id<b.id end)
        if #component.terminals==1 then component.id=component.terminals[1] end
        table.insert(components,component)
    end end
    return components,byNode
end
function Cable:For(id)
    local ep=self.context.resolve(id)
    if not ep then return nil end
    local key=self.bindings[id] or ((ep.terminal or ep.kind=="terminal") and ("terminal@"..ep.id))
    local _,nodes=self:Components()
    return key and nodes[key] or nil
end
function Cable:HasAttached(id)
    local k=self.bindings[id]
    if not k then return false end
    for _,e in pairs(self.edges) do if e.a==k or e.b==k then return true end end
    return false
end
function Cable:BindPick(x,z)
    local best,score=nil,math.huge
    for _,ep in ipairs(self.context.endpoints()) do if Cable.Supported(ep) then
        local d=(ep.x-x)^2+(ep.z-z)^2
        if d<score and math.abs(x-ep.x)<=ep.width/2+0.3 and math.abs(z-ep.z)<=ep.depth/2+0.3 then best,score=ep,d end
    end end
    if best then return {key=self:Anchor(best),id=best.id} end
    local k=Cable.Key(x,z)
    if self:Adjacency()[k] then return {key=k} end
    return nil
end
function Cable.Route(points,verticalFirst)
    local result={}
    for index=2,#points do
        local a,b=points[index-1],points[index]
        local x,z=math.floor(a.x+0.5),math.floor(a.z+0.5)
        local tx,tz=math.floor(b.x+0.5),math.floor(b.z+0.5)
        local function axis(vertical)
            while (vertical and z~=tz) or (not vertical and x~=tx) do
                local old=Cable.Key(x,z)
                if vertical then z=z+(tz>z and 1 or -1) else x=x+(tx>x and 1 or -1) end
                table.insert(result,{a=old,b=Cable.Key(x,z)})
            end
        end
        axis(verticalFirst); axis(not verticalFirst)
    end
    return result
end
function Cable:Plan(start,finish,points,verticalFirst)
    if not start or not finish then return nil,"请选择支持的建筑或已有电缆网格接点。" end
    if start.key==finish.key or (start.id and start.id==finish.id) then return nil,"不能自连或创建零长度电缆。" end
    local edges,bindings=copy(self.edges),copy(self.bindings)
    local additions=Cable.Route(points,verticalFirst)
    for _,e in ipairs(additions) do
        local a,b=Cable.Point(e.a),Cable.Point(e.b)
        if self.context.valid and (not self.context.valid(a.x,a.z) or not self.context.valid(b.x,b.z)) then return {valid=false,reason="电缆超出车间范围。",segments=additions} end
        edges[edge(e.a,e.b)]=e
    end
    if start.id then bindings[start.id]=start.key end
    if finish.id then bindings[finish.id]=finish.key end
    local components=self:Components(edges,bindings)
    for _,c in ipairs(components) do if #c.terminals>1 then return {valid=false,reason="同一网络不能有多个下单组件。",segments=additions} end end
    return {valid=true,reason="可连接；交点自动合并为同一网络。",edges=edges,bindings=bindings,segments=additions}
end
function Cable:Commit(start,finish,points,verticalFirst)
    local plan,message=self:Plan(start,finish,points,verticalFirst)
    if not plan or not plan.valid then return false,message or plan.reason end
    local added=0; for key in pairs(plan.edges) do if not self.edges[key] then added=added+1 end end
    if self.context.purchase then local ok,reason=self.context.purchase('cable',added); if not ok then return false,reason end end
    self.edges,self.bindings=plan.edges,plan.bindings; self.revision=self.revision+1
    return true,"电缆已连接；继续选择起点。"
end
function Cable:NearestEdge(x,z)
    local best,score=nil,0.4^2
    for k,e in pairs(self.edges) do
        local a,b=Cable.Point(e.a),Cable.Point(e.b)
        local px=math.max(math.min(a.x,b.x),math.min(math.max(a.x,b.x),x))
        local pz=math.max(math.min(a.z,b.z),math.min(math.max(a.z,b.z),z))
        local d=(px-x)^2+(pz-z)^2
        if d<=score then best,score=k,d end
    end
    return best
end
function Cable:Segment(key)
    local initial=self.edges[key]; if not initial then return {} end
    local graph=self:Adjacency(); local anchors={}; for _,k in pairs(self.bindings) do anchors[k]=true end
    local result={key}; local a,b=Cable.Point(initial.a),Cable.Point(initial.b)
    local horizontal=a.z==b.z
    for _,side in ipairs({{initial.a,initial.b},{initial.b,initial.a}}) do
        local current,previous=side[1],side[2]
        while not anchors[current] do
            local nextKey,count=nil,0
            for k in pairs(graph[current] or {}) do count=count+1; if k~=previous then nextKey=k end end
            if count~=2 or not nextKey then break end
            local p,q=Cable.Point(current),Cable.Point(nextKey)
            if (horizontal and p.z~=q.z) or (not horizontal and p.x~=q.x) then break end
            table.insert(result,edge(current,nextKey)); previous,current=current,nextKey
        end
    end
    return result
end
function Cable:RemoveSegment(key)
    local removed=self:Segment(key)
    for _,k in ipairs(removed) do self.edges[k]=nil end
    if self.context.recover then self.context.recover('cable',#removed) end
    self.revision=self.revision+1
    return #removed>0,"已删除选中连接段；源端物品不受影响。"
end
function Cable:RemoveBuilding(id)
    local k=self.bindings[id]; self.bindings[id]=nil
    local removed=0
    if k then for e,v in pairs(self.edges) do if v.a==k or v.b==k then self.edges[e]=nil; removed=removed+1 end end end
    if self.context.recover then self.context.recover('cable',removed) end
    self.revision=self.revision+1
end
return Cable
