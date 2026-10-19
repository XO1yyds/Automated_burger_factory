local Cable=require('Factory/CableNetwork')
local Service=require('Factory/OrderAutomation')
local Definitions=require('Factory/Items').Definitions
local Area=require('Factory/AutomationArea')
---@class FactoryOrderAutomationControl
---@field context table
---@field cables FactoryCableNetwork
---@field service FactoryOrderAutomation
---@field reason string
---@field mode string
---@field tab string
---@field quantity integer
---@field cursor table
---@field waypoints table[]
---@field selected integer
---@field verticalFirst boolean
---@field page integer
---@field visualSignature string
---@field terminal string?
---@field product FactoryItemType?
---@field target string?
---@field start table?
---@field finish table?
---@field drag integer?
---@field deleteEdge string?
---@field visual Node?
---@field visualVisible boolean?
---@field managing boolean
---@field details boolean
---@field choosingTarget boolean
---@field showHistory boolean
---@field inventoryKind FactoryItemType?
local Control={}
Control.__index=Control
local function action(text,command,value,disabled) return {text=text,command=command,value=value,disabled=disabled} end
local function point(x,z) return {x=math.floor(x+0.5),z=math.floor(z+0.5)} end
---@return FactoryOrderAutomationControl
function Control.New(context)
    local self=setmetatable({context=context,mode='idle',tab='products',quantity=1,cursor={x=-40,z=0},waypoints={},managing=false,details=false,choosingTarget=false,showHistory=false,
        selected=0,verticalFirst=false,page=1,visualSignature='',reason=''},Control)
    self.cables=Cable.New({resolve=context.resolve,endpoints=context.endpoints,valid=function(x,z) return Area.At(x,z)=='workshop' end})
    self.service=Service.New(self.cables,{resolve=context.resolve,endpoints=context.endpoints})
    for _,ep in ipairs(context.endpoints()) do if ep.terminal and ep.storage then self.service:ObserveStorage(ep.id,ep.storage) end end
    return self
end
function Control:Sample()
    local base=self.context.resolve('ws_inventory')
    if not base or not base.terminal then base=self.context.resolve('ws_terminal') end
    if not base then return end
    for _,id in ipairs({'ws_raw','ws_bun','ws_lettuce','ws_cooker','ws_assembler','ws_inventory'}) do
        local ep=self.context.resolve(id)
        if ep and id~=base.id then local a={id=base.id,key=self.cables:Anchor(base)}; local b={id=id,key=self.cables:Anchor(ep)}
            assert(self.cables:Commit(a,b,{Cable.Point(a.key),Cable.Point(b.key)},false))
        end
    end
end
function Control:Close() self.mode='idle'; self.terminal=nil; self.start=nil; self.finish=nil; self.waypoints={}; self.selected=0; self.drag=nil; self.managing=false; self.deleteEdge=nil end
function Control:ManageCables()
    self:Close(); self.managing=true; local p=self.context.player.position; self:SetCursor(p.x,p.z)
end
function Control:PickManaged(x,z)
    self.deleteEdge=self.cables:NearestEdge(x,z)
    return self.deleteEdge~=nil
end
function Control:DeleteManaged()
    local ok,message=self.cables:RemoveSegment(self.deleteEdge)
    self.deleteEdge=nil
    return ok,message
end
function Control:OpenEditor()
    if self.context.area()~='workshop' then return false,'请先进入自动化车间。' end
    self:Close(); self.mode='source'; local p=self.context.player.position; self.cursor=point(p.x,p.z)
    return true,'选择建筑顶部或已有电缆网格点作为起点。'
end
function Control:OpenTerminal(id)
    self:Close(); self.terminal=id; self.tab='products'; self.product=nil; self.inventoryKind=nil; self.page=1; self.details=false; self.choosingTarget=false; self.showHistory=false
    return true,'已打开下单组件；生产与日计时继续。'
end
function Control:Back(escape)
    if self.terminal then
        if self.inventoryKind then self.inventoryKind=nil elseif self.choosingTarget then self.choosingTarget=false elseif self.product then self.product=nil; self.details=false else self.terminal=nil end
        return self.terminal~=nil
    end
    if escape then self:Close(); return false end
    if self.mode=='adjust' then self.finish=nil; self.mode='destination'; self.selected=0; self.waypoints={}
    elseif self.mode=='destination' then self.start=nil; self.mode='source'
    elseif self.mode=='delete' and self.deleteEdge then self.deleteEdge=nil
    else self:Close(); return false end
    return true
end
function Control:SetCursor(x,z)
    local w,d=Area.Size('workshop'); local center=Area.WorkshopCenter
    self.cursor=point(math.max(center-w/2,math.min(center+w/2,x)),math.max(-d/2,math.min(d/2,z)))
end
function Control:Points()
    if not self.start then return {} end
    local list={Cable.Point(self.start.key)}
    for _,p in ipairs(self.waypoints) do table.insert(list,p) end
    table.insert(list,self.finish and Cable.Point(self.finish.key) or self.cursor)
    return list
end
function Control:Preview()
    if not self.start then return nil end
    local finish=self.finish or {key=Cable.Key(self.cursor.x,self.cursor.z)}
    local plan,message=self.cables:Plan(self.start,finish,self:Points(),self.verticalFirst)
    return plan or {valid=false,reason=message,segments=Cable.Route(self:Points(),self.verticalFirst)}
end
function Control:Pick(x,z)
    self:SetCursor(x,z)
    if self.mode=='delete' then self.deleteEdge=self.cables:NearestEdge(x,z); return true,self.deleteEdge and '选中连接段；点击删除连接。' or '当前位置没有可删除电缆。' end
    if self.mode=='adjust' then
        local nearest,distance=nil,0.8^2
        for i,p in ipairs(self.waypoints) do local d=(p.x-x)^2+(p.z-z)^2; if d<distance then nearest,distance=i,d end end
        self.selected=nearest or 0; return true,nearest and '已选路径节点，可拖动或WASD逐格移动。' or '移动光标后可添加拐点。'
    end
    local pick=self.cables:BindPick(x,z)
    if not pick then return false,'请选择支持的建筑或已有电缆接点。' end
    if self.mode=='source' then self.start=pick; self.mode='destination'; return true,'起点已选；预览持续连接当前位置。' end
    if self.mode=='destination' then
        self.finish=pick; self.waypoints={}; self.selected=0; self.mode='adjust'
        return true,'调整路径后，请选中确认连接按钮。'
    end
    return false,''
end
function Control:Pointer(phase,p)
    if self.mode=='idle' then return end
    if phase=='down' and self.mode=='adjust' then
        self:Pick(p.x,p.z)
        if self.selected>0 then self.drag=self.selected end
    elseif phase=='move' then
        -- In adjustment, a clicked grid location stays selected while the
        -- pointer travels to the Add button. Only an owned drag moves it.
        if self.mode~='adjust' or self.drag then self:SetCursor(p.x,p.z) end
        if self.drag then self.waypoints[self.drag]=point(self.cursor.x,self.cursor.z) end
    elseif phase=='up' or phase=='cancel' then self.drag=nil end
end
function Control:Keyboard(dx,dz,confirm)
    if self.terminal then return end
    if dx~=0 or dz~=0 then
        if self.mode=='adjust' and self.selected>0 then
            local p=self.waypoints[self.selected]; self:SetCursor(p.x+dx,p.z+dz); self.waypoints[self.selected]=point(self.cursor.x,self.cursor.z)
        else self:SetCursor(self.cursor.x+dx,self.cursor.z+dz) end
    end
    if confirm then return self:Pick(self.cursor.x,self.cursor.z) end
end
function Control:Command(command,value)
    if command=='cableTool' then self:Close(); self.mode=value; return true,'电缆工具已切换。'
    elseif command=='cableTurn' then self.verticalFirst=not self.verticalFirst; return true,'直角走线顺序已切换。'
    elseif command=='cableAdd' and self.mode=='adjust' then
        table.insert(self.waypoints,point(self.cursor.x,self.cursor.z)); self.selected=#self.waypoints; return true,'已添加拐点；可拖动或WASD微调。'
    elseif command=='cableRemovePoint' and self.selected>0 then table.remove(self.waypoints,self.selected); self.selected=0; return true,'已移除选中拐点。'
    elseif command=='cableConfirm' and self.mode=='adjust' then
        local ok,message=self.cables:Commit(self.start,self.finish,self:Points(),self.verticalFirst)
        if ok then self:Close(); self.mode='source' end
        return ok,message
    elseif command=='cableDelete' and self.mode=='delete' then
        local ok,message=self.cables:RemoveSegment(self.deleteEdge); self.deleteEdge=nil; return ok,message
    elseif command=='terminalDetails' then self.details=not self.details; return true,''
    elseif command=='terminalChooseTarget' then self.choosingTarget=not self.choosingTarget; self.page=1; return true,''
    elseif command=='terminalHistory' then self.showHistory=not self.showHistory; return true,''
    elseif command=='terminalTab' then self.tab=value; self.product=nil; self.inventoryKind=nil; self.page=1; self.details=false; self.choosingTarget=false; return true,''
    elseif command=='terminalInventoryKind' then self.inventoryKind=value; return true,''
    elseif command=='terminalWithdraw' and self.inventoryKind then
        local ep=self.context.resolve(self.terminal)
        if not ep or not ep.terminal or not ep.storage then return false,'下单终端已失效。' end
        return ep.storage:Withdraw(self.inventoryKind,self.context.items,self.context.player.position,self.context.facing())
    elseif command=='terminalPage' then self.page=math.max(1,self.page+value); return true,''
    elseif command=='terminalProduct' then self.product=value; self.quantity=1; self.details=false; self.choosingTarget=false; self.target=self:Targets()[1] and self:Targets()[1].id; return true,''
    elseif command=='terminalQuantity' then self.quantity=math.max(1,math.min(99,self.quantity+value)); return true,''
    elseif command=='terminalTarget' then self.target=value; self.choosingTarget=false; return true,''
    elseif command=='terminalSubmit' and self.product then
        local ok,message=self.service:Enqueue(self.terminal,self.product,self.quantity,self.target)
        if ok then self.product=nil; self.tab='tasks' end; return ok,message
    elseif command=='terminalCancel' then return self.service:Cancel(self.terminal,value) end
    return false,''
end
---@return FactoryConveyorEndpoint[]
function Control:Targets()
    local host=self.context.resolve(self.terminal)
    if host and host.terminal and host.storage then return {host} end
    local list={}
    for _,ep in ipairs(self.service:Endpoints(self.terminal)) do if ep.storage then table.insert(list,ep) end end
    table.sort(list,function(a,b) if (a.kind=='storage')~=(b.kind=='storage') then return a.kind=='storage' end; return a.id<b.id end)
    return list
end
---@return table?
function Control:Modal() return require('Factory/OrderTerminalModel').Build(self) end
function Control:BuildModel(model)
    model.back='返回建筑'; model.title='电缆编辑 · '..({source='选择起点',destination='选择终点',adjust='调整路径',delete='删除连接段'})[self.mode]
    model.reason=self.reason
    if self.mode=='source' then
        model.reason='金框插头=已接线，灰框=未接线；点选建筑或电缆，WASD/F选取。'
        model.actions={action('删除工具','cableTool','delete')}
    elseif self.mode=='destination' then
        model.reason='预览连接起点和光标；点选目标建筑/线段接点。'
        model.actions={action('切换直角走线','cableTurn')}
    elseif self.mode=='adjust' then
        local plan=self:Preview(); model.reason=plan and plan.reason or '选择拐点可拖动；光标位置可添加拐点。'
        model.actions={action('添加拐点','cableAdd'),action('移除拐点','cableRemovePoint',nil,self.selected==0),action('切换走线','cableTurn'),action('确认连接','cableConfirm',nil,not plan or not plan.valid)}
    elseif self.mode=='delete' then
        model.reason='点选直线连接段，再点击删除；分支保留。'
        model.actions={action('布置工具','cableTool','source'),action('删除连接','cableDelete',nil,self.deleteEdge==nil)}
    end
end
function Control:RefreshWorld(visible)
    local plan=self:Preview(); local signature=self.cables.revision..':'..self.mode..':'..self.cursor.x..':'..self.cursor.z..':'..tostring(self.selected)..':'..tostring(self.deleteEdge)..':'..tostring(self.verticalFirst)
    for _,p in ipairs(self.waypoints) do signature=signature..':'..p.x..','..p.z end
    signature=signature..tostring(self.start and self.start.key)..tostring(self.start and self.start.id)..tostring(self.finish and self.finish.key)..tostring(self.finish and self.finish.id)..tostring(self.managing)
    if visible and signature~=self.visualSignature then
        if self.visual then self.visual:Remove() end
        self.visual=self.context.scene:CreateChild('CeilingCableNetwork'); self.visualSignature=signature; self.visualVisible=nil
        local function box(name,x,z,w,d,color,y)
            self.context.makeBox(self.visual,name,Vector3(x,y or 2.4,z),Vector3(w,0.04,d),color,false)
        end
        local marked={}; if self.deleteEdge then for _,k in ipairs(self.cables:Segment(self.deleteEdge)) do marked[k]=true end end
        local function draw(e,color)
            local a,b=Cable.Point(e.a),Cable.Point(e.b)
            box('Cable', (a.x+b.x)/2,(a.z+b.z)/2,math.max(0.08,math.abs(a.x-b.x)),math.max(0.08,math.abs(a.z-b.z)),color)
        end
        for k,e in pairs(self.cables.edges) do draw(e,marked[k] and Color(1,0.3,0.2) or Color(0.35,0.78,1)) end
        if plan then for _,e in ipairs(plan.segments or {}) do draw(e,plan.valid and Color(0.2,1,0.5) or Color(1,0.2,0.2)) end end
        -- A cable merely passing over a machine is not a connection. Only actual
        -- bound anchors with an incident edge receive the large plug marker.
        for _,ep in ipairs(self.context.endpoints()) do if Cable.Supported(ep) then
            local connected=self.cables:HasAttached(ep.id)
            local selected=(self.start and self.start.id==ep.id) or (self.finish and self.finish.id==ep.id)
            if connected or not self.managing then
                local p=Cable.Point(self.cables.bindings[ep.id] or self.cables:Anchor(ep))
                local size=connected and 0.68 or 0.34
                local thickness=connected and 0.10 or 0.045
                local rim=selected and Color(1,1,1) or connected and Color(1,0.72,0.12) or Color(0.50,0.55,0.60)
                if connected then
                    box('ConnectedSocketBack',p.x,p.z,0.84,0.84,Color(0.035,0.045,0.06),2.42)
                    box('DeviceSocketFoot',p.x,p.z,0.42,0.42,Color(1,0.72,0.12),1.06)
                    local px,pz=assert(p.x),assert(p.z)
                    self.context.makeBox(self.visual,'DeviceCableDrop',Vector3(px,1.74,pz),Vector3(0.055,1.36,0.055),Color(1,0.72,0.12),false)
                end
                for _,edge in ipairs({{0,-size/2,size,thickness},{0,size/2,size,thickness},{-size/2,0,thickness,size},{size/2,0,thickness,size}}) do
                    box(connected and 'ConnectedSocketRim' or 'EmptySocketRim',p.x+edge[1],p.z+edge[2],edge[3],edge[4],rim,2.47)
                end
                if connected then
                    box('ConnectedPlugCore',p.x,p.z,0.28,0.24,Color(0.12,0.92,1),2.51)
                    for _,dx in ipairs({-0.08,0.08}) do box('ConnectedPlugPin',p.x+dx,p.z+0.14,0.055,0.14,Color(1,1,1),2.54) end
                end
            end
        end end
        for i,p in ipairs(self.waypoints) do box('CableHandle',p.x,p.z,0.35,0.35,i==self.selected and Color(1,1,1) or Color(1,0.65,0.2),2.47) end
        box('CableCursor',self.cursor.x,self.cursor.z,0.45,0.45,Color(1,1,1),2.5)
    end
    -- Component effective state only checks its immediate node in this engine.
    -- Disabling the container alone leaves child StaticModels on screen.
    if self.visual and self.visualVisible~=visible then self.visual:SetDeepEnabled(visible); self.visualVisible=visible end
end
function Control:Stop()
    self.service:Stop(); if self.visual then self.visual:Remove(); self.visual=nil end
end
return Control
