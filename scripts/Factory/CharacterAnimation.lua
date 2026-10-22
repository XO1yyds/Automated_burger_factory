-- Presentation-only four-frame clock. No inventory, physics or production writes.
local Animation={}
Animation.FPS={idle=2,walk=6,run=8,carry_idle=2,carry_walk=6,carry_run=8,operate=6,think=2}
function Animation.New()
    return {action='idle',direction='front',frame=1,time=0,idleAge=0}
end
function Animation.Reset(state)
    state.action,state.direction,state.frame,state.time,state.idleAge='idle','front',1,0,0
end
function Animation.Step(state,dt,context)
    if not context.active then return state end
    dt=math.max(0,dt)
    local action='idle'
    local elapsed=state.time+dt
    local carry=context.carrying
    local interrupted=context.activity or context.moving or context.operating or carry or not context.controllable
    if interrupted then state.idleAge=0 else state.idleAge=state.idleAge+dt end
    if not context.controllable then action=carry and 'carry_idle' or 'idle'
    elseif context.operating then action='operate'
    elseif context.moving then action=carry and (context.running and 'carry_run' or 'carry_walk') or (context.running and 'run' or 'walk')
    elseif carry then action='carry_idle'
    elseif not context.activity and state.action=='think' and elapsed<2 then action='think'
    elseif not context.activity and state.action=='think' then state.idleAge=0
    elseif state.idleAge>=30 then action='think' end
    local direction=context.direction or state.direction
    if action~=state.action or direction~=state.direction then elapsed=0 end
    state.action,state.direction,state.time=action,direction,elapsed
    local index=math.floor(elapsed*Animation.FPS[action])
    state.frame=action=='think' and math.min(4,index+1) or index%4+1
    return state
end
return Animation
