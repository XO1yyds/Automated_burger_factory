"""Execute actual StaticArt binding against a recording renderer, not native visual QA."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/conveyor-test-runtime'))
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
report=lua.execute(r'''
package.path='scripts/?.lua;'..package.path
Vector3=setmetatable({},{__call=function(_,x,y,z)return{x=x,y=y,z=z}end});Vector3.UP=Vector3(0,1,0)
function Vector2(x,y)return{x=x,y=y}end
function Color(r,g,b,a)return{r=r,g=g,b=b,a=a or 1}end
function Variant(value)return value end
TRIANGLE_LIST=0
Material={};function Material:new()
 return {SetSurfaceShader=function()return true end,SetSurfaceTexture=function(s,k,v)s.texture=v end,
 SetShaderParameter=function(s,k,v)s[k]=v end}
end
cache={GetResource=function(_,kind,path)if path=='missing.png'then return nil end;return{name=path}end}
local Node={};Node.__index=Node
function Node.New(name)return setmetatable({name=name,children={},components={}},Node)end
function Node:CreateChild(name)local n=Node.New(name);self.children[name]=n;return n end
function Node:GetChild(name)return self.children[name]end
function Node:GetComponent(kind)return self.components[kind]end
function Node:CreateComponent(kind)
 local c={enabled=true,uv={},vertices={}}
 function c:BeginGeometry()self.uv={};self.vertices={}end
 function c:DefineVertex(v)self.vertices[#self.vertices+1]=v end
 function c:DefineNormal()end
 function c:DefineTexCoord(v)self.uv[#self.uv+1]=v end
 function c:Commit()end
 function c:SetMaterial(m)self.material=m end
 self.components[kind]=c;return c
end
local Art=require('Factory/StaticArt');local Frames=require('Factory/CharacterFrames')
local checks={};local function check(name,ok)checks[#checks+1]={name=name,passed=not not ok};assert(ok,name)end
local actor=Node.New('Player');local box=Node.New('Box');box:CreateComponent('StaticModel')
local front=Vector3(0,0,-1);local ctx={active=true,controllable=true,moving=true,carrying=false}
Art.AnimatePlayer(actor,box,front,nil,false,0,ctx)
local quad=actor:GetChild('EmployeePaper');local geo=quad:GetComponent('CustomGeometry');local pivot=quad.position.z
local paperY=geo.vertices[1].y
check('player display plane clears machine tops without actor movement',.55+paperY>1.10 and actor.position==nil and actor.scale==nil)
check('atlas frame1 texture and guard UV',geo.material.texture.name==Frames.front_walk.atlas and math.abs(geo.uv[1].x-8/1088)<1e-9)
Art.AnimatePlayer(actor,box,front,nil,false,1/6+.0001,ctx)
check('frame2 changes UV without moving paper pivot',math.abs(geo.uv[1].x-280/1088)<1e-9 and quad.position.z==pivot)
check('animation UV rebuild preserves elevated display plane',geo.vertices[1].y==paperY)
local other=Node.New('Other');Art.AnimatePlayer(other,other,front,nil,false,0,ctx)
check('independent actor UV clocks',math.abs(geo.uv[1].x-280/1088)<1e-9 and math.abs(other:GetChild('EmployeePaper'):GetComponent('CustomGeometry').uv[1].x-8/1088)<1e-9)
local food=actor:CreateChild('Held_burger');Art.Quad(food,'ItemArt','burger',1.55,1.55,.55)
local ground=Node.New('Ground');local g=Art.Quad(ground,'Food','burger',1.55,1.55,.55)
ctx.moving=false;ctx.carrying=true;Art.AnimatePlayer(actor,box,front,food,true,0,ctx)
check('held fades to25percent during construction',food:GetChild('ItemArt'):GetComponent('CustomGeometry').material.art_tint.a==.25)
check('held fade never changes shared ground opacity',g:GetComponent('CustomGeometry').material.art_tint.a==1)
Art.AnimatePlayer(actor,box,front,food,false,0,ctx)
check('held opacity restores',food:GetChild('ItemArt'):GetComponent('CustomGeometry').material.art_tint.a==1)
local rearY=food.position.y;Art.AnimatePlayer(actor,box,Vector3(0,0,1),food,false,0,ctx)
check('rear cargo is behind body plane',food.position.y<rearY)
check('cargo planes clear machines and retain front back ordering',.55+food.position.y+.55*.20>1.10 and food.position.y+.55*.20<paperY and rearY+.55*.20>paperY)
local saved=Frames.left_run.atlas;Frames.left_run.atlas='missing.png';local missing=Node.New('Missing')
Art.AnimatePlayer(missing,missing,Vector3(-1,0,0),nil,true,0,{active=true,controllable=true,moving=true,running=true})
local mg=missing:GetChild('EmployeePaper'):GetComponent('CustomGeometry')
check('missing texture falls back to whole static direction',mg.material.texture.name:find('employee_left.png',1,true)~=nil and mg.uv[1].x==0 and mg.uv[3].x==1)
check('missing texture keeps same elevated paper layer',mg.vertices[1].y==paperY)
Frames.left_run.atlas=saved
Art.AnimatePlayer(actor,box,front,nil,false,0,{active=true,controllable=true,moving=true})
local clip=Frames.front_walk;Frames.front_walk=nil
Art.AnimatePlayer(actor,box,front,nil,false,0,{active=true,controllable=true,moving=true})
check('missing clip also resets atlas UV to whole static frame',geo.uv[1].x==0 and geo.uv[3].x==1 and geo.material.texture.name:find('employee_front.png',1,true)~=nil)
Frames.front_walk=clip;Art.AnimatePlayer(actor,box,front,nil,false,0,{active=true,controllable=true,moving=true})
check('restored clip returns to atlas',geo.material.texture.name==clip.atlas and geo.uv[1].x>0)
Art.ResetPlayer(actor);local clock=Art.PlayerState(actor)
check('reset clears animation while retaining fixed quad',clock.action=='idle' and clock.frame==1 and clock.idleAge==0 and actor:GetChild('EmployeePaper')==quad and quad.position.z==pivot)
return checks
''')
rows=[dict(r) for r in report.values()]
out={'passed':len(rows),'failed':0,'checks':rows,'scope':'Actual StaticArt Lua with recording geometry/material mocks; texture coordinates, ownership and failure paths, not native shader output'}
(ROOT/'docs/v04-character-four-frame-render-evidence.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in out.items() if k!='checks'}))
