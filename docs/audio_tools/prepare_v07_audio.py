"""Export provider originals to bounded, normalized runtime audio. No generation calls."""
from pathlib import Path
import sys, json, subprocess, wave, hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/audio-runtime'))
import imageio_ffmpeg
FF=imageio_ffmpeg.get_ffmpeg_exe()
OUT=ROOT/'assets/audio/v07/runtime'
OUT.mkdir(parents=True,exist_ok=True)
RATE=44100

def ff(args, data=None):
    r=subprocess.run([FF,'-v','error','-nostdin',*args],input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode: raise RuntimeError(r.stderr.decode(errors='replace'))
    return r.stdout
def decode(path,channels=1):
    return np.frombuffer(ff(['-i',str(path),'-f','f32le','-ac',str(channels),'-ar',str(RATE),'-']),dtype='<f4').reshape(-1,channels).copy()
def ramp(x,seconds=.008):
    n=min(len(x)//2,int(seconds*RATE))
    if n: x[:n]*=np.linspace(0,1,n)[:,None];x[-n:]*=np.linspace(1,0,n)[:,None]
    return x
def circular(x,seconds):
    n=min(int(RATE*seconds),len(x)//4)
    t=np.linspace(0,1,n)[:,None]
    return np.concatenate([x[n:-n],x[-n:]*(1-t)+x[:n]*t])
def normalize(x,rms=.16,peak=.50):
    magnitude=np.abs(x);gate=magnitude>max(float(magnitude.max())*.015,1e-5)
    energy=float(np.sqrt(np.mean(x[gate]**2))) if gate.any() else 0
    if energy<1e-7: raise ValueError('silent source')
    x=x*min(rms/energy,peak/max(float(magnitude.max()),1e-9))
    return x.astype('<f4')
def wav(name,x):
    pcm=(np.clip(x,-1,1)*32767).round().astype('<i2')
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(x.shape[1]);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm.tobytes())
    return path
def metrics(path):
    x=decode(path,2 if path.suffix=='.ogg' else 1)
    peak=float(np.abs(x).max());rms=float(np.sqrt(np.mean(x*x)))
    return {'path':path.relative_to(ROOT).as_posix(),'seconds':round(len(x)/RATE,4),'bytes':path.stat().st_size,
        'peak_dbfs':round(20*np.log10(max(peak,1e-12)),2),'rms_dbfs':round(20*np.log10(max(rms,1e-12)),2),
        'clipped_samples':int(np.sum(np.abs(x)>=.9999)), 'seam_jump':round(float(np.max(np.abs(x[-1]-x[0]))),6),
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

music=json.loads((ROOT/'assets/audio/v07/receipts/music.json').read_text(encoding='utf-8'))
sfx=json.loads((ROOT/'assets/audio/v07/receipts/sfx.json').read_text(encoding='utf-8'))
sources={}
mp=ROOT/music['music']['localPath'];x=decode(mp,2)
start=round(6*RATE);end=min(len(x)-round(6*RATE),start+120*RATE)
x=circular(x[start:end],60/104*4)
x=ramp(normalize(x,.10,.48),.006)
# Stable PCM -> Vorbis; decode again below so QA includes the encoded result.
ff(['-y','-f','f32le','-ar',str(RATE),'-ac','2','-i','-','-c:a','libvorbis','-q:a','4',str(OUT/'music.ogg')],x.tobytes())
sources['music']={'source':mp.relative_to(ROOT).as_posix(),'provider_id':music['music']['id'],
    'processing':'6s intro/outro exclusion, <=120s core, 1 bar circular crossfade at nominal104BPM, normalize, Vorbis q4'}
for item in sfx['audio_files']:
    name=item['name'].removeprefix('v07_').replace('grill_loop','grill')
    path=ROOT/item['localPath'];x=decode(path)
    if name=='grill': x=circular(x,.22)
    else:
        magnitude=np.abs(x[:,0]);indices=np.flatnonzero(magnitude>max(float(magnitude.max())*.015,.0005))
        if not len(indices):raise ValueError('silent '+name)
        x=x[max(0,int(indices[0])-int(.008*RATE)):min(len(x),int(indices[-1])+int(.08*RATE))]
        x=ramp(x)
    x=normalize(x,.14 if name=='grill' else .16)
    wav(name,x)
    sources[name]={'source':path.relative_to(ROOT).as_posix(),'remote':item.get('audioUrl'),'processing':'mono44100 PCM16, bounded gain, trim/fade or circular crossfade'}

def tone(freq,duration,amp=.4):
    t=np.arange(round(RATE*duration))/RATE
    return (amp*np.sin(2*np.pi*freq*t)*np.exp(-t*9))[:,None]
# Simple interface tones are authored locally, reserving paid work for texture/music.
ui=tone(880,.065,.32)+tone(1320,.065,.08)
error=np.concatenate([tone(220,.09,.25),np.zeros((round(RATE*.03),1)),tone(180,.13,.22)])
day=np.zeros((round(RATE*1.05),1))
for at,note in [(0,523.25),(.17,659.25),(.34,783.99),(.55,1046.50)]:
    part=tone(note,.43,.26);i=round(at*RATE);day[i:i+len(part)]+=part[:len(day)-i]
for name,x in [('ui',ui),('error',error),('day',day)]:
    wav(name,normalize(ramp(x),.14,.45));sources[name]={'source':'local additive synthesis','processing':'simple decaying sine tones, fade and PCM16'}

rows=[metrics(p) for p in sorted(OUT.iterdir()) if p.suffix in {'.ogg','.wav'}]
assert len(rows)==12 and all(r['clipped_samples']==0 and r['rms_dbfs']>-55 for r in rows)
report={'sample_rate':RATE,'runtime_files':rows,'total_bytes':sum(r['bytes'] for r in rows),'sources':sources,
    'scope':'decoded waveform/size/seam checks, not a claim of human listening or Android verification'}
(ROOT/'docs/v07-audio-assets.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'files':len(rows),'bytes':report['total_bytes'],'duration_music':next(r['seconds'] for r in rows if r['path'].endswith('music.ogg')),'clipped_samples':sum(r['clipped_samples'] for r in rows)}))
