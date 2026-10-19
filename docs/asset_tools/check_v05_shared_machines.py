from pathlib import Path
import sys,os,json
ROOT=Path(__file__).resolve().parents[2]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'.tmp/conveyor-test-runtime'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
for p in Path('scripts').rglob('*.lua'):
    lua.execute('assert(load(...))',p.read_text(encoding='utf-8-sig'))
print('All user Lua files parse with Lua 5.4')
logs=[]
lua.globals().print=lambda *args:logs.append(' '.join(map(str,args)))
lua.execute('''
Color=function(...) return {...} end
local function widget(props) props=props or {}; props.SetVisible=function() end; props.AddChild=function() end; return props end
package.preload['urhox-libs/UI']=function() return {Label=widget,Panel=widget,Button=widget,GetRoot=widget} end
local Items=require('Factory/Items')
local Automatic=require('Factory/AutomaticWorkstation')
local item=Items.New({createHeld=function() return {Remove=function() end} end})
local stations=require('Factory/AutomationArea').Stations()
local machines={}; for _,s in ipairs(stations) do if s.automaticKind then machines[s.id]=Automatic.New(s.automaticKind,item) end end
local Control=require('Factory/ConveyorControl')
local control=Control.New({stations=function() return stations end,items=item,machines=machines,sources={ws_raw='raw_beef',ws_bun='bun',ws_lettuce='lettuce'},action=function() end,scene={},makeBox=function() end,buildings={}})
control:Sample()
local automation=require('Factory/OrderAutomationControl').New({resolve=function(id) return control:Endpoint(id) end,endpoints=function() local a={}; for _,s in ipairs(stations) do local ep=control:Endpoint(s.id); if ep then table.insert(a,ep) end end; return a end,area=function() return 'workshop' end,player={position={x=-40,z=0}}})
automation:Sample()
for _,belt in ipairs(control.network.belts) do print('Sample route',belt.from.id,belt.to.id,#belt.cells,belt.length) end
local function step(n) for _=1,n*20 do for _,m in pairs(machines) do m:Update(0.05) end; control.network:Update(0.05); automation.service:Update(0.05) end end
for _,delay in ipairs({0,5,15,30,90}) do
    step(delay)
    local ok,message,job=automation.service:Enqueue('ws_inventory','burger',2,'ws_inventory'); assert(ok,message)
    step(50)
    if job.delivered<2 then
        assert(job.reason:find('交接',1,true),'missing blocked output explanation')
        for _=1,20 do while control.buffers.ws_buffer:PeekOutput() do control.buffers.ws_buffer:TakeOutput('burger') end; step(3); if job.delivered==2 then break end end
    end
    print('Hybrid burger order',delay,job.delivered,job.reason)
    if job.delivered<2 then for id,m in pairs(machines) do print(id,m:Status(),m.automationOwner,m.automationIntakeOwner,job.units[id]) end end
    assert(job.delivered==2,'hybrid order stalled after draining downstream')
end
step(150)
assert(control.buffers.ws_buffer:Count()==6,'sample failed to fill buffer')
local ok,_,job=automation.service:Enqueue('ws_inventory','cooked_beef',3,'ws_inventory'); assert(ok)
for _=1,60 do while control.buffers.ws_buffer:PeekOutput() do control.buffers.ws_buffer:TakeOutput('burger') end; step(2); if job.delivered==3 then break end end
assert(job.delivered==3,'shared cooker production stalled')
automation.service:Stop()
for _,m in pairs(machines) do assert(not m.automationOwner and not m.automationIntakeOwner,'machine lock leaked') end
print('Shared original machines deliver all orders and keep conveyor sample running')
''')


report={'passed':True,'scope':'Actual shared workshop machines with original conveyor sample; UI is stubbed; no native input verification','logs':logs}
(ROOT/'docs/v05-shared-machines-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
