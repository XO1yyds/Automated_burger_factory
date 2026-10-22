local Config=require('Factory/DayConfig')
local Save=require('Factory/LocalSave')
local World=require('Factory/CampaignWorld')
---@class FactoryCampaignRuntime
---@field context table
---@field save FactoryLocalSave
---@field clock number
---@field record? table
---@field loadMessage? string
---@field future? boolean
---@field dayStart? table
---@field lastSave string
---@field pendingSave boolean
local Runtime={}
Runtime.__index=Runtime
---@return FactoryCampaignRuntime
function Runtime.New(context)
    local self=setmetatable({context=context,save=Save.New(),clock=0,lastSave='',dayStart=nil,pendingSave=false},Runtime)
    self.save.validate=World.Validate
    self.record,self.loadMessage,self.future=self.save:Load()
    return self
end
function Runtime:Snapshot() return World.Capture(self.context.get(),self.dayStart) end
function Runtime:Flush()
    local c=self.context.get()
    if c.loop.state=='title' then return true end
    local ok,message=self.save:Write(self:Snapshot())
    if ok then self.clock=0; c.campaign.dirty=false; self.lastSave=os.date('%H:%M:%S'); self.record,self.loadMessage=self.save:Load() end
    self.saveError=not ok and message or nil
    return ok,message
end
function Runtime:Frame(dt)
    local c=self.context.get(); self.clock=self.clock+math.max(0,dt)
    if c.loop.state~='title' and (self.pendingSave or c.campaign.dirty or self.clock>=30) then
        self.pendingSave=false
        if not self.retryAt or self.clock>=self.retryAt then
            local ok,message=self:Flush()
            if not ok then self.retryAt=self.clock+30; self.context.notify('保存失败：'..message) else self.retryAt=nil end
        end
    end
    if self.returnTitle then
        self.returnTitle=false
        local ok,message=self:Flush()
        if ok then c.loop.state='title'; self.context.closeEditors() else self.context.notify(message) end
    end
end
function Runtime:Command(command,value,ui)
    local c=self.context.get(); local loop=c.loop
    local function notify(ok,message) if message then ui:Notify(message) end; return ok end
    if command=='uiDetails' then self.presentationDetails=not self.presentationDetails; return true
    elseif command=='uiMachines' then self.presentationMachines=not self.presentationMachines; return true
    elseif command=='uiHistory' then self.presentationHistory=not self.presentationHistory; return true
    elseif command=='newGame' then
        if loop.state~='title' and loop.state~='complete' then return true end
        if self.future then ui:Notify('存在更高版本存档，已保护；请使用对应版本继续。'); return true end
        if self.record then ui:ConfirmDialog('v06New','开始新游戏并覆盖本地经营档案？') else self.context.rebuild({new=true}) end
    elseif command=='loadGame' then
        if loop.state~='title' then return true end
        local r,message=self.save:Load(); self.record=r
        if r then self.context.rebuild({state=r.state}) else ui:Notify(message) end
    elseif command=='beginTrading' and loop.state=='preparation' then
        self.context.closeEditors(); ui.overlay=nil; ui:Release()
        self.dayStart=World.Clone(World.Capture(c,nil))
        self.dayStart.loop.briefing=true
        assert(loop:StartTrading()); c.campaign.dirty=true
    elseif command=='arrange' and loop.state=='preparation' then loop.briefing=false; ui:Release()
    elseif command=='dayBriefing' and loop.state=='preparation' then loop.briefing=true; ui:Release()
    elseif command=='bonusOrders' and loop.state=='preparation' then
        if c.campaign.bonusAvailable then c.campaign.bonusEnabled=not c.campaign.bonusEnabled; c.campaign.dirty=true end
    elseif command=='saveTitle' and (loop.state=='paused' or loop.state=='complete' or loop.state=='settlement') then
        ui.overlay=nil; ui:Release(); self.returnTitle=true
    elseif command=='retryDay' and (loop.state=='settlement' or loop.state=='complete') then
        if self.dayStart then ui:ConfirmDialog('v06Retry','重试当天？恢复开业时的钱、建筑和物品，替换本日结果。') end
    elseif command=='nextDay' and loop.state=='settlement' then
        loop:Continue(); self.context.ensureSupplies(); c.campaign.dirty=true; ui.overlay=nil; ui:Release()
    elseif command=='confirmYes' and ui.overlay=='confirm' and (ui.confirmCommand=='v06New' or ui.confirmCommand=='v06Retry') then
        local cmd=ui.confirmCommand; ui.overlay=nil; ui:Release()
        self.context.rebuild(cmd=='v06New' and {new=true} or {state=World.Clone(self.dayStart),retry=true})
    elseif command=='settings' and loop.state=='title' then ui.overlay='settings'; ui.focus=0
    elseif command=='exitGame' then
        if loop.state=='title' then engine:Exit() else ui:ConfirmDialog('v06Exit','保存进度并退出游戏？') end
    elseif command=='confirmYes' and ui.overlay=='confirm' and ui.confirmCommand=='v06Exit' then
        ui.overlay=nil; local ok,message=self:Flush(); if ok then engine:Exit() else ui:Notify(message) end
    elseif command=='confirmYes' and ui.overlay=='confirm' and ui.confirmCommand=='v06RecoverLoss' then
        ui.overlay=nil; c.loop.teaching=false; return ui:Command('deleteManagedConfirmed')
    elseif command=='restart' and loop.state=='complete' then self:Command('newGame',nil,ui)
    elseif command=='networkInfo' then
        local components=c.automation.cables:Components(); local lines={}
        for i,net in ipairs(components) do
            local names={}; for _,ep in ipairs(net.endpoints) do names[#names+1]=ep.name end
            lines[#lines+1]='网络'..i..'：'..(#names>0 and table.concat(names,' / ') or '仅电缆，无设备')
        end
        self.networkLines=lines; c.campaign:Learn('network'); ui.overlay='networkInfo'; ui:Release()
    elseif command=='overview' then
        c.cameraNode.position=Vector3(-40,30.2,0); self.context.zoom(0.8); self.overview=true
    elseif command=='cameraPlayer' then
        c.cameraNode.position=Vector3(c.player.position.x,30.2,c.player.position.z); self.context.zoom(1); self.overview=false
    -- The mandatory first briefing is already frozen in preparation. Reviewing
    -- it during trading must not create an unlimited production/time pause.
    elseif command=='lesson' then ui.overlay='lesson'; ui:Release()
    elseif command=='back' and ui.overlay=='lesson' then loop.teaching=false; ui.overlay=nil; ui:Release()
    else return false end
    return true
end
function Runtime.Modal(c,ui,phase)
    local r=c.runtime; local d=Config.Day(c.loop.day)
    local function a(text,command,value,disabled) return {text=text,command=command,value=value,disabled=disabled} end
    local desktop=not GetPlatform or GetPlatform()=='Windows' or GetPlatform()=='Linux' or GetPlatform()=='Mac OS X'
    if phase=='title' then
        local lines={'从一份手工汉堡，到一座自动化工厂。','十天经营 · 手工→机器→传送带→电缆→下单→交付'}
        if r.record then
            local saved=r.record.state.loop
            local stateName=({preparation='准备中',running='营业中',paused='已暂停',settlement='待结算',complete='十天完成'})[saved.state] or '待继续'
            local remaining=math.ceil(saved.remaining or 0)
            lines[#lines+1]=string.format('本地进度：第%d天 · %s · 剩余%02d:%02d\n保存于 %s',saved.day,stateName,remaining//60,remaining%60,r.record.stamp)
        end
        if r.loadMessage and not r.record then lines[#lines+1]=r.loadMessage end
        local tools={a('设置','settings')}; if desktop then tools[#tools+1]=a('退出游戏','exitGame') end
        return {title='自动化汉堡工厂',lines=r.record and {lines[1],lines[2]} or lines,entries=r.record and {{text='本地经营档案',detail=table.concat(lines,'\n',3)}} or {},tools=tools,buttons={a('继续游戏','loadGame',nil,not r.record),a('新游戏','newGame')}}
    elseif phase=='briefing' or phase=='lesson' then
        local lines={'今日主题：'..d.title,d.lesson,
            string.format('基础计划最多%d个汉堡 · 达标%d个 · 同时%d单',Config.Total(d),d.goal,d.limit),
            string.format('营业%d分%d秒；准备阶段不生产、不出单、不计时。',d.seconds//60,d.seconds%60),
            '金币 '..c.campaign.coins..' · 汉堡交付10/件，完成整单额外5，达标奖励20。',
            '操作：WASD/摇杆移动，Shift/摇杆外圈奔跑，F交互，B建造；场景点击仅选取，放置须点击确认。',
            c.campaign.lessons[d.objective] and '本日操作教学已完成，可复习或继续优化。' or '本日操作教学待体验；不影响下一天解锁。'}
        if c.campaign.bonusAvailable then lines[#lines+1]='上一日效率达标，可自愿增加最多'..math.max(1,math.floor(Config.Total(d)*0.25))..'件需求；当前'..(c.campaign.bonusEnabled and '已选择' or '未选择') end
        local cards={{text=d.title,detail=d.lesson},{text=string.format('今日目标  %d件汉堡',d.goal),detail=lines[3]..'\n'..lines[4]},
            {text='经营与进度',detail=lines[5]..'\n'..lines[7]}}
        local tools={a(r.presentationDetails and '收起操作说明' or '展开操作说明','uiDetails')}
        if c.campaign.bonusAvailable then tools[#tools+1]=a('切换可选加量单','bonusOrders'); cards[#cards+1]={text='可选加量单',detail=lines[8]} end
        if phase=='lesson' then return {title='当日教学 · '..c.loop.day,back='继续',entries=cards,lines=r.presentationDetails and {lines[6]} or {},tools=tools} end
        return {title='第'..c.loop.day..'/10天 · 开店准备',entries=cards,lines=r.presentationDetails and {lines[6]} or {},
            tools=tools,
            buttons={a('先整理工厂','arrange'),a('开始营业','beginTrading')}}
    elseif phase=='paused' then
        local tools={a('当日教学','lesson'),a('运行统计','statistics'),a('操作与显示设置','settings'),a('保存并返回标题','saveTitle'),a('提前结束当天','pauseEnd',nil,c.loop.pausedFrom=='preparation')}
        if desktop then tools[#tools+1]=a('保存并退出','exitGame') end
        return {title='暂停',back='继续游戏',lines={'模拟已冻结。'..(r.lastSave~='' and '最近保存 '..r.lastSave or ''),'结束当天进入结算；保存并返回标题会保留当前进度。'},
            tools=tools}
    elseif phase=='settlement' then
        local s=c.loop.history[#c.loop.history]
        return {title='第'..s.day..'天结算 · '..(s.achieved and '达标' or '继续练习'),
            entries={{text=string.format('交付 %d/%d件  ·  完成%d单',s.delivered,s.goal,s.orders),detail=string.format('产量%d  |  手工%d  |  自动%d',s.total,s.manual,s.automatic)},
                {text=string.format('余额 %d金币',s.coins),detail=string.format('收入%d  ·  购置%d  ·  %.1f个/分',s.income,s.spent,s.rate)}},
            lines={s.early and '提前结束，未完成顾客订单已清除。' or '未完成顾客订单已清除。','建筑、库存和任务保留；重试恢复日初快照，不叠加收益。'},
            tools={a('保存并返回标题','saveTitle')},buttons={a('重试当天','retryDay',nil,not r.dayStart),a(s.day==10 and '十天总结' or '下一天准备','nextDay')}}
    elseif phase=='complete' then
        local lines={'十天经营完成。工厂已保存到本机。'}
        for _,s in ipairs(c.loop.history) do if r.presentationHistory or s.day==1 or s.day==5 or s.day==10 then lines[#lines+1]=string.format('第%02d天  交付 %d/%d  |  产量 %d  |  %.1f/分  |  %s',s.day,s.delivered,s.goal,s.total,s.rate,s.achieved and '达标' or '未达标') end end
        lines[#lines+1]='对比第1、5、10天：你减少了多少搬运？下一轮尝试怎样布局？'
        return {title='十天汉堡工厂',lines=lines,tools={a(r.presentationHistory and '仅看第1/5/10天' or '展开十天记录','uiHistory')},buttons={a('重试第10天','retryDay',nil,not r.dayStart),a('返回标题','saveTitle'),a('新游戏','newGame')}}
    elseif phase=='networkInfo' then
        return {title='电缆网络信息',back='返回编辑',lines=#(r.networkLines or {})>0 and r.networkLines or {'尚无电缆网络。连接建筑后在这里查看。','电缆本身不运输；第7天下单任务驱动索料。'}}
    elseif phase=='statistics' then
        local entries={{text=string.format('本日交付 %d/%d · 产量 %d',c.campaign.delivered,d.goal,c.loop.manual+c.loop.automatic),
            detail=string.format('金币 %d · 收入 %d · 购置 %d',c.campaign.coins,c.campaign.income,c.campaign.spent)}}
        if r.presentationMachines then
            local ids={}; for id in pairs(c.campaign.machineTimes) do ids[#ids+1]=id end; table.sort(ids)
            for _,id in ipairs(ids) do local t=c.campaign.machineTimes[id]; entries[#entries+1]={text=id,detail=string.format('加工 %.0fs / 等料 %.0fs / 堵塞 %.0fs',t.processing or 0,t.waiting or 0,t.blocked or 0)} end
            if #ids==0 then entries[#entries+1]={text='暂无设备运行记录'} end
        end
        if r.presentationHistory then
            for _,s in ipairs(c.loop.history) do entries[#entries+1]={text='第'..s.day..'天',detail=string.format('产量 %d · 交付 %d · %.1f个/分',s.total,s.delivered,s.rate)} end
            if #c.loop.history==0 then entries[#entries+1]={text='暂无已结束日记录'} end
        end
        return {title='工厂效率统计',back='返回暂停',entries=entries,lines={'日初准备、暂停和零时整理不计入营业产能。'},
            tools={a(r.presentationMachines and '收起设备明细' or '展开设备明细','uiMachines'),a(r.presentationHistory and '收起历史' or '展开历史','uiHistory')}}
    end
end
return Runtime
