-- One state owner for desktop and mobile UI. Gameplay services remain authoritative.
local UI=require('urhox-libs/UI')
local State=require('Factory/UIState')
local Projection=require('Factory/OrthographicView')
local Prefs=require('Factory/UIPreferences')
local Touch=require('Factory/TouchInput')
local Buildings=require('Factory/Buildings')
local Items=require('Factory/Items')
local World=require('Factory/ConveyorWorld')
local Network=require('Factory/ConveyorNetwork')
local Grid=require('Factory/ConveyorGeometry')
local Area=require('Factory/AutomationArea')
local CampaignUI=require('Factory/CampaignRuntime')
local Days=require('Factory/DayConfig')
local Recovery=require('Factory/CampaignRecovery')
---@class FactoryUIController
---@field context table
---@field view FactoryInterface
---@field touch table
---@field losses string[]
---@field focusActions table[]
---@field events table[]
---@field selected FactoryStation?
---@field hover table?
---@field cameraSaved table?
---@field drag table?
local Controller={}
Controller.__index=Controller

local function name(kind) return kind and Items.Definitions[kind].name or '空' end
local function action(text,command,value,disabled) return {text=text,command=command,value=value,disabled=disabled} end
local function key(code) return input:GetKeyPress(code) end

---@return FactoryUIController
function Controller.New(context,view)
    local self=setmetatable({context=context,view=view,touch=Touch.New(),preferences=Prefs.Load(),category=1,
        kind='cooker',ordersOpen=false,events={},elapsed=0,toastUntil=0,losses={},focus=0,selectedAt=0,
        holdingInteraction=false,suppressClick=false,overlay=nil,selected=nil,hover=nil},Controller) --[[@as FactoryUIController]]
    view.onWorld=function(phase,e) self:QueuePointer(phase,e) end
    view.onJoystick=function(phase,e,rect) self:Joystick(phase,e,rect) end
    self:ApplyPreferences()
    return self
end

function Controller:ApplyPreferences()
    local ratio=self.preferences.uiScale
    UI.SetScale(function() return UI.Scale.DEFAULT()*ratio end)
end

function Controller:SavePreferences()
    self.preferences=State.SanitizePreferences(self.preferences)
    self:ApplyPreferences()
    if not Prefs.Save(self.preferences) then self:Notify('本机设置写入不可用；本次运行仍保留设置。') end
end

function Controller:Phase()
    local c=self.context.get()
    if not c.loop:IsRunning() then return self.overlay or c.loop.state end
    if self.overlay then return self.overlay end
    if c.loop.briefing then return 'briefing' end
    if c.cashier then return 'cashier' end
    if c.components and c.components.mode then return 'attach' end
    if c.automation and c.automation.terminal then return 'terminal' end
    if c.automation and c.automation.mode~='idle' then return 'cable' end
    return State.Phase{loop=c.loop.state,ordersOpen=self.ordersOpen,buffer=c.logistics.bufferId,
        conveyor=c.logistics.builder.mode,build=c.buildings.mode,selected=self.selected or c.logistics.selectedBelt or (c.automation and c.automation.managing and c.automation.deleteEdge)}
end

function Controller:Release()
    self.inspectId=nil
    self.touch:Reset(); self.events={}; self.holdingInteraction=false; self.suppressClick=false; self.interactionValid=false
    local b=self.context.get().logistics.builder
    b:EndEdit(); self.drag=nil
    local automation=self.context.get().automation; if automation then automation.drag=nil end
end

function Controller:Notify(message)
    if not message or message=='' then return end
    local loss=message:find('实际删除：',1,true)~=nil
    if loss then table.insert(self.losses,message) end
    if self.toastLoss and self.elapsed<self.toastUntil and not loss then return end
    self.toast,self.toastLoss=message,loss
    self.toastUntil=self.elapsed+(loss and 5 or 3)
end

function Controller:ConfirmDialog(command,title)
    self:Release(); self.confirmCommand=command; self.overlay='confirm'; self.focus=0
    self.confirmTitle=title; self.confirmDetails=nil
end

function Controller:Back(escape)
    local c=self.context.get(); local phase=self:Phase(); local build,b=c.buildings,c.logistics.builder
    self:Release(); self.focus=0
    if self.overlay then if self.overlay=='lesson' or self.confirmCommand=='v06RecoverLoss' then c.loop.teaching=false end; self.overlay=nil; return end
    if c.campaign and phase=='briefing' then c.loop.briefing=false; return end
    if c.campaign and phase=='title' then return end
    if phase=='paused' then c.loop:Resume(); return end
    if phase=='settlement' or phase=='complete' then return end
    if phase=='attach' then
        if c.components.selected and not escape then c.components.selected=nil
        else c.components.mode,c.components.selected=nil,nil; build:Menu() end
        return
    end
    if phase=='terminal' then c.automation:Back(escape); return end
    if phase=='cable' then if not c.automation:Back(escape) then build:Menu() end; return end
    if phase=='cashier' then self.context.cashier(false); return end
    if phase=='orders' then self.ordersOpen=false; return end
    if phase=='buffer' then c.logistics.bufferId,c.logistics.selectedToken=nil,nil; return end
    if escape and State.IsBuild(phase) then
        if c.automation then c.automation:Close() end
        b:Cancel(); self.selected=nil; c.logistics.selectedBelt=nil
        if phase=='menu' then build:Cancel() else build:Menu() end
    elseif b.mode~='idle' then b:Back(); if b.mode=='idle' then build:Menu() end
    elseif phase=='selected' then self.selected=nil; c.logistics.selectedBelt=nil; if c.automation then c.automation.deleteEdge=nil end
    elseif phase=='move' then
        local selected=self.selected; build:Manage(); self.selected=selected
    elseif phase=='preview' or phase=='manage' then build:Menu(); self.selected=nil; if c.automation then c.automation:Close() end
    elseif phase=='menu' then build:Cancel()
    else c.loop:Pause() end
end

function Controller:OpenBuild()
    local c=self.context.get()
    if c.area~='workshop' then self:Notify('仅自动化车间开放建造；店内手工生产仍可使用。'); return end
    self:Release(); self.category,self.kind=1,'cooker'; self.selected=nil; self.ordersOpen=false
    c.logistics:Cancel(); if c.automation then c.automation:Close() end; self.context.cashier(false); c.buildings:Menu()
    if c.components then c.components.mode,c.components.selected=nil,nil end
end

function Controller:SelectManaged(station,belt)
    local c=self.context.get()
    self.selected=station; c.logistics.selectedBelt=belt; self.selectedAt=self.elapsed; self.focus=0
end

function Controller:Command(command,value)
    local c=self.context.get(); local phase=self:Phase(); local build,control=c.buildings,c.logistics
    local b=control.builder
    if c.runtime and c.runtime:Command(command,value,self) then return true end
    if command=='interactionHold' then
        self.holdingInteraction=value==true and phase=='normal'
        if value then self.interactionValid=phase=='normal'; self.suppressClick=c.target~=nil and c.target.id=='grill' and c.manual.grillItem=='raw_beef' and not c.items.held end
        return true
    elseif command=='interactionCancel' then self.holdingInteraction=false; self.suppressClick=false; self.interactionValid=false; return true
    elseif command=='back' then self:Back(false); return true
    elseif command=='pause' then
        if c.loop:IsRunning() then self:Release(); self.ordersOpen=false; c.loop:Pause() end
        return true
    elseif command=='resume' then self:Release(); self.overlay=nil; c.loop:Resume(); return true
    elseif command=='statistics' or command=='settings' then
        if c.loop.state=='paused' then self.overlay=command; self.focus=0 end; return true
    elseif command=='pauseEnd' then
        if c.loop.state=='paused' then self:ConfirmDialog('endDay','提前结束当天？未完成订单将清除。') end; return true
    elseif command=='restart' then
        if c.loop.state=='complete' then self:ConfirmDialog('restart','重新开始？本局进度不会保存。') end; return true
    elseif command=='exitGame' then
        if c.loop.state=='paused' or c.loop.state=='complete' then self.confirmParent=c.loop.state; self:ConfirmDialog('exitGame','退出游戏？再次进入将重新开始，无进度存档。') end; return true
    elseif command=='confirmYes' then
        if self.overlay~='confirm' then return true end
        local cmd=self.confirmCommand; self.overlay=nil; self:Release()
        if cmd=='endDay' then local _,message=c.loop:EndDay('pause'); self:Notify(message)
        elseif cmd=='restart' then self.context.restart()
        elseif cmd=='exitGame' then engine:Exit()
        elseif cmd=='deleteTerminal' and self.selected then
            build.selected=self.selected; local ok,message=build:DeleteSelected(c.player.position); self:Notify(message); if ok then self.selected=nil end end
        if cmd=='unbindComponent' and self.selected then local _,message=c.components:Unbind(self.selected.id); self:Notify(message) end
        return true
    elseif command=='nextDay' then c.loop:Continue(); self.overlay=nil; self:Release(); return true
    elseif command=='preference' and self.overlay=='settings' then
        if value=='display' then local nextValue={both='keyboard',keyboard='touch',touch='both'}; self.preferences.display=nextValue[self.preferences.display]
        elseif value=='joystick' then self.preferences.joystick=self.preferences.joystick=='fixed' and 'floating' or 'fixed'
        elseif value=='scaleDown' then self.preferences.uiScale=self.preferences.uiScale-0.1
        elseif value=='scaleUp' then self.preferences.uiScale=self.preferences.uiScale+0.1
        elseif value=='sensitivityDown' then self.preferences.sensitivity=self.preferences.sensitivity-0.1
        elseif value=='sensitivityUp' then self.preferences.sensitivity=self.preferences.sensitivity+0.1
        elseif value=='tutorials' then self.preferences.tutorials={}
        elseif value=='defaults' then self.preferences=State.DefaultPreferences() end
        self:Release(); self:SavePreferences(); return true
    end
    if not c.loop:IsRunning() then return true end
    if c.automation and (phase=='cable' or phase=='terminal') and (command:sub(1,5)=='cable' or command:sub(1,8)=='terminal') then
        local _,message=c.automation:Command(command,value); self:Notify(message); self.focus=0; return true
    end
    if command=='tutorialClose' then self.preferences.tutorials[self:TutorialKey(phase)]=true; Prefs.Save(self.preferences); return true
    elseif command=='ordersToggle' then
        if phase=='normal' or phase=='orders' then self.ordersOpen=not self.ordersOpen; self:Release() end; return true
    elseif command=='selectRow' then
        if phase=='orders' or phase=='cashier' then local order=c.orders.active[value]; if order then c.orders:Select(order.id) end end; return true
    elseif command=='deliver' then
        if phase=='cashier' then local _,message=c.orders:Deliver(); self:Notify(message) end; return true
    elseif command=='cashierEnd' then
        if phase=='cashier' then local ok,message=c.loop:EndDay('cashier'); self:Notify(message); if ok then self.context.cashier(false) end end; return true
    elseif command=='interactUI' then
        if phase=='normal' and self.interactionValid and not self.suppressClick then self.context.resolve(); local _,message=self.context.interact(); self:Notify(message) end
        self.suppressClick=false; self.interactionValid=false; return true
    elseif command=='dropUI' then
        if phase=='normal' then local _,message=c.items:Drop(c.player.position,c.facing); self:Notify(message) end; return true
    elseif command=='openBuild' then if phase=='normal' then self:OpenBuild() end; return true
    elseif command=='category' and phase=='menu' then
        self.category=value; self.kind=State.Kinds[value][1]; self.focus=0; return true
    elseif command=='selectKind' and phase=='menu' then self.kind=value; self.focus=0; return true
    elseif command=='enterKind' and phase=='menu' then
        if c.campaign and not c.campaign:Unlocked(self.kind) then self:Notify('第'..(Days.UnlockDay[self.kind] or '?')..'天开放。'); return true end
        self:Release()
        if self.kind=='terminal' or self.kind=='delivery_component' then
            c.automation:Close(); control:Cancel(); build:Manage()
            c.components.mode=self.kind=='terminal' and 'order' or 'delivery'; c.components.selected=nil
        elseif self.kind=='conveyor' then control:Open()
        elseif self.kind=='cable' then build:Cancel(); control:Cancel(); local _,message=c.automation:OpenEditor(); self:Notify(message)
        elseif self.kind=='manage' then self.selected=nil; c.automation:Close(); build:Manage()
        else build:Choose(self.kind,c.player.position,c.facing) end
        return true
    elseif command=='confirmAttachment' and phase=='attach' then
        local _,message=c.components:Bind(c.components.selected,c.components.mode); self:Notify(message); self.focus=0; return true
    elseif command=='unbindComponent' and phase=='selected' and self.selected and self.selected.component then
        if self.selected.component=='order' and c.automation.service:HasTasks(self.selected.id) then self:ConfirmDialog('unbindComponent','卸下下单组件？将取消任务，保留宿主与库存，已有加工安全收尾。')
        else local _,message=c.components:Unbind(self.selected.id); self:Notify(message) end; return true
    elseif (command=='manageCables' or command=='manageDevices') and (phase=='manage' or phase=='selected') then
        self:Release(); self.selected=nil; control.selectedBelt=nil; self.focus=0
        if command=='manageCables' then c.automation:ManageCables() else c.automation:Close() end
        build:Manage(); return true
    elseif command=='buildMenu' and State.IsBuild(phase) then b:Cancel(); c.automation:Close(); if c.components then c.components.mode,c.components.selected=nil,nil end; self.selected=nil; build:Menu(); self:Release(); return true
    elseif command=='rotateUI' and (phase=='preview' or phase=='move') then build:Rotate(); build.confirmFocus=false; return true
    elseif command=='confirmBuild' and (phase=='preview' or phase=='move') then
        build.confirmFocus=true; local ok,message=build:Confirm(c.player.position); self:Notify(message)
        if ok then self.selected=nil; build.previewPinned=true end; self.focus=0; return true
    elseif (command=='moveManaged' or command=='rotateManaged') and phase=='selected' and self.selected then
        local ok,message=build:BeginMove(self.selected,c.player.position)
        if ok and command=='rotateManaged' then build:Rotate() end
        if ok then build.previewPinned=true else self:Notify(message) end
        self:Release(); return true
    elseif (command=='deleteManaged' or command=='deleteManagedConfirmed') and phase=='selected' then
        if self.elapsed-self.selectedAt<0.5 or (self.deleteUntil or 0)>self.elapsed then return true end
        if c.campaign and command=='deleteManaged' and not c.automation.managing then
            local loss=Recovery.Forecast(c,self.selected,control.selectedBelt)
            if loss~='' then
                c.loop.teaching=true; self:ConfirmDialog('v06RecoverLoss','回收可能造成物品损失')
                self.confirmDetails='将实际删除：'..loss..'。\n取消可保留全部内容；确认后回收建筑，其他物品按队列落地。'
                return true
            end
        end
        if self.selected and (self.selected.buildingKind=='terminal' or self.selected.component=='order') and c.automation.service:HasTasks(self.selected.id) then
            self:ConfirmDialog('deleteTerminal','拆除下单组件？将取消该组件的生产任务，已开始加工安全收尾。'); return true end
        if c.automation.managing then local _,message=c.automation:DeleteManaged(); self:Notify(message)
        elseif control.selectedBelt then control:DeleteBelt()
        elseif self.selected then build.selected=self.selected; local _,message=build:DeleteSelected(c.player.position); self:Notify(message) end
        self.selected=nil; self.deleteUntil=self.elapsed+0.5; return true
    elseif command=='bufferConfirm' and phase=='buffer' then control:ConfirmBuffer(); return true
    elseif command=='reverseUI' and phase=='adjust' then local _,message=b:Reverse(); self:Notify(message); return true
    elseif command=='confirmBelt' and phase=='adjust' then
        b.focus,b.button='buttons',1; local _,message=b:Confirm(); self:Notify(message); self.focus=0; return true

    end
    return false
end

function Controller:TutorialKey(phase)
    if phase=='normal' then return 'normal' end
    if phase=='preview' then return 'preview' end
    if phase=='source' or phase=='destination' or phase=='adjust' then return 'adjust' end
    return ''
end

function Controller:Keyboard()
    local c=self.context.get(); local phase=self:Phase(); local build,b=c.buildings,c.logistics.builder
    if key(KEY_ESCAPE) then self:Back(true); return true end
    if input:GetMouseButtonPress(MOUSEB_RIGHT) then
        if phase~='normal' then self:Back(false); return true end
    end
    if key(KEY_B) and phase=='normal' then self:OpenBuild(); return true end
    if key(KEY_TAB) then
        self.focus=self.focus%math.max(1,#(self.focusActions or {}))+1
        if b.editing then b:EndEdit() end
        return true
    end
    if (key(KEY_F) or key(KEY_RETURN)) and self.focus>0 then
        local actions=self.focusActions or {}
        local a=actions[self.focus]
        if a and not a.disabled then self:Command(a.command,a.value) end
        return true
    end
    local dx=((key(KEY_D) or key(KEY_RIGHT)) and 1 or 0)-((key(KEY_A) or key(KEY_LEFT)) and 1 or 0)
    local dz=((key(KEY_W) or key(KEY_UP)) and 1 or 0)-((key(KEY_S) or key(KEY_DOWN)) and 1 or 0)
    if not c.loop:IsRunning() or phase=='briefing' or self.overlay then
        if dx~=0 or dz~=0 then self.focus=(self.focus-1+(dx-dz))%math.max(1,#(self.focusActions or {}))+1 end
        return true
    end
    if phase=='terminal' then
        if dx~=0 or dz~=0 then self.focus=(self.focus-1+dx-dz)%math.max(1,#(self.focusActions or {}))+1 end
        return true
    elseif phase=='cable' then
        local _,message=c.automation:Keyboard(dx,dz,key(KEY_F)); self:Notify(message); return true
    elseif phase=='attach' then
        if dx~=0 or dz~=0 then
        local current=c.components:Host(c.components.selected); local sx,sy=graphics:GetWidth()/UI.GetScale()/2,graphics:GetHeight()/UI.GetScale()/2
            if current then sx,sy=self:Project(current.x,current.z,1) else sy=graphics:GetHeight()/UI.GetScale()/2 end
            local best,score=nil,math.huge
            for _,s in ipairs(c.stations) do if c.components:CanBind(s.id,c.components.mode) then
                local x,y=self:Project(s.x,s.z,1); local along=(x-sx)*dx-(y-sy)*dz
                local across=math.abs((x-sx)*dz+(y-sy)*dx)
                if along>1 and along+across*3<score then best,score=s.id,along+across*3 end
            end end
            if best then c.components.selected=best end; self.focus=0
        end
        if key(KEY_F) then self.context.resolve(); if c.target then local ok,message=c.components:CanBind(c.target.id,c.components.mode); if ok then c.components.selected=c.target.id else self:Notify(message) end end end
        return true
    elseif phase=='cashier' or phase=='orders' then
        if (dx~=0 or dz~=0) and #c.orders.active>0 then local _,index=c.orders:Find(c.orders.selectedId)
            local i=index and ((index-1+dx-dz)%#c.orders.active+1) or 1; c.orders:Select(c.orders.active[i].id) end
        if phase=='cashier' and key(KEY_F) then self:Command('deliver') end
        if phase=='cashier' and key(KEY_E) then self:Command('cashierEnd') end
        return true
    elseif phase=='buffer' then
        if dx~=0 or dz~=0 then c.logistics:SelectSlot((c.logistics.slot-1+dx-dz*2)%6+1) end
        if key(KEY_F) then c.logistics:ConfirmBuffer() end; return true
    elseif phase=='menu' then
        if dx~=0 then
            local list=assert(State.Kinds[self.category]); local index=1; for i,k in ipairs(list) do if k==self.kind then index=i end end
            self.kind=list[(index-1+dx)%#list+1]
        end
        if dz~=0 then self.category=(self.category-1-dz)%5+1; self.kind=State.Kinds[self.category][1] end
        if key(KEY_F) or key(KEY_RETURN) then self:Command('enterKind') end; return true
    elseif phase=='preview' or phase=='move' then
        if dx~=0 or dz~=0 then build:Move(dx,dz); build.confirmFocus=false; self.focus=0 end
        if key(KEY_R) then build:Rotate(); self.focus=0 end
        local wheel=input:GetMouseMoveWheel()
        if wheel~=0 and self:WorldMouseAvailable() then build:Rotate(wheel); build.confirmFocus=false; self.focus=0 end
        return true
    elseif phase=='manage' or phase=='selected' then
        if c.automation and c.automation.managing then
            if dx~=0 or dz~=0 then c.automation:SetCursor(c.automation.cursor.x+dx,c.automation.cursor.z+dz); self.focus=0 end
            if key(KEY_F) then c.automation:PickManaged(c.automation.cursor.x,c.automation.cursor.z); self.selectedAt=self.elapsed end
            return true
        end
        if key(KEY_F) and not self.selected then self.context.resolve(); if c.target and (c.target.automaticKind or c.target.buildingKind) then self:SelectManaged(c.target,nil) end end
        return true
    elseif phase=='source' or phase=='destination' then
        if dx~=0 or dz~=0 then b:SetCursor(b.cursor.x+dx,b.cursor.z+dz) end
        if key(KEY_F) then local s=c.logistics:At(b.cursor.x,b.cursor.z); if s then local _,message=b:Select(s.id); self:Notify(message) end end
        return true
    elseif phase=='adjust' then
        if self.touch.objectId then return true end
        if dx~=0 or dz~=0 then if b.editing and b.handle then b:MoveBy(dx,dz) else b:EndEdit(); b:Navigate(dx,dz) end; self.focus=0 end
        if key(KEY_F) then
            if not b.handle then self:Notify("长按路段 0.35 秒后拖动，松手结束编辑。")
            elseif b.editing then b:EndEdit() else b:BeginEdit(b.selected,true) end
        end
        return true
    end
    return false
end

function Controller:Joystick(phase,e,rect)
    if self:Phase()~='normal' or self.preferences.display=='keyboard' then return end
    local id=e.pointerId
    if phase=='down' then
        local floating=self.preferences.joystick=='floating'
        local cx,cy=floating and e.x or rect.x+56,floating and e.y or rect.y+56
        self.joyCenter={x=cx,y=cy}; self.joyRect=rect
        self.touch:Begin(id,e.x,e.y,'joystick',cx,cy)
    elseif phase=='move' then self.touch:Move(id,e.x,e.y)
    else self.touch:End(id); self.joyCenter=nil end
end

function Controller:WorldMouseAvailable()
    local hovered=UI.GetHoveredWidgetForPointer(0)
    return (hovered==nil or hovered==self.view.worldSurface) and self.touch.objectId==nil
end

function Controller:QueuePointer(phase,e)
    if e.pointerType=='mouse' and e.button~=MOUSEB_LEFT and phase~='move' then return end
    table.insert(self.events,{phase=phase,id=e.pointerId,x=e.x,y=e.y,pointerType=e.pointerType,buttons=e.buttons})
end

function Controller:Point(x,y,height)
    local c=self.context.get(); local node=c.cameraNode
    local px,py,pz=Projection.Point(x,y,height or 0,node.worldPosition,node.worldRight,node.worldUp,node.worldDirection,
        c.camera.orthoSize,c.camera.zoom,graphics:GetWidth(),graphics:GetHeight(),UI.GetScale())
    return px and Vector3(px,py,pz) or nil
end

function Controller:Project(x,z,height)
    local c=self.context.get(); local node=c.cameraNode
    return Projection.Project(Vector3(x,height or 1.15,z),node.worldPosition,node.worldRight,node.worldUp,
        c.camera.orthoSize,c.camera.zoom,graphics:GetWidth(),graphics:GetHeight(),UI.GetScale())
end

function Controller:ActivateSegmentDrag()
    local drag=self.drag
    if not drag or drag.kind~="segment-wait" or self.elapsed-drag.started<0.35 then return false end
    local pointer=self.touch.pointers[drag.id]
    if not pointer or pointer.moved then return false end
    self.context.get().logistics.builder:BeginEdit(drag.index,false)
    drag.kind="node"
    return true
end

function Controller:HitNode(x,y)
    local b=self.context.get().logistics.builder
    local targets=b:Targets(); local best,score=nil,math.huge
    -- Endpoints/corners have priority over a segment within their 48-unit hot zone.
    for _,candidate in ipairs(targets) do if candidate.handle then
        local sx,sy=self:Project(candidate.x,candidate.z,0.3)
        local distance=(sx-x)^2+(sy-y)^2
        local cost=distance-(candidate.index==b.selected and b.handle and 0.1 or 0)
        if distance<=24^2 and cost<score then best,score=candidate,cost end
    end end
    if best then return best end
    if not b.plan then return nil end
    local points=Grid.Simplify(b.plan.cells)
    for _,candidate in ipairs(targets) do if not candidate.handle then
        local a,nextPoint=points[candidate.index],points[candidate.index+1]
        if a and nextPoint then
            local ax,ay=self:Project(a.x,a.z,0.3); local bx,by=self:Project(nextPoint.x,nextPoint.z,0.3)
            local distance=Projection.SegmentDistance(x,y,ax,ay,bx,by)
            if distance<=24^2 and distance<score then best,score=candidate,distance end
        end
    end end
    return best
end

function Controller:CameraGesture(g)
    local c=self.context.get(); local s=self.preferences.sensitivity
    local units=c.camera.orthoSize/c.zoom/math.max(1,graphics:GetHeight()/UI.GetScale())
    local center=Area.Center(c.area); local p=c.cameraNode.position
    local width,depth=Area.Size(c.area)
    p.x=State.Clamp(p.x-g.dx*units*s,center-width/2+2,center+width/2-2); p.z=State.Clamp(p.z+g.dy*units*s,-depth/2+2,depth/2-2)
    c.cameraNode.position=p; self.context.zoom(State.Clamp(c.zoom*g.scale^s,0.8,2.5))
end

function Controller:WorldEndFrame()
    local c=self.context.get(); local build,b=c.buildings,c.logistics.builder
    for _,e in ipairs(self.events) do
        local phase=self:Phase(); local point=self:Point(e.x,e.y,phase=='cable' and 2.4 or phase=='buffer' and 1.15 or 0)
        if point and c.loop:IsRunning() then
            if e.phase=='down' then
                local kind='scene'; local hit=phase=='adjust' and self:HitNode(e.x,e.y) or nil
                if phase=='cable' and not self.touch.objectId then
                    c.automation:Pointer('down',point); if c.automation.drag then kind='object'; self.drag={kind='cable'} end
                elseif hit and not self.touch.objectId then
                    if not hit.handle then
                        b:EndEdit(); b.selected,b.handle=hit.index,false; b.focus="path"; b.revision=b.revision+1
                        self.nodeSelected=true; kind="object"
                        self.drag={kind="segment-wait",id=e.id,index=hit.index,started=self.elapsed,x=point.x-hit.x,z=point.z-hit.z}
                    elseif self.nodeSelected and hit.index==b.selected and hit.handle==b.handle then
                        b:BeginEdit(hit.index,hit.handle); kind='object'; self.drag={kind='node',x=point.x-hit.x,z=point.z-hit.z}
                    else b:EndEdit(); b.selected,b.handle=hit.index,hit.handle; b.revision=b.revision+1; self.nodeSelected=true end
                elseif (phase=='preview' or phase=='move') and not self.touch.objectId then
                    local width,depth=build:Dimensions()
                    if math.abs(point.x-build.x)<=width/2 and math.abs(point.z-build.z)<=depth/2 then
                        kind='object'; self.drag={kind='building',x=point.x-build.x,z=point.z-build.z}
                    end
                end
                local accepted=self.touch:Begin(e.id,e.x,e.y,kind)
                if not accepted and kind=='object' then b:EndEdit(); self.drag=nil; if c.automation then c.automation.drag=nil end end
            elseif e.phase=='move' then
                -- Arm against the stationary press before recording this move.
                if self.touch.objectId==e.id then self:ActivateSegmentDrag() end
                local gesture=self.touch:Move(e.id,e.x,e.y)
                if gesture then self:CameraGesture(gesture)
                elseif self.touch.objectId==e.id and self.drag then
                    if self.drag.kind=='cable' then c.automation:Pointer('move',point)
                    elseif self.drag.kind=='building' then build:SetPosition(point.x-self.drag.x,point.z-self.drag.z); build.confirmFocus=false
                    elseif self.drag.kind=="node" then b:MoveSelection(b.selected,b.handle,point.x-self.drag.x,point.z-self.drag.z)
                    elseif self.drag.kind=="segment-wait" and self.touch.pointers[e.id].moved then
                        self.drag.kind="segment-cancel"; self:Notify("先按住路段 0.35 秒，再开始拖动。")
                    end
                elseif phase=='cable' and not self.touch.gesture then c.automation:Pointer('move',point)
                elseif (phase=='source' or phase=='destination') and not self.touch.gesture and e.pointerType=='mouse' then b:SetCursor(point.x,point.z)
                elseif (phase=='source' or phase=='destination') and self.touch.pointers[e.id] and not self.touch.gesture then b:SetCursor(point.x,point.z)
                elseif (phase=='preview' or phase=='move') and not build.previewPinned and e.pointerType=='mouse' and not self.touch.gesture then build:SetPosition(point.x,point.z) end
            elseif e.phase=='up' or e.phase=='cancel' then
                local p=self.touch:End(e.id)
                if p and p.kind=='object' then
                    if self.drag and self.drag.kind=='cable' then c.automation:Pointer('up',point)
                    elseif self.drag and self.drag.kind=='building' then build.previewPinned=true else b:EndEdit() end
                    self.drag=nil
                elseif p and p.kind=='scene' and not p.moved and e.phase=='up' then self:WorldClick(phase,point,e.x,e.y) end
            end
        end
    end
    self.events={}
end

function Controller:WorldClick(phase,p,x,y)
    local c=self.context.get(); local build,b=c.buildings,c.logistics.builder
    if phase=='cable' then local _,message=c.automation:Pick(p.x,p.z); self:Notify(message); return end
    if phase=='terminal' then return end
    if phase=='attach' then
        local station=c.logistics:At(p.x,p.z); local ok,message=c.components:CanBind(station and station.id,c.components.mode)
        c.components.selected=ok and station.id or nil; self:Notify(message); self.focus=0; return
    end
    if phase=='orders' then self.ordersOpen=false; return end
    if phase=='preview' or phase=='move' then
        build:SetPosition(p.x,p.z); build.previewPinned=not build.previewPinned; build.confirmFocus=false; return
    elseif phase=='buffer' then
        local station=c.logistics:At(p.x,p.z)
        if station and station.id==c.logistics.bufferId then
            local best,d=nil,math.huge
            for i=1,6 do local sx,sz=World.SlotPosition(station,i); local px,py=self:Project(sx,sz,1.15)
                local distance=(x-px)^2+(y-py)^2; if distance<=24^2 and distance<d then best,d=i,distance end end
            if best then c.logistics:SelectSlot(best) end
        end; return
    elseif phase=='manage' or phase=='selected' then
        if c.automation and c.automation.managing then
            local ceiling=self:Point(x,y,2.4)
            self:SelectManaged(nil,nil)
            if ceiling then c.automation:PickManaged(ceiling.x,ceiling.z) end
            return
        end
        local station=c.logistics:At(p.x,p.z)
        if station and (station.automaticKind or station.buildingKind) then self:SelectManaged(station,nil); return end
        for _,belt in ipairs(c.logistics.network.belts) do for _,r in ipairs(Network.Rects(belt)) do
            if Grid.Overlap(p.x,p.z,0.1,0.1,r.x,r.z,r.width,r.depth) then self:SelectManaged(nil,belt.id); return end
        end end
        self:SelectManaged(nil,nil); return
    elseif phase=='source' or phase=='destination' then
        b:SetCursor(p.x,p.z); local station=c.logistics:At(p.x,p.z)
        if station then local _,message=b:Select(station.id); self:Notify(message) else self:Notify('请选择可接入建筑；空白位置不确认。') end
        self.nodeSelected=false; return
    elseif phase=='normal' then
        local station=c.logistics:At(p.x,p.z)
        -- Pointing cannot bypass the established range, facing and obstruction gate.
        if station then
            self.inspectId=station.id; self.context.resolve(); c=self.context.get()
            if not c.target or c.target.id~=station.id then self.inspectId=nil end
        end
    end
end

function Controller:Card(station,text)
    local x,y=self:Project(station.x,station.z+station.depth/2,1.15)
    local insets=UI.GetSafeAreaInsets()
    return {title=station.name,text=text,anchorX=x-(insets.left or 0),anchorY=y-(insets.top or 0)}
end

function Controller:StationText(s)
    local c=self.context.get(); local machine=c.machines[s.id]
    if machine and machine.kind=='cooker' then
        local rows={}
        for i=1,3 do local slot=machine.slots[i]; rows[i]='槽'..i..'：'..(slot and (name(slot.itemType)..(slot.itemType=='raw_beef' and string.format(' %.1fs',math.max(0,3-slot.progress)) or '')) or '空') end
        return table.concat(rows,'\n')
    elseif machine then return machine:Status():gsub(' | ','\n'):gsub(' · ','\n')
    elseif s.id=='grill' then return c.manual:GrillStatus()
    elseif s.id=='assembly' then return c.manual:AssemblyStatus():gsub(' · ','\n')
    elseif c.logistics.buffers[s.id] then return c.logistics.buffers[s.id]:LoadText()..(s.component=='order' and '\n下单 / 本机库存 / 网络 / 任务' or s.buildingKind=='storage' and '\n空手取栈顶；禁止手动存入或交换' or '\n选槽取换；空槽可存入')
    elseif s.buildingKind=='terminal' then return '网络信息 / 生产下单 / 任务\n整网2件/秒，不自动交顾客订单'
    elseif s.id=='delivery' then return '交付库存 '..c.orders.stock..'/5'
    elseif s.destination then return s.destination=='workshop' and '进入自动化车间，可携带物品' or '返回汉堡店，车间继续生产'
    elseif s.id=='trash' then return '交互销毁手持物品'
    elseif s.id=='cashier' then return '交付库存 '..c.orders.stock..'/5\n在收银台选择并交付订单' end
    return s.buildingKind and '物流接口 · 由接入传送带驱动' or '无限供料 · 不消耗库存'
end

function Controller:Modal(phase)
    local c=self.context.get(); local loop=c.loop
    if c.campaign then local modal=CampaignUI.Modal(c,self,phase); if modal then return modal end end
    if phase=='terminal' then return c.automation:Modal() end
    if phase=='paused' then return {title='暂停',back='继续游戏',lines={'模拟已冻结；继续后恢复原操作模式。','本 Demo 不保存游戏进度。'},
        tools={action('运行统计 / 设备说明','statistics'),action('操作与显示设置','settings'),action('提前结束当天','pauseEnd'),action('退出游戏','exitGame')},buttons={}}
    elseif phase=='confirm' then return {title=self.confirmTitle,back='取消',lines={self.confirmDetails or '仅确认后执行此操作。'},buttons={action('确认','confirmYes')}}
    elseif phase=='statistics' then
        local network=c.logistics.network; local cargo,used,capacity=0,0,0; local counts={}
        for _,belt in ipairs(network.belts) do cargo=cargo+#belt.cargo end
        for _,storage in pairs(c.logistics.buffers) do used=used+storage:Count(); capacity=capacity+storage.capacity end
        for _,s in ipairs(c.stations) do local kind=s.buildingKind or s.automaticKind; if kind then counts[kind]=(counts[kind] or 0)+1 end end
        local devices={}; for _,kind in ipairs(Buildings.Order) do table.insert(devices,Buildings.Definitions[kind].name..' '..(counts[kind] or 0)) end
        local history={}; for _,day in ipairs(loop.history) do table.insert(history,string.format('第%d天 订单%d · 手工%d · 自动%d',day.day,day.orders,day.manual,day.automatic)) end
        local lines={'运行数据 · 全项目 / 当前时刻',loop:ClockText(),string.format('当日完成订单 %d · 待处理 %d/5',c.orders.completed,#c.orders.active),
            string.format('当日产量 %d · 手工 %d · 自动 %d',loop.manual+loop.automatic,loop.manual,loop.automatic),
            table.concat(devices,'\n'),string.format('传送带 %d · 带上物品 %d · 缓存 %d/%d\n交付库存 %d/5 · 累计交接件次 %d',#network.belts,cargo,used,capacity,c.orders.stock,network.total),
            '已结束日记录\n'..(#history>0 and table.concat(history,'\n') or '暂无'),
            '本局拆除损失\n'..(#self.losses>0 and table.concat(self.losses,'\n') or '无记录'),
            '设备说明（静态规则）','烹饪台 2.4×1.5格：3槽各3秒，手动生肉后进先出。\n组合台 2.4×1.5格：胚+熟肉+生菜，自动2秒。',
            '缓存台 2×2格：容量6，输出后进先出。\n库存 2×4格：容量24，空手取栈顶，禁止手动存换。\n下单/交付组件依附库存或缓存，不另占地。下单终端可在本机库存页任取。\n电缆整网共享2件/秒，任务按入库到货计数。\n接口 1×1格：无独立速度或缓存，按接入口收束/分散。','基础带 0.5格/秒，单入单出，不过滤，不重叠，禁止环路。'}
        return {title='统计与设备说明',back='返回暂停',lines=lines}
    elseif phase=='settings' then return {title='操作与显示设置',back=loop.state=='title' and '返回标题' or '返回暂停',lines={State.PreferenceText(self.preferences),
        c.campaign and '经营进度保存于本机；UI偏好独立保存。' or '仅保存本机 UI 偏好，不包含游戏进度。','WASD 移动 / 选项 / 节点；Shift 奔跑\nF 交互；手工铁板空手长按 F 3秒\nQ 放下；B 建造；R 旋转\nTab 选右下动作，F/Enter 执行\n右键逐层返回；ESC 返回建造首页 / 暂停\n鼠标中键平移、滚轮缩放；双指平移/捏合',
        '手机：摇杆内圈步行，外圈奔跑；交互按钮可独立按住加工。\n场景点击只选取；最终放置必须点确认。\n切后台会暂停，回前台需主动继续。'},tools={
        action('切换：固定 / 浮动摇杆','preference','joystick'),action('切换：双端 / 键鼠 / 触屏','preference','display'),
        action('UI 缩小','preference','scaleDown'),action('UI 放大','preference','scaleUp'),action('降低镜头灵敏度','preference','sensitivityDown'),
        action('提高镜头灵敏度','preference','sensitivityUp'),action('重看全部阶段教学','preference','tutorials'),action('恢复默认 UI 设置','preference','defaults')}}
    elseif phase=='settlement' then
        local s=loop.history[#loop.history]
        return {title='第 '..loop.day..' 天结算',lines={string.format('完成订单 %d\n制作汉堡 %d\n手工 %d · 自动 %d',s.orders,s.total,s.manual,s.automatic),
            s.early and '提前结束：未完成订单已清除。' or '当日时间结束：未完成订单已清除。','库存、缓存和产线按原跨天规则保留。'},buttons={action(loop.day==3 and '查看 Demo 完成' or '下一天','nextDay')}}
    elseif phase=='complete' then
        local lines={'三天演示完成；未保存游戏进度。'}; local total=0
        for _,s in ipairs(loop.history) do table.insert(lines,string.format('第%d天：订单%d · 产量%d（手工%d / 自动%d）',s.day,s.orders,s.total,s.manual,s.automatic)); total=total+s.total end
        table.insert(lines,'三天总产量 '..total)
        return {title='Demo 完成',lines=lines,buttons={action('退出游戏','exitGame'),action('重新开始','restart')}}
    elseif phase=='cashier' then
        local tools={}; for i,o in ipairs(c.orders.active) do table.insert(tools,action(string.format('%s订单%02d · %d/%d',o.id==c.orders.selectedId and '[已选] ' or '',o.id,o.delivered,o.required),'selectRow',i)) end
        local lines={'可交付汉堡 '..c.orders:DeliveryCount()..' · 待处理 '..#c.orders.active..'/'..(c.orders.limit or 5),
            c.orders:Find(c.orders.selectedId) and '已选订单：可部分交付。' or '请选择有效订单。',loop.remaining==0 and '计时已归零，可以结束当天。' or '计时归零后才可结束当天。'
        }
        for _,line in ipairs(c.orders:DeliverySummary()) do table.insert(lines,line) end
        return {title='收银台',back='关闭收银',lines=lines,tools=tools,buttons={action('结束当天','cashierEnd',nil,not loop:CanCashierEnd()),action('交付订单','deliver',nil,not c.orders:CanDeliver())}}
    end
    return nil
end

function Controller:Update(dt)
    self.elapsed=self.elapsed+dt
    local c=self.context.get(); local phase=self:Phase(); local build,b=c.buildings,c.logistics.builder
    if self.lastPhase~=phase then
        self:Release(); self.focus=0
        if phase~='adjust' then self.nodeSelected=false end
        self.lastPhase=phase
    end
    self:ActivateSegmentDrag()
    local editing=State.IsBuild(phase)
    -- Pausing preserves the snapshot; closing construction is the only restore.
    local underlying=build.mode~='idle' or b.mode~='idle' or (c.automation and c.automation.mode~='idle')
    if c.runtime and not underlying then c.runtime.overview=false end
    if underlying and not self.cameraSaved then self.cameraSaved={position=c.cameraNode.position,zoom=c.zoom}; self.context.zoom(State.Clamp(c.zoom*0.9,0.8,2.5))
    elseif not underlying and self.cameraSaved then c.cameraNode.position=self.cameraSaved.position; self.context.zoom(self.cameraSaved.zoom); self.cameraSaved=nil end
    self.context.presentation(State.Grid(phase),editing)
    if c.logistics.toolbar then c.logistics.toolbar:SetVisible(false) end
    local scale=UI.GetScale(); local insets=UI.GetSafeAreaInsets()
    local w=graphics:GetWidth()/scale-((insets.left or 0)+(insets.right or 0))
    local h=graphics:GetHeight()/scale-((insets.top or 0)+(insets.bottom or 0))
    local model={phase=phase,width=w,height=h,title=State.Titles[phase] or '',normal=phase=='normal',clock=string.format('第%d/%d天 · %s',c.loop.day,c.campaign and 10 or 3,c.loop.state=='preparation' and '准备中' or string.format('%02d:%02d',math.ceil(c.loop.remaining)//60,math.ceil(c.loop.remaining)%60)),
        held='手持：'..name(c.items.held),orderCount=#c.orders.active,orderLimit=c.orders.limit or 5,category=self.category,kind=self.kind,
        display=self.preferences.display,floating=self.preferences.joystick=='floating',toast=self.elapsed<self.toastUntil and self.toast or '',actions={}}
    local a=model.actions; local function add(text,command,value,disabled) table.insert(a,action(text,command,value,disabled)) end
    if phase=='normal' then
        if c.campaign then add(c.loop.state=='preparation' and '准备 / 开业' or '当日教学',c.loop.state=='preparation' and 'dayBriefing' or 'lesson') end
        add('放下','dropUI',nil,c.items.held==nil); add('建造','openBuild',nil,c.area~='workshop')
        local text='交互'; if c.ground then text=c.items.held and '交换' or '拾取'
        elseif c.target then
            local s=c.target
            text=s.id=='grill' and c.manual.grillItem=='raw_beef' and not c.items.held and '按住加工' or
                (s.id=='trash' and '销毁' or s.destination and '进入区域' or '交互')
            model.card=self:Card(s,self:StationText(s))
        end
        if c.ground then model.card=self:Card({name=name(c.ground.itemType),x=c.ground.position.x,z=c.ground.position.z,depth=0.3},'地面物品 · '..(c.items.held and '可交换' or '可拾取')) end
        add(text,'interactUI',nil,c.target==nil and c.ground==nil)
        model.reason=c.loop.remaining==0 and '当日计时结束：未完成订单已清除，去收银台结束当天。' or (c.area=='shop' and '建造仅在自动化车间开放；左上入口进入车间。' or '')
    elseif phase=='orders' then model.back='关闭订单'; model.reason='这里只浏览和选单；请在收银台交付。'
    elseif phase=='menu' then model.back='退出建造'; add(self.kind=='manage' and '进入管理' or (self.kind=='conveyor' or self.kind=='cable') and '进入布线' or '进入放置','enterKind')
    elseif phase=='preview' or phase=='move' then
        model.back=phase=='move' and '取消编辑' or '取消放置'; model.title=model.title..' · '..Buildings.Definitions[build.kind].name
        local valid,reason=build:Validate(c.player.position)
        if c.campaign and phase=='preview' then local cost,msg=c.campaign:Quote(build.kind); if not cost then valid,reason=false,msg else reason=reason..' · '..msg end end
        if build.selected and (c.logistics.network:HasAttached(build.selected.id) or (c.automation and c.automation.cables:HasAttached(build.selected.id))) then valid,reason=false,'请先拆除相连传送带/电缆，再移动或旋转。' end
        if build.selected and c.machines[build.selected.id] and c.machines[build.selected.id]:IsProcessing() then valid,reason=false,'加工中的建筑不能移动。' end
        model.reason=(build.previewPinned and '投影已固定' or '投影跟随')..' · '..(valid and reason or '不可放置：'..reason)
        add('旋转 90°','rotateUI'); add('确认摆放','confirmBuild',nil,not valid)
    elseif phase=='manage' then model.back='返回选型'; model.reason='点选已有建筑或整条传送带。'
    elseif phase=='attach' then
        model.title=c.components.mode=='order' and '绑定下单组件 · 选择库存' or '绑定交付组件 · 选择库存或缓存'
        model.back=c.components.selected and '取消选中' or '返回选型'
        local ok,reason=c.components:CanBind(c.components.selected,c.components.mode)
        model.reason=reason; add('确认绑定','confirmAttachment',nil,not ok)
        local host=c.components:Host(c.components.selected); if host then model.card=self:Card(host,self:StationText(host)) end
    elseif phase=='selected' then
        model.back='取消选中'; local locked=false
        if self.selected then
            model.card=self:Card(self.selected,self:StationText(self.selected))
            local machine=c.machines[self.selected.id]
            locked=c.logistics.network:HasAttached(self.selected.id) or (c.automation and c.automation.cables:HasAttached(self.selected.id)) or (machine and (machine:IsProcessing() or machine.automationOwner))
            add('移动','moveManaged',nil,locked); add('旋转','rotateManaged',nil,locked)
            if self.selected.component then add('卸下组件','unbindComponent') end
        end
        local cooling=self.elapsed-self.selectedAt<0.5 or (self.deleteUntil or 0)>self.elapsed
        local processing=self.selected and c.machines[self.selected.id] and c.machines[self.selected.id]:IsProcessing()
        add(cooling and '回收待解锁' or '回收','deleteManaged',nil,cooling or processing)
        model.reason=locked and '加工中或已接带：先停止加工 / 拆带再移动。' or (cooling and '选中后 0.5 秒可拆除。' or '拆除后仍可继续选择；物品按原规则落地。')
    elseif phase=='source' or phase=='destination' then
        model.back=phase=='source' and '取消布置' or '返回选 A'
        local source=b.sourceId and c.logistics:Endpoint(b.sourceId)
        if source then model.title=model.title..' · A '..source.name end
        model.reason=phase=='source' and '选择一个可输出的建筑 A。' or '点击有效输入建筑 B；拖动仅调整预览。'
    elseif phase=='adjust' then
        local from=b.sourceId and c.logistics:Endpoint(b.sourceId)
        local to=b.destinationId and c.logistics:Endpoint(b.destinationId)
        if from and to then model.title=model.title.." · "..from.name.." → "..to.name end
        model.back='返回选 B'; model.reason=b.plan and b.plan.reason or b.message
        if not b.handle then model.reason=(self.drag and self.drag.kind=="node" and "正在拖动路段；松手结束" or "路段：长按 0.35 秒后拖动").." · "..model.reason end
        add('反转方向','reverseUI'); add('确认摆放','confirmBelt',nil,not b.plan or not b.plan.valid)
    elseif phase=='buffer' then
        model.back='取消选物'; local storage=c.logistics.buffers[c.logistics.bufferId]; local slot=storage and storage.slots[c.logistics.slot]
        local text,valid=State.BufferAction(c.items.held,slot,c.logistics.selectedToken~=nil)
        local station=c.logistics:At(assert(c.logistics:Endpoint(c.logistics.bufferId)).x,assert(c.logistics:Endpoint(c.logistics.bufferId)).z)
        model.card=self:Card(station,'槽 '..c.logistics.slot..'/6：'..name(slot and slot.itemType)..'\n缓存 '..storage:Count()..'/6')
        model.reason=valid and '点槽只选择；点击右下动作后执行并退出。' or '空槽无物可取，或物品已被产线取走；请重新选择。'
        add(text,'bufferConfirm',nil,not valid)
    end
    if (phase=='manage' or phase=='selected') and c.automation then
        local managing=c.automation.managing
        if managing then
            model.title='设备管理 · 电缆'
            model.reason=c.automation.deleteEdge and ('已选 '..#c.automation.cables:Segment(c.automation.deleteEdge)..' 格直线段；拆除后分支保留，任务等待重连。') or '金框插头为设备接线口；点击线段拆除，橙红为拆除范围。'
        end
        table.insert(a,1,action(managing and '设备' or '切换电缆',managing and 'manageDevices' or 'manageCables'))
    end
    if phase=='cable' then c.automation:BuildModel(model); a=model.actions end
    if c.campaign then
        model.campaign=c.campaign
        model.status=string.format('金币 %d · 本日交付 %d/%d',c.campaign.coins,c.campaign.delivered,Days.Day(c.loop.day).goal)
        if phase=='menu' then model.reason=c.campaign:Card(self.kind) end
        if phase=='cable' then
            a[#a+1]=action('网络信息','networkInfo')
            local plan=c.automation:Preview(); if plan and plan.valid then
                local edges=0; for k in pairs(plan.edges or {}) do if not c.automation.cables.edges[k] then edges=edges+1 end end
                local cost,reason=c.campaign:Quote('cable',edges); model.reason=(model.reason or '')..' · '..reason
                if not cost then for _,act in ipairs(a) do if act.command=='cableConfirm' then act.disabled=true end end end
            end
        elseif phase=='adjust' and b.plan then
            local cost,reason=c.campaign:Quote('belt',#b.plan.cells); model.reason=(model.reason or '')..' · '..reason
            if not cost then for _,act in ipairs(a) do if act.command=='confirmBelt' then act.disabled=true end end end
        elseif phase=='attach' then
            local cost,reason=c.campaign:Quote(c.components.mode=='order' and 'terminal' or 'delivery_component')
            model.reason=(model.reason or '')..' · '..reason; if not cost then for _,act in ipairs(a) do if act.command=='confirmAttachment' then act.disabled=true end end end
        end
        if State.IsBuild(phase) then a[#a+1]=action(c.runtime.overview and '回到玩家' or '一览车间',c.runtime.overview and 'cameraPlayer' or 'overview') end
        if c.loop.state=='preparation' and phase=='normal' then model.reason='准备中：加工与物流冻结；整理后点击“准备 / 开业”。' end
    end
    local tutorialKey=self:TutorialKey(phase)
    if tutorialKey~='' and not self.preferences.tutorials[tutorialKey] then
        model.tutorial=({normal='摇杆移动，外圈奔跑；交互与放下在右下。',preview='拖动投影后松手固定；最终点击确认摆放。',adjust='路段长按0.35秒拖动；端点/转角先选再拖；确认后继续选A。'})[tutorialKey]
        model.tutorialKey=tutorialKey
    end
    model.modal=self:Modal(phase)
    self.focusActions=model.modal and {} or a
    if model.modal then
        for _,item in ipairs(model.modal.tabs or {}) do table.insert(self.focusActions,item) end
        for _,item in ipairs(model.modal.quantity and model.modal.quantity.actions or {}) do table.insert(self.focusActions,item) end
        for _,entry in ipairs(model.modal.entries or {}) do if entry.action then table.insert(self.focusActions,entry.action) end end
        for _,item in ipairs(model.modal.tools or {}) do table.insert(self.focusActions,item) end
        for _,item in ipairs(model.modal.buttons or {}) do table.insert(self.focusActions,item) end
    end
    if self.preferences.display~="touch" then
        for _,item in ipairs(a) do
            local shortcut=({dropUI="Q",openBuild="B",interactUI="F",rotateUI="R"})[item.command]
            if shortcut then item.text=item.text.." ("..shortcut..")" end
        end
    end
    for i,item in ipairs(self.focusActions) do
        if self.preferences.display~='touch' and i==self.focus then item.text='[F] '..item.text end
    end
    local pointer=self.touch.objectId and self.touch.pointers[self.touch.objectId]
    if pointer then model.dragMarker={x=pointer.x-(insets.left or 0),y=pointer.y-(insets.top or 0)} end
    for _,station in ipairs(c.stations) do
        if station.highlight then
            local endpoint=c.logistics:Endpoint(station.id)
            station.highlight.enabled=(phase=='normal' and station==c.target) or (phase=='selected' and station==self.selected)
                or (phase=='attach' and c.components.selected==station.id)
                or ((phase=='source' or phase=='destination') and endpoint~=nil and
                    ((phase=='source' and Network.CanOutput(endpoint)) or (phase=='destination' and (station.id==b.sourceId or Network.CanInput(endpoint)))))
        end
    end
    self.view:Render(model)
    local joy=self.touch.pointers[self.touch.joystickId]
    self.view.joystickBase:SetVisible(self.preferences.joystick~="floating" or joy~=nil)
    if joy and self.joyRect then
        local dx,dy=(joy.x-joy.cx),(joy.y-joy.cy); local length=math.sqrt(dx*dx+dy*dy); local factor=length>56 and 56/length or 1
        local cx,cy=joy.cx-self.joyRect.x,joy.cy-self.joyRect.y
        self.view.joystickBase:SetStyle({left=cx-56,top=cy-56})
        self.view.joystickKnob:SetStyle({left=36+dx*factor,top=36+dy*factor})
    else self.view.joystickBase:SetStyle({left=0,top=0}); self.view.joystickKnob:SetStyle({left=36,top=36}) end
end

function Controller:FocusLost()
    self:Release(); local loop=self.context.get().loop
    loop.teaching=false
    if loop:IsRunning() then loop:Pause() end
    if self.context.freeze then self.context.freeze() end
    self.overlay=nil
    if self.context.get().runtime then self.context.get().runtime.pendingSave=true end
end

function Controller:Stop() self:Release(); self.view.onWorld,self.view.onJoystick=nil,nil end
return Controller
