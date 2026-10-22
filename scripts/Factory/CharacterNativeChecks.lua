-- Opt-in fixture, isolated LocalSave namespace. Uses the existing Update bridge only.
local Art=require('Factory/StaticArt')
local Frames=require('Factory/CharacterFrames')
local Checks={}
function Checks.Run(c,r,h)
    local self={elapsed=0,stage=-1,seen={},route={},fixtures={},reported=false}
    local function check(name,ok)
        self.route[#self.route+1]={name=name,passed=not not ok}
        print('[Character Native QA] '..(ok and 'PASS ' or 'FAIL ')..name)
    end
    local domain=require('Factory/CharacterAnimationChecks').Run()
    check('actual Lua clock suite50',domain.failed==0 and domain.passed==50)
    c.loop:Prepare();c.loop.briefing=false;c.loop.teaching=false
    check('first day can enter workshop',h.switch('workshop'))
    c=h.context()
    local count=0;for _,s in ipairs(c.stations) do if s.id:match('^ws_') and s.buildingKind and s.buildingKind:match('^supply') then count=count+1 end end
    check('day1 entrance does not grant supplies or unlock cooker',count==0 and not c.campaign:Unlocked('cooker') and c.campaign.coins==50)
    local root=c.player.parent:CreateChild('CharacterAnimationFixture')
    local dirs={{'front',0,-1},{'left',-1,0},{'right',1,0},{'back',0,1}}
    local actions={'idle','walk','run','carry_idle','carry_walk','carry_run','operate','think'}
    for row,d in ipairs(dirs) do for col,action in ipairs(actions) do
        local id=d[1]..'_'..action;local actor=root:CreateChild(id);actor.position=Vector3(-54+(col-1)*4,0.55,8-(row-1)*4)
        local food=nil ---@type Node?
        if action:find('carry',1,true) then food=actor:CreateChild('Held_burger');food.scale=Vector3(.3,.2,.3);Art.Quad(food,'ItemArt','burger',1.55,1.55,.55) end
        self.fixtures[#self.fixtures+1]={id=id,node=actor,held=food,facing=Vector3(d[2],0,d[3]),action=action}
        self.seen[id]={}
        check(id..' atlas available',cache:GetResource('Texture2D',Frames[id].atlas)~=nil)
    end end
    local function touch(x,z,run)
        local ui=h.ui();ui.touch:Reset();if x~=0 or z~=0 then ui.touch.joystickId=999;ui.touch.x=x;ui.touch.z=z;ui.touch.running=run end
    end
    local function locate(x,z)
        c.player.position=Vector3(x,.55,z);local b=c.player:GetComponent('RigidBody');b.position=c.player.position;b.linearVelocity=Vector3.ZERO
    end
    function self:Frame(dt)
        if not input.focus then return end
        self.elapsed=self.elapsed+dt
        for _,f in ipairs(self.fixtures) do
            local state=Art.PlayerState(f.node)
            if state and f.action=='think' and state.action~='think' then state.idleAge=30 end
            Art.AnimatePlayer(f.node,f.node,f.facing,f.held,false,dt,{active=true,controllable=true,activity=false,
                moving=f.action:find('walk',1,true)~=nil or f.action:find('run',1,true)~=nil,
                running=f.action:find('run',1,true)~=nil,carrying=f.held~=nil,operating=f.action=='operate'})
            local clock=Art.PlayerState(f.node);if clock and clock.action==f.action then self.seen[f.id][clock.frame]=true end
        end
        local stage=self.elapsed<2 and 0 or self.elapsed<3 and 1 or self.elapsed<4 and 2 or self.elapsed<5 and 3 or self.elapsed<6 and 4 or self.elapsed<7 and 5 or self.elapsed<11 and 6 or self.elapsed<12 and 7 or self.elapsed<14 and 8 or self.elapsed<16 and 9 or self.elapsed<48 and 10 or self.elapsed<50 and 11 or 12
        local clock=Art.PlayerState(c.player)
        if clock then self['observed_'..clock.action]=true end
        if stage~=self.stage then
            if self.stage==8 then check('pause freezes actual player frame and clock',clock and clock.time==self.pausedTime and clock.frame==self.pausedFrame) end
            self.stage=stage
            if stage==0 then locate(-40,-10);c.loop.state='preparation'
            elseif stage==1 then touch(-1,0,false)
            elseif stage==2 then touch(1,0,true)
            elseif stage==3 then assert(c.items:Give('burger'));touch(-1,0,false)
            elseif stage==4 then touch(1,0,true)
            elseif stage==5 then touch(0,0,false)
            elseif stage==6 then
                c.items:ConsumeHeld(c.items.held);assert(h.switch('shop'));c=h.context();locate(2.7,4.2)
                c.loop.state='running';c.manual.grillItem='raw_beef';c.manual.grillProgress=0;c.manual.grillArmed=true;h.ui().holdingInteraction=true
            elseif stage==7 then h.ui().holdingInteraction=false;check('real manual cooking still completes in3s',c.manual.grillItem=='cooked_beef')
            elseif stage==8 then c.loop:Pause();self.pausedTime=clock.time;self.pausedFrame=clock.frame
            elseif stage==9 then c.loop:Resume();c.buildings.mode='menu';assert(c.items:Give('burger'))
            elseif stage==10 then c.buildings:Cancel();c.items:ConsumeHeld(c.items.held);touch(0,0,false)
            elseif stage==11 then check('real player thinks after30s idle',self.observed_think==true)
            elseif stage==12 then
                for _,a in ipairs(actions) do check('actual gameplay state '..a,self['observed_'..a]) end
                for id,seen in pairs(self.seen) do local n=0;for _ in pairs(seen) do n=n+1 end;check(id..' renders all4 frames',n==4) end
                self.reported=true;c.loop.state='preparation';c.loop.briefing=false;assert(h.switch('workshop'));c=h.context();locate(-40,-10)
                local failed=0;for _,entry in ipairs(self.route) do if not entry.passed then failed=failed+1 end end
                print('[Character Native QA] REPORT '..cjson.encode({passed=#self.route-failed,failed=failed,checks=self.route,scope='Native texture/UV clock, real movement/carry/cooking route and day1 workshop; synthetic touch joystick context, not Android touch'}))
            end
        end
        if stage>=12 then c.cameraNode.position=Vector3(-40,30.2,1);c.camera.orthoSize=25;c.camera.zoom=1 end
    end
    return self
end
return Checks
