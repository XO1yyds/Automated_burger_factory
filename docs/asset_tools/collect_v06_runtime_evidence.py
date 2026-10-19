"""Extract only V0.6 automated scene results from a native Lua log, not session credentials."""
from pathlib import Path
import argparse,json
parser=argparse.ArgumentParser()
parser.add_argument('log',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[2]
matches=[]
for line in args.log.read_text(encoding='utf-8-sig').splitlines():
    if not line.strip():continue
    row=json.loads(line)
    value=row.get('m','')
    token='[V06 Native QA] RESULT '
    if token in value: matches.append(json.loads(value.split(token,1)[1].strip()))
assert matches,'No native result in selected log'
report=matches[-1]
report.update({'date':'2026-10-19','native_log':args.log.name,'uses_separate_test_save_files':True,'real_user_save_replaced_by_test_factory':False})
(root/'docs/v06-runtime-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:report[k] for k in ('passed','failed','native_log')}))
raise SystemExit(bool(report['failed']))
