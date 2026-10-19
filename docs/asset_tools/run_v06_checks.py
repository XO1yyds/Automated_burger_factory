"""Run actual V0.6 Lua domain logic with an in-memory file backend and JSON bridge.
This is not native IO, visuals, Android or a human ten-day playthrough.
"""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/conveyor-test-runtime'))
from lupa.lua54 import LuaRuntime, lua_type
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
def plain(value):
    if lua_type(value)!='table': return value
    keys=list(value.keys())
    if keys and set(keys)==set(range(1,len(keys)+1)):
        return [plain(value[i]) for i in range(1,len(keys)+1)]
    return {k:plain(v) for k,v in value.items()}
def tables(value):
    if isinstance(value,dict): return lua.table_from({k:tables(v) for k,v in value.items()})
    if isinstance(value,list): return lua.table_from([tables(v) for v in value])
    return value
bridge=lua.table_from({'encode':lambda value:json.dumps(plain(value),ensure_ascii=False,separators=(',',':')),'decode':lambda value:tables(json.loads(value))})
result=lua.eval("require('Factory/V06Checks')")[0].Run(bridge)
report=plain(result)
report['scope']='Lua domain, graph persistence and failure-injected memory backend; excludes native IO/render/input and real playthrough balance'
(ROOT/'docs/v06-domain-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},ensure_ascii=False))
for row in report['checks']:
    if not row['passed']:print('FAIL',row['name'])
raise SystemExit(bool(report['failed']))
