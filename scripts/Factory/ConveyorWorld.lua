local G = require("Factory/ConveyorGeometry")
local Network = require("Factory/ConveyorNetwork")
local Definitions = require("Factory/Items").Definitions
local StaticArt=require('Factory/StaticArt')
---@class FactoryConveyorWorld
---@field network FactoryConveyorNetwork?
---@field root Node
---@field makeBox function
---@field static Node?
---@field preview Node?
---@field inventory Node?
---@field cargo table<integer,Node>
---@field signature string
---@field previewSignature string
---@field inventorySignature string
local World = {}
World.__index = World

---@param root Node
---@param makeBox function
---@return FactoryConveyorWorld
function World.New(root, makeBox)
    return setmetatable({root=root,makeBox=makeBox,cargo={},signature="",previewSignature="",inventorySignature=""},World)
end

function World:Box(parent,name,x,y,z,w,h,d,color)
    return self.makeBox(parent,name,Vector3(x,y,z),Vector3(w,h,d),color,false)
end

---@param plan FactoryConveyorPlan
---@param parent Node
---@param preview boolean
---@param selected boolean
function World:Draw(plan,parent,preview,selected)
    local color = preview and (plan.valid and Color(0.15,0.78,0.4) or Color(0.95,0.15,0.17))
        or (selected and Color(0.95,0.7,0.15) or Color(0.16,0.28,0.32))
    for _,r in ipairs(Network.Rects(plan)) do self:Box(parent,"Belt",r.x,preview and 0.15 or 0.09,r.z,r.width,0.09,r.depth,color) end
    if preview and self.network and not plan.valid then
        for _,cell in ipairs(plan.cells) do
            if not self.network.context.free(cell.x,cell.z,0.8,0.8) or not self.network:Clear(cell.x,cell.z,0.8,0.8) then
                self:Box(parent,"ConflictCell",cell.x,1.13,cell.z,0.82,0.025,0.82,Color(0.96,0.12,0.15))
            end
        end
    end
    for distance=0.35,plan.length-0.15,1 do
        local x,z,dx,dz=G.Position(plan.points,distance)
        local arrow=self:Box(parent,"Direction",x,0.22,z,0.22,0.025,0.22,Color(0.96,0.84,0.3))
        arrow.rotation=Quaternion(45,Vector3.UP)
        local length=math.abs(dx)+math.abs(dz)
        if length>0 then self:Box(parent,"ArrowTail",x-dx/length*0.16,0.21,z-dz/length*0.16,
            math.abs(dx)>0 and 0.3 or 0.07,0.025,math.abs(dz)>0 and 0.3 or 0.07,Color(0.96,0.84,0.3)) end
    end
end

---@param station FactoryStation
---@param index integer
---@return number,number
function World.SlotPosition(station,index)
    local dx,dz=((index-1)%2-0.5)*0.64,(1-math.floor((index-1)/2))*0.56
    local q=station.quarter or 0
    if q==1 then dx,dz=-dz,dx elseif q==2 then dx,dz=-dx,-dz elseif q==3 then dx,dz=dz,-dx end
    return station.x+dx,station.z+dz
end

---@param network FactoryConveyorNetwork
---@param builder FactoryConveyorBuilder
---@param stations FactoryStation[]
---@param buffers table<string,FactoryBufferStorage>
---@param visible boolean
---@param selectedBelt integer?
---@param bufferId string?
---@param slot integer
function World:Update(network,builder,stations,buffers,visible,selectedBelt,bufferId,slot)
    self.network=network
    local signature=tostring(network.revision)..":"..tostring(selectedBelt)
    if signature~=self.signature then
        if self.static then self.static:Remove() end
        self.static=self.root:CreateChild("ConveyorBeds")
        for _,belt in ipairs(network.belts) do self:Draw(belt,self.static,false,belt.id==selectedBelt) end
        self.signature=signature
    end
    assert(self.static).enabled=visible
    local previewSignature=tostring(builder.revision)..":"..builder.focus..":"..builder.selected..":"..tostring(builder.handle)
    if previewSignature~=self.previewSignature then
        if self.preview then self.preview:Remove() end
        self.preview=self.root:CreateChild("ConveyorPreview")
        local plan=builder.plan or builder.hoverPlan
        if plan then self:Draw(plan,self.preview,true,false) end
        if builder.mode=="adjust" and builder.plan then
            local points=G.Simplify(builder.plan.cells)
            for i,point in ipairs(points) do
                self:Box(self.preview,"CornerHandle",point.x,0.3,point.z,0.26,0.08,0.26,
                    builder.handle and i==builder.selected and Color(1,1,1) or Color(0.2,0.7,1))
            end
            for _,candidate in ipairs(builder:Targets()) do
                if not candidate.handle then self:Box(self.preview,"SegmentHandle",candidate.x,0.29,candidate.z,0.13,0.06,0.13,Color(0.2,0.65,0.8)) end
            end
            if not builder.handle and points[builder.selected+1] then
                local a,b=points[builder.selected],points[builder.selected+1]
                self:Box(self.preview,"SelectedSegment",(a.x+b.x)/2,0.31,(a.z+b.z)/2,0.3,0.1,0.3,Color(1,1,1))
            end
        elseif builder.mode~="idle" then
            self:Box(self.preview,"BuildingCursor",builder.cursor.x,1.14,builder.cursor.z,0.65,0.04,0.65,Color(0.2,0.85,1))
        end
        self.previewSignature=previewSignature
    end
    assert(self.preview).enabled=visible
    -- Offscreen simulation still runs. No cargo positions/meshes are updated there.
    if visible then
        local alive={}
        for _,belt in ipairs(network.belts) do for _,cargo in ipairs(belt.cargo) do
            alive[cargo.id]=true
            local node=self.cargo[cargo.id]
            if not node then
                local c=Definitions[cargo.itemType].color
                node=self:Box(self.root,"Cargo_"..cargo.itemType,0,0,0,0.3,0.22,0.3,Color(assert(c[1]),assert(c[2]),assert(c[3])))
                self.cargo[cargo.id]=node
            end
            local x,z=G.Position(belt.points,cargo.distance)
            node.position=Vector3(x,0.38,z); node.enabled=true
        end end
        for id,node in pairs(self.cargo) do if not alive[id] then node:Remove(); self.cargo[id]=nil end end
    else for _,node in pairs(self.cargo) do node.enabled=false end end
    local invSignature=tostring(bufferId)..":"..slot
    for _,station in ipairs(stations) do
        local storage=buffers[station.id]
        if storage or station.buildingKind then
            invSignature=invSignature..station.id..":"..station.x..":"..station.z..":"..tostring(station.quarter)..tostring(station.component)
            if storage then for i=1,storage.capacity do local item=storage.slots[i]; invSignature=invSignature..":"..(item and item.id or 0) end end
        end
    end
    if visible and invSignature~=self.inventorySignature then
        if self.inventory then self.inventory:Remove() end
        self.inventory=self.root:CreateChild("LogisticsFixtures")
        for _,station in ipairs(stations) do
            local storage=buffers[station.id]
            if storage and station.component then
                local badge=StaticArt.Quad(self.inventory,'AttachedComponentArt',station.component=='order' and 'order_badge' or 'delivery_badge',0.65,0.65,1.62)
                if badge then badge.position=Vector3(station.x+(station.buildingKind=='buffer' and 0.83 or 0),0,station.z+(station.buildingKind=='buffer' and 0 or 0.85)) end
                local color=station.component=='order' and Color(0.2,0.65,1) or Color(1,0.7,0.2)
                if station.buildingKind=='buffer' then
                    -- Keep all six slot faces unobscured; the component uses the rim.
                    self:Box(self.inventory,'ComponentBase',station.x+0.83,1.13,station.z,0.18,0.10,1.3,Color(0.12,0.17,0.2))
                    self:Box(self.inventory,'ComponentScreen',station.x+0.83,1.20,station.z,0.12,0.03,1.0,color)
                else
                    self:Box(self.inventory,'ComponentBase',station.x,1.38,station.z+0.35,0.9,0.18,0.55,Color(0.12,0.17,0.2))
                    self:Box(self.inventory,'ComponentScreen',station.x,1.5,station.z+0.35,0.72,0.06,0.38,color)
                end
            end
            if storage and station.buildingKind=="storage" then
                local count=storage:Count()
                local level=count<=8 and 1 or count<=16 and 2 or 3
                for i=1,3 do
                    self:Box(self.inventory,"InventoryLoad",station.x+(i-2)*0.4,1.08,station.z,0.32,0.06,0.55,
                        i<=level and (level==3 and Color(0.95,0.55,0.2) or Color(0.4,0.85,0.65)) or Color(0.15,0.2,0.22))
                end
                local label=self.inventory:CreateChild("InventoryLoadText")
                label.position=Vector3(station.x,1.18,station.z-0.6)
                local text=label:CreateComponent("Text3D")
                text:SetFont("Fonts/MiSans-Regular.ttf",24); text:SetText(storage:LoadText())
                text:SetAlignment(HA_CENTER,VA_CENTER); text.faceCameraMode=FC_ROTATE_XYZ; text.fixedScreenSize=false
                text.color=Color(1,1,1); text.textEffect=TE_STROKE; text.effectColor=Color(0.04,0.05,0.06); text.effectStrokeThickness=2
                local height=text.worldBoundingBox.size.y
                if height>0.00001 then label.scale=Vector3.ONE*(0.27/height) end
            elseif storage then
                for i=1,6 do
                    local x,z=World.SlotPosition(station,i)
                    self:Box(self.inventory,"Slot",x,1.05,z,0.56,0.05,0.48,
                        bufferId==station.id and slot==i and Color(1,0.8,0.18) or Color(0.15,0.22,0.25))
                    local item=storage.slots[i]
                    if item then local c=Definitions[item.itemType].color; self:Box(self.inventory,"Stored_"..item.itemType,x,1.2,z,0.34,0.22,0.34,Color(assert(c[1]),assert(c[2]),assert(c[3]))) end
                end
            elseif station.buildingKind and station.buildingKind:find("isolator",1,true) then
                local endpoint={id=station.id,kind=station.buildingKind,quarter=station.quarter or 0}
                local channels={}
                for side=0,3 do
                    local key=Network.Channel(endpoint --[[@as FactoryConveyorEndpoint]],side)
                    channels[key]=channels[key] or {}
                    table.insert(channels[key],G.Directions[side+1])
                end
                for key,directions in pairs(channels) do
                    local c=key:sub(-1)=="0" and Color(0.2,0.8,1) or Color(1,0.55,0.2)
                    for _,dir in ipairs(directions) do self:Box(self.inventory,"IsolatedPort",station.x+dir.x*0.3,1.07,station.z+dir.z*0.3,0.18,0.05,0.18,c) end
                end
            elseif station.buildingKind=="junction" then
                self:Box(self.inventory,"JunctionNS",station.x,1.06,station.z,0.15,0.05,0.85,Color(0.9,0.9,0.65))
                self:Box(self.inventory,"JunctionEW",station.x,1.06,station.z,0.85,0.05,0.15,Color(0.9,0.9,0.65))
            end
        end
        self.inventorySignature=invSignature
    end
    if self.inventory then self.inventory.enabled=visible end
end

function World:Stop()
    if self.static then self.static:Remove() end
    if self.preview then self.preview:Remove() end
    if self.inventory then self.inventory:Remove() end
    for _,node in pairs(self.cargo) do node:Remove() end
    self.cargo={}
end
return World
