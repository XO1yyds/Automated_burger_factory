local UI = require("urhox-libs/UI")
local Area = require("Factory/AutomationArea")
local G = require("Factory/ConveyorGeometry")
local Network = require("Factory/ConveyorNetwork")
local Builder = require("Factory/ConveyorBuilder")
local Buffer = require("Factory/BufferStorage")
local World = require("Factory/ConveyorWorld")
local Definitions = require("Factory/Items").Definitions
---@class FactoryConveyorControl
---@field context table
---@field network FactoryConveyorNetwork
---@field builder FactoryConveyorBuilder
---@field world FactoryConveyorWorld
---@field buffers table<string,FactoryBufferStorage>
---@field bufferId string?
---@field slot integer
---@field selectedToken integer?
---@field selectedBelt integer?
---@field dragging boolean
---@field v3 boolean?
---@field toolbar Panel
---@field hint Label
---@field buttons Button[]
local Control = {}
Control.__index = Control

---@param context table
---@return FactoryConveyorControl
function Control.New(context)
    local self=setmetatable({context=context,buffers={},slot=1,dragging=false,buttons={}},Control)
    for _,station in ipairs(context.stations()) do if station.buildingKind=="buffer" or station.buildingKind=="storage" then self.buffers[station.id]=Buffer.New(station.buildingKind=="storage" and 24 or 6) end end
    self.network=Network.New({resolve=function(id) return self:Endpoint(id) end,
        endpoints=function()
            local all={}; for _,station in ipairs(context.stations()) do local ep=self:Endpoint(station.id); if ep then table.insert(all,ep) end end; return all
        end,
        free=function(x,z,w,d)
            if Area.At(x,z,w,d)~="workshop" then return false end
            for _,station in ipairs(context.stations()) do if G.Overlap(x,z,w,d,station.x,station.z,station.width,station.depth) then return false end end
            for _,item in pairs(context.items.ground) do if G.Overlap(x,z,w,d,item.position.x,item.position.z,0.36,0.36) then return false end end
            return true
        end})
    self.builder=Builder.New(self.network)
    self.world=World.New(context.scene,context.makeBox)
    self.hint=UI.Label{text="",fontSize=14}
    local children={self.hint}
    local row={}
    local labels={"确认摆放","反转方向","类型：基础带","取消布置"}
    for i,name in ipairs(labels) do
        self.buttons[i]=UI.Button{text=name,onPointerEnter=function()
            if self.builder.mode=="adjust" then self.builder.focus,self.builder.button="buttons",i
            elseif i==1 then context.buildings.confirmFocus=true end
        end,onClick=function() context.action("placementButton",i) end}
        table.insert(row,self.buttons[i])
    end
    table.insert(children,UI.Panel{flexDirection="row",gap=8,children=row})
    self.toolbar=UI.Panel{position="absolute",left=18,bottom=130,right=18,padding=10,gap=6,
        backgroundColor={22,32,40,245},children=children}
    self.toolbar:SetVisible(false); UI.GetRoot():AddChild(self.toolbar)
    return self
end

---@param id string
---@return FactoryConveyorEndpoint?
function Control:Endpoint(id)
    for _,s in ipairs(self.context.stations()) do if s.id==id and Area.At(s.x,s.z)=="workshop" then
        local machine=self.context.machines[id]
        local source=self.context.sources[id]
        if source or machine or s.buildingKind then return {id=id,name=s.name,kind=s.buildingKind or s.automaticKind or "source",
            x=s.x,z=s.z,width=s.width,depth=s.depth,quarter=s.quarter or 0,area="workshop",source=source,machine=machine,storage=self.buffers[id],terminal=s.component=='order',component=s.component} end
    end end
    return nil
end

function Control:At(x,z)
    for _,s in ipairs(self.context.stations()) do
        if math.abs(x-s.x)<=s.width/2 and math.abs(z-s.z)<=s.depth/2 then return s end
    end
    return nil
end

function Control:Sample()
    local specs={{"ws_raw","ws_cooker",2,0},{"ws_cooker","ws_assembler",1,3},
        {"ws_bun","ws_assembler",2,0},{"ws_lettuce","ws_assembler",2,1},{"ws_assembler","ws_buffer",2,3}}
    for _,spec in ipairs(specs) do
        local function port(id,side)
            for _,p in ipairs(G.Ports(assert(self:Endpoint(id)))) do if p.side==side then return p end end
            error("Missing sample port "..id)
        end
        local plan=assert(self.network:Plan(spec[1],spec[2],port(spec[1],spec[3]),port(spec[2],spec[4])))
        local ok,message=self.network:Place(plan)
        assert(ok,"Sample route "..spec[1].." -> "..spec[2]..": "..message)
    end
end

function Control:Open()
    if self.context.area()~="workshop" then self.context.feedback("请先进入自动化车间。实体传送带仅在车间布置。") return end
    self.context.buildings:Cancel(); self.selectedBelt=nil
    self.builder:Open(self.context.player.position.x,self.context.player.position.z)
end

function Control:Cancel()
    self.builder:Cancel(); self.dragging=false; self.selectedBelt=nil; self.bufferId=nil; self.selectedToken=nil
end

function Control:SelectSlot(index)
    self.slot=math.max(1,math.min(6,index))
    local storage=self.bufferId and self.buffers[self.bufferId]
    local value=storage and storage.slots[self.slot]
    self.selectedToken=value and value.id or 0
end

function Control:OpenBuffer(id)
    self.bufferId=id; self:SelectSlot(1)
    return true,"选择缓存槽：WASD选择，F取出/交换/存入空槽；也可鼠标点选；右键/ESC取消。"
end

function Control:ConfirmBuffer()
    local storage=self.bufferId and self.buffers[self.bufferId]
    if not storage then return end
    if self.selectedToken==nil then self.context.feedback("选中物品已被传送带取走，请重新选择。") return end
    local ok,message=storage:TakeOrSwap(self.slot,self.selectedToken,self.context.items)
    self.context.feedback(message)
    if ok then self.bufferId,self.selectedToken=nil,nil else self:SelectSlot(self.slot) end
end

-- Spill in input queue order. Failure is an explicitly authorized loss, never
-- an all-or-nothing demolition rollback. Report each actual lost item type.
---@param contents FactoryItemType[]
---@param x number
---@param z number
function Control:Spill(contents,x,z)
    local lost,placed={},0
    for _,kind in ipairs(contents) do
        local done=false
        for ring=0,9 do
            if done then break end
            for step=0,31 do
                local angle=step*math.pi/16; local radius=ring*0.45
                local position=Vector3(x+math.cos(angle)*radius,0.14,z+math.sin(angle)*radius)
                if self.context.items:IsSpotFree(position) then
                    local item=self.context.items:SpawnGround(kind,position)
                    if item then placed=placed+1; done=true; break end
                end
            end
        end
        if not done then lost[kind]=(lost[kind] or 0)+1 end
    end
    local losses={}
    for _,kind in ipairs({"bun","raw_beef","cooked_beef","lettuce","burger"}) do
        if lost[kind] then table.insert(losses,Definitions[kind].name.." ×"..lost[kind]) end
    end
    local message="已拆除；落地 "..placed.." 件。"..(#losses>0 and ("空间不足，实际删除："..table.concat(losses,"、")) or "无物品损失。")
    print("[Conveyor demolition] "..message)
    return message,lost,placed
end

function Control:DeleteBelt()
    if not self.selectedBelt then return false end
    local contents,belt=self.network:Remove(self.selectedBelt)
    self.selectedBelt=nil
    if belt then
        local x,z=G.Position(belt.points,belt.length/2)
        self.context.feedback(self:Spill(contents,x,z))
    end
    return true
end

function Control:Button(index)
    local b=self.builder; local build=self.context.buildings
    if b.mode=="adjust" then
        b.focus,b.button="buttons",index
        if index==1 then local ok,message=b:Confirm(); self.context.feedback(message); if ok then build:Cancel() end
        elseif index==2 then local _,message=b:Reverse(); self.context.feedback(message)
        elseif index==3 then self.context.feedback("当前类型：基础传送带，0.5格/秒；本期仅此类型。")
        else b:Cancel(); build:Menu() end
    elseif b.mode~="idle" then
        if index==4 then b:Cancel(); build:Menu() end
    elseif build.mode=="preview" or build.mode=="move" then
        if index==1 then build.confirmFocus=true; local _,message=build:Confirm(self.context.player.position); self.context.feedback(message)
        elseif index==4 then build:Back() end
    end
end

function Control:Keyboard()
    local b,build=self.builder,self.context.buildings
    if self.bufferId then
        if input:GetMouseButtonPress(MOUSEB_RIGHT) then self.bufferId,self.selectedToken=nil,nil; return true end
        local dx=(input:GetKeyPress(KEY_D) and 1 or 0)-(input:GetKeyPress(KEY_A) and 1 or 0)
        local dz=(input:GetKeyPress(KEY_S) and 1 or 0)-(input:GetKeyPress(KEY_W) and 1 or 0)
        if dx~=0 or dz~=0 then self:SelectSlot(((self.slot-1+dx+dz*2)%6)+1) end
        if input:GetKeyPress(KEY_F) then self:ConfirmBuffer() end
        return true
    end
    if b.mode=="idle" then return false end
    if input:GetMouseButtonPress(MOUSEB_RIGHT) then
        b:Back(); self.dragging=false; if b.mode=="idle" then build:Menu() end; return true
    end
    local dx=(input:GetKeyPress(KEY_D) and 1 or 0)-(input:GetKeyPress(KEY_A) and 1 or 0)
    local dz=(input:GetKeyPress(KEY_W) and 1 or 0)-(input:GetKeyPress(KEY_S) and 1 or 0)
    if b.mode~="adjust" then
        if dx~=0 or dz~=0 then b:SetCursor(b.cursor.x+dx,b.cursor.z+dz) end
        if input:GetKeyPress(KEY_F) then
            local station=self:At(b.cursor.x,b.cursor.z)
            if station then local _,message=b:Select(station.id); self.context.feedback(message) else self.context.feedback("光标处没有可接入建筑。") end
        end
    else
        if input:GetKeyPress(KEY_TAB) then b.focus=b.focus=="path" and "buttons" or "path"; b:EndEdit() end
        if b.focus=="buttons" then
            local delta=dx-dz
            if delta~=0 then b.button=(b.button-1+delta)%4+1 end
            if input:GetKeyPress(KEY_F) then self:Button(b.button) end
        elseif b.editing then
            if dx~=0 or dz~=0 then b:MoveBy(dx,dz) end
            if input:GetKeyPress(KEY_F) then b:EndEdit() end
        else
            if dx~=0 or dz~=0 then b:Navigate(dx,dz) end
            if input:GetKeyPress(KEY_F) then b:BeginEdit(b.selected,b.handle) end
        end
        if input:GetKeyPress(KEY_E) then self.context.feedback("类型：基础传送带（本期仅此类型）。") end
    end
    return true
end

-- Called only after renderer selects the viewport, matching the accepted camera.
---@param ray Ray
---@param pressRay? Ray
function Control:Mouse(ray,pressRay)
    local b,build=self.builder,self.context.buildings
    if UI.IsPointerOverUI() then
        if self.dragging and not input:GetMouseButtonDown(MOUSEB_LEFT) then self.dragging=false; b:EndEdit() end
        return false
    end
    local y=self.bufferId and 1.15 or 0
    if math.abs(ray.direction.y)<0.000001 then return false end
    local t=(y-ray.origin.y)/ray.direction.y
    if t<0 then return false end
    local point=ray.origin+ray.direction*t
    local pressed=pressRay~=nil or input:GetMouseButtonPress(MOUSEB_LEFT)
    local pressPoint=point
    if pressRay and math.abs(pressRay.direction.y)>0.000001 then
        pressPoint=pressRay.origin+pressRay.direction*((y-pressRay.origin.y)/pressRay.direction.y)
    end
    if self.bufferId then
        if pressed then
            local station=self:At(pressPoint.x,pressPoint.z)
            if station and station.id==self.bufferId then
                for i=1,6 do local x,z=World.SlotPosition(station,i)
                    if math.abs(pressPoint.x-x)<0.38 and math.abs(pressPoint.z-z)<0.5 then self:SelectSlot(i); self:ConfirmBuffer(); break end
                end
            end
        end
        return true
    end
    if b.mode~="idle" then
        if b.mode=="adjust" then
            if pressed then
                b.focus="path"; b:EndEdit()
                local index,handle=b:Hit(pressPoint.x,pressPoint.z)
                if index then b:BeginEdit(index,handle); self.dragging=true end
            end
            if self.dragging then
                b:MoveSelection(b.selected,b.handle,point.x,point.z)
                if not input:GetMouseButtonDown(MOUSEB_LEFT) then self.dragging=false; b:EndEdit() end
            end
        else
            local move=input:GetMouseMove()
            if pressed then b:SetCursor(pressPoint.x,pressPoint.z)
            elseif move.x~=0 or move.y~=0 then b:SetCursor(point.x,point.z) end
            if pressed then
                local station=self:At(pressPoint.x,pressPoint.z)
                if station then local _,message=b:Select(station.id); self.context.feedback(message) end
            end
        end
        return true
    end
    if build.mode=="manage" and pressed then
        for _,belt in ipairs(self.network.belts) do for _,r in ipairs(Network.Rects(belt)) do
            if G.Overlap(point.x,point.z,0.02,0.02,r.x,r.z,r.width,r.depth) then
                self.selectedBelt=belt.id; self.context.feedback("已选整条传送带 #"..belt.id.."；Q拆除，右键取消选择。"); return true
            end
        end end
        self.selectedBelt=nil
    end
    return false
end

function Control:Refresh()
    local b,build=self.builder,self.context.buildings
    local active=b.mode~="idle" or build.mode=="preview" or build.mode=="move"
    self.toolbar:SetVisible(not self.v3 and active)
    local texts={"确认摆放","反转方向","类型：基础带","取消布置"}
    local focused=b.mode=="adjust" and b.focus=="buttons" and b.button or (build.confirmFocus and 1 or 0)
    for i,button in ipairs(self.buttons) do
        button:SetVisible(b.mode=="adjust" or (b.mode=="idle" and i==1) or i==4)
        button:SetText((focused==i and "已选 · " or "")..texts[i])
    end
    local hint=""
    if b.mode=="adjust" and b.plan then
        hint=(b.editing and "编辑中：WASD移动，F结束" or "选取中：WASD按画面方向选节点/路段，F编辑").." · Tab切换按钮 · "..b.plan.reason
    elseif b.mode~="idle" then hint=b.mode=="source" and "选择输出建筑 A：WASD移动光标，F或左键选建筑" or "选择输入建筑 B：WASD移动光标，F或左键选建筑"
    elseif active then hint=(build.previewPinned and "投影已固定：空白处左键解除；WASD仍可微调" or "鼠标定位，场景左键固定投影").." · R旋转 · Tab选确认/F摆放" end
    self.hint:SetText(hint)
    if self.bufferId then
        local storage=self.buffers[self.bufferId]
        local item=storage and storage.slots[self.slot]
        if self.selectedToken and (item and item.id or 0)~=self.selectedToken then
            self.selectedToken=nil; self.context.feedback("选中物品已被传送带取走或更新，请WASD重新选择。")
        end
    end
    self.world:Update(self.network,b,self.context.stations(),self.buffers,self.context.area()=="workshop",self.selectedBelt,self.bufferId,self.slot)
end

function Control:Prompt()
    if self.bufferId then
        local storage=self.buffers[self.bufferId]; local item=storage and storage.slots[self.slot]
        return "缓存台 槽"..self.slot.."/6："..(item and Definitions[item.itemType].name or "空").." · WASD选槽 · F取出/交换/存入 · 右键/ESC取消"
    end
    if self.builder.mode~="idle" then return self.hint:GetText() end
    if self.selectedBelt then return "选中传送带 #"..self.selectedBelt.." · Q拆除整条带（有货按队列落地） · 右键取消选择" end
    return nil
end

function Control:Stop() self.world:Stop() end
return Control
