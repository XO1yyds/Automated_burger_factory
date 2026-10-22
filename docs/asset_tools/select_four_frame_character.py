"""Explicit existing-source choices; no generation and no image edits."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/image/employee_v04/four_frame_v1'
catalog=json.loads((ROOT/'assets/image/employee_v04/character_animations_v04.json').read_text(encoding='utf-8'))
selected={}
def old(key,index):
 e=next(e for e in catalog['entries'] if e['id']==key)
 meta=json.loads((ROOT/'assets'/e['runtime256']['config']).read_text(encoding='utf-8'))
 r=meta['frames'][index]['frame']
 return {'source':'assets/'+e['runtime256']['atlas'],'rect':[r['x'],r['y'],r['x']+r['w'],r['y']+r['h']],
         'normalized':True,'original_index':index,'provenance':'pre_task_catalog'}
def source(path,cell=None):
 s={'source':path,'provenance':'current_task_existing_delivered_asset'}
 if cell is not None:s['cell']=cell
 return s
def choose(key,frames,note):
 selected[key]={'frames':frames,'art_review':'selected_for_simple_four_frame_runtime_review','note':note}
for d in ['front','left','right','back']:
 for a in ['idle','carry_idle','operate','think']:
  indices=[0,1,2,3] if a=='carry_idle' else [0,3,6,9] if a=='think' else [0,2,4,6]
  choose(f'{d}_{a}',[old(f'{d}_{a}',i) for i in indices],'Reuse complete authored poses; no head/eye replacement')
choose('front_walk',[old('front_walk',0),old('front_walk',2),old('front_walk',4),source('assets/image/employee_four_front_walk_r2_pose_20261019073040.png',0)],'Neutral/step/neutral/opposite lifting foot; simple4, not smooth8')
choose('left_walk',[source('assets/image/employee_left_walk_four_r3_20261019072330.png',i) for i in range(4)],'Reviewed4-pose strip, near/far overlap changes after half-cycle')
choose('right_walk',[old('right_walk',i) for i in [0,1,3,6]],'Reuse same-batch complete poses including odd-index transitions; simple4 gait')
choose('back_walk',[source('assets/image/employee_four_back_walk_r2_pose_20261019073150.png',i) for i in range(4)],'Rear4-pose strip; alternate lifting foot')
for d in ['front','back']:
 export='front_run_depth_demo_v2/export_v2' if d=='front' else 'back_run_depth_demo_v1/export_v1'
 choose(f'{d}_run',[{'source':f'assets/image/employee_v04/{export}/frames256/frame_{i+1:02}.png','normalized':True,'provenance':'pre_task_depth_guided_full_pose'} for i in [0,2,4,6]],'Reuse depth-guided complete run poses across both half-cycles')
choose('left_run',[source('assets/image/employee_four_left_run_r1_20261019072803.png',i) for i in range(4)],'Simple run poses, complete head/body and different knee bends')
choose('right_run',[old('right_run',i) for i in [0,2,4,5]],'Reuse same-batch high-knee poses and odd-index transition; not only accelerated walk')
for d in ['front','left','right']:
 for a in ['carry_walk','carry_run']:
  suffix='_r2' if d=='left' else '_r1' if d=='right' else ''
  path=f'assets/image/employee_v04/four_frame_v1/builtin/{d}_{a}_b{suffix}.png'
  if a=='carry_run':
   choose(f'{d}_{a}',[old(f'{d}_{a}',i) for i in ([0,2,4,6] if d=='front' else [0,2,4,5])],'Reuse same-batch full-body poses; prefer odd-index passing phase over newly generated proportion changes')
  elif d=='right':
   choose(f'{d}_{a}',[old(f'{d}_{a}',0),old(f'{d}_{a}',2),old(f'{d}_{a}',4),old('right_carry_run',5)],'Reuse one existing carrying run passing pose; all complete characters, simple4')
  else:
   choose(f'{d}_{a}',[old(f'{d}_{a}',0),old(f'{d}_{a}',2),old(f'{d}_{a}',4),source(path)],'Existing neutral and step poses with already-delivered opposite-leg whole pose; no props baked in')
choose('back_carry_walk',[old('back_carry_walk',0),old('back_carry_walk',2),old('back_carry_walk',5),old('back_carry_run',3)],'Reuse rear carry_run frame4 for opposite heel; no new rear request')
choose('back_carry_run',[old('back_carry_run',0),old('back_carry_run',2),old('back_carry_run',3),old('back_carry_run',7)],'Includes original frame4 opposite outsole, missed by even-index extraction')
assert len(selected)==32
for value in selected.values():
 for spec in value['frames']:assert (ROOT/spec['source']).exists(),spec
(BASE/'selected.json').write_text(json.dumps(selected,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
old_count=sum(f['provenance'].startswith('pre_task') for v in selected.values() for f in v['frames'])
print(json.dumps({'groups':32,'pre_task_source_slots':old_count,'current_task_existing_slots':128-old_count,'new_generation_called':False}))
