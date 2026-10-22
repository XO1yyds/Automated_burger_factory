from pathlib import Path
from PIL import Image
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/image/employee_v04/four_frame_v1'
manifest=json.loads((BASE/'manifest.json').read_text(encoding='utf-8'))
checks=[]
def check(name,ok):checks.append({'name':name,'passed':bool(ok)})
check('32 direction/action groups',len(manifest['entries'])==32)
total_bytes=0
for e in manifest['entries']:
 key=e['id'];atlas=Image.open(ROOT/'assets'/e['atlas']).convert('RGBA');total_bytes+=atlas.width*atlas.height*4
 check(key+' atlas1088x272 RGBA',atlas.size==(1088,272))
 check(key+' four metadata frames',e['frames']==4 and len(e['sockets'])==4)
 hashes=[];match=True;bounds=True;guard=True
 for i in range(4):
  frame=Image.open(BASE/f'runtime/{key}/{i+1}.png').convert('RGBA')
  hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
  match=match and frame.tobytes()==atlas.crop((i*272+8,8,i*272+264,264)).tobytes()
  b=frame.getchannel('A').point(lambda a:255 if a>=24 else 0).getbbox();bounds=bounds and b is not None and b[0]>0 and b[1]>0 and b[2]<256 and b[3]<256
  guard=guard and atlas.crop((i*272,0,i*272+272,8)).getchannel('A').getbbox() is None
 check(key+' atlas matches all4 exported frames',match)
 check(key+' transparent safe margin',bounds and guard)
 check(key+' four distinct exported images',len(set(hashes))==4)
 webp=Image.open(BASE/f'runtime/{key}/preview.webp')
 check(key+' four preview frames',webp.n_frames==4)
 check(key+' sockets inside image',all(0<=s[0]<=1 and 0<=s[1]<=1 for s in e['sockets']))
failed=[r for r in checks if not r['passed']]
report={'passed':len(checks)-len(failed),'failed':len(failed),'checks':checks,'groups':32,'frames':128,
        'atlas_gpu_bytes_uncompressed':total_bytes,'scope':'Deterministic image/atlas/pivot metadata checks; not artistic quality, fps or Android memory measurement'}
(ROOT/'docs/v04-character-four-frame-asset-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'}))
for row in failed:print('FAIL',row['name'])
raise SystemExit(bool(failed))
