-- Opt-in only, isolated save/UI files selected in main.lua before Phase1.Start.
local Assets=require('Factory/AudioAssets')
local Checks={}
function Checks.Run(c,r,h,phase)
    local self={elapsed=0,stage=-1,results={},reported=false}
    local function check(name,ok)
        self.results[#self.results+1]={name=name,passed=not not ok}
        print('[V07 Audio QA] '..(ok and 'PASS ' or 'FAIL ')..name)
    end
    for key,d in pairs(Assets) do
        local sound=cache:GetResource('Sound',d.file)
        check(key..' native resource decodes',sound~=nil and sound.length>0 and sound:GetFrequency()>8000)
    end
    c.loop:Prepare();c.loop.briefing=false;assert(c.loop:StartTrading());c.items:Reset()
    local function touch(x,z)
        local ui=h.ui();ui.touch:Reset()
        if x~=0 or z~=0 then ui.touch.joystickId=999;ui.touch.x=x;ui.touch.z=z end
    end
    function self:Frame(dt)
        if self.reported or not input.focus then return end
        self.elapsed=self.elapsed+dt
        local t=self.elapsed
        local stage=t<1 and 0 or t<2.2 and 1 or t<3.2 and 2 or t<3.4 and 3 or t<4.3 and 4 or t<7.3 and 5
            or t<7.5 and 6 or t<8.5 and 7 or t<9.3 and 8 or t<9.7 and 9 or t<10.5 and 10 or t<11.5 and 11 or 12
        if stage==self.stage then return end
        self.stage=stage
        local report=phase.AudioReport()
        if stage==1 then
            check('normal game BGM starts',report.native.music and report.native.musicGain>0)
            assert(c.items:Give('bun'));touch(1,0)
        elseif stage==2 then touch(0,0);c.items:ConsumeHeld('bun')
        elseif stage==3 then
            local spot=Vector3(2.7,.55,4.2);c.player.position=spot
            c.player:GetComponent('RigidBody').position=spot;touch(0,1)
        elseif stage==4 then
            touch(0,0);c.manual.grillItem='raw_beef';c.manual.grillArmed=true;c.manual.grillProgress=0;h.ui().holdingInteraction=true
        elseif stage==5 then check('real hand cooking enables sizzling loop',report.native.grill)
        elseif stage==6 then
            h.ui().holdingInteraction=false
            check('cooking still completes in three seconds',c.manual.grillItem=='cooked_beef')
            check('completed cooking stops sizzling',not report.native.grill)
        elseif stage==7 then c.orders.wait=0
        elseif stage==8 then
            check('real order generated',#c.orders.active>0)
            c.orders.stock=1
            if c.orders.active[1] then c.orders:Select(c.orders.active[1].id);check('real delivery accepted',c.orders:Deliver())
            else check('real delivery accepted',false) end
        elseif stage==9 then c.loop:Pause()
        elseif stage==10 then
            check('pause stops production loop',not report.native.grill)
            check('pause retains quiet music',report.native.music and report.native.musicGain>0 and report.native.musicGain<.2)
            h.ui():Command('settings');h.ui():Command('audioVolume',{key='masterVolume',volume=0})
        elseif stage==11 then
            check('master zero mutes native music',not report.native.music or report.native.musicGain==0)
            h.ui():Command('audioDefaults')
        elseif stage==12 then
            check('restoring defaults resumes music',report.native.music and report.native.musicGain>0)
            for _,key in ipairs({'pickup','drop','step','machine','order','delivery'}) do check('real gameplay emits '..key,(report.counts[key] or 0)>0) end
            check('native source pool stays bounded',report.native.voices==8)
            check('no runtime audio assets missing',next(report.native.missing)==nil)
            local rows=h.ui().view.audioRows
            check('three audio sliders in actual settings',#rows==3 and rows[1].panel:IsVisible() and rows[2].panel:IsVisible() and rows[3].panel:IsVisible())
            local failed=0;for _,v in ipairs(self.results) do if not v.passed then failed=failed+1 end end
            print('[V07 Audio QA] REPORT '..cjson.encode({passed=#self.results-failed,failed=failed,checks=self.results,audio=report,
                scope='Actual native Sound resource decode, source state and isolated gameplay route; device listening and Android excluded'}))
            self.reported=true
        end
    end
    return self
end
return Checks
