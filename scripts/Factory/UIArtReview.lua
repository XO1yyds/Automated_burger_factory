-- Opt-in native UI review. Requires the isolated StaticArtChecks save namespace.
-- No extra Update subscription, production save writes or gameplay service changes.
local UI=require('urhox-libs/UI')
local Review={}
function Review.Run(c,r,h,fixture)
    local ui=h.ui(); local view=ui.view
    local pages={'normal','menu','terminal','paused','settings','briefing','cashier','settlement','complete','title'}
    local page=1
    ---@type number
    local ratio=1.0
    local render=view.Render
    local pending=0; local signature=''
    ---@type function?
    local record
    view.Render=function(self,model)
        -- Observe the real viewport; never override the production dimensions/root.
        render(self,model)
        local key=model.phase..':'..model.width..':'..model.height..':'..ratio..':'..tostring(model.modal and model.modal.scrollKey)
        if key~=signature then signature=key; pending=0 end
        pending=pending+1
        if pending==20 and record then record() end
    end
    record=function()
        local model=view.model; local rows={phase=ui:Phase(),canvas={model.width,model.height,ratio},liveViewport=true,widgets={},actions={},problems={}}
        for _,name in ipairs({'modalPanel','modalTitle','modalTabs','modalScroll','modalFooter','actionBar','clockPanel','campaignStatusPanel','selector'}) do
            local widget=view[name]; local rect=widget:GetAbsoluteLayout(); rows.widgets[name]=rect
            if widget:IsVisible() and rect.w>0 and rect.h>0 and (rect.x< -1 or rect.y< -1 or rect.x+rect.w>model.width+1 or rect.y+rect.h>model.height+1) then rows.problems[#rows.problems+1]='outside viewport: '..name end
        end
        rows.actions={}
        for i,b in ipairs(view.actions) do if view.actionData[i] then rows.actions[#rows.actions+1]={command=view.actionData[i].command,rect=b:GetAbsoluteLayout()} end end
        print('[UIArtReview] '..cjson.encode(rows))
    end
    local function show()
        c.loop.state='preparation'; c.loop.briefing=false; c.loop.teaching=false
        ui.overlay=nil; ui.ordersOpen=false; ui:Release(); c.buildings:Cancel(); c.logistics:Cancel(); c.automation:Close()
        local p=pages[page]
        if p=='menu' then ui:OpenBuild()
        elseif p=='terminal' then c.automation:OpenTerminal(fixture.stock)
        elseif p=='paused' then c.loop.state='paused'; c.loop.pausedFrom='preparation'
        elseif p=='briefing' then c.loop.briefing=true
        elseif p=='normal' then
        elseif p=='title' then c.loop.state='title'
        elseif p=='settlement' or p=='complete' then
            c.loop.history={{day=1,total=4,delivered=4,goal=4,orders=2,manual=4,automatic=0,rate=1,coins=100,income=50,spent=0,achieved=true},
                {day=5,total=18,delivered=16,goal=16,orders=6,manual=2,automatic=16,rate=4,coins=260,income=190,spent=90,achieved=true},
                {day=10,total=40,delivered=40,goal=40,orders=10,manual=0,automatic=40,rate=8,coins=600,income=470,spent=130,achieved=true}}
            c.loop.state=p
        else ui.overlay=p end
        ui:Update(0); print('[UIArtReview] PAGE '..p..' / live viewport')
    end
    local controls=UI.Panel{position='absolute',right=12,top=125,width=128,gap=12,zIndex=999,
        children={UI.Button{text='QA 下一页',height=48,onClick=function()page=page%#pages+1;show()end},
            UI.Button{text='QA 缩放',height=48,onClick=function()ratio=ratio==1 and 1.2 or 1;UI.SetScale(function()return UI.Scale.DEFAULT()*ratio end);ui:Update(0)end},
            UI.Button{text='QA 记录',height=48,onClick=record}}}
    view.root:AddChild(controls); show()
end
return Review
