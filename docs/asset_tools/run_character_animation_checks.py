from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/conveyor-test-runtime'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
r=lua.eval("require('Factory/CharacterAnimationChecks')")[0].Run()
report={'scope':'Actual pure Lua animation clock/priorities and campaign unlock rules; not image quality or native input/render',
        'passed':r['passed'],'failed':r['failed'],'checks':[dict(x) for x in r['checks'].values()]}
(ROOT/'docs/v04-character-four-frame-domain-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'}))
for row in report['checks']:
 if not row['passed']:print('FAIL',row['name'])
raise SystemExit(bool(r['failed']))
