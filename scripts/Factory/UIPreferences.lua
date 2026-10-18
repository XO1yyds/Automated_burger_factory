local State = require("Factory/UIState")
local Preferences = {}
Preferences.FileName = "burger-ui-v03.json"

function Preferences.Load()
    if not fileSystem or not File or not cjson then return State.DefaultPreferences() end
    local ok,result=pcall(function()
        if not fileSystem:FileExists(Preferences.FileName) then return State.DefaultPreferences() end
        local file=File(Preferences.FileName,FILE_READ)
        if not file:IsOpen() then return State.DefaultPreferences() end
        local text=file:ReadString(); file:Close()
        return State.SanitizePreferences(cjson.decode(text))
    end)
    return ok and result or State.DefaultPreferences()
end

function Preferences.Save(data)
    if not File or not cjson then return false end
    local ok,saved=pcall(function()
        local file=File(Preferences.FileName,FILE_WRITE)
        if not file:IsOpen() then return false end
        file:WriteString(cjson.encode(State.SanitizePreferences(data))); file:Close(); return true
    end)
    return ok and saved
end

return Preferences
