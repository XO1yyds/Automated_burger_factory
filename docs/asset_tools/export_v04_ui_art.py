"""Extract Maker UI atlases, preserving source receipts and actual grid dimensions."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
from collections import deque
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/image/v04_ui/runtime';OUT.mkdir(parents=True,exist_ok=True)
rows=[]
def atlas(pattern,keys,cols,rs,frames=False):
    source=sorted((ROOT/'assets/image').glob(pattern))[-1]
    original=Image.open(source).convert('RGBA');w,h=original.size
    for i,key in enumerate(keys):
        x,y=i%cols,i//cols;region=(x*w//cols,y*h//rs,(x+1)*w//cols,(y+1)*h//rs)
        im=original.crop(region);box=im.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox();assert box,key
        if frames:
            # Grid boundaries can catch a disconnected edge of a neighbour.
            mask=im.getchannel('A').point(lambda a:255 if a>32 else 0)
            seen=set();groups=[];pix=mask.load()
            for yy in range(im.height):
                for xx in range(im.width):
                    if not pix[xx,yy] or (xx,yy) in seen: continue
                    q=deque([(xx,yy)]);seen.add((xx,yy));group=[]
                    while q:
                        ax,ay=q.popleft();group.append((ax,ay))
                        for bx,by in [(ax-1,ay),(ax+1,ay),(ax,ay-1),(ax,ay+1)]:
                            if 0<=bx<im.width and 0<=by<im.height and (bx,by) not in seen and pix[bx,by]:
                                seen.add((bx,by));q.append((bx,by))
                    groups.append(group)
            keep=max(groups,key=len);clean=Image.new('L',im.size)
            for pt in keep: clean.putpixel(pt,255)
            im.putalpha(Image.composite(im.getchannel('A'),Image.new('L',im.size),clean))
            box=clean.getbbox()
        im=im.crop(box)
        if frames:
            heights={'frame_main':128,'frame_card':64,'frame_status':48,'frame_button':48,'frame_tab':48,'frame_slot':64,'frame_tooltip':96,'frame_joystick':128}
            nh=heights[key];im=im.resize((round(im.width*nh/im.height),nh),Image.Resampling.LANCZOS)
        if not frames:
            im.thumbnail((104,104),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(128,128))
            canvas.alpha_composite(im,((128-im.width)//2,(128-im.height)//2));im=canvas
        pixels=list(im.getdata());im.putdata([(r,g,b,a) if a else (0,0,0,0) for r,g,b,a in pixels])
        target=OUT/(key+'.png');im.save(target)
        rows.append({'id':key,'source':source.relative_to(ROOT).as_posix(),'region':region,'alpha_bounds':box,
                     'path':target.relative_to(ROOT).as_posix(),'size':list(im.size),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
                     'review':'source alpha composition passed; runtime pending'})
atlas('v04_ui_frames_r1_*.png',['frame_'+k for k in ['main','card','status','button','tab','slot','tooltip','joystick']],2,4,True)
atlas('v04_ui_actions_r1_*.png',['icon_'+k for k in ['back','close','pause','play','settings','build','rotate','move','delete','cable','reverse','network','tasks','warning','help','clock','confirm','minus','plus','orders']],5,4)
(OUT.parent/'manifest.json').write_text(json.dumps({'total':len(rows),'assets':rows,'actual_points':'platform did not return'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
contact=Image.new('RGB',(1120,((len(rows)+6)//7)*160),(232,233,218));d=ImageDraw.Draw(contact)
for i,row in enumerate(rows):
    im=Image.open(ROOT/row['path']);im.thumbnail((145,120));x=i%7*160;y=i//7*160
    contact.paste(im,(x+(160-im.width)//2,y+(124-im.height)//2),im);d.text((x+5,y+132),row['id'],fill=(35,40,40))
contact.save(ROOT/'docs/v04-ui-art-contact.jpg')
print(json.dumps({'exported':len(rows),'bytes':sum((ROOT/r['path']).stat().st_size for r in rows)}))
