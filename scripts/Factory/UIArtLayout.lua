-- Logical units after safe-area and UI scaling; independent of game simulation.
local Layout={}
function Layout.For(w,h,phase,model)
    local compact=h<540; local narrow=w<1000
    local menu=phase=='menu';local edit=phase=='preview' or phase=='move'
    local width=math.min(680,w-32)
    local rows=model and model.modal or {}
    local lineCount=0
    for _,text in ipairs(rows.lines or {}) do local _,n=text:gsub('\n',''); lineCount=lineCount+n+1 end
    local toolRows=math.ceil(#(rows.tools or {})/(width>=580 and 2 or 1))
    local wanted=120+lineCount*32+#(rows.entries or {})*84+toolRows*56
        +(rows.tabs and 56 or 0)+(rows.summary and 40 or 0)+(rows.quantity and 64 or 0)+#(rows.audio or {})*100
        +(#(rows.buttons or {})>0 and 60 or 0)
    local height=math.min(h-48,math.max(230,wanted))
    if phase=='title' then width=math.min(620,w-32);height=math.min(h-48,448)
    elseif phase=='terminal' then height=math.min(h-48,math.max(450,height)) end
    local header=phase=='normal' and (narrow and 112 or 68) or (narrow and 164 or 120)
    return {compact=compact,narrow=narrow,modalWidth=width,modalHeight=height,modalTop=(h-height)/2,
        selectorHeight=compact and 156 or 168,cardHeight=compact and 78 or 90,
        toolbarRight=12,reasonBottom=menu and (compact and 180 or 188) or edit and 142 or 82,
        headerBottom=header,tutorialTop=header+12,heldLeft=140,
        reasonWidth=math.min(560,w-172),toastWidth=math.min(480,w-40)}
end
return Layout
