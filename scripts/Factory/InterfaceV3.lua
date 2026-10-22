local UI=require("urhox-libs/UI")
local State=require("Factory/UIState")
local Projection=require("Factory/OrthographicView")
local Buildings=require("Factory/Buildings")
local StaticArt=require('Factory/StaticArt')
local Skin=require('Factory/UIArt')
local ArtLayout=require('Factory/UIArtLayout')
---@class FactoryInterface
---@field campaignStatus Label
---@field campaignStatusPanel Panel
---@field prompt Label
---@field feedback Label
---@field grill Label
---@field assembly Label
---@field cooker Label
---@field automaticAssembly Label
---@field depot Label
---@field dayStats Label
---@field selectedLabel Label
---@field clock Label
---@field held Label
---@field mode Label
---@field toast Label
---@field reason Label
---@field tutorial Label
---@field cardTitle Label
---@field cardBody Label
---@field modalTitle Label
---@field modalTabs Panel
---@field modalSummary Label
---@field modalQuantity Panel
---@field modalQuantityValue Label
---@field modalQuantityButtons Button[]
---@field modalQuantityData table[]
---@field modalEntries table[]
---@field modalEntryData table[]
---@field modalTabButtons Button[]
---@field modalTabData table[]
---@field audioRows table[]
---@field audioSyncing? boolean
---@field version Label
---@field lifecycleTitle Label
---@field lifecycleHint Label
---@field card Panel
---@field toastPanel Panel
---@field reasonPanel Panel
---@field tutorialPanel Panel
---@field clockPanel Panel
---@field modePanel Panel
---@field heldPanel Panel
---@field heldIcon Panel
---@field titleArt Panel
---@field actionBar Panel
---@field worldSurface Panel
---@field joystickKnob Panel
---@field joystickBase Panel
---@field joystick Panel
---@field selector Panel
---@field cardsRow Panel
---@field weakSelector Panel
---@field orderList Panel
---@field modalContent Panel
---@field modalTools Panel
---@field modalFooter Panel
---@field modalPanel Panel
---@field modalMask Panel
---@field root SafeAreaView
---@field buildPanel Panel
---@field managePanel Panel
---@field cashierPanel Panel
---@field lifecyclePanel Panel
---@field back Button
---@field pause Button
---@field orderSummary Button
---@field reselect Button
---@field modalBack Button
---@field cookerButton Button
---@field assemblerButton Button
---@field deliverButton Button
---@field cashierEndButton Button
---@field summaryButton Button
---@field restartButton Button
---@field exitButton Button
---@field tutorialClose Button
---@field dragMarker Panel
---@field actions Button[]
---@field tabs Button[]
---@field orderButtons Button[]
---@field orderLabels Label[]
---@field modalRows Label[]
---@field modalButtons Button[]
---@field footerButtons Button[]
---@field pauseButtons Button[]
---@field summaryLabels Label[]
---@field buildButtons table<string,Button>
---@field buildCardTitles table<string,Label>
---@field buildCardDetails table<string,Label>
---@field actionData table[]
---@field modalToolData table[]
---@field modalFooterData table[]
---@field content Panel
---@field orderScroll ScrollView
---@field orderRows Panel
---@field cardScroll ScrollView
---@field modalScroll ScrollView
---@field model table
---@field modalPhase string?
---@field onWorld function?
---@field onJoystick function?
---@field Render fun(self:FactoryInterface,model:table)
local View={}
View.__index=View

local function label(text,size) return Skin.Label(text,size) end
local function panel(props) return Skin.Panel(props) end
local function button(text,click) return Skin.Button(text,click) end

---@return FactoryInterface
function View.New(action)
    local self=setmetatable({action=action,category=1,actionData={},modalData={},focus=1},View) --[[@as FactoryInterface]]
    -- Legacy producers still write these labels. They no longer occupy the HUD.
    for _,name in ipairs({"prompt","feedback","grill","assembly","cooker","automaticAssembly","depot","dayStats","selectedLabel"}) do self[name]=label("") end
    self.clock=label("第1/10天 · 准备中",18); self.held=label("手持：空",17)
    self.mode=label("",20); self.mode:SetStyle({textAlign="center",height=48})
    self.toast=label("",17); self.reason=label("",16); self.tutorial=label("",16)
    self.cardTitle=label("",20); self.cardBody=label("",17)
    self.card=panel{position="absolute",width=260,padding=16,pointerEvents="none",zIndex=25,children={self.cardTitle,self.cardBody}}
    self.toastPanel=panel{position="absolute",left="26%",right="26%",bottom=124,padding=14,pointerEvents="none",zIndex=40,children={self.toast}}
    self.reasonPanel=panel{position="absolute",left=156,right=20,bottom=82,padding=8,pointerEvents="none",children={self.reason}}
    self.tutorialClose=button("知道了",function() action("tutorialClose") end)
    self.tutorialClose:SetStyle({position="absolute",right=0,top=0,width=88,height=48})
    self.tutorialPanel=Skin.Panel({position="absolute",left=156,right=20,top=72,padding=6,pointerEvents="auto",children={self.tutorial,self.tutorialClose}},'tooltip')
    self.back=button("返回",function() action("back") end)
    self.back:SetStyle({position="absolute",left=12,top=12,zIndex=30})
    self.pause=button("暂停",function() action("pause") end)
    self.pause:SetStyle({position="absolute",right=12,top=12,zIndex=30})
    self.orderSummary=button("待处理 0/5",function() action("ordersToggle") end)
    self.orderSummary:SetStyle({position="absolute",right=90,top=12,zIndex=30})
    self.clockPanel=Skin.Panel({position="absolute",left=88,top=12,width=218,height=48,padding=10,pointerEvents="none",children={self.clock}},'status')
    self.campaignStatus=label('',16)
    self.campaignStatusPanel=Skin.Panel({position='absolute',left=152,top=66,width=330,height=42,padding=8,pointerEvents='none',children={self.campaignStatus}},'status')
    self.campaignStatusPanel:AddChild(UI.Panel{position='absolute',left=5,top=6,width=28,height=28,backgroundImage=StaticArt.Path('coin_icon'),backgroundFit='contain',pointerEvents='none'})
    self.campaignStatus:SetStyle({paddingLeft=32,fontColor=Skin.White})
    self.clock:SetStyle({fontColor=Skin.White})
    self.modePanel=panel{position="absolute",left="32%",right="29%",top=12,padding=0,pointerEvents="none",children={self.mode}}
    self.heldPanel=panel{position="absolute",left=156,bottom=16,width=210,height=48,padding=10,pointerEvents="none",children={self.held}}
    self.heldIcon=UI.Panel{position='absolute',left=6,top=4,width=40,height=40,backgroundFit='contain',pointerEvents='none'}
    self.heldPanel:AddChild(self.heldIcon)

    self.actions={}
    self.actionBar=UI.Panel{position="absolute",right=12,bottom=16,flexDirection="row",gap=12,pointerEvents="box-none",zIndex=30}
    for i=1,6 do
        local index=i
        local control=button("",function()
            local data=self.actionData[index]
            if data and not data.disabled then action(data.command,data.value) end
        end)
        -- Button overrides do not forward pointer props: extend this instance,
        -- leaving the engine library untouched. Up/cancel always releases hold.
        local down,up,cancel=control.OnPointerDown,control.OnPointerUp,control.OnPointerCancel
        control.OnPointerDown=function(widget,event)
            down(widget,event)
            local data=self.actionData[index]
            if event:IsPrimaryAction() and data and data.command=="interactUI" and not data.disabled then widget.factoryHolding=true; action("interactionHold",true) end
        end
        control.OnPointerUp=function(widget,event)
            up(widget,event)
            if widget.factoryHolding then widget.factoryHolding=false; action("interactionHold",false) end
        end
        control.OnPointerCancel=function(widget,event)
            cancel(widget,event)
            if widget.factoryHolding then widget.factoryHolding=false; action("interactionCancel") end
        end
        self.actions[i]=control; self.actionBar:AddChild(control)
    end

    local function pointer(phase,event)
        if self.onWorld then self.onWorld(phase,event) end
    end
    self.worldSurface=UI.Panel{position="absolute",left=0,top=0,right=0,bottom=0,zIndex=-10,backgroundColor={0,0,0,0},
        onPointerDown=function(e) pointer("down",e) end,onPointerMove=function(e) pointer("move",e) end,
        onPointerUp=function(e) pointer("up",e) end,onPointerCancel=function(e) pointer("cancel",e) end}
    self.joystickKnob=UI.Panel{position="absolute",left=36,top=36,width=40,height=40,borderRadius=20,
        backgroundColor={247,175,68,245},pointerEvents="none"}
    self.joystickBase=UI.Panel{backgroundImage=Skin.Path('frame_joystick'),backgroundFit='contain',position="absolute",left=0,top=0,width=112,height=112,borderRadius=56,
        borderWidth=0,borderColor={172,174,176,255},backgroundColor={0,0,0,0},pointerEvents="none",children={self.joystickKnob}}
    local function joy(phase,e)
        if self.onJoystick then self.onJoystick(phase,e,self.joystick:GetAbsoluteLayout()) end
    end
    self.joystick=UI.Panel{position="absolute",left=16,bottom=16,width=112,height=112,pointerEvents="box-only",zIndex=35,
        children={self.joystickBase},onPointerDown=function(e) joy("down",e) end,onPointerMove=function(e) joy("move",e) end,
        onPointerUp=function(e) joy("up",e) end,onPointerCancel=function(e) joy("cancel",e) end}

    self.selector=panel{position="absolute",left=12,right=12,bottom=12,height=148,padding=6,zIndex=20}
    local tabs=UI.Panel{height=44,flexDirection="row",gap=6,pointerEvents="box-none"}
    self.tabs={}
    for i,name in ipairs(State.Categories) do
        local index=i
        local b=button(name,function() action("category",index) end); b:SetStyle({height=44,flexGrow=1})
        self.tabs[i]=b; tabs:AddChild(b)
    end
    self.cardScroll=UI.ScrollView{height=82,scrollX=true,scrollY=false,showScrollbar=true}
    self.cardsRow=UI.Panel{flexDirection="row",gap=8,flexShrink=0,height=94}
    self.cardScroll:AddChild(self.cardsRow); self.selector:AddChild(tabs); self.selector:AddChild(self.cardScroll)
    self.buildButtons={}; self.buildCardTitles={}; self.buildCardDetails={}
    for _,kind in ipairs({"cooker","assembler","junction","isolator_straight","isolator_corner","buffer","storage","terminal","delivery_component","conveyor","cable","manage","supply_raw","supply_bun","supply_lettuce"}) do
        local key=kind
        local name=Buildings.Definitions[kind] and Buildings.Definitions[kind].name or (kind=="conveyor" and "基础传送带" or kind=="cable" and "传物电缆" or "管理已有对象")
        local b=button(name,function() action("selectKind",key) end)
        b:SetStyle({width=204,height=90,fontSize=12})
        b:SetText("")
        local icon=UI.Panel{position='absolute',left=12,top=16,width=38,height=38,backgroundImage=StaticArt.Icon(kind),backgroundFit='contain',pointerEvents='none'}
        b:AddChild(icon)
        local title=label(name,16); title:SetStyle({position="absolute",left=58,top=10,width=136,height=42,whiteSpace="normal"})
        local detail=label("",14); detail:SetStyle({position="absolute",left=12,top=58,width=180,height=24,whiteSpace="nowrap",fontColor=Skin.Muted})
        b:AddChild(title); b:AddChild(detail)
        self.buildCardTitles[kind],self.buildCardDetails[kind]=title,detail
        self.buildButtons[kind]=b; self.cardsRow:AddChild(b)
    end
    self.weakSelector=panel{position="absolute",left=156,right=12,bottom=74,height=56,padding=4,zIndex=20}
    self.reselect=button("重选建筑",function() action("buildMenu") end); self.reselect:SetStyle({height=48})
    self.weakSelector:AddChild(self.reselect)

    self.orderButtons,self.orderLabels={},{}
    self.orderList=panel{position="absolute",right=90,top=66,width=300,maxHeight=330,padding=8,zIndex=45}
    self.orderScroll=UI.ScrollView{flexGrow=1,flexBasis=0,scrollY=true}
    self.orderRows=UI.Panel{width="100%",gap=6,flexShrink=0}
    self.orderScroll:AddChild(self.orderRows); self.orderList:AddChild(self.orderScroll)
    for i=1,6 do
        local index=i; self.orderLabels[i]=label("")
        self.orderButtons[i]=button("",function() action("selectRow",index) end)
        self.orderRows:AddChild(self.orderButtons[i])
    end
    self.modalTitle=label("",22); self.modalTitle:SetStyle({height=36})
    self.modalTabButtons={}; self.modalTabData={}
    self.modalTabs=UI.Panel{flexDirection="row",gap=8,flexShrink=0}
    for i=1,4 do
        local index=i
        local b=button("",function() local d=self.modalTabData[index]; if d and not d.disabled then action(d.command,d.value) end end)
        b:SetStyle({flexGrow=1,flexBasis=0}); self.modalTabButtons[i]=b; self.modalTabs:AddChild(b)
    end
    self.modalSummary=label('',19); self.modalSummary:SetStyle({height=32})
    self.modalQuantity=UI.Panel{flexDirection='row',gap=8,flexShrink=0,height=48,alignItems='center'}
    self.modalQuantityValue=label('',20); self.modalQuantityValue:SetStyle({width=70,height=32,textAlign='center'})
    self.modalQuantityButtons={}; self.modalQuantityData={}
    for i=1,4 do
        local index=i
        local b=button('',function() local d=self.modalQuantityData[index]; if d and not d.disabled then action(d.command,d.value) end end)
        b:SetStyle({flexGrow=1,flexBasis=0}); self.modalQuantityButtons[i]=b
        if i==3 then self.modalQuantity:AddChild(self.modalQuantityValue) end
        self.modalQuantity:AddChild(b)
    end
    self.modalRows={}; self.modalButtons={}; self.modalToolData={}; self.modalFooterData={}
    self.modalScroll=UI.ScrollView{flexGrow=1,flexBasis=0,scrollY=true}
    self.modalContent=UI.Panel{width="100%",gap=8,flexShrink=0}
    self.modalScroll:AddChild(self.modalContent)
    self.audioRows={}
    for i,key in ipairs({'masterVolume','musicVolume','effectsVolume'}) do
        local index=i
        local title=label('',18)
        local minus=button('−',function() action('audioStep',{key=key,delta=-.1}) end)
        local plus=button('+',function() action('audioStep',{key=key,delta=.1}) end)
        minus:SetStyle({width=52,minWidth=52,flexShrink=0});plus:SetStyle({width=52,minWidth=52,flexShrink=0})
        local slider=UI.Slider{value=80,min=0,max=100,step=1,flexGrow=1,flexBasis=0,height=48,thumbSize=26,trackHeight=8,
            onChange=function(_,v) if not self.audioSyncing then action('audioVolume',{key=key,volume=v/100}) end end,
            onChangeEnd=function() if not self.audioSyncing then action('audioCommit') end end}
        local row=UI.Panel{width='100%',gap=4,flexShrink=0,paddingTop=4,paddingBottom=8,children={title,
            UI.Panel{width='100%',flexDirection='row',alignItems='center',gap=8,children={minus,slider,plus}}}}
        self.audioRows[index]={panel=row,label=title,slider=slider,minus=minus,plus=plus}
        self.modalContent:AddChild(row);row:SetVisible(false)
    end
    for i=1,32 do local item=label("",17); self.modalRows[i]=item; self.modalContent:AddChild(item) end
    self.modalEntries={}; self.modalEntryData={}
    for i=1,20 do
        local index=i
        local heading=label('',18); local detail=label('',15)
        detail:SetStyle({fontColor=Skin.Muted})
        local texts=UI.Panel{flexGrow=1,flexBasis=0,gap=3,children={heading,detail}}
        local b=button('',function() local e=self.modalEntryData[index]; local d=e and e.action; if d and not d.disabled then action(d.command,d.value) end end)
        b:SetStyle({flexShrink=0,minWidth=72})
        local icon=UI.Panel{width=36,height=36,flexShrink=0,backgroundFit='contain',pointerEvents='none'}
        local line=panel{width='100%',padding=10,flexDirection='row',alignItems='center',flexShrink=0,gap=12,children={icon,texts,b}}
        self.modalEntries[i]={panel=line,heading=heading,detail=detail,button=b,icon=icon}; self.modalContent:AddChild(line)
    end
    self.modalTools=UI.Panel{width='100%',flexDirection='row',flexWrap='wrap',gap=8,flexShrink=0}
    self.modalContent:AddChild(self.modalTools)
    for i=1,32 do
        local index=i
        local b=button("",function() local d=self.modalToolData[index]; if d and not d.disabled then action(d.command,d.value) end end)
        self.modalButtons[i]=b; self.modalTools:AddChild(b)
    end
    self.modalFooter=UI.Panel{flexDirection="row",justifyContent="flex-end",gap=12}
    self.footerButtons={}
    for i=1,3 do
        local index=i
        local b=button("",function() local d=self.modalFooterData[index]; if d and not d.disabled then action(d.command,d.value) end end)
        self.footerButtons[i]=b; self.modalFooter:AddChild(b)
    end
    self.modalPanel=Skin.Panel({position="absolute",padding=24,gap=10,children={self.modalTitle,self.modalTabs,self.modalSummary,self.modalQuantity,self.modalScroll,self.modalFooter}},'main')
    self.titleArt=UI.Panel{position='absolute',left=0,top=0,right=0,bottom=0,backgroundImage=StaticArt.Path('title_bg'),backgroundFit='cover',pointerEvents='none'}
    self.modalMask=UI.Panel{position="absolute",left=0,top=0,right=0,bottom=0,zIndex=100,backgroundColor={21,35,39,165},children={self.titleArt,self.modalPanel}}
    self.version=label("自动化汉堡工厂 · "..State.Version,14)
    self.version:SetStyle({position="absolute",right=16,bottom=12,width=290,height=26}); self.modalMask:AddChild(self.version)
    self.modalBack=button("返回",function() action("back") end)
    self.modalBack:SetStyle({position="absolute",left=12,top=12}); self.modalMask:AddChild(self.modalBack)
    self.dragMarker=UI.Panel{position="absolute",width=12,height=12,borderRadius=6,borderWidth=2,borderColor={240,240,240,255},backgroundColor={35,35,35,210},pointerEvents="none",zIndex=40}
    -- Compatibility references retained for existing runtime checks/callers.
    self.buildPanel,self.managePanel,self.cashierPanel,self.lifecyclePanel=self.selector,self.card,self.modalPanel,self.modalMask
    self.cookerButton,self.assemblerButton=self.buildButtons.cooker,self.buildButtons.assembler
    self.deliverButton=button("交付",function() action("deliver") end)
    self.cashierEndButton=button("结束当天",function() action("cashierEnd") end)
    self.summaryLabels={label(""),label(""),label(""),label("")}
    self.lifecycleTitle,self.lifecycleHint=self.modalTitle,label("")
    self.pauseButtons={button("继续",function() action("resume") end),button("结束当天",function() action("pauseEnd") end),button("退出",function() action("exitGame") end)}
    self.summaryButton=button("下一天",function() action("nextDay") end)
    self.restartButton=button("重新开始",function() action("restart") end)
    self.exitButton=button("退出",function() action("exitGame") end)
    self.content=UI.Panel{width="100%",flexGrow=1,flexBasis=0,position="relative",pointerEvents="box-none",children={self.worldSurface,
        self.clockPanel,self.campaignStatusPanel,self.modePanel,self.orderSummary,self.pause,self.back,self.heldPanel,self.card,self.selector,
        self.weakSelector,self.actionBar,self.joystick,self.reasonPanel,self.toastPanel,self.tutorialPanel,self.orderList,self.dragMarker,self.modalMask}}
    self.root=UI.SafeAreaView{width="100%",height="100%",pointerEvents="box-none",children={self.content}}
    UI.SetRoot(self.root)
    for _,p in ipairs({self.selector,self.weakSelector,self.card,self.modalMask,self.orderList,self.reasonPanel,self.toastPanel,self.tutorialPanel}) do p:SetVisible(false) end
    return self
end

local function setData(buttons,data)
    for i,b in ipairs(buttons) do
        local d=data[i]; b:SetVisible(d~=nil)
        if d then b:SetText(d.text:gsub("%[F%] ",""):gsub("● ","")); b:SetDisabled(not not d.disabled); Skin.Apply(b,d,d.text:find("[F]",1,true)~=nil or d.text:find("●",1,true)~=nil); b:SetStyle({marginLeft=d.command=="deleteManaged" and 24 or 0}) end
    end
end

---@param self FactoryInterface
---@param model table
function View.Render(self,model)
    self.model=model
    local w,h=model.width,model.height; local layout=State.Layout(w,h)
    local art=ArtLayout.For(w,h,model.phase,model)
    self.clock:SetText(model.clock); self.held:SetText(model.held)
    self.heldIcon:SetVisible(model.heldType~=nil)
    if model.heldType then self.heldIcon:SetStyle({backgroundImage=StaticArt.Path(model.heldType)}) end
    self.held:SetStyle({paddingLeft=model.heldType and 38 or 0})
    self.titleArt:SetVisible(model.phase=='title' or model.phase=='complete')
    self.clock:SetStyle({height=28,whiteSpace="nowrap",fontSize=13.5})
    local narrow=art.narrow
    self.clockPanel:SetStyle({left=144,top=12,width=240,height=48,padding=10})
    self.campaignStatusPanel:SetStyle({left=narrow and 144 or 396,top=narrow and 66 or 12,width=math.min(338,w-170),height=48})
    self.modePanel:SetStyle({top=narrow and 120 or 68,left=144,right=12,height=48})
    self.mode:SetStyle({fontSize=13.5,height=30})
    self.mode:SetText(model.title or ''); self.modePanel:SetVisible(model.title~='' and not model.modal)
    self.clockPanel:SetVisible(not model.modal); self.pause:SetVisible(not model.modal)
    Skin.Apply(self.pause,{command='pause'}); Skin.Apply(self.back,{command='back'})
    Skin.Apply(self.orderSummary,{command='ordersToggle'})
    self.campaignStatusPanel:SetVisible(model.status~=nil and not model.modal)
    self.campaignStatus:SetText(model.status or '')
    self.tutorialPanel:SetStyle({top=art.tutorialTop,left=math.max(16,w-math.min(430,w-32)-16),right=16,width=math.min(430,w-32),padding=14})
    self.pause:SetStyle({width=124}); self.orderSummary:SetStyle({right=148}); self.orderSummary:SetWidthAuto()
    self.orderSummary:SetText(State.OrderSummary(model.orderCount,model.orderLimit)); self.orderSummary:SetVisible(model.normal or model.phase=="orders")
    self.back:SetVisible(model.back~=nil and not model.modal); if model.back then self.back:SetText(model.back) end
    self.heldPanel:SetVisible(not model.modal and model.phase~="menu")
    self.heldPanel:SetStyle({left=art.heldLeft,width=math.min(240,w-320),height=52,padding=12})
    self.joystick:SetVisible(model.normal and model.display~="keyboard")
    self.joystick:SetStyle({width=model.floating and 180 or 112,height=model.floating and 160 or 112})
    self.selector:SetVisible(model.phase=="menu")
    self.selector:SetStyle({height=art.selectorHeight,right=184,padding=10})
    self.cardScroll:SetHeight(art.selectorHeight-72)
    self.weakSelector:SetVisible(model.phase=="preview")
    for i,b in ipairs(self.tabs) do b:SetText(State.Categories[i]); Skin.Apply(b,{command="category",value=i},model.category==i) end
    for kind,b in pairs(self.buildButtons) do
        local visible=false
        for _,k in ipairs(State.Kinds[model.category]) do if k==kind then visible=true end end
        b:SetVisible(visible)
        local def=Buildings.Definitions[kind]
        local name=def and def.name or (kind=="conveyor" and "基础传送带" or kind=="cable" and "传物电缆" or "管理已有对象")
        b:SetText("")
        local selected=model.kind==kind
        b:SetStyle({borderWidth=selected and 3 or 0,borderColor={38,112,125,255},imageTint=selected and {166,228,231,255} or {255,255,255,255},height=art.cardHeight})
        self.buildCardDetails[kind]:SetStyle({top=art.compact and 48 or 60,fontSize=10.5})
        self.buildCardTitles[kind]:SetText(name)
        local detail=def and string.format("%.1f×%.1f格",def.width,def.depth) or (kind=="conveyor" and "单入单出 · 0.5格/s" or kind=="cable" and "下单驱动 · 整网2件/s" or "选择现有对象")
        if kind=='terminal' or kind=='delivery_component' then detail=kind=='terminal' and '依附库存 · 不另占地' or '依附库存/缓存 · 不另占地' end
        self.buildCardDetails[kind]:SetText((selected and "已选 · " or "")..detail)
        if model.campaign then self.buildCardDetails[kind]:SetText(model.campaign:Card(kind)) end
    end
    self.actionData=model.actions or {}; setData(self.actions,self.actionData)
    self.actionBar:SetVisible(not model.modal)
    self.actionBar:SetStyle({width=model.normal and 292 or model.phase=='menu' and 156 or math.min(760,w-172),height=(model.normal or model.phase=='menu') and 112 or 48,justifyContent='flex-end'})
    for i,b in ipairs(self.actions) do
        local d=self.actionData[i]
        if d then
            if model.normal then
                local lower=d.command=='interactUI' or d.command=='dropUI'
                local right=d.command=='interactUI' or d.command=='openBuild'
                b:SetStyle({position='absolute',left=right and 148 or 0,right=0,bottom=lower and 0 or 60,width=136,height=48,marginLeft=0})
            elseif model.phase=='menu' then b:SetStyle({position='absolute',left=0,right=0,bottom=(#self.actionData-i)*60,width=156,height=48,marginLeft=0})
            else b:SetStyle({position='relative',left=0,right=0,bottom=0,width=(math.min(760,w-172)-12*(#self.actionData-1))/#self.actionData,height=48,minWidth=104}) end
        end
    end
    self.reasonPanel:SetVisible(not model.modal and model.reason and model.reason~="" and (not model.normal or model.reasonCritical or (model.phaseAge or 0)<7))
    self.reason:SetText(model.reason or ""); self.reason:SetStyle({height=model.phase=='menu' and art.compact and 24 or 48,fontSize=12})
    self.reasonPanel:SetStyle({left=156,right=0,width=art.reasonWidth,bottom=model.normal and 140 or art.reasonBottom,padding=model.phase=='menu' and art.compact and 8 or 12})
    self.toastPanel:SetVisible(model.toast~=nil and model.toast~='')
    self.toast:SetText(model.toast or ''); self.toast:SetStyle({height=48})
    self.toastPanel:SetStyle({left=(w-art.toastWidth)/2,right=0,width=art.toastWidth,bottom=(model.phase=='preview' or model.phase=='move') and 214 or 150,zIndex=model.modal and 120 or 40})
    self.tutorial:SetText(model.tutorial or ''); self.tutorial:SetStyle({height=64,paddingRight=88,fontSize=12})
    self.tutorialPanel:SetVisible(not model.modal and model.tutorial and model.tutorial~='')
    self.orderList:SetVisible(model.phase=="orders")
    self.orderList:SetStyle({width=math.min(330,w-114),height=math.min(330,h-100),maxHeight=h-100})
    self.card:SetVisible(model.card~=nil and not model.modal)
    if model.card then
        self.cardTitle:SetText(model.card.title)
        if self.cardBody.props.text~=model.card.text then self.cardBody:SetText(model.card.text); self.cardBody:SetHeightAuto() end
        self.cardTitle:SetStyle({height=30})
        local cardHeight=math.max(90,self.card:GetAbsoluteLayout().h)
        local x,y=Projection.Card(model.card.anchorX,model.card.anchorY,layout.cardWidth,cardHeight,w,h,art.headerBottom,model.normal and 146 or 200)
        self.card:SetVisible(x~=nil)
        if x then self.card:SetStyle({width=layout.cardWidth,left=x,top=y}) end
    end
    self.dragMarker:SetVisible(model.dragMarker~=nil and not model.modal)
    if model.dragMarker then self.dragMarker:SetStyle({left=model.dragMarker.x-6,top=model.dragMarker.y-38}) end
    self.modalMask:SetVisible(model.modal~=nil)
    if model.modal then
        local m=model.modal
        self.modalPanel:SetStyle({left=(w-art.modalWidth)/2,top=art.modalTop,width=art.modalWidth,height=art.modalHeight,padding=32})
        self.modalFooter:SetStyle({flexWrap="wrap",gap=12,flexShrink=0})
        self.modalTitle:SetText(m.title)
        local scrollKey=model.phase..':'..(m.scrollKey or '')
        if self.modalPhase~=scrollKey then self.modalScroll:ScrollToTop(); self.modalPhase=scrollKey end
        self.modalTabs:SetVisible(m.tabs~=nil)
        self.modalTabData=m.tabs or {}; setData(self.modalTabButtons,self.modalTabData)
        for i,row in ipairs(self.audioRows) do
            local d=m.audio and m.audio[i];row.panel:SetVisible(d~=nil)
            if d then
                row.label:SetText(d.label..'  '..math.floor(d.volume*100+.5)..'%')
                local percent=math.floor(d.volume*100+.5)
                if row.slider:GetValue()~=percent then self.audioSyncing=true;row.slider:SetValue(percent);self.audioSyncing=false end
                for _,pair in ipairs({{row.minus,d.minus},{row.plus,d.plus}}) do pair[1]:SetText(pair[2].text);Skin.Apply(pair[1],pair[2],pair[2].text:find('[F]',1,true)~=nil) end
            end
        end
        self.modalSummary:SetVisible(m.summary~=nil); self.modalSummary:SetText(m.summary or '')
        self.modalQuantity:SetVisible(m.quantity~=nil)
        self.modalQuantityData=m.quantity and m.quantity.actions or {}; setData(self.modalQuantityButtons,self.modalQuantityData)
        if m.quantity then self.modalQuantityValue:SetText(tostring(m.quantity.value)) end
        self.modalEntryData=m.entries or {}
        for i,entry in ipairs(self.modalEntries) do
            local d=self.modalEntryData[i]; entry.panel:SetVisible(d~=nil)
            if d then
                entry.icon:SetVisible(d.itemType~=nil)
                if d.itemType then entry.icon:SetStyle({backgroundImage=StaticArt.Path(d.itemType)}) end
                for _,pair in ipairs({{entry.heading,d.text or ''},{entry.detail,d.detail or ''}}) do
                    local widget,text=pair[1],pair[2]
                    if widget.props.text~=text then widget:SetText(text); widget:SetHeightAuto() end
                end
                entry.detail:SetVisible(d.detail~=nil and d.detail~='')
                entry.button:SetVisible(d.action~=nil)
                if d.action then entry.button:SetText(d.action.text); entry.button:SetDisabled(not not d.action.disabled); Skin.Apply(entry.button,d.action) end
            end
        end
        for i,item in ipairs(self.modalRows) do
            local text=m.lines and m.lines[i]; item:SetVisible(text~=nil)
            if text then
                if item.props.text~=text then item:SetText(text); item:SetHeightAuto() end
            end
        end
        self.modalToolData=m.tools or {}; setData(self.modalButtons,self.modalToolData)
        self.modalTools:SetVisible(#self.modalToolData>0)
        for _,b in ipairs(self.modalButtons) do b:SetStyle({width=art.modalWidth>=580 and '48%' or '100%',minWidth=0}) end
        self.modalFooterData=m.buttons or {}; setData(self.footerButtons,self.modalFooterData)
        self.modalBack:SetVisible(m.back~=nil); if m.back then self.modalBack:SetText(m.back) end
        self.version:SetVisible(model.phase=="paused")
        Skin.Apply(self.modalBack,{command="back"})
    end
end

---@param self FactoryInterface
---@param machine FactoryAutomaticWorkstation?
function View.RefreshAutomatic(self,machine)
    self.cooker:SetVisible(machine==nil or machine.kind=="cooker"); self.automaticAssembly:SetVisible(machine~=nil and machine.kind~="cooker")
    if not machine then self.cooker:SetText("当前没有自动化设备")
    elseif machine.kind=="cooker" then self.cooker:SetText(machine:Status()) else self.automaticAssembly:SetText(machine:Status()) end
end
---@param self FactoryInterface
---@param loop FactoryGameLoop
function View.RefreshLoop(self,loop,selected)
    -- The controller owns the compact HUD clock; the diagnostic ClockText may
    -- contain a long end-of-day explanation that must not overwrite this label.
    self.cashierEndButton:SetDisabled(not loop:CanCashierEnd())
    self.dayStats:SetText(string.format("订单%d · 汉堡%d",loop.orders.completed,loop.manual+loop.automatic))
end
---@param self FactoryInterface
---@param book FactoryOrders
function View.RefreshOrders(self,book)
    self.depot:SetText("可交付汉堡 "..book:DeliveryCount())
    for i=1,6 do local o=book.active[i]
        local text=o and string.format("%s订单%02d · %d/%d",o.id==book.selectedId and "[已选] " or "",o.id,o.delivered,o.required) or ""
        self.orderLabels[i]:SetText(text); self.orderButtons[i]:SetText(text); self.orderButtons[i]:SetVisible(o~=nil)
    end
    self.deliverButton:SetDisabled(not book:CanDeliver())
end
---@param self FactoryInterface
function View.RefreshBuild(self,mode,kind) end -- V3 owns visibility atomically.

return View
