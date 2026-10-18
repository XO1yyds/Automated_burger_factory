-- V0.3 native integration checks. Uses workshop fixtures and real UI callbacks.
local Checks={}
function Checks.Run(items,buildings,orders,view,machines,context)
    local ui=context.ui; local c=ui.context.get(); local control=c.logistics
    local count,failed=0,0
    local function check(n,ok) count=count+1; if not ok then failed=failed+1 end; print('[Phase5-7 Route QA] '..(ok and 'PASS ' or 'FAIL ')..n) end
    local function refresh() control:Refresh(); ui:Update(0) end
    local function command(cmd,value) context.command(cmd,value); context.controls(); refresh() end
    local originalPreferences=ui.preferences; ui.preferences=require("Factory/UIState").DefaultPreferences(); ui:ApplyPreferences()
    items:Reset(); for _,machine in pairs(machines) do machine:Reset() end
    check('shop initial automated fixtures removed',machines.auto_grill==nil and machines.auto_assembly==nil)
    check('retained workshop fixtures exist',machines.ws_cooker~=nil and machines.ws_assembler~=nil)
    check('walk speed four sprint eight normalized',math.abs(context.velocity(1,1,false,false):Length()-4)<0.001 and math.abs(context.velocity(1,1,true,false):Length()-8)<0.001)
    check('blocked player velocity is zero',context.velocity(1,1,true,true):LengthSquared()==0)
    command('openBuild'); check('shop cannot enter construction',buildings.mode=='idle')
    assert(context.switch('workshop')); ui:OpenBuild(); refresh()
    local saved=ui.cameraSaved; local baseline=#buildings.records
    check('construction opens production category without placing',ui.category==1 and buildings.mode=='menu' and #buildings.records==baseline)
    check('enter construction captures camera once',saved~=nil and math.abs(ui.context.get().zoom-saved.zoom*0.9)<0.001)
    command('selectKind','assembler'); check('card only selects kind',ui.kind=='assembler' and buildings.mode=='menu' and #buildings.records==baseline)
    command('category',2); command('selectKind','junction'); command('enterKind')
    check('explicit enter button opens projection',buildings.mode=='preview' and #buildings.records==baseline)
    check('submode does not zoom repeatedly',ui.cameraSaved==saved)
    buildings:SetPosition(-46,-4); buildings.previewPinned=true; refresh()
    check('valid workshop projection accepted',buildings:Validate(c.player.position))
    check('scene pin never creates a real object',#buildings.records==baseline)
    check('unfocused direct F cannot place',not buildings:Confirm(c.player.position))
    local main=view.actions[#view.actionData]; assert(main.props.onClick)(main); context.controls(); refresh()
    check('real main button places exactly one object',#buildings.records==baseline+1)
    check('success retains fixed same-position projection',buildings.mode=='preview' and buildings.previewPinned)
    check('same-position repeat placement disabled',view.actions[#view.actionData]:IsDisabled())
    local record=buildings.records[#buildings.records]
    ui:Back(false); command('category',5); command('enterKind')
    ui:SelectManaged(record,nil); refresh()
    check('management selection does not enter move',buildings.mode=='manage' and ui:Phase()=='selected' and record.x==-46)
    check('demolition waits half second',view.actions[#view.actionData]:IsDisabled())
    command('moveManaged'); buildings:SetPosition(-44,-4); buildings:Rotate(); ui:Back(false); refresh()
    check('cancel movement preserves original entity',record.x==-46 and record.z==-4 and (record.quarter or 0)==0 and ui:Phase()=='selected')
    command('moveManaged'); buildings:SetPosition(-44,-4); command('confirmBuild')
    check('confirmed movement updates original object',record.x==-44 and record.z==-4 and buildings.mode=='manage')
    ui:SelectManaged(record,nil); ui:Update(0.6); command('deleteManaged')
    check('deletion continues management',#buildings.records==baseline and buildings.mode=='manage' and ui.selected==nil)
    ui:Back(true); ui:Back(true); refresh()
    check('exit construction restores camera',buildings.mode=='idle' and ui.cameraSaved==nil and math.abs(ui.context.get().zoom-saved.zoom)<0.001)
    -- Full A -> B -> adjust -> commit path uses the V0.3 world/controller actions.
    local added={}
    for _,x in ipairs({-45,-39}) do
        buildings:Choose("buffer",c.player.position,c.facing); buildings:SetPosition(x,-4); buildings.confirmFocus=true
        assert(buildings:Confirm(c.player.position)); table.insert(added,buildings.records[#buildings.records])
    end
    control:Open(); refresh()
    ui:WorldClick("source",Vector3(added[1].x,0,added[1].z),0,0); refresh()
    check("source click progresses to destination only",ui:Phase()=="destination" and control.builder.sourceId==added[1].id)
    control.builder:SetCursor(added[2].x,added[2].z); refresh()
    check("destination hover keeps a physical preview from A",control.builder.hoverPlan~=nil and control.builder.hoverPlan.from.id==added[1].id)
    ui:WorldClick("destination",Vector3(-48,0,-6),0,0); refresh()
    check("blank destination click never confirms B",ui:Phase()=="destination")
    ui:WorldClick("destination",Vector3(added[2].x,0,added[2].z),0,0); refresh()
    local builder=control.builder; local originalPlan=builder.plan; local beltCount=#control.network.belts
    check("valid B opens path tools with enabled confirmation",ui:Phase()=="adjust" and originalPlan.valid and not view.actions[#view.actionData]:IsDisabled())
    local selected=builder:SelectedTarget(); local px,py=ui:Project(selected.x,selected.z,0.3)
    local function pointer(phase,x,y) ui:QueuePointer(phase,{pointerId=21,pointerType="touch",x=x,y=y}) end
    pointer("down",px,py); pointer("up",px,py); ui:WorldEndFrame()
    check("first node tap selects without editing or placing",ui.nodeSelected and not builder.editing and #control.network.belts==beltCount)
    pointer("down",px,py); pointer("move",px,py-40); pointer("up",px,py-40); ui:WorldEndFrame()
    check("node drag release never commits belt",not builder.editing and #control.network.belts==beltCount)
    builder.plan=originalPlan; builder.revision=builder.revision+1; refresh()
    local segment=nil
    for _,candidate in ipairs(builder:Targets()) do if not candidate.handle then segment=candidate; break end end
    assert(segment)
    px,py=ui:Project(segment.x,segment.z,0.3)
    pointer("down",px,py); ui:WorldEndFrame()
    check("segment press selects and reserves input without moving",not builder.editing and ui.touch.objectId==21 and ui.drag.kind=="segment-wait")
    ui:QueuePointer("down",{pointerId=22,pointerType="touch",x=px,y=py}); ui:WorldEndFrame()
    check("second pointer cannot steal pending segment hold",ui.touch.objectId==21 and ui.drag and ui.drag.id==21 and not builder.editing)
    ui:QueuePointer("up",{pointerId=22,pointerType="touch",x=px,y=py}); ui:WorldEndFrame()
    ui:Update(0.34)
    check("segment cannot start before 350 milliseconds",not builder.editing)
    ui:Update(0.02)
    check("stationary 350 millisecond hold arms segment drag",builder.editing and not builder.handle and ui.drag.kind=="node")
    pointer("move",px,py-50); pointer("up",px,py-50); ui:WorldEndFrame()
    check("long segment drag ends without placing belt",not builder.editing and #control.network.belts==beltCount and ui.touch.objectId==nil)
    builder.plan=originalPlan; builder.revision=builder.revision+1; refresh()
    px,py=ui:Project(segment.x,segment.z,0.3)
    pointer("down",px,py); pointer("move",px+30,py); ui:WorldEndFrame(); ui:Update(0.4)
    check("moving early cancels hold instead of moving the segment",not builder.editing and ui.drag.kind=="segment-cancel" and builder.plan==originalPlan)
    pointer("up",px+30,py); ui:WorldEndFrame()
    pointer("down",px,py); ui:WorldEndFrame(); ui:FocusLost()
    check("focus loss cancels pending segment hold",ui.drag==nil and ui.touch.objectId==nil and not builder.editing)
    command("resume"); refresh()
    check("four directional controls removed from scene",rawget(view,"nudge")==nil and view.model.nudge==nil)
    builder.plan=originalPlan; builder.revision=builder.revision+1; refresh()
    command("confirmBelt")
    check("path confirmation places one and continues selecting A",#control.network.belts==beltCount+1 and ui:Phase()=="source")
    control.network:Remove(control.network.belts[#control.network.belts].id); control:Cancel()
    for _,record in ipairs(added) do buildings.selected=record; assert(buildings:DeleteSelected(c.player.position)) end
    buildings:Cancel(); refresh()
    local projectionContext=ui.context.get()
    local cameraPosition,originalZoom=projectionContext.cameraNode.position,projectionContext.zoom
    -- Restart creates this camera inside one synchronous QA call. The renderer
    -- has not yet supplied its main viewport aspect (the default is still 1).
    local originalAspect,originalAutoAspect=projectionContext.camera.aspectRatio,projectionContext.camera.autoAspectRatio
    projectionContext.camera.aspectRatio=graphics:GetWidth()/graphics:GetHeight()
    for _,pose in ipairs({{dx=0,dz=0,zoom=1},{dx=2,dz=-2,zoom=1},{dx=-1,dz=1,zoom=1.5}}) do
        projectionContext.cameraNode.position=cameraPosition+Vector3(pose.dx,0,pose.dz)
        ui.context.zoom(pose.zoom)
        local wx,wz=projectionContext.player.position.x+1,projectionContext.player.position.z+2
        local sx,sy=ui:Project(wx,wz,1.15)
        local scale=require("urhox-libs/UI").GetScale()
        local ray=projectionContext.camera:GetScreenRay(sx*scale/graphics:GetWidth(),sy*scale/graphics:GetHeight())
        local t=(1.15-ray.origin.y)/ray.direction.y
        local hit=(ray.origin+ray.direction*t) --[[@as Vector3]]
        check("engine ray matches world anchor pan="..pose.dx.." zoom="..pose.zoom,math.abs(hit.x-wx)<0.001 and math.abs(hit.z-wz)<0.001)
    end
    projectionContext.cameraNode.position=cameraPosition; ui.context.zoom(originalZoom)
    projectionContext.camera.aspectRatio=originalAspect; projectionContext.camera.autoAspectRatio=originalAutoAspect
    local zoomBefore=ui.context.get().zoom
    ui:QueuePointer("down",{pointerId=41,pointerType="touch",x=500,y=300})
    ui:QueuePointer("down",{pointerId=42,pointerType="touch",x=650,y=300})
    ui:QueuePointer("move",{pointerId=42,pointerType="touch",x=680,y=330})
    ui:WorldEndFrame()
    check("native camera receives two scene pointer pinch",ui.context.get().zoom~=zoomBefore)
    ui:FocusLost(); refresh()
    check("background clears all input and pauses",next(ui.touch.pointers)==nil and not ui.holdingInteraction and c.loop.state=="paused")
    command("resume")
    local function route(id) assert(context.aim(id)); return context.interact() end
    check('source dispatches real raw material',route('ws_raw') and items.held=='raw_beef')
    check('workshop cooking accepts real hand material',route('ws_cooker') and items.held==nil)
    machines.ws_cooker:Update(3); assert(route('ws_cooker')); assert(route('ws_assembler'))
    assert(route('ws_bun')); assert(route('ws_assembler')); assert(route('ws_lettuce')); assert(route('ws_assembler')); machines.ws_assembler:Update(2)
    check('complete workshop hand route produces burger',route('ws_assembler') and items.held=='burger')
    items:Reset()
    local storage=control.buffers.ws_buffer; storage.slots={}; storage:Receive('burger'); control:OpenBuffer('ws_buffer'); refresh()
    check('buffer first entry does not transfer',storage:Count()==1 and items.held==nil)
    control:SelectSlot(1); refresh(); check('select occupied slot only selects',storage:Count()==1 and items.held==nil and view.actionData[1].text=='取出')
    command('bufferConfirm'); check('explicit buffer button retrieves then exits',items.held=='burger' and storage:Count()==0 and control.bufferId==nil)
    control:OpenBuffer('ws_buffer'); control:SelectSlot(2); command('bufferConfirm')
    check('empty slot manual deposit supported',items.held==nil and storage.slots[2].itemType=='burger')
    items:Give('bun'); control:OpenBuffer('ws_buffer'); control:SelectSlot(2); command('bufferConfirm')
    check('occupied slot exchanges real held material',items.held=='burger' and storage.slots[2].itemType=='bun')
    items:Reset(); control:OpenBuffer('ws_buffer'); control:SelectSlot(2)
    local kind,token=storage:PeekOutput(); storage:TakeOutput(kind,token); refresh()
    check('concurrent belt output invalidates selected token',control.selectedToken==nil and view.actions[1]:IsDisabled())
    command('bufferConfirm'); check('stale confirmation cannot duplicate',items.held==nil and storage:Count()==0)
    ui:Back(false); refresh()
    orders.active={{id=101,required=3,delivered=0},{id=102,required=1,delivered=0}}; orders.stock=1; orders.selectedId=nil
    command('ordersToggle'); command('selectRow',1); command('deliver')
    check('order browser selects but cannot deliver',orders.selectedId==101 and orders.stock==1)
    ui:Back(false); assert(context.switch('shop')); assert(context.aim('cashier')); assert(context.interact()); refresh()
    check('cashier retains still-valid browsed order',orders.selectedId==101)
    command('deliver'); check('cashier partially delivers without false completion',orders.active[1].delivered==1 and orders.stock==0 and orders.completed==0)
    check('cashier end stays disabled before zero',view.model.modal.buttons[1].disabled)
    ui:Back(false); assert(context.aim("raw")); refresh()
    ui:WorldClick("normal",Vector3(5.3,0,5.8),0,0)
    check("explicit in-range target wins nearest automatic target",ui.context.get().target and ui.context.get().target.id=="bun")
    ui:WorldClick("normal",Vector3(-46,0,5),0,0)
    check("explicit click cannot remotely interact with workshop source",not ui.inspectId or ui.context.get().target.id~="ws_raw")
    assert(context.aim("grill")); c.manual:Reset(); items:Reset(); items:Give("raw_beef"); assert(context.interact())
    c.manual:UpdateGrill(0,true,false,false); refresh()
    command("interactionHold",true)
    c.manual:UpdateGrill(3,true,ui.holdingInteraction,false)
    command("interactionHold",false); command("interactUI")
    check("releasing completed touch hold does not retrieve meat",c.manual.grillItem=="cooked_beef" and items.held==nil)
    command("interactionHold",true); command("interactionHold",false); command("interactUI")
    check("next complete interaction retrieves cooked meat",items.held=="cooked_beef")
    items:Reset(); items:Give('burger'); assert(context.aim('trash')); assert(context.interact())
    check('trash deletes real held burger',items.held==nil)
    command('pause'); command('settings'); command('preference','display'); command('preference','scaleUp')
    check('settings updates only UI preferences',ui.preferences.display=='keyboard' and math.abs(ui.preferences.uiScale-1.1)<0.001 and c.loop.state=='paused')
    local prefs=require('Factory/UIPreferences')
    check('UI preferences persist and reload on native host',prefs.Save(ui.preferences) and prefs.Load().display==ui.preferences.display and math.abs(prefs.Load().uiScale-ui.preferences.uiScale)<0.001)
    command('preference','defaults'); ui:Back(false); command('statistics')
    check('statistics separates actual data and device rules',view.model.modal.lines[1]=='运行数据 · 全项目 / 当前时刻' and view.model.modal.lines[9]=='设备说明（静态规则）')
    ui:Back(false); command('resume'); refresh()
    check('resume restores normal state',ui:Phase()=='normal')
    ui.preferences=originalPreferences; ui:SavePreferences()
    print('[Phase5-7 Route QA] COMPLETE checks='..count..' failures='..failed)
    return {passed=count-failed,failed=failed}
end
return Checks
