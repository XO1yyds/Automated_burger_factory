"""Deterministic atlas extraction and runtime sizing; never redraws AI artwork."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/image/v04_static/runtime'; OUT.mkdir(parents=True,exist_ok=True)
rows=[]
def latest(pattern):
    paths=sorted((ROOT/'assets/image').glob(pattern));assert paths,pattern
    return paths[-1]
def export(key,source,region=None,size=(512,512),tight=True):
    im=Image.open(source).convert('RGBA')
    if region:im=im.crop(region)
    box=im.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
    assert box,key
    if tight:im=im.crop(box)
    if size:
        im.thumbnail((size[0]-12,size[1]-12),Image.Resampling.LANCZOS)
        framed=Image.new('RGBA',size);framed.alpha_composite(im,((size[0]-im.width)//2,(size[1]-im.height)//2));im=framed
    # Remove undefined RGB from fully transparent pixels before GPU mip sampling.
    pixels=list(im.getdata());im.putdata([(r,g,b,a) if a else (0,0,0,0) for r,g,b,a in pixels])
    path=OUT/(key+'.png');im.save(path)
    rows.append({'id':key,'source':source.relative_to(ROOT).as_posix(),'source_region':region,'source_alpha_bounds':box,
        'path':path.relative_to(ROOT).as_posix(),'size':im.size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'alpha_range':im.getchannel('A').getextrema(),'method':'crop/common canvas/resize/clear invisible RGB only','art_review':'pending runtime review'})
food=latest('v04_static_food_clean_r2_*.png')
for i,key in enumerate(['bun','raw_beef','cooked_beef','lettuce','burger']):
    x=(i%3)*512;y=(i//3)*512;export(key,food,(x,y,x+512,y+512),(256,256))
for key in ['cooker_top','assembler_top','manual_grill_top','manual_assembly_top','supply_top','buffer_top','storage_top','cashier_top','trash_top']:
    size=(256,512) if key=='storage_top' else (512,512) if key in ['buffer_top','trash_top'] else (768,480)
    # Device silhouette should fill its footprint; no perspective redraw or faux states.
    source=latest('v04_static_'+key+'_r1_*.png')
    export(key,source,size=None)
for direction in ['front','left','right','back']:
    source=ROOT/'assets/image/employee_v04/basis_v1'/f'{direction}.png'
    # Preserve original common 512 canvas and foot pivot exactly.
    export('employee_'+direction,source,size=None,tight=False)
for key in ['shop_floor','workshop_floor','belt_tile','title_bg']:
    paths=list((ROOT/'assets/image').glob('v04_static_'+key+'_r1_*.png'))
    if paths:export(key,sorted(paths)[-1],size=None,tight=False)
symbols=list((ROOT/'assets/image').glob('v04_static_symbols_atlas_r1_*.png'))
if symbols:
    source=sorted(symbols)[-1];w,h=Image.open(source).size
    for i,key in enumerate(['order_badge','delivery_badge','stock_icon','coin_icon','junction_icon','save_icon','workshop_icon','shop_icon']):
        x=(i%4)*w//4;y=(i//4)*h//2
        export(key,source,(x,y,x+w//4,y+h//2),(128,128))
body={'date':'2026-10-19','baseline':'user-accepted V0.6 gameplay; V0.4 static art resumed','assets':rows,'total':len(rows),
    'character_pivot':[0.5,0.96875],'animation_added':False,'source_receipts':'assets/image/v04_static/receipts'}
(ROOT/'assets/image/v04_static/manifest.json').write_text(json.dumps(body,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
canvas=Image.new('RGB',(1200,((len(rows)+5)//6)*170),(221,224,216));draw=ImageDraw.Draw(canvas)
for i,row in enumerate(rows):
    im=Image.open(ROOT/row['path']).convert('RGBA');im.thumbnail((180,140))
    x=(i%6)*200+(200-im.width)//2;y=(i//6)*170
    canvas.paste(im,(x,y),im);draw.text(((i%6)*200+6,y+146),row['id'],fill=(20,30,30))
canvas.save(ROOT/'docs/v04-static-contact.jpg')
print(json.dumps({'exported':len(rows),'manifest':'assets/image/v04_static/manifest.json'}))
