"""Run actual Lua 5.4 domain checks without claiming engine/UI validation."""
from pathlib import Path
import json,sys,time
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/conveyor-test-runtime'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
logs=[];lua.globals().print=lambda *args:logs.append(' '.join(map(str,args)))
start=time.perf_counter();result=lua.eval("require('Factory/V05AttachedChecks')")[0].Run()
checks=[{'name':v['name'],'passed':v['passed']} for v in result['results'].values()]
report={'runtime':lua.eval('_VERSION'),'passed':result['passed'],'failed':result['failed'],
        'duration_seconds':round(time.perf_counter()-start,3),'checks':checks,
        'scope':'Actual Lua domain code; excludes native rendering/input and Android verification'}
(ROOT/'docs/v05-attached-domain-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'}))
for row in checks:
    if not row['passed']:print('FAIL',row['name'])
sys.exit(bool(result['failed']))
