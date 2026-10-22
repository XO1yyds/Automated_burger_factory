-- Edge follow for the accepted vertical orthographic camera; pure math/policy.
local Follow={}
Follow.__index=Follow
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
function Follow.New() return setmetatable({previous=false},Follow) end
function Follow:Reset() self.previous=false end
function Follow:Step(dt,s)
    local previous=self.previous
    self.previous={x=s.x,z=s.z,area=s.area}
    if not s.enabled or s.manual or not s.moving or dt<=0 or not previous or previous.area~=s.area then return s.cx,s.cz,false end
    if (s.x-previous.x)^2+(s.z-previous.z)^2<.0000001 then return s.cx,s.cz,false end
    -- The full paper character is projected about its centre, not its feet.
    -- Start moving well before the outer screen boundary, with an FPS-neutral ease.
    local width,height=s.viewWidth,s.viewHeight
    if width<=0 or height<=0 then return s.cx,s.cz,false end
    local alpha=1-math.exp(-12*dt)
    local dx=(s.screenX-clamp(s.screenX,.20,.80))*width*alpha
    local dz=-(s.screenY-clamp(s.screenY,.26,.76))*height*alpha
    -- Recover immediately if a previous manual pan/zoom placed the actor outside.
    local afterX,afterY=s.screenX-dx/width,s.screenY+dz/height
    dx=dx+(afterX-clamp(afterX,.12,.88))*width
    dz=dz-(afterY-clamp(afterY,.12,.88))*height
    local x,z=clamp(s.cx+dx,s.minX,s.maxX),clamp(s.cz+dz,s.minZ,s.maxZ)
    return x,z,math.abs(x-s.cx)+math.abs(z-s.cz)>.000001
end
return Follow
