-- A JSON-safe object graph. Reference IDs preserve table-keyed arrival history and
-- owner/lock identity; functions, engine values and runtime contexts are never saved.
local Codec={}
local skip={context=true,node=true,body=true,visual=true,highlight=true,nameNode=true,nameText=true,nameBackground=true,label=true,heldNode=true}
function Codec.Pack(root)
    local ids,nodes={},{}
    local function value(v)
        local kind=type(v)
        if kind=='string' or kind=='boolean' then return {value=v} end
        if kind=='number' then assert(v==v and math.abs(v)<math.huge,'Nonfinite save value'); return {value=v} end
        if kind~='table' then return nil end
        if ids[v] then return {ref=ids[v]} end
        local id=#nodes+1; ids[v]=id; local rows={}; nodes[id]=rows
        for k,x in pairs(v) do
            if not (type(k)=='string' and skip[k]) and not (k=='items' and type(x)=='table' and x.context) then
                local a,b=value(k),value(x); if a and b then rows[#rows+1]={a,b} end
            end
        end
        return {ref=id}
    end
    local ref=value(root)
    return {root=ref,nodes=nodes}
end
function Codec.Unpack(data)
    assert(type(data)=='table' and type(data.nodes)=='table' and #data.nodes<=100000,'Invalid save graph')
    local nodes={}; for i=1,#data.nodes do nodes[i]={} end
    local function value(v)
        assert(type(v)=='table','Invalid graph value')
        if v.ref then assert(type(v.ref)=='number' and v.ref%1==0 and nodes[v.ref],'Bad graph reference'); return nodes[v.ref] end
        assert(type(v.value)=='string' or type(v.value)=='number' or type(v.value)=='boolean','Bad graph scalar')
        return v.value
    end
    for i,rows in ipairs(data.nodes) do
        assert(type(rows)=='table','Invalid graph node')
        for _,row in ipairs(rows) do nodes[i][value(row[1])]=value(row[2]) end
    end
    return value(data.root)
end
function Codec.Hash(text)
    local hash=2166136261
    for i=1,#text do hash=((hash ~ text:byte(i))*16777619)&0xffffffff end
    return string.format('%08x',hash)
end
return Codec
