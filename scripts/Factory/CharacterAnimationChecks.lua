local Animation=require('Factory/CharacterAnimation')
local Days=require('Factory/DayConfig')
local Checks={}
function Checks.Run()
    local report={passed=0,failed=0,checks={}}
    local function check(name,ok)
        report.checks[#report.checks+1]={name=name,passed=not not ok}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1 end
    end
    local s=Animation.New()
    local c={active=true,controllable=true,direction='front'}
    local function step(dt,changes)
        for k,v in pairs(changes or {}) do c[k]=v end
        return Animation.Step(s,dt,c)
    end
    step(29.9);check('not thinking before30s',s.action=='idle')
    step(.11);check('thinking begins at30s frame1',s.action=='think' and s.frame==1)
    step(.6);check('think advances',s.frame==2)
    step(1.4);check('think finishes once and rearms',s.action=='idle' and s.idleAge==0)
    step(29);step(1,{activity=true});check('effective input resets idle',s.idleAge==0 and s.action=='idle')
    step(30,{activity=false});step(.1,{activity=true});check('input interrupts thinking',s.action=='idle')
    step(31,{carrying=true,activity=false});check('holding never thinks',s.action=='carry_idle' and s.idleAge==0)
    step(.1,{moving=true});check('carrying walk',s.action=='carry_walk')
    step(.1,{running=true});check('carrying run',s.action=='carry_run')
    step(.1,{carrying=false});check('empty run',s.action=='run')
    step(.1,{running=false});check('empty walk',s.action=='walk')
    step(.1,{moving=false,operating=true});check('true cooking selects operate',s.action=='operate')
    step(.1,{operating=false});check('completion/release immediately ends operate',s.action=='idle')
    step(.3,{moving=true,running=true});step(.2)
    local frame,time,age=s.frame,s.time,s.idleAge
    step(90,{active=false});check('pause freezes frame time and idle',s.frame==frame and s.time==time and s.idleAge==age)
    step(.1,{active=true,controllable=false});check('editing blocks movement animation',s.action=='idle')
    step(50);check('editing blocks thinking',s.idleAge==0 and s.action=='idle')
    step(.1,{carrying=true});check('editing holding selects static carry',s.action=='carry_idle')
    step(.1,{controllable=true,moving=false,carrying=false});step(.6)
    local before=s.time;step(.1,{direction='right'});check('turn resets clip clock',s.direction=='right' and s.frame==1 and s.time==0 and before>0)
    for _,dir in ipairs({'front','left','right','back'}) do
        for _,a in ipairs({'idle','walk','run','carry_idle','carry_walk','carry_run','operate'}) do
            Animation.Reset(s);c={active=true,controllable=true,direction=dir,moving=a:find('walk')~=nil or a:find('run')~=nil,
                running=a:find('run')~=nil,carrying=a:find('carry')~=nil,operating=a=='operate'}
            step(0);local seen={[s.frame]=true}
            for i=1,4 do step(1/Animation.FPS[a]+.000001);seen[s.frame]=true end
            local n=0;for _ in pairs(seen) do n=n+1 end
            check(dir..' '..a..' four-frame loop',s.action==a and n==4)
        end
    end
    Animation.Reset(s);check('area/restart clears transient state',s.action=='idle' and s.frame==1 and s.idleAge==0)
    check('day1 workshop open',Days.UnlockDay.workshop==1)
    check('day2 machine and supplies unchanged',Days.UnlockDay.cooker==2 and Days.UnlockDay.supply_raw==2 and Days.UnlockDay.supply_bun==2 and Days.UnlockDay.supply_lettuce==2)
    check('later automation unlocks unchanged',Days.UnlockDay.assembler==3 and Days.UnlockDay.belt==4 and Days.UnlockDay.cable==6 and Days.UnlockDay.terminal==7)
    return report
end
return Checks
