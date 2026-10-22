"""Meaningful playback-policy and native-adapter checks using the actual Lua modules."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/conveyor-test-runtime'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
rows=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
local Soundscape=require('Factory/Soundscape');local State=require('Factory/UIState')
local results={};local function check(name,ok)results[#results+1]={name=name,passed=not not ok};assert(ok,name)end
local events,loops={},{}
local backend={Play=function(_,key,gain,pitch)events[#events+1]={key=key,gain=gain,pitch=pitch};return true end,
 Loop=function(_,key,on,gain)loops[key]={on=on,gain=gain}end,
 Mix=function(self,now,music,effects,focus,active)self.music,self.effects,self.focus,self.active=music,effects,focus,active end,
 Stop=function(self)self.stopped=true end}
local a=Soundscape.New(nil,backend)
local function snapshot(p)
 local s={state='running',normal=true,focused=true,day=2,area='shop',x=0,z=0,orders=1,delivered=0,layout='0',grill=0,moving=false}
 for k,v in pairs(p or {})do s[k]=v end;return s
end
local function count(key)local n=0;for _,e in ipairs(events)do if e.key==key then n=n+1 end end;return n end
local legacy=State.SanitizePreferences{display='touch',joystick='floating',uiScale=1.1,sensitivity=.8}
check('old preferences receive safe audio defaults',legacy.masterVolume==.8 and legacy.effectsVolume==.8 and not legacy.muted)
local invalid=State.SanitizePreferences{masterVolume=99,musicVolume=-1,effectsVolume=0/0,muted='true'}
check('audio ranges and invalid fields sanitized',invalid.masterVolume==1 and invalid.musicVolume==0 and invalid.effectsVolume==.8 and not invalid.muted)
a:Frame(.1,snapshot{held='old-save',orders=9})
check('loading inventory or pending orders has no fake cue',#events==0)
check('music starts once in focused scene',loops.music.on)
a:Frame(.2,snapshot{held='new-item',orders=10,delivered=1})
check('real order arrival cues once',count('order')==1)
check('real partial delivery cues once',count('delivery')==1)
check('held identity exchange cues once',count('pickup')==1)
a:Frame(.1,snapshot{held='new-item',orders=10,delivered=1})
check('stable state never repeats reward cues',count('order')==1 and count('delivery')==1 and count('pickup')==1)
a:Frame(.3,snapshot{orders=10,delivered=1})
check('held release cues once',count('drop')==1)
a:Frame(.3,snapshot{orders=10,delivered=1,layout='1',editing=true})
check('committed layout changes cue',count('build')==1)
a:Frame(.3,snapshot{orders=10,delivered=1,layout='2',editing=false})
check('non editing background changes stay silent',count('build')==1)
a:Frame(.3,snapshot{grill=1})
check('actual cooking enables one grill loop',loops.grill.on)
a:Frame(.3,snapshot{state='paused',grill=1})
check('pause stops world but retains soft music',not loops.grill.on and loops.music.on and not backend.active)
check('paused music is attenuated',backend.music<.8*.6*.5)
check('paused world emission rejected',not a:Emit('step'))
check('paused UI still responds',a:Emit('ui'))
a:Frame(.3,snapshot{focused=false,grill=1})
check('background mutes all categories immediately',backend.music==0 and backend.effects==0 and not loops.music.on and not loops.grill.on)
check('background refuses notifications',not a:Emit('delivery'))
a:Frame(.3,snapshot{state='paused'})
check('focus return never starts production audio',not backend.active and not loops.grill.on)
a:Frame(.3,snapshot{})
a:Machine(1,0,'shop');a:Machine(2,0,'shop')
check('dense machines coalesce completion sounds',count('machine')==1)
a:Frame(1,snapshot{})
check('off area machine remains silent',not a:Machine(1,0,'workshop'))
check('distant machine remains silent',not a:Machine(13,0,'shop'))
a:Frame(.2,snapshot{x=1,moving=true});a:Frame(.2,snapshot{x=2,moving=true})
check('actual distance drives footsteps',count('step')==1)
a:Frame(.2,snapshot{x=2,moving=true});a:Frame(.2,snapshot{x=2,moving=true})
check('blocked movement does not make footsteps',count('step')==1)
a:Frame(.2,snapshot{x=100,moving=true})
check('teleports do not produce step bursts',count('step')==1)
a:Frame(.2,snapshot{x=101,moving=true,area='workshop'})
check('area switch resets footstep distance',count('step')==1)
a:Preferences{masterVolume=.4,musicVolume=.2,effectsVolume=.5}
check('independent gains multiply master and category',math.abs(backend.effects-.2)<1e-9 and backend.music<.081)
a:Preferences{muted=true};a:Frame(.2,snapshot{})
check('mute preserves preferences but silences output',backend.music==0 and backend.effects==0 and not a:Emit('ui'))
a:Preferences(State.DefaultPreferences());a:Frame(1,snapshot{})
check('unmute restores sound',a:Emit('ui'))
a:Frame(1,snapshot{state='settlement'})
check('settlement emits one jingle',count('day')==1)
a:Frame(1,snapshot{state='settlement'})
check('settlement jingle never repeats per frame',count('day')==1)
local n=#events;a:Frame(1,snapshot{day=3,orders=200,held='day-load'})
check('day changes do not replay save inventory or orders',#events==n)
a:Stop();a:Stop();check('stop is idempotent and blocks later cues',backend.stopped and not a:Emit('ui'))

-- Actual native adapter against a recording SoundSource graph, no engine API assumptions.
local nodes,resources={},{}
local Node={};Node.__index=Node
function Node:CreateChild(name)local n=setmetatable({name=name},Node);nodes[#nodes+1]=n;return n end
function Node:CreateComponent()
 local s={playing=false,gain=0}
 function s:Play(sound,frequency,gain)self.playing=true;self.sound=sound;self.frequency=frequency;self.gain=gain end
 function s:Stop()self.playing=false end
 return s
end
function Node:Remove()self.removed=true end
cache={GetResource=function(_,kind,path)
 if path:find('drop.wav',1,true)then return nil end
 local s=resources[path] or {frequency=path:find('music.ogg',1,true) and 44100 or 22050}
 function s:GetFrequency()return self.frequency end
 function s:SetLooped(loop)self.looped=loop end
 resources[path]=s;return s
end}
local native=Soundscape.Native(setmetatable({},Node));native:Mix(1,.2,.4,true,true)
check('fixed pool creates exactly ten sources',#native.voices==8 and native.loops.music~=nil and native.loops.grill~=nil and #nodes==11)
check('native effect uses actual sample rate not pitch multiplier',native:Play('pickup',.5,1.1) and math.abs(native.voices[3].source.frequency-24255)<1e-8)
check('native category gain applies immediately',math.abs(native.voices[3].source.gain-.2)<1e-9)
native:Play('ui',.4,1)
check('UI uses separate two voice pool',native.voices[1].source.playing)
for i=1,60 do native:Play('machine',.5,1)end
check('many simultaneous events never grow source count',#nodes==11)
native:Loop('music',true,.5);check('music resource explicitly loops',native.loops.music.sound.looped)
native:Mix(2,.1,.2,true,false)
check('pause stops world voices but leaves UI pool',not native.voices[3].source.playing and native.voices[1].source.playing)
native:Mix(3,0,0,false,false);native:Loop('music',false,.5)
check('focus loss stops every voice and music',not native.voices[1].source.playing and not native.loops.music.playing)
check('missing effect never crashes or pretends success',not native:Play('drop',1,1))
native:Stop();check('native root removed on teardown',native.root.removed)
return results
''')
report={'passed':len(rows),'failed':0,'checks':[dict(v) for v in rows.values()],
 'scope':'Actual Lua policy and native adapter with recording SoundSource; not device audibility or Android'}
(ROOT/'docs/v07-audio-policy-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='checks'}))
