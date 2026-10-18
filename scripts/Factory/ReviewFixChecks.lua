-- Independent examples/invariants for the reported card anchoring regression.
local View=require('Factory/OrthographicView')
local Checks={}
function Checks.Run()
    local results={}; local failed=0
    local function check(n,ok)
        table.insert(results,{name=n,passed=not not ok}); if not ok then failed=failed+1 end
        print('[UI Review Fix QA] '..(ok and 'PASS ' or 'FAIL ')..n)
    end
    local function near(a,b) return math.abs(a-b)<0.00001 end
    local right,up,forward={x=1,y=0,z=0},{x=0,y=0,z=1},{x=0,y=-1,z=0}
    local camera={x=0,y=30,z=0}; local item={x=3,y=1.15,z=2}
    local x,y=View.Project(item,camera,right,up,18,1,1280,720,1)
    check('known 18m full-height projection',near(x,760) and near(y,280))
    local px,py=View.Project(item,{x=1,y=30,z=2},right,up,18,1,1280,720,1)
    check('camera translation shifts anchor by world displacement',near(px,x-40) and near(py,y+80))
    local zx,zy=View.Project(item,camera,right,up,18,2,1280,720,1)
    check('zoom doubles displacement about viewport center',near(zx-640,(x-640)*2) and near(zy-360,(y-360)*2))
    local hx,hy=View.Project(item,camera,right,up,18,1,2560,1440,2)
    check('high DPI converts physical pixels once',near(hx,x) and near(hy,y))
    local sx,sy=View.Project(item,camera,right,up,18,1,1280,720,1.2)
    check('UI scale does not change world anchor',near(sx*1.2,x) and near(sy*1.2,y))
    local roundTrip=true
    for _,zoom in ipairs({0.8,1,1.5,2.5}) do for _,size in ipairs({{1280,720,1},{2400,1080,2.75}}) do
        for _,position in ipairs({camera,{x=-40,y=30,z=3},{x=6,y=30,z=-5}}) do
            local a,b=View.Project(item,position,right,up,19,zoom,size[1],size[2],size[3])
            local wx,wy,wz=View.Point(a,b,item.y,position,right,up,forward,19,zoom,size[1],size[2],size[3])
            roundTrip=roundTrip and near(wx,item.x) and near(wy,item.y) and near(wz,item.z)
        end
    end end
    check('pan zoom aspect and DPI preserve pointer round trip',roundTrip)
    local ax,ay=View.Card(400,400,280,100,1280,720,72,150)
    local bx,by=View.Card(450,420,280,100,1280,720,72,150)
    check('card follows building exactly when camera pans',near(bx-ax,50) and near(by-ay,20))
    check('card sits five UI units above its building anchor',near(ay+100+5,400))
    local ex,ey=View.Card(100,300,280,100,1280,720,72,150)
    local fx,fy=View.Card(101,301,280,100,1280,720,72,150)
    check('edge avoidance stays relative to the building',near(ex,105) and near(fx-ex,1) and near(fy-ey,1))
    check('offscreen building never leaves a pinned floating card',View.Card(-20,300,280,100,1280,720,72,150)==nil)
    check('insufficient space hides instead of screen clamping',View.Card(200,95,280,210,480,320,72,150)==nil)
    check('whole straight segment is hittable away from midpoint',near(View.SegmentDistance(120,15,0,0,500,0),225))
    check('segment hit test clamps beyond endpoint',near(View.SegmentDistance(-10,0,0,0,500,0),100))
    print('[UI Review Fix QA] COMPLETE checks='..#results..' failures='..failed)
    return {passed=#results-failed,failed=failed,results=results}
end
return Checks
