local Codec=require('Factory/SaveCodec')
---@class FactoryLocalSave
---@field backend table
---@field json table
---@field validate? fun(state:table):boolean
---@field archivedInvalid? boolean
local Save={}
Save.Version=6
-- Official Maker relative-path sandbox provides project/user isolation on native platforms.
Save.Files={'burger-v06-a.json','burger-v06-b.json'}
function Save.NativeBackend()
    return {
        read=function(path)
            if not fileSystem or not fileSystem:FileExists(path) then return nil end
            local file=File(path,FILE_READ); if not file:IsOpen() then return nil end
            local text=file:ReadString(); file:Close(); return text
        end,
        write=function(path,text)
            local file=File(path,FILE_WRITE); if not file:IsOpen() then return false end
            local ok=file:WriteString(text); file:Flush(); file:Close(); return ok~=false
        end,
    }
end
---@return FactoryLocalSave
function Save.New(backend,json)
    return setmetatable({backend=backend or Save.NativeBackend(),json=json or cjson}, {__index=Save})
end
function Save:Read(path)
    local ok,record=pcall(function()
        local text=self.backend.read(path); if not text then return nil end
        local r=self.json.decode(text)
        if type(r)~='table' then return nil end
        if type(r.version)=='number' and r.version>Save.Version then return {future=true} end
        if r.version~=Save.Version or type(r.payload)~='string' or r.hash~=Codec.Hash(r.payload) or type(r.sequence)~='number' then return nil end
        local graph=self.json.decode(r.payload); local state=Codec.Unpack(graph)
        if type(state)~='table' or type(state.loop)~='table' or type(state.campaign)~='table' or type(state.stations)~='table' then return nil end
        if type(state.campaign.day)~='number' or state.campaign.day%1~=0 or state.campaign.day<1 or state.campaign.day>10 then return nil end
        if self.validate and not self.validate(state) then return nil end
        return {state=state,sequence=r.sequence,stamp=r.stamp,path=path}
    end)
    return ok and record or nil
end
function Save:Load()
    local a,b=self:Read(Save.Files[1]),self:Read(Save.Files[2])
    if (a and a.future) or (b and b.future) then return nil,'发现更高版本存档，请勿覆盖或降级读取。',true end
    if a and b then return a.sequence>=b.sequence and a or b end
    if a or b then return a or b,'已从单份有效存档恢复；另一份可能缺失或损坏。' end
    local hasInvalid=false
    for _,path in ipairs(Save.Files) do local ok,text=pcall(self.backend.read,path); if ok and text then hasInvalid=true end end
    return nil,hasInvalid and '本地存档均未通过校验；新游戏会先保留损坏副本再新建。' or '没有有效经营存档。'
end
function Save:Write(state)
    local current,_,future=self:Load(); if future then return false,'更高版本存档受保护，保存已拒绝。' end
    local target=current and (current.path==Save.Files[1] and Save.Files[2] or Save.Files[1]) or Save.Files[1]
    local ok,message=pcall(function()
        if not current and not self.archivedInvalid then
            for i,path in ipairs(Save.Files) do
                local old=self.backend.read(path)
                if old then assert(self.backend.write(path..'.invalid-'..os.time()..'-'..i,old),'无法保留损坏存档，拒绝覆盖') end
            end
            self.archivedInvalid=true
        end
        local payload=self.json.encode(Codec.Pack(state))
        local sequence=(current and current.sequence or 0)+1
        local text=self.json.encode({version=Save.Version,sequence=sequence,stamp=os.date('%Y-%m-%d %H:%M:%S'),hash=Codec.Hash(payload),payload=payload})
        -- Write the older/inactive slot. The latest valid slot is untouched even if
        -- this write is interrupted; choose the greatest valid sequence on load.
        assert(self.backend.write(target,text),'无法写入本地保存区')
        local verify=self:Read(target); assert(verify and verify.sequence==sequence,'存档写后校验失败')
    end)
    return ok,ok and '进度已保存至本机。' or tostring(message)
end
return Save
