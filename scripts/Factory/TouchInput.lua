-- Pure pointer ownership, joystick and two-finger camera. No synthetic key events.
local State = require("Factory/UIState")
local Touch = {}
Touch.__index=Touch

function Touch.New()
    return setmetatable({pointers={},x=0,z=0,running=false,gesture=nil,joystickId=nil,objectId=nil},Touch)
end

function Touch:Reset()
    self.pointers={}; self.x,self.z,self.running=0,0,false
    self.gesture,self.joystickId,self.objectId=nil,nil,nil
end

function Touch:Begin(id,x,y,kind,centerX,centerY)
    if self.pointers[id] then return false end
    if kind=="joystick" and self.joystickId then return false end
    if kind=="object" and (self.objectId or self.gesture) then return false end
    if kind=="scene" and self.objectId then kind="blocked" end
    if kind=="joystick" then self.joystickId=id end
    if kind=="object" then self.objectId=id end
    self.pointers[id]={x=x,y=y,startX=x,startY=y,kind=kind,cx=centerX,cy=centerY,moved=false}
    self:Move(id,x,y)
    return true
end

function Touch:Move(id,x,y)
    local p=self.pointers[id]; if not p then return nil end
    p.x,p.y=x,y
    if (x-p.startX)^2+(y-p.startY)^2>=64 then p.moved=true end
    if p.kind=="joystick" then
        local dx,dy=(x-p.cx)/56,(y-p.cy)/56
        local length=math.sqrt(dx*dx+dy*dy)
        if length<0.15 then self.x,self.z,self.running=0,0,false
        else
            self.x,self.z=dx/math.max(1,length),-dy/math.max(1,length)
            if length>=0.85 then self.running=true elseif length<0.75 then self.running=false end
        end
        return nil
    end
    if self.objectId then return nil end
    local fingers={}
    for key,value in pairs(self.pointers) do if value.kind=="scene" then table.insert(fingers,{id=key,p=value}) end end
    table.sort(fingers,function(a,b) return a.id<b.id end)
    if #fingers~=2 then self.gesture=nil; return nil end
    local a,b=fingers[1].p,fingers[2].p
    a.moved,b.moved=true,true
    local g={x=(a.x+b.x)/2,y=(a.y+b.y)/2,d=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)}
    local previous=self.gesture; self.gesture=g
    if previous then return {dx=g.x-previous.x,dy=g.y-previous.y,scale=previous.d>0 and g.d/previous.d or 1} end
    return nil
end

function Touch:End(id)
    local p=self.pointers[id]
    if id==self.joystickId then self.joystickId=nil; self.x,self.z,self.running=0,0,false end
    if id==self.objectId then self.objectId=nil end
    self.pointers[id]=nil; self.gesture=nil
    return p
end

return Touch
