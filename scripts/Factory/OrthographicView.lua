-- Full-window orthographic coordinates, independent of the renderer's active viewport.
-- UrhoX orthoSize is the full visible height; zoom scales both axes equally.
local View={}
local function dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end

function View.Project(point,position,right,up,orthoSize,zoom,width,height,scale)
    local density=height*zoom/(orthoSize*scale)
    local delta={x=point.x-position.x,y=point.y-position.y,z=point.z-position.z}
    return width/(2*scale)+dot(delta,right)*density,height/(2*scale)-dot(delta,up)*density
end

-- Return a world point on a horizontal plane. Inputs x/y are full-window UI units.
function View.Point(x,y,plane,position,right,up,forward,orthoSize,zoom,width,height,scale)
    if math.abs(forward.y)<0.000001 then return nil end
    local density=height*zoom/(orthoSize*scale)
    local vx,vy=(x-width/(2*scale))/density,(height/(2*scale)-y)/density
    local ox=position.x+right.x*vx+up.x*vy
    local oy=position.y+right.y*vx+up.y*vy
    local oz=position.z+right.z*vx+up.z*vy
    local distance=(plane-oy)/forward.y
    if distance<0 then return nil end
    return ox+forward.x*distance,plane,oz+forward.z*distance
end

-- All candidate positions remain relative to the same projected building anchor.
-- Never clamp a card to a fixed screen coordinate while its building moves away.
function View.Card(anchorX,anchorY,cardWidth,cardHeight,width,height,top,bottom)
    local gap,margin=5,12
    if anchorX<margin or anchorX>width-margin or anchorY<top or anchorY>height-bottom then return nil end
    local x=anchorX-cardWidth/2
    if x<margin then x=anchorX+gap
    elseif x+cardWidth>width-margin then x=anchorX-cardWidth-gap end
    local y=anchorY-cardHeight-gap
    if y<top then y=anchorY+gap end
    if x<margin or x+cardWidth>width-margin or y<top or y+cardHeight>height-bottom then return nil end
    return x,y
end

function View.SegmentDistance(x,y,ax,ay,bx,by)
    local dx,dy=bx-ax,by-ay
    local length=dx*dx+dy*dy
    local t=length>0 and math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/length)) or 0
    return (x-ax-dx*t)^2+(y-ay-dy*t)^2
end

return View
