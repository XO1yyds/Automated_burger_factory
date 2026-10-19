"""Record bounded final source synchronization and startup evidence."""
from pathlib import Path
import argparse
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('prepared_source',type=Path)
parser.add_argument('lua_log',type=Path)
args=parser.parse_args()
checks=[]
for source in sorted((ROOT/'scripts').rglob('*.lua')):
    relative=source.relative_to(ROOT)
    prepared=args.prepared_source/relative
    checks.append({'file':relative.as_posix(),'matches':prepared.is_file() and hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256(prepared.read_bytes()).digest()})
rows=[json.loads(line) for line in args.lua_log.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
report={
    'date':'2026-10-19',
    'scope':'Final prepared source plus current Lua startup; native observations recorded separately',
    'source_files':len(checks),
    'source_sync_passed':all(c['matches'] for c in checks),
    'source_checks':checks,
    'lua_log_name':args.lua_log.name,
    'lua_error_rows':[r for r in rows if r.get('l')=='ERROR'],
    'v05_startup_seen':any('[V05] READY:' in r.get('m','') for r in rows),
    'unexpected_qa_startup':any('[V05 Native QA]' in r.get('m','') or '[V05 Runtime QA]' in r.get('m','') for r in rows),
    'native_observations':[
        'Final ordinary shop Day 1 spawn observed; no automatic terminal or task',
        'Same cable-control source tested in prior reload: visible in editor, hidden on return, visible on re-entry',
    ],
    'platform_check':{
        'process_alive':True,
        'preview_check_result':'FAIL',
        'evidence_available':False,
        'scope':'readiness_and_evidence_only',
        'known_errors':['Could not find resource Cube/Day/DaySpecularHDR.dds','Can not load themis_x64.dll.'],
        'note':'Existing runtime resource failures remain; do not claim full platform readiness or Android verification.',
    },
}
target=ROOT/'docs/v05-final-preview-evidence.json'
target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:report[k] for k in ('source_files','source_sync_passed','v05_startup_seen','unexpected_qa_startup')},ensure_ascii=False))
raise SystemExit(not report['source_sync_passed'] or not report['v05_startup_seen'] or report['unexpected_qa_startup'] or bool(report['lua_error_rows']))
