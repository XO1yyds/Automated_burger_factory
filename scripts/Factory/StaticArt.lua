-- Pure presentation on the accepted V0.6 simulation. No inventory/task/save state.
local Art={}
Art.Root='image/v04_static/runtime/'
local materials={}
local missing={}
local actors={}
local Animation=require('Factory/CharacterAnimation')
local CharacterFrames=require('Factory/CharacterFrames')
local characterMaterials={}
-- The locked top-down camera looks down Y. Keep the paper above machine tops
-- (world Y ~1.02), without raising the actor/collider or moving its XZ pivot.
local PLAYER_PAPER_Y=1.10
local HELD_LAYER_OFFSET=PLAYER_PAPER_Y-.10
local bases={cooker='cooker_top',assembler='assembler_top',buffer='buffer_top',storage='storage_top',
    isolator_straight='supply_top',isolator_corner='supply_top',
    supply_raw='supply_top',supply_bun='supply_top',supply_lettuce='supply_top',grill='manual_grill_top',assembly='manual_assembly_top',cashier='cashier_top',trash='trash_top'}
local sources={raw='raw_beef',bun='bun',lettuce='lettuce',ws_raw='raw_beef',ws_bun='bun',ws_lettuce='lettuce',
    supply_raw='raw_beef',supply_bun='bun',supply_lettuce='lettuce'}
function Art.Path(key) return Art.Root..key..'.png' end
local function warn(key)
    if not missing[key] then missing[key]=true;print('[StaticArt] Missing '..key..'; retaining whitebox fallback') end
end
function Art.Material(key,alpha,tint)
    local id=key..':'..tostring(alpha or 1)..':'..(tint and tostring(tint) or '')
    if materials[id] then return materials[id] end
    local texture=cache:GetResource('Texture2D',Art.Path(key))
    if not texture then warn(key);return nil end
    local material=Material:new()
    if not material:SetSurfaceShader('Shaders/BLGL/FactoryStaticArt.shader') then warn('shader');return nil end
    material:SetSurfaceTexture('art_map',texture)
    material:SetShaderParameter('art_tint',Variant(tint or Color(1,1,1,alpha or 1)))
    materials[id]=material
    return material
end
-- +Z is screen up in the locked orthographic camera; UV(0,0) is image top-left.
function Art.Quad(parent,name,key,width,depth,y,quarter,repeatX,repeatZ,alpha)
    local material=Art.Material(key,alpha)
    if not material then return nil end
    local node=parent:CreateChild(name)
    local geom=node:CreateComponent('CustomGeometry')
    geom:BeginGeometry(0,TRIANGLE_LIST)
    local corners={{-0.5,0.5,0,0},{-0.5,-0.5,0,1},{0.5,-0.5,1,1},{0.5,0.5,1,0}}
    for _,index in ipairs({1,2,3,1,3,4}) do
        local p=corners[index];local u,v=p[3],p[4]
        for _=1,(quarter or 0)%4 do u,v=1-v,u end
        geom:DefineVertex(Vector3(p[1]*width,y,p[2]*depth))
        geom:DefineNormal(Vector3.UP);geom:DefineTexCoord(Vector2(u*(repeatX or 1),v*(repeatZ or 1)))
    end
    geom:Commit();geom:SetMaterial(material);geom.castShadows=false
    return node
end
function Art.DecorateBox(node,name,size)
    local key=name:match('^Item_(.+)') or name:match('^Held_(.+)') or name:match('^StationItem_(.+)') or name:match('^Cargo_(.+)') or name:match('^Stored_(.+)')
    if key and ({bun=true,raw_beef=true,cooked_beef=true,lettuce=true,burger=true})[key] then
        -- Return the existing ownership node; only its drawable changes.
        local quad=Art.Quad(node,'ItemArt',key,1.55,1.55,0.55)
        if quad then local model=node:GetComponent('StaticModel');if model then model.enabled=false end end
    elseif name=='Floor' or name=='WorkshopFloor' then
        Art.Quad(node,'FloorArt',name=='Floor' and 'shop_floor' or 'workshop_floor',1,1,0.507,0,size.x/2,size.z/2)
    elseif name=='Belt' then
        Art.Quad(node,'BeltArt','belt_tile',1,1,0.56,size.x>size.z and 1 or 0,math.max(1,size.x),math.max(1,size.z))
    elseif name=='ComponentScreen' then
        -- Actual component identity is assigned where the station is available.
    elseif name:find('Wall',1,true) or name:find('WorkshopNorth',1,true) or name:find('WorkshopSouth',1,true) or name:find('WorkshopEast',1,true) or name:find('WorkshopWest',1,true) then
        local model=node:GetComponent('StaticModel')
        if model then
            local material=Material:new();material:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'))
            material:SetShaderParameter('MatDiffColor',Variant(Color(0.23,0.34,0.36)));model:SetMaterial(material)
        end
    end
end
function Art.Station(station)
    local body=station.visual
    if not body then return end
    local old=body:GetChild('StationArt');if old then old:Remove() end
    local kind=station.buildingKind or station.automaticKind or station.id
    local source=sources[kind] or sources[station.id]
    local key=bases[kind] or (source and 'supply_top')
    local q=station.quarter or 0
    if key then Art.Quad(body,'StationArt',key,1,1,0.516,q) end
    if station.highlight and not station.highlight:GetComponent('CustomGeometry') then
        local oldModel=station.highlight:GetComponent('StaticModel');if oldModel then oldModel.enabled=false end
        local rim=station.highlight:CreateComponent('CustomGeometry');rim:BeginGeometry(0,TRIANGLE_LIST)
        -- An outline leaves generated artwork and real processing slots visible.
        for _,r in ipairs({{-0.5,-0.5,0.5,-0.475},{-0.5,0.475,0.5,0.5},{-0.5,-0.475,-0.475,0.475},{0.475,-0.475,0.5,0.475}}) do
            for _,v in ipairs({{r[1],r[4]},{r[1],r[2]},{r[3],r[2]},{r[1],r[4]},{r[3],r[2]},{r[3],r[4]}}) do
                rim:DefineVertex(Vector3(v[1],0.6,v[2]));rim:DefineNormal(Vector3.UP)
            end
        end
        rim:Commit()
        local material=Material:new();material:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'))
        material:SetShaderParameter('MatDiffColor',Variant(Color(1,0.72,0.16)));rim:SetMaterial(material)
    end
    if source then
        local existing=body:GetChild('SupplyArt');if existing then existing:Remove() end
        Art.Quad(body,'SupplyArt',source,0.64,0.72,0.55,q)
    elseif station.destination then
        Art.Quad(body,'StationArt',station.destination=='workshop' and 'workshop_icon' or 'shop_icon',1.2/station.width,1.2/station.depth,0.55)
    elseif station.id=='depot' then
        Art.Quad(body,'StationArt','delivery_badge',0.23,0.7,0.55)
    elseif kind=='junction' then
        -- Real channel overlay continues to draw above this neutral rim.
        Art.Quad(body,'StationArt','junction_icon',0.94,0.94,0.516,q)
    end
end
function Art.Direction(x,z,previous)
    if math.abs(x)+math.abs(z)<0.001 then return previous or 'front' end
    local ax,az=math.abs(x),math.abs(z)
    if math.abs(ax-az)<0.12 and previous then return previous end
    return ax>az and (x<0 and 'left' or 'right') or (z>0 and 'back' or 'front')
end
local function playerUV(geom,frame)
    geom:BeginGeometry(0,TRIANGLE_LIST)
    local corners={{-.5,.5,0,0},{-.5,-.5,0,1},{.5,-.5,1,1},{.5,.5,1,0}}
    for _,i in ipairs({1,2,3,1,3,4}) do
        local p=corners[i];geom:DefineVertex(Vector3(p[1]*1.55,PLAYER_PAPER_Y,p[2]*1.55));geom:DefineNormal(Vector3.UP)
        geom:DefineTexCoord(frame and Vector2(((frame-1)*272+8+p[3]*256)/1088,(8+p[4]*256)/272) or Vector2(p[3],p[4]))
    end
    geom:Commit()
end
function Art.Player(actor,box,facing,held,editing)
    local state=actors[actor]
    if not state then state={direction='front',clock=Animation.New()};actors[actor]=state end
    local direction=Art.Direction(facing.x,facing.z,state.direction)
    if not state.node then
        state.node=Art.Quad(actor,'EmployeePaper','employee_'..direction,1.55,1.55,PLAYER_PAPER_Y)
        if not state.node then return end
        state.node.position=Vector3(0,0,1.55*(0.96875-0.5))
        local model=box:GetComponent('StaticModel');if model then model.enabled=false end
    end
    local opacity=editing and 0.25 or 1
    local clip=CharacterFrames[direction..'_'..state.clock.action]
    local frame=state.clock.frame
    local clipId=direction..'_'..state.clock.action..':'..opacity
    if clip and (clipId~=state.clipId or frame~=state.frame) then
        local material=characterMaterials[clipId]
        if not material then
            local texture=cache:GetResource('Texture2D',clip.atlas)
            if texture then
                material=Material:new()
                if material:SetSurfaceShader('Shaders/BLGL/FactoryStaticArt.shader') then
                    material:SetSurfaceTexture('art_map',texture)
                    material:SetShaderParameter('art_tint',Variant(Color(1,1,1,opacity)))
                    characterMaterials[clipId]=material
                else material=nil end
            end
        end
        if material then
            local geom=state.node:GetComponent('CustomGeometry')
            playerUV(geom,frame);geom:SetMaterial(material)
            state.clipId,state.frame=clipId,frame
        else
            warn('animation '..clipId)
            local fallback=Art.Material('employee_'..direction,opacity)
            if fallback then
                local geom=state.node:GetComponent('CustomGeometry');playerUV(geom);geom:SetMaterial(fallback)
            end
            state.clipId,state.frame=clipId,frame
        end
    elseif not clip and state.clipId~='fallback:'..direction..opacity then
        warn('animation config '..direction..'_'..state.clock.action)
        local geom=state.node:GetComponent('CustomGeometry')
        local material=Art.Material('employee_'..direction,opacity)
        if material then playerUV(geom);geom:SetMaterial(material) end
        state.clipId='fallback:'..direction..opacity
    end
    state.direction,state.opacity=direction,opacity
    if held then
        -- Hands sit in the upper half of the paper. Back-view cargo is behind
        -- the torso; the HUD still names it. No duplicate inventory entity.
        local socket=clip and clip.sockets and clip.sockets[frame]
        local dx=socket and (socket[1]-.5)*1.55 or (direction=='left' and -.34 or direction=='right' and .34 or 0)
        local dz=socket and (.96875-socket[2])*1.55 or (direction=='back' and .76 or .60)
        held.position=Vector3(dx,HELD_LAYER_OFFSET+(direction=='back' and -.04 or .16),dz)
        -- Per-owner item material avoids mutating shared ground/station artwork.
        local itemArt=held:GetChild('ItemArt')
        if itemArt and state.heldOpacity~=opacity then
            local key=held.name:match('^Held_(.+)')
            if key then itemArt:GetComponent('CustomGeometry'):SetMaterial(Art.Material(key,opacity)) end
        end
        state.heldOpacity=opacity
    end
end
function Art.AnimatePlayer(actor,box,facing,held,editing,dt,context)
    if not actors[actor] then Art.Player(actor,box,facing,held,editing) end
    local state=actors[actor]
    if not state then return end
    context.direction=Art.Direction(facing.x,facing.z,state.direction)
    Animation.Step(state.clock,dt,context)
    -- New held ownership must receive opacity even if the previous item had it.
    if state.held~=held then state.heldOpacity=nil;state.held=held end
    Art.Player(actor,box,facing,held,editing)
end
function Art.ResetPlayer(actor)
    local state=actors[actor];if state then Animation.Reset(state.clock);state.lastPosition=nil end
end
function Art.PlayerState(actor) return actors[actor] and actors[actor].clock end
function Art.Preview(node,kind,quarter)
    local key=bases[kind]
    if key then Art.Quad(node,'PreviewArt',key,0.96,0.96,0.515,quarter,nil,nil,0.45) end
end
function Art.Icon(kind)
    local icons={terminal='order_badge',delivery_component='delivery_badge',junction='junction_icon',conveyor='belt_tile',cable='order_badge',manage='stock_icon',supply_raw='raw_beef',supply_bun='bun',supply_lettuce='lettuce'}
    return Art.Path(icons[kind] or bases[kind] or kind)
end
function Art.Reset() actors={} end
function Art.Report() local n=0;for _ in pairs(materials) do n=n+1 end;return {materials=n,missing=missing} end
return Art
