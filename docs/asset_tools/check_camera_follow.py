"""Run actual Lua camera-follow policy across paths, frame rates and view sizes."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/conveyor-test-runtime'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
rows=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local Follow=require('Factory/CameraFollow')
local checks={};local function check(name,ok)checks[#checks+1]={name=name,passed=not not ok};assert(ok,name)end
local function state(p)
 local s={enabled=true,manual=false,moving=true,x=-40,z=0,area='workshop',cx=-40,cz=0,
 screenX=.5,screenY=.5,viewWidth=30,viewHeight=19,minX=-56,maxX=-24,minZ=-12,maxZ=12}
 for k,v in pairs(p or {})do s[k]=v end;return s
end
local f=Follow.New();f:Step(.016,state())
local x,z,moved=f:Step(.016,state{x=-39.9,screenX=.503})
check('central movement keeps camera still',not moved and x==-40 and z==0)
x,z,moved=f:Step(.016,state{x=-39.8,screenX=.84})
check('right edge pans right smoothly without rotation or zoom inputs',moved and x>-40 and x<-38.8 and z==0)
f:Reset();f:Step(.016,state());x,z,moved=f:Step(.016,state{z=.1,screenY=.20})
check('top edge pans positive Z',moved and z>0 and x==-40)
f:Reset();f:Step(.016,state());x,z,moved=f:Step(.016,state{z=-.1,screenY=.82})
check('bottom edge pans negative Z',moved and z<0)
for _,flags in ipairs({{enabled=false},{manual=true},{moving=false}})do
 f:Reset();f:Step(.016,state());local s=state{x=-39,screenX=.99};for k,v in pairs(flags)do s[k]=v end
 x,z,moved=f:Step(.016,s);check('no camera takeover '..(flags.manual and 'manual pan' or flags.enabled==false and 'shop UI pause' or 'stationary'),not moved and x==-40 and z==0)
end
f:Reset();f:Step(.016,state());x,z,moved=f:Step(.016,state{screenX=.99})
check('pushing into wall with no displacement never pans',not moved)
f:Reset();f:Step(.016,state());x,z,moved=f:Step(.016,state{x=-39,area='shop',screenX=.99})
check('area transition discards old movement sample',not moved)
f:Reset();f:Step(.016,state());x,z,moved=f:Step(0,state{x=-39,screenX=.99})
check('zero time is stable',not moved)
f:Reset();f:Step(.016,state());local far=state{x=-24.1,cx=-56,screenX=.5+31.9/30}
x,z,moved=f:Step(.016,far)
check('moving after far manual pan restores visibility immediately',moved and .5+(far.x-x)/30<=.880001)

local anchor=1.55*(.96875-.5)
for _,aspect in ipairs({.56,4/3,16/9,2340/1080})do for _,zoom in ipairs({.8,1,2.5})do for _,fps in ipairs({15,30,60,144})do
 local follow=Follow.New();local cx,cz=-40,0;local px,pz=-40,0
 local height=math.max(19,22/aspect)/zoom;local width=height*aspect
 local visible,bounded=true,true
 local function step()
  local sx=.5+(px-cx)/width;local sy=.5-(pz+anchor-cz)/height
  cx,cz=follow:Step(1/fps,state{x=px,z=pz,cx=cx,cz=cz,screenX=sx,screenY=sy,viewWidth=width,viewHeight=height})
  local left=.5+(px-.775-cx)/width;local right=.5+(px+.775-cx)/width
  local top=.5-(pz+anchor+.775-cz)/height;local bottom=.5-(pz+anchor-.775-cz)/height
  visible=visible and left>=-.000001 and right<=1.000001 and top>=-.000001 and bottom<=1.000001
  bounded=bounded and cx>=-56 and cx<=-24 and cz>=-12 and cz<=12
 end
 step()
 for _,target in ipairs({{-23.3,13.3},{-56.7,13.3},{-56.7,-13.3},{-23.3,-13.3},{-40,0}})do
  local dx,dz=target[1]-px,target[2]-pz;local distance=math.sqrt(dx*dx+dz*dz)
  local n=math.ceil(distance/(8/fps));local startX,startZ=px,pz
  for i=1,n do px,pz=startX+dx*i/n,startZ+dz*i/n;step()end
 end
 check(string.format('full paper stays visible sprint aspect%.3f zoom%.1f fps%d',aspect,zoom,fps),visible and bounded)
 local beforeX,beforeZ=cx,cz;for i=1,60 do step()end
 check(string.format('stopping does not drift aspect%.3f zoom%.1f fps%d',aspect,zoom,fps),cx==beforeX and cz==beforeZ)
end end end
return checks
''')
report={'passed':len(rows),'failed':0,'checks':[dict(v) for v in rows.values()],
 'scope':'Actual Lua edge-follow math at 48 combinations, full paper bounds, camera limits and control ownership; not native projection/Android'}
(ROOT/'docs/v07-camera-follow-policy-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'}))
