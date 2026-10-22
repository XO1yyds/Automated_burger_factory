-- Presentation only: never consumes inventory, saves campaign state or gameplay RNG.
local Assets=require('Factory/AudioAssets')
local State=require('Factory/UIState')
---@class FactorySoundscape
---@field backend table
---@field preferences table
---@field now number
---@field focused boolean
---@field active boolean
---@field cooldowns table
---@field counts table
---@field previous? table
---@field stopped? boolean
---@field stride number
---@field stepIndex integer
local Soundscape={}
Soundscape.__index=Soundscape

function Soundscape.Native(scene)
    local root=scene:CreateChild('V07Audio')
    local backend={root=root,sounds={},retry={},warned={},voices={},loops={},now=0,musicMix=0,effectsMix=0,focused=true,active=false}
    -- Two UI voices and six world voices: fixed cost even in a large factory.
    for i=1,8 do backend.voices[i]={source=root:CreateChild('Voice'..i):CreateComponent('SoundSource'),ui=i<=2} end
    for _,key in ipairs({'music','grill'}) do backend.loops[key]=root:CreateChild(key):CreateComponent('SoundSource') end
    function backend:Resource(key)
        if self.sounds[key] then return self.sounds[key] end
        if (self.retry[key] or -1)>self.now then return nil end
        local sound=cache:GetResource('Sound',Assets[key].file)
        if sound then sound:SetLooped(Assets[key].loop==true);self.sounds[key]=sound;return sound end
        self.retry[key]=self.now+3
        if not self.warned[key] then self.warned[key]=true;print('[V07 Audio] Missing '..Assets[key].file..'; gameplay continues') end
        return nil
    end
    function backend:Mix(now,musicGain,effectsGain,focused,active)
        self.now,self.musicMix,self.effectsMix,self.focused,self.active=now,musicGain,effectsGain,focused,active
        for _,v in ipairs(self.voices) do
            if not focused or (not v.ui and not active) then v.source:Stop();v.source.gain=0
            else v.source.gain=(v.base or 0)*effectsGain end
        end
    end
    function backend:Play(key,gain,pitch)
        local definition=Assets[key];local ui=not definition.world
        local first,last=ui and 1 or 3,ui and 2 or 8
        ---@type {source:SoundSource, ui:boolean, base?:number, at?:number}?
        local selected=nil
        for i=first,last do local v=self.voices[i] --[[@as {source:SoundSource, ui:boolean, base?:number, at?:number}]]
            if not v.source.playing then selected=v;break end
            if not selected or (v.at or 0)<(selected.at or 0) then selected=v end
        end
        local sound=self:Resource(key)
        if not sound then return false end
        selected.source:Stop();selected.base=gain;selected.at=self.now
        selected.source:Play(sound,sound:GetFrequency()*(pitch or 1),gain*self.effectsMix)
        return true
    end
    function backend:Loop(key,on,gain)
        local source=self.loops[key]
        local mix=key=='music' and self.musicMix or self.effectsMix
        if not on or mix<=0 or gain<=0 then source:Stop();source.gain=0;return end
        if not source.playing then
            local sound=self:Resource(key);if not sound then return end
            source:Play(sound,0,gain*mix)
        end
        source.gain=gain*mix
    end
    function backend:Stop()
        for _,v in ipairs(self.voices) do v.source:Stop() end
        for _,source in pairs(self.loops) do source:Stop() end
        self.root:Remove()
    end
    function backend:Report()
        local sources=0;for _,v in ipairs(self.voices) do if v.source.playing then sources=sources+1 end end
        return {voices=#self.voices,playing=sources,music=self.loops.music.playing,musicGain=self.loops.music.gain,
            grill=self.loops.grill.playing,grillGain=self.loops.grill.gain,missing=self.warned}
    end
    return backend
end

function Soundscape.New(scene,backend)
    return setmetatable({backend=backend or Soundscape.Native(scene),preferences=State.DefaultPreferences(),now=0,
        focused=true,active=false,cooldowns={},counts={},stride=0,stepIndex=0},Soundscape)
end
function Soundscape:Preferences(p)
    self.preferences=State.SanitizePreferences(p)
    self:Mix()
end
function Soundscape:Mix()
    local p=self.preferences;local master=p.muted and 0 or p.masterVolume
    local music=master*p.musicVolume*(self.duck or .65)
    local effects=master*p.effectsVolume
    self.backend:Mix(self.now,self.focused and music or 0,self.focused and effects or 0,self.focused,self.active)
end
function Soundscape:Emit(key,scale,pitch)
    local d=Assets[key]
    if self.stopped or not d or d.loop or not self.focused or (d.world and not self.active) then return false end
    local p=self.preferences
    if p.muted or p.masterVolume<=0 or p.effectsVolume<=0 or (self.cooldowns[key] or -1)>self.now then return false end
    if not self.backend:Play(key,d.gain*(scale or 1),pitch or 1) then return false end
    self.cooldowns[key]=self.now+(d.cooldown or .1)
    self.counts[key]=(self.counts[key] or 0)+1
    return true
end
function Soundscape:Machine(x,z,area)
    local p=self.previous
    if not p or p.area~=area then return false end
    local distance=math.sqrt((p.x-x)^2+(p.z-z)^2)
    if distance>=12 then return false end
    return self:Emit('machine',.25+.75*(1-distance/12))
end
function Soundscape:Frame(dt,s)
    if self.stopped then return end
    self.now=self.now+math.max(0,dt)
    self.focused=s.focused~=false
    self.active=self.focused and (s.state=='running' or s.state=='preparation') and not s.frozen
    local target=not self.focused and 0 or s.state=='paused' and .38 or s.state=='title' and .72 or s.normal and 1 or .65
    self.duck=(self.duck or target)+(target-(self.duck or target))*math.min(1,math.max(0,dt)*5)
    self:Mix()
    self.backend:Loop('music',self.focused,Assets.music.gain)
    self.backend:Loop('grill',self.active and (s.grill or 0)>0,Assets.grill.gain*(s.grill or 0))
    local p=self.previous
    if p and p.day==s.day and p.state~='title' and s.state~='title' then
        if s.orders>p.orders then self:Emit('order') end
        if s.delivered>p.delivered then self:Emit('delivery') end
        if s.state=='settlement' and p.state~='settlement' then self:Emit('day') end
        if self.active then
            if s.held~=p.held then self:Emit(s.held and 'pickup' or 'drop') end
            if s.layout~=p.layout and s.editing then self:Emit('build') end
            if s.manualReady~=p.manualReady and s.manualReady then self:Emit('machine',.75) end
        end
    end
    if p and self.active and s.normal and p.area==s.area and s.moving then
        local distance=math.sqrt((p.x-s.x)^2+(p.z-s.z)^2)
        if distance<3 then
            self.stride=self.stride+distance
            local stride=s.running and 1.8 or 1.5
            if self.stride>=stride then
                self.stride=self.stride%stride;self.stepIndex=self.stepIndex+1
                self:Emit('step',s.running and 1 or .8,.97+(self.stepIndex%3)*.03)
            end
        else self.stride=0 end
    else self.stride=0 end
    -- Snapshot only primitive presentation values. No retained gameplay containers.
    self.previous=s
end
function Soundscape:Stop() if not self.stopped then self.stopped=true;self.backend:Stop() end end
function Soundscape:Report() return {counts=self.counts,focused=self.focused,active=self.active,native=self.backend.Report and self.backend:Report()} end
return Soundscape
