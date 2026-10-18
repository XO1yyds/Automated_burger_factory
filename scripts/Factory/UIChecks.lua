-- Engine-independent behavioral checks, also run in the native preview suite.
local State=require('Factory/UIState')
local Touch=require('Factory/TouchInput')
local Checks={}
function Checks.Run()
    local results={}; local failed=0
    local function check(n,ok) table.insert(results,{name=n,passed=not not ok}); if not ok then failed=failed+1 end
        print('[UI Policy QA] '..(ok and 'PASS ' or 'FAIL ')..n) end
    check('pause overrides construction',State.Phase{loop='paused',build='preview'}=='paused')
    check('settings overrides paused parent',State.Phase{loop='paused',overlay='settings'}=='settings')
    check('buffer owns gameplay input',State.Phase{loop='running',buffer='buffer',build='idle'}=='buffer')
    check('orders browse is an explicit state',State.Phase{loop='running',ordersOpen=true}=='orders')
    check('managed selection is distinct from movement',State.Phase{loop='running',build='manage',selected=true}=='selected')
    check('normal grid hidden',not State.Grid('normal') and not State.Grid('menu') and not State.Grid('manage'))
    check('editing grid visible',State.Grid('preview') and State.Grid('move') and State.Grid('adjust'))
    check('empty hand occupied slot retrieves',State.BufferAction(nil,{},true)=='取出')
    check('held occupied slot swaps',State.BufferAction('bun',{},true)=='交换')
    check('held empty slot deposits',State.BufferAction('bun',nil,true)=='存入')
    local _,empty=State.BufferAction(nil,nil,true); local _,stale=State.BufferAction('bun',{},false)
    check('empty and stale actions disabled',not empty and not stale)
    local prefs=State.SanitizePreferences{uiScale=100,sensitivity=-1,display='unknown',joystick='unknown',gameProgress={day=3},tutorials={normal=true,unknown=true}}
    check('preferences clamp valid ranges',prefs.uiScale==1.2 and prefs.sensitivity==0.5)
    check('preferences whitelist no gameplay state',prefs.display=='both' and prefs.joystick=='fixed' and prefs.gameProgress==nil and prefs.tutorials.unknown==nil)
    check('NaN preferences become defaults',State.SanitizePreferences{uiScale=0/0}.uiScale==1)
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{760,360}}) do
        local l=State.Layout(size[1],size[2]); check('layout modal contained '..size[1]..'x'..size[2],l.modalWidth<size[1] and l.button>=48 and l.cardWidth<size[1])
    end
    local touch=Touch.New(); touch:Begin(1,100,100,'joystick',100,100); touch:Move(1,105,100)
    check('joystick dead zone releases speed',touch.x==0 and not touch.running)
    touch:Move(1,130,100); check('joystick inner ring walks',touch.x>0 and not touch.running)
    touch:Move(1,149,100); check('outer ring starts sprint',touch.running)
    touch:Move(1,145,100); check('sprint hysteresis avoids jitter',touch.running)
    touch:Move(1,139,100); check('inner return stops sprint',not touch.running)
    touch:Begin(2,300,200,'scene'); check('joystick never counted as camera finger',touch:Move(2,310,210)==nil)
    touch:Begin(3,400,200,'scene'); local g=touch:Move(3,420,210)
    check('two scene fingers generate pan pinch',g~=nil and g.scale>0)
    check('camera movement prevents release click',touch:End(2).moved)
    touch:End(1); check('joystick up stops all movement',touch.x==0 and touch.z==0 and not touch.running)
    touch:Reset(); touch:Begin(1,100,100,'object'); touch:Begin(2,300,200,'scene')
    check('object owner blocks competing camera',touch.pointers[2].kind=='blocked' and touch:Move(2,350,220)==nil)
    touch:Reset(); check('focus reset clears every owner',next(touch.pointers)==nil and touch.objectId==nil and touch.joystickId==nil)
    print('[UI Policy QA] COMPLETE checks='..#results..' failures='..failed)
    return {passed=#results-failed,failed=failed,results=results}
end
return Checks
