-- Shared presentation skin. Commands and game state remain in their services.
local UI=require('urhox-libs/UI')
local Art={Root='image/v04_ui/runtime/'}
Art.Ink={42,48,50,255}; Art.Muted={83,98,101,255}; Art.White={255,249,229,255}
local transparent={0,0,0,0}
-- Some runtime versions visit zero-size descendants of display:none parents.
-- Nine-slice corners must not draw outside those collapsed boxes.
local function guardCollapsed(widget)
    local render=widget.Render
    widget.Render=function(self,nvg)
        local rect=self:GetAbsoluteLayout()
        if rect.w<=0 or rect.h<=0 then return end
        return render(self,nvg)
    end
    return widget
end
function Art.Path(key) return Art.Root..key..'.png' end
function Art.Panel(props,key)
    props.backgroundColor=transparent; props.backgroundImage=Art.Path('frame_'..(key or 'card'))
    props.backgroundFit='sliced'; local inset=({main=32,status=24,tooltip=24})[key or 'card'] or 12; props.backgroundSlice={inset,inset,inset,inset}
    props.borderRadius=12; props.gap=props.gap or 8
    return guardCollapsed(UI.Panel(props))
end
function Art.Label(text,size)
    return UI.Label{text=text or '',fontSize=(size or 18)*0.75,fontColor=Art.Ink,width='100%',height=28,
        lineHeight=1.22,whiteSpace='normal',flexShrink=0,pointerEvents='none'}
end
function Art.Button(text,click)
    local b=UI.Button{text=text,onClick=click,height=48,minWidth=48,fontSize=13.5,minFontSize=12,paddingHorizontal=16,
        textColor=Art.Ink,disabledTextColor={100,110,110,255},backgroundColor=transparent,hoverBackgroundColor=transparent,
        pressedBackgroundColor=transparent,disabledBackgroundColor=transparent,backgroundImage=Art.Path('frame_button'),
        backgroundFit='sliced',backgroundSlice={12,12,12,12},borderRadius=10,
        hoverBackgroundImageOpacity=0.88,pressedBackgroundImageOpacity=0.75,disabledBackgroundImageOpacity=0.42,
        pressedPadding={9,16,5,16},hoverBorderWidth=2,borderColor={44,115,127,255}}
    return guardCollapsed(b)
end
local icons={back='back',pause='pause',resume='play',ordersToggle='orders',openBuild='build',rotateUI='rotate',rotateManaged='rotate',
    moveManaged='move',deleteManaged='delete',manageCables='cable',manageDevices='build',reverseUI='reverse',networkInfo='network',
    confirmBuild='confirm',confirmBelt='confirm',confirmAttachment='confirm',cableConfirm='confirm',terminalSubmit='confirm',deliver='confirm',
    beginTrading='play',loadGame='play',newGame='play',nextDay='play',saveTitle='save',settings='settings',lesson='help',dayBriefing='help',
    statistics='tasks',exitGame='close',terminalCancel='close',terminalHistory='tasks',terminalDetails='help',overview='network',cameraPlayer='back'}
local primary={interactUI=true,enterKind=true,confirmBuild=true,confirmBelt=true,confirmAttachment=true,cableConfirm=true,
    terminalSubmit=true,terminalWithdraw=true,bufferConfirm=true,deliver=true,loadGame=true,beginTrading=true,nextDay=true,confirmYes=true,resume=true}
local danger={deleteManaged=true,exitGame=true,pauseEnd=true,terminalCancel=true}
function Art.Icon(command,value)
    if command=='terminalQuantity' then return value<0 and 'minus' or 'plus' end
    if command=='terminalTab' then return ({products='orders',inventory='stock',network='network',tasks='tasks'})[value] end
    return icons[command]
end
function Art.IconPath(key)
    if key=='save' or key=='stock' then return 'image/v04_static/runtime/'..(key=='save' and 'save_icon' or 'stock_icon')..'.png' end
    return Art.Path('icon_'..key)
end
function Art.Apply(b,data,selected)
    local command=data.command or ''
    local tint=primary[command] and {255,190,98,255} or danger[command] and {255,175,161,255} or {220,241,240,255}
    if selected then tint={143,216,226,255} end
    b:SetStyle({imageTint=tint,borderWidth=selected and 3 or 0,borderColor={38,112,125,255},textColor=Art.Ink})
    local key=Art.Icon(command,data.value)
    if not b.factoryIcon then
        b.factoryIcon=UI.Panel{position='absolute',left=10,top=12,width=24,height=24,backgroundFit='contain',pointerEvents='none'}
        b:AddChild(b.factoryIcon)
    end
    b.factoryIcon:SetVisible(key~=nil)
    if key then b.factoryIcon:SetStyle({backgroundImage=Art.IconPath(key)}) end
    b:SetStyle({paddingLeft=key and 42 or 16,paddingRight=16})
end
return Art
