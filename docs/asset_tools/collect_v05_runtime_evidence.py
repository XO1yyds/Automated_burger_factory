"""Extract bounded V0.5 test messages, never export launcher session secrets."""
from pathlib import Path
import argparse
import hashlib
import json
from datetime import datetime, timezone, timedelta

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('lua_log', type=Path)
args = parser.parse_args()
messages = []
errors = []
for line in args.lua_log.read_text(encoding='utf-8-sig').splitlines():
    try:
        row = json.loads(line)
    except json.JSONDecodeError:
        continue
    msg = row.get('m', '')
    if '[V05 Runtime QA]' in msg:
        messages.append({'time': row.get('t'), 'message': msg.split('[V05 Runtime QA] ', 1)[-1].strip()})
    if row.get('l') == 'ERROR':
        errors.append({'time': row.get('t'), 'message': msg})
checks = [m for m in messages if m['message'].startswith(('PASS ', 'FAIL '))]
report = {
    'collected_at': datetime.now(timezone(timedelta(hours=8))).isoformat(),
    'source_log_name': args.lua_log.name,
    'scope': 'Actual UrhoX scene services and UI commands via startup QA driver; not native keyboard/touch input',
    'passed': sum(m['message'].startswith('PASS ') for m in checks),
    'failed': sum(m['message'].startswith('FAIL ') for m in checks),
    'completed': any(m['message'].startswith('COMPLETE ') for m in messages),
    'messages': messages,
    'lua_error_rows': errors,
    'current_source_sha256': {
        str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted((ROOT / 'scripts').rglob('*.lua'))
    },
    'note': 'Hashes describe collection-time sources; native final refresh must verify current delivery configuration separately.',
}
if not report['completed'] or not checks:
    raise SystemExit('No completed V0.5 QA suite found; do not replace evidence with an empty success.')
target = ROOT / 'docs/v05-runtime-evidence.json'
target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: report[k] for k in ('passed', 'failed', 'completed')}, ensure_ascii=False))
raise SystemExit(bool(report['failed'] or errors))
