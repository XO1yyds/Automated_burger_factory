-- Read-only runtime measurements; does not set gap, row height or font styles.
local UI = require("urhox-libs/UI")
local Diagnostics = {}

---@param stage string
---@param view FactoryInterface
function Diagnostics.Capture(stage, view)
    local panel = assert(UI.GetRoot()):FindById("factory_info") --[[@as Panel?]]
    if not panel then return end
    local panelBox = panel:GetAbsoluteLayout()
    local translation = rawget(_G, "i18n")
    print(string.format("[HUD Diagnosis] %s scale=%s autoFit=%s i18nActive=%s gap=%s",
        stage, tostring(UI.GetScale()), tostring(UI.defaultAutoFitText),
        tostring(translation and translation.IsActive and translation.IsActive()), tostring(panel.props.gap)))
    print(string.format("[HUD Diagnosis] %s panelWidth=%.3f panelHeight=%.3f", stage, panelBox.w, panelBox.h))
    local previousBottom = nil
    for index, child in ipairs(panel:GetChildren()) do
        if child:IsVisible() then
            local box = child:GetAbsoluteLayout()
            print(string.format("[HUD Diagnosis] %s row=%d y=%.3f h=%.3f measuredGap=%s font=%s lineHeight=%s text=%s",
                stage, index, box.y, box.h, previousBottom and string.format("%.3f", box.y - previousBottom) or "none",
                tostring(child.props.fontSize), tostring(child.props.lineHeight), tostring(child.props.text)))
            previousBottom = box.y + box.h
            print(string.format("[HUD Diagnosis] %s detailsRow=%d width=%.3f configuredHeight=%s whiteSpace=%s autoHeight=%s",
                stage, index, box.w, tostring(child.props.height), tostring(child.props.whiteSpace), tostring(rawget(child, "autoHeight_"))))
        end
    end
end

return Diagnostics
