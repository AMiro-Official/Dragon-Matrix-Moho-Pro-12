--[[
    needed functions
--]
function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

--local s = "dsfadf"
--print(s.split("a")[1])
--[
function DF_Joystick:serialize(val, name , skipnewlines, depth)

    skipnewlines = skipnewlines or false
    depth = depth or 0

    if depth == 0 and name == nil then
        name = 'v'
    end

    local tmp = string.rep(" ", depth)

    --if name then tmp = tmp .. name .. " = " end

    if type(val) == "table" then
      tmp = tmp .. "{" .. (not skipnewlines and "" or "")

      for k, v in pairs(val) do
         tmp =  tmp .. DF_Joystick:serialize(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "" or "")
      end

      tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
      tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
      tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
      tmp = tmp .. tostring(val)
    elseif type(val) == "function" then
      tmp = tmp .. "loadstring(" .. DF_Joystick:serialize(string.dump(val)) .. ")"
    else
      tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

function DF_Joystick:unserialize(s,name)
    print('unserialize',s,type(s))
    if tonumber(s) ~= -1 then
        s = 'return'..s
        local func = loadstring(s)
        if func~= nil then
            func()
        end
    end
    --return v
end
--]
function serialize(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lua = lua .. "{"
    for k, v in pairs(obj) do
        lua = lua .. "[" .. DF_Joystick:serialize(k) .. "]=" .. DF_Joystick:serialize(v) .. ","
    end
    local metatable = getmetatable(obj)
        if metatable ~= nil and type(metatable.__index) == "table" then
        for k, v in pairs(metatable.__index) do
            lua = lua .. "[" .. DF_Joystick:serialize(k) .. "]=" .. DF_Joystick:serialize(v) .. ","
        end
    end
        lua = lua .. "}"
    elseif t == "nil" then
        return nil
    else
        error("can not serialize a " .. t .. " type.")
    end
    lua = string.gsub(lua,'%"','%`')
    return lua
end

function unserialize(lua)
    local t = type(lua)
    if t == "nil" or lua == "" then
        return nil
    elseif t == "number" or t == "string" or t == "boolean" then
        lua = tostring(lua)
    else
        error("can not unserialize a " .. t .. " type.")
    end
    lua = string.gsub(lua,'%`', '%"')
    lua = "return " .. lua
    local func = loadstring(lua)
    if func == nil then
        return nil
    end
    return func()
end
--]]
--[[
s = DF_Joystick:serialize({a = "foo", b = {c = 123, d = "foo"}})
print(' string: '..s)

print( DF_Joystick:unserialize(s,'v').a )
--]]
--[[
local data = { ["actionId"] = -1 , ["joystickName"] = 'none' , ["layerName"] = 'none' }
print(DF_Joystick:serialize(data))

--]]
--[[
local data = DF_Joystick:serialize({["a"] = '0',})
print(DF_Joystick:unserialize(data).a)
--]]
--[[
data = {["a"] = "a", ["b"] = "b", ["c"] = -1 , [1] = 1, [2] = 2, ["t"] = {1, 2, 3}}
local sz = DF_Joystick:serialize(data)
print('string:'..sz)
print("---------")
print(DF_Joystick:unserialize(sz).a)
print('serial:'..DF_Joystick:serialize(DF_Joystick:unserialize(sz)))
--]]


--[[
    getset.lua
    A library for adding getters and setters to Lua tables.
    Copyright (c) 2011 Josh Tynjala
    Licensed under the MIT license.
--

local function throwReadOnlyError(table, key)
    error("Cannot assign to read-only property '" .. key .. "' of " .. tostring(table) .. ".");
end

local function throwNotExtensibleError(table, key)
    error("Cannot add property '" .. key .. "' because " .. tostring(table) .. " is not extensible.")
end

local function throwSealedError(table, key)
    error("Cannot redefine property '" .. key .. "' because " .. tostring(table) .. " is sealed.")
end

local function getset__index(table, key)
    local gs = table.__getset

    -- try to find a descriptor first
    local descriptor = gs.descriptors[key]
    if descriptor and descriptor.get then
        return descriptor.get()
    end

    -- if an old metatable exists, use that
    local old__index = gs.old__index
    if old__index then
        return old__index(table, key)
    end

    return nil
end
local function getset__newindex(table, key, value)
    local gs = table.__getset

    -- check for a property first
    local descriptor = gs.descriptors[key]
    if descriptor then
        if not descriptor.set then
            throwReadOnlyError(table, key)
        end
        descriptor.set(value)
        return
    end

    -- use the __newindex from the previous metatable next
    -- if it exists, then isExtensible will be ignored
    local old__newindex = gs.old__newindex
    if old__newindex then
        old__newindex(table, key, value)
        return
    end

    -- finally, fall back to rawset()
    if gs.isExtensible then
        rawset(table, key, value)
    else
        throwNotExtensibleError(table, key)
    end
end

-- initializes the table with __getset field
local function initgetset(table)
    if table.__getset then
        return
    end

    local mt = getmetatable(table)
    local old__index
    local old__newindex
    if mt then
        old__index = mt.__index
        old__newindex = mt.__newindex
    else
        mt = {}
        setmetatable(table, mt)
    end
    mt.__index = getset__index
    mt.__newindex = getset__newindex
    rawset(table, "__getset",
    {
        old__index = old__index,
        old__newindex = old__newindex,
        descriptors = {},
        isExtensible = true,
        isOldMetatableExtensible = true,
        isSealed = false
    })
    return table
end

local getset = {}

--- Defines a new property or modifies an existing property on a table. A getter
-- and a setter may be defined in the descriptor, but both are optional.
-- If a metatable already existed, and it had something similar to getters and
-- setters defined using __index and __newindex, then those functions can be 
-- accessed directly through table.__getset.old__index() and
-- table.__getset.old__newindex(). This is useful if you want to override with
-- defineProperty(), but still manipulate the original functions.
-- @param table         The table on which to define or modify the property
-- @param key           The name of the property to be defined or modified
-- @param descriptor    The descriptor containing the getter and setter functions for the property being defined or modified
-- @return              The table and the old raw value of the field
function getset.defineProperty(table, key, descriptor)
    initgetset(table)

    local gs = table.__getset

    local oldDescriptor = gs.descriptors[key]
    local oldValue = table[key]

    if gs.isSealed and (oldDescriptor or oldValue) then
        throwSealedError(table, key)
    elseif not gs.isExtensible and not oldDescriptor and not oldValue then
        throwNotExtensibleError(table, key)
    end

    gs.descriptors[key] = descriptor

    -- we need to set the raw value to nil so that the metatable works
    rawset(table, key, nil)

    -- but we'll return the old raw value, just in case it is needed
    return table, oldValue
end

--- Prevents new properties from being added to a table. Existing properties may
-- be modified and configured.
-- @param table     The table that should be made non-extensible
-- @return          The table
function getset.preventExtensions(table)
    initgetset(table)

    local gs = table.__getset
    gs.isExtensible = false
    return table
end

--- Determines if a table is extensible. If a table isn't initialized with
-- getset, this function returns true, since regular tables are always
-- extensible. If a previous __newindex metatable method was defined before
-- this table was initialized with getset, then isExtensible will be ignored
-- completely.
-- @param table     The table to be checked
-- @return          true if extensible, false if non-extensible
function getset.isExtensible(table)
    local gs = table.__getset
    if not gs then
        return true
    end
end

--- Prevents new properties from being added to a table, and existing properties 
-- may be modified, but not configured.
-- @param table     The table that should be sealed
-- @return          The table
function getset.seal(table)
    initgetset(table)
    local gs = table.__getset
    gs.isExtensible = false
    gs.isSealed = true
    return table
end

--= Determines if a table is sealed. If a table isn't initialized with getset,
-- this function returns false, since regular tables are never sealed.
-- completely.
-- @param table     The table to be checked
-- @return          true if sealed, false if not sealed
function getset.isSealed(table)
    local gs = table.__getset
    if not gs then
        return false
    end
    return gs.isSealed
end
]]--



































--[[
function DF_Joystick:Update2(moho)
    local frame = moho.frame
    local skel  = moho:Skeleton()
    local layer = moho.layer
    local meta  = moho.layer:Metadata()
    if (frame == 0) then return end
    if (skel == nil) then return end
    if (layer == nil) then return end
    if (layer:CurrentAction() ~= '') then return end
    --print('update')
    local bonesCount    = moho:CountBones()

--s = "hello world"
--_,_,p1,p2 = string.find(s, "(%a+) (%a+)")
--print(p1, p2)

    Bone    = {}
    setmetatable(Bone, {
        __index = function(t, k)
            --print('__index',k)
            --get the bones list
            local bones = {}
            for i = 0, bonesCount - 1 do
                local b         = skel:Bone(i)
                local namespace = {}
                local boneName  = b:Name()
                p0, _, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10 = string.match(boneName, '^'..k..'$')
                if(p0 ~= nil) then
                    --print(p1)
                    --table.insert(bones, {
                    --    bone = b,
                    --    namespace = {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10},
                    --    pattern = k
                    --})
                    bones[boneName] = {
                        bone = b,
                        namespace = {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10},
                        pattern = k
                    }
                end
            end
            local t = {}
            setmetatable(t, {
                __index = function(t, k)
                    local result    = {}
                    local value
                    for i,item in pairs(bones) do
                        local bone      = item.bone
                        --if (bones == nil) then return [{x=0, y=0} end
                        if k == 'angle' then
                            value   = item.bone.fAngle
                        elseif k == 'base' then
                            --print('get base')
                            value   = LM.Vector2:new_local()
                            value:Set(0, 0)
                            bone.fMovedMatrix:Transform(value)
                        elseif k == 'tip' then
                            value = LM.Vector2:new_local()
                            value:Set(bone.fLength, 0)
                            bone.fMovedMatrix:Transform(value)
                        elseif k == 'length' then
                            local baseVec = LM.Vector2:new_local()
                            local tipVec = LM.Vector2:new_local()
                            baseVec:Set(0, 0)
                            tipVec:Set(bone.fLength, 0)
                            bone.fMovedMatrix:Transform(baseVec)
                            bone.fMovedMatrix:Transform(tipVec)
                            value = (tipVec - baseVec):Mag()
                        end
                        table.insert(result, {
                            --key         = bone,
                            namespace   = item.namespace,
                            pattern     = item.pattern,
                            --name        = 'base',
                            value       = value
                        })
                    end
                    return result
                end,
                __newindex  = function(t, k, target)--bone lists
                    --print('set base')
                    for _,oItem in pairs(bones) do
                        local oBone         = oItem.bone
                        local oKey          = oItem.key
                        local oNameSpace    = oItem.namespace
                        local oPattern      = oItem.oPattern
                        for _,tItem in pairs(target) do
                            local tNameSpace    = tItem.namespace
                            if  oNameSpace[1] == tNameSpace[1] and
                                oNameSpace[2] == tNameSpace[2] and
                                oNameSpace[3] == tNameSpace[3] and
                                oNameSpace[4] == tNameSpace[4] and
                                oNameSpace[5] == tNameSpace[5] and
                                oNameSpace[6] == tNameSpace[6] and
                                oNameSpace[7] == tNameSpace[7] and
                                oNameSpace[8] == tNameSpace[8] and
                                oNameSpace[9] == tNameSpace[9] and
                                oNameSpace[10] == tNameSpace[10]
                            then
                                --print('match:',oBone:Name(),tBone:Name())
                                local value = tItem.value
                                if k == 'angle' then
                                    oBone.fAngle    = value
                                    oBone.fAnimAngle:SetValue(moho.frame , oBone.fAngle)
                                elseif k == 'base' then
                                    oBone.fPos  = tItem.value
                                    oBone.fAnimPos:SetValue(moho.frame , oBone.fPos)
                                elseif k == 'tip' then
                                    --print("set tip")
                                    --if (currBone == nil) then return end    
                                    local baseVec = LM.Vector2:new_local()
                                    baseVec:Set(0, 0)
                                    oBone.fMovedMatrix:Transform(baseVec)
                                    local vec = alue - baseVec

                                    oBone.fScale = vec:Mag()/oBone.fLength
                                    oBone.fAnimScale:SetValue(moho.frame , oBone.fScale)
                                    oBone.fAngle = math.atan2(vec.y, vec.x)
                                    oBone.fAnimAngle:SetValue(moho.frame , oBone.fAngle)
                                elseif k == 'length' then
                                    oBone.fScale = value/oBone.fLength
                                    oBone.fAnimScale:SetValue(moho.frame , oBone.fScale)
                                end
                            end
                        end
                    end
                    skel:UpdateBoneMatrix()
                end,
                __add = function(op1, op2)
                    for _,oItem in ipairs(op1) do
                        local oNameSpace    = oItem.namespace
                        for _,tItem in ipairs(op2) do
                            local tNameSpace    = tItem.namespace
                            if  oNameSpace[1] == tNameSpace[1] and
                                oNameSpace[2] == tNameSpace[2] and
                                oNameSpace[3] == tNameSpace[3] and
                                oNameSpace[4] == tNameSpace[4] and
                                oNameSpace[5] == tNameSpace[5] and
                                oNameSpace[6] == tNameSpace[6] and
                                oNameSpace[7] == tNameSpace[7] and
                                oNameSpace[8] == tNameSpace[8] and
                                oNameSpace[9] == tNameSpace[9] and
                                oNameSpace[10] == tNameSpace[10]
                            then
                                oItem.value = tItem.value + oItem.value
                            end
                        end
                    end
                    return op1
                end,
                __sub = function(op1, op2)
                    for _,oItem in ipairs(op1) do
                        local oNameSpace    = oItem.namespace
                        for _,tItem in ipairs(op2) do
                            local tNameSpace    = tItem.namespace
                            if  oNameSpace[1] == tNameSpace[1] and
                                oNameSpace[2] == tNameSpace[2] and
                                oNameSpace[3] == tNameSpace[3] and
                                oNameSpace[4] == tNameSpace[4] and
                                oNameSpace[5] == tNameSpace[5] and
                                oNameSpace[6] == tNameSpace[6] and
                                oNameSpace[7] == tNameSpace[7] and
                                oNameSpace[8] == tNameSpace[8] and
                                oNameSpace[9] == tNameSpace[9] and
                                oNameSpace[10] == tNameSpace[10]
                            then
                                oItem.value = tItem.value + oItem.value
                            end
                        end
                    end
                    return op1
                end
            })
            return t
        end
    })

    Action  = {}
    setmetatable(Action, {
        __index = function(t,k)
            local actions = {}
            DF_Joystick:visitLayer(moho, layer, '', function(_layer , pref)
                local actionsCount  = _layer:CountActions()
                for i = 0, actionsCount - 1 do
                    local actionName    = _layer:ActionName(i)
                    local namespace     = {}
                    p0, _, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10 = string.match(actionName, '^'..k..'$')
                    if(p0 ~= nil) then
                        --print(p1)
                        --table.insert(actions, {
                        --    action = actionName,
                        --    namespace = {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10},
                        --    pattern = k
                        --})
                        actions[actionName] = {
                            action = actionName,
                            namespace = {p1, p2, p3, p4, p5, p6, p7, p8, p9, p10},
                            pattern = k
                        }
                    end
                end
            end)
            local t = {}
            setmetatable(t, {
                __index = function(t,k)
                    if k == 'strength' then
                        return actions
                    end
                end,
                __newindex = function(t,k,target)
                    if k == 'strength' then
                        actions[key] = target
                    end
                end
            })
            return t
        end
    })

    --Action['action 1'].strength = (Bone['B1'].tip - Bone['B2'].base):Mag()/Bone['B2'].length
    Action['action 1'].strength = Bone['B1'].length
    --Bone['B1'].base = Bone['B2'].base
    --print(tostringex(Bone['B1'].base))

    ---[[Read Codes
    local codes = meta:GetString('DF_Joystick_codes')
    if(codes ~= nil) then
        local func = loadstring(codes)
        if pcall(func) then
            func()
            --blend actions
            --local names   = {}
            --local values  = {}
            --local str
            --for k,v in pairs(actions) do
            --  --print(k)
            --  --print(v)
            --  str = LM.String:new_local()
            --  str:Set(k)

            --  if(type(v) == "number") then
            --      table.insert( names , str )
            --      table.insert( values , v )
            --  end
            --end
            --layer:BlendActions( frame , true , #names , names , values )
            --DF_Joystick:visitLayer(moho, layer, '', function(childLayer , pref)
            --  childLayer:BlendActions( frame , true , #names , names , values )
            --end)
        end
    end
end
--]]

--[[
function DF_Joystick:a()
    --print("Update")
    --print(os.time())

    --print(moho.layer:CurrentAction())
    --print(moho.layer:DeleteAction('action 1'))

    local frame = moho.frame
    local skel  = moho:Skeleton()
    local layer = moho.layer
    local meta  = moho.layer:Metadata()
    if (frame == 0) then return end
    if (skel == nil) then return end
    if (layer == nil) then return end
    if (layer:CurrentAction() ~= '') then return end
    -- directive 
    -- Bone('name')
    --[
    function update()
        --if true then return end
        DF_Joystick.view:DrawMe()
        DF_Joystick.view:RefreshView()
        DF_Joystick.document:DepthSort()
        moho:UpdateSelectedChannels()
        moho:UpdateBonePointSelection()
        --DF_Joystick.LayerScriptUpdate = false
        skel:UpdateBoneMatrix()
        --DF_Joystick.layer:UpdateCurFrame()
        --DF_Joystick.LayerScriptUpdate = true

    end
    --]

    function Bone(name)
        local bone      = {}
        local currBone  = skel:BoneByName(name)
        --angle
        getset.defineProperty( bone, "angle",{
            get = function()
                --print('get angle')
                if (currBone == nil) then return end    
                --return currBone.fAnimAngle:GetValue(moho.frame)           
                return currBone.fAngle          
            end,
            set = function(angle)
                --print('set angle')
                if (currBone == nil) then return end
                
                currBone.fAngle = angle     
                --currBone.fAnimAngle:SetValue(moho.frame , value)          
                --currBone.fAnimAngle.value = value
                skel:UpdateBoneMatrix()
            end
        })
        --base
        getset.defineProperty( bone, "base",{
            get = function()
                --print('get base')
                if (currBone == nil) then return {x=0, y=0} end 
                local baseVec = LM.Vector2:new_local()
                baseVec:Set(0, 0)
                currBone.fMovedMatrix:Transform(baseVec)
                return baseVec          
            end,
            set = function(value)
                --print('set base')
                if (currBone == nil) then return end    
                
                local tipVec = LM.Vector2:new_local()
                tipVec:Set(currBone.fLength, 0)
                currBone.fRestMatrix:Transform(tipVec)
                --currBone.fMovedMatrix:Transform(tipVec)
                local vec = LM.Vector2:new_local()
                vec:Set(tipVec.x - value.x, tipVec.y - value.y)

                currBone.fAngle = math.atan2(vec.y, vec.x)
                --currBone.fAnimAngle:SetValue(moho.frame , currBone.fAngle)
                currBone.fScale = vec:Mag()/currBone.fLength
                --currBone.fAnimScale:SetValue(moho.frame , currBone.fScale)
                currBone.fPos:Set(value.x, value.y)  
                --currBone.fAnimPos:SetValue(moho.frame , currBone.fPos)
                
                skel:UpdateBoneMatrix()
            end
        })
        --tip
        getset.defineProperty( bone, "tip",{
            get = function()
                --print("get tip")
                if (currBone == nil) then return {x=0, y=0} end 
                local tipVec = LM.Vector2:new_local()
                tipVec:Set(currBone.fLength, 0)
                --currBone.fRestMatrix:Transform(tipVec)
                currBone.fMovedMatrix:Transform(tipVec)
                return tipVec           
            end,
            set = function(value)
                --print("set tip")
                if (currBone == nil) then return end    
                local baseVec = LM.Vector2:new_local()
                baseVec:Set(0, 0)
                currBone.fMovedMatrix:Transform(baseVec)
                
                local vec = LM.Vector2:new_local()
                vec:Set(value.x - baseVec.x, value.y - baseVec.y)

                currBone.fScale = vec:Mag()/currBone.fLength
                --currBone.fAnimScale:SetValue(moho.frame , currBone.fScale)
                currBone.fAngle = math.atan2(vec.y, vec.x)
                --currBone.fAnimAngle:SetValue(moho.frame , currBone.fAngle)
                
                skel:UpdateBoneMatrix()
            end
        })
        --length
        getset.defineProperty( bone, "length",{
            get = function()
                --print("get length")
                if (currBone == nil) then return {x=0, y=0} end 
                local baseVec = LM.Vector2:new_local()
                local tipVec = LM.Vector2:new_local()
                baseVec:Set(0, 0)
                tipVec:Set(currBone.fLength, 0)
                currBone.fMovedMatrix:Transform(baseVec)
                currBone.fMovedMatrix:Transform(tipVec)
                return (tipVec - baseVec):Mag()         
            end,
            set = function(value)
                --print("set length")
                if (currBone == nil) then return end    

                local baseVec = LM.Vector2:new_local()
                baseVec:Set(0, 0)
                currBone.fMovedMatrix:Transform(baseVec)

                local tipVec = LM.Vector2:new_local()
                tipVec:Set(currBone.fLength, 0)
                currBone.fMovedMatrix:Transform(tipVec)

                local vec = tipVec - baseVec
                vec = vec*(value/vec:Mag())

                local pos = currBone.fAnimPos:GetValue(moho.frame)
                vec:Set(value.x - pos.x, value.y - pos.y)

                currBone.fScale = vec:Mag()/currBone.fLength
                --currBone.fAnimScale:SetValue(moho.frame , currBone.fScale)
                
                skel:UpdateBoneMatrix()
            end
        })
        return bone
    end
    --Bone('B1').angle = Bone('B2').angle
    --print(Bone('B1').tip.x..' '..Bone('B1').tip.y)
    --Bone('B1').tip = {x=0,y=1} 
    --Bone('B1').base = {x=1,y=1} 
    local actions = {}
    function Action(name)
        local action = {}
        local currAction = skel:BoneByName(name)    
        --strength
        getset.defineProperty( action, "strength",{
            get = function()
                return (actions[name] or 0)
            end,
            set = function(value)
                --print('set action')
                actions[name] = value   
                return value
            end
        })
        return action
    end

    --Action('a').strength = .5
    --Action('b').strength = .5
    
    ---[Read Codes
    local codes = meta:GetString('DF_Joystick_codes')
    if(codes ~= nil) then 
        local func = loadstring(codes)
        if pcall(func) then
            func()
            
            --blend actions
            local names     = {}
            local values    = {}
            local str
            for k,v in pairs(actions) do
                --print(k)
                --print(v)
                str = LM.String:new_local()
                str:Set(k)

                if(type(v) == "number") then
                    table.insert( names , str )
                    table.insert( values , v )
                end
            end
            --layer:BlendActions( frame , true , #names , names , values )
            DF_Joystick:visitLayer(moho, layer, '', function(childLayer , pref)
                childLayer:BlendActions( frame , true , #names , names , values )
            end)
        else
        end
    end
    --]
end




-- **************************************************
-- Tool options - create and respond to tool's UI
-- **************************************************

DF_Joystick.CODE = MOHO.MSG_BASE
DF_Joystick.APPLY = MOHO.MSG_BASE + 1

function DF_Joystick:DoLayout(moho, layout)
    --print('DoLayout')
    --set auto update
    local script = ''
    if(#moho:UserAppDir() ~= 0) then
        script  = script .. moho:UserAppDir()
    else
        script  = script .. moho:AppDir()
    end

    script  = script .. '\\Extra Files\\DF_Joystick_UpdateWidgets.lua'

    local file=io.open(script)
    if not file then
        local file=io.open(script,"w")
        file:write("function LayerScript(moho) if(DF_Joystick.LayerScriptUpdate) then DF_Joystick:Update(moho) end end")
        io.close(file)
    end

    moho.layer:SetLayerScript(script);
    DF_Joystick:Update(moho)



    --local codes = moho.layer:Metadata():GetString('DF_Joystick_codes')
    --local width = 300
    --if #codes ~= 0 then
    --    width = 0
    --end

    --layout:PushH()
    --    DF_Joystick.code = LM.GUI.TextControl(width, codes, DF_Joystick.CODE, LM.GUI.FIELD_TEXT)
    --    DF_Joystick.code:SetConstantMessages(true)
    --    --layout:AddChild(DF_Joystick.code)
    --    --layout:AddChild(LM.GUI.Button(MOHO.Localize("/Scripts/DF_Joystick/Apply=Apply"), DF_Joystick.APPLY))
    --layout:Pop()
end

function DF_Joystick:HandleMessage(moho, view, msg)
    if ( msg == self.APPLY) then
        --print(msg)
        local meta = moho.layer:Metadata()
        if(meta ~= nil) then
            meta:Set('DF_Joystick_codes', DF_Joystick.code:Value());
            local script = ''
            if(moho:UserAppDir() ~= nil) then
                script  = script .. moho:UserAppDir()
            else
                script  = script .. moho:AppDir()
            end
            script  = script .. '\\Extra Files\\DF_Joystick_UpdateWidgets.lua'

            local file=io.open(script)
            if not file then
                local file=io.open(script,"w")
                file:write("function LayerScript(moho) if(DF_Joystick.LayerScriptUpdate) then DF_Joystick:Update(moho) end end")
                io.close(file)
            end

            moho.layer:SetLayerScript(script);
            DF_Joystick:Update(moho)
        end
    end
end

function DF_Joystick:UpdateWidgets(moho)
    --print('update widgets')
    DF_Joystick:Update(moho)
end
--[[
Bone['bone1'].base = Bone['bone2'].base + Bone['bone1'].tip;
bone Bone
bone['bone1'] bone
--]]

--[[
--only work once when AS startup
table.insert( MOHO.UpdateTable , function(moho,a) 
    print('update')
    --print(type(moho.frame))
    --print(type(moho.layer))
    --print(type(moho.document))
end)
--]]


--]]













--local inspect = require("inspect")
--function pprint(s)
--    print(inspect(s))
--end
--**************************************************
-- Description: script for morph blend with control of bones
-- **************************************************
-- Version: 3.0.5
-- Author: Defims Loong

ScriptName = "DF_Joystick"

-- **************************************************
-- General information about this script
-- **************************************************
DF_Joystick                     = {}
DF_Joystick.Update              = nil
DF_Joystick.LayerAsGroup        = nil
DF_Joystick.LayerScriptUpdate   = true

function DF_Joystick:Name()
    return "Link"
end

function DF_Joystick:Version()
    return "3.0.5"
end

function DF_Joystick:Description()
    return MOHO.Localize("/Scripts/Tool/DFJoystick/Description=Click to attach bone to a new joystick (hold <alt> to select a new bone)")
end

function DF_Joystick:Creator()
    return "Defims Loong"
end

function DF_Joystick:UILabel()
    return(MOHO.Localize("/Scripts/Tool/DFJoystick/DFJoystick=DF Joystick"))
end

-- **************************************************
-- The guts of this script
-- **************************************************

function DF_Joystick:IsEnabled(moho)
    --print('Is Enabled')

    local skel = moho:Skeleton()
    if (skel == nil) then return false end
    if (moho.frame == 0) then return false end
    if (moho.layer:CurrentAction() ~= "") then return false end
    --DF_Joystick.moho = moho
    --print('get links')

    DF_Joystick.links = self:getLinks(moho)
    --for id,link in pairs(links) do
    --    self:blend(moho ,link)
    --end

    --print(moho.layer:Name())
    --if(moho.layer:IsVisible()) then
    --    print("visible")
    --else
    --    print("invisible")
    --end
    return true
end

--table.insert( MOHO.UpdateTable , function()
--    print("update")
--    local moho = DF_Joystick.moho
--    if moho == nil then return end
--    --if(moho:Skeleton() == nil) then return end
--    --if(moho.frame == 0) then return end
--    --if(moho.layer:CurrentAction() ~= "") then return end
--    print("in")
--    local links = DF_Joystick:getLinks(moho)
--    pprint(links)
--    --for id,link in pairs(links) do
--    --    DF_Joystick:blend(moho ,link)
--    --end
--end)


function DF_Joystick:IsRelevant(moho)
    --print('Is Relevant')
    --if(moho.frame == 0) then return false end
    --local skel = moho:Skeleton()
    --if (skel == nil) then return false end
    --local link = self:getLinks(skel)

    --save moho for DF_Joystick:Update use
    --DF_Joystick.moho = moho
    --always fire when action end or movie play
    --table.insert( MOHO.UpdateTable , function() DF_Joystick:Update(moho) end)
    return true
end

function DF_Joystick:OnMouseDown(moho, mouseEvent)
    --print("OnMouseDown")

    moho.document:PrepUndo(moho.layer)
    moho.document:SetDirty()
end

function DF_Joystick:OnMouseMoved(moho, mouseEvent)
    --print("OnMouseMoved")
    --self:reJoystick(moho, mouseEvent)

    local skel = moho:Skeleton()
    if true then
        --return
    end
    if skel == nil then
        return
    end

end

function DF_Joystick:OnMouseUp(moho, mouseEvent)
    --print("OnMouseUp")
    local skel = moho:Skeleton()
    if (skel == nil) then
        return
    end
end

function DF_Joystick:OnKeyDown(moho, keyEvent)
    --print("OnKeyDown")
end

function DF_Joystick:DrawMe(moho, view)
    --print('DrawMe')
    local skel = moho:Skeleton()
    if (skel == nil) then
        return
    end

    local g = view:Graphics()
    local matrix = LM.Matrix:new_local()
    local boneRestVec = LM.Vector2:new_local()
    local boneVec = LM.Vector2:new_local()
    local parentRestVec = LM.Vector2:new_local()
    local parentVec = LM.Vector2:new_local()

    moho.layer:GetFullTransform(moho.frame, matrix, moho.document)
    g:Push()
    g:ApplyMatrix(matrix)

    g:SetSmoothing(true)
    --ScreenToWorld
    --[[for i = 0, skel:CountBones() - 1 do
        local bone      = skel:Bone(i)
        local boneName  = bone:Name()
        print(boneName)
        if string.sub(boneName, 1, 1) == '*' then --match *
            prefix,id = string.match(boneName, "^%*(%S+)%s?(%d*)$")
            if id and id ~= '0' then
                print(type(id),id,#id,id=='0')
                local baseVec   = LM.Vector2:new_local()
                bone.fMovedMatrix:Transform(baseVec)
                local radius    = bone.fLength      
                local tipColor  = LM.rgb_color:new_local()
                tipColor.r, tipColor.g, tipColor.b , tipColor.a = 240, 241, 114, 127

                g:SetColor( tipColor )
                g:FillCircle(baseVec,radius)
            end
        end
    end
    g:Pop()
    --]]
end

function DF_Joystick:visitLayer( moho , layer , pref , func)
    --print("visitLayer")
    func( layer , pref )
    local function listChildLayer ( moho , _layer , pref )
        local layerAsGroup = _layer
        if (_layer.Path == nil) then --group layer
            layerAsGroup = moho:LayerAsGroup( _layer )
        end
        local layerCount = layerAsGroup:CountLayers()
        for i = 0 , layerCount - 1 do
            local childLayer = layerAsGroup:Layer(i)
            if childLayer:IsGroupType() then
                listChildLayer( moho , childLayer , pref..'.' )
            end
            func( childLayer , pref )
        end
    end

    listChildLayer ( moho , layer , pref )
end

--find link from links if hasnt create it
function DF_Joystick:getLink(links ,prefix)
    --{
    --    prefix = {
    --           actions = {Bone}
    --          ,joystickBone = Bone
    --          ,limbBone = Bone
    --          ,layers = []
    --    }
    --}
    local link = links[prefix]
    if link == nil then
        link = {
             actions = {}
            ,joystickBone = nil
            ,limbBone = nil
            ,layers = {}
        }
        links[prefix] = link
    end
    return link
end

--=find link relationship
function DF_Joystick:getLinks(moho)
    local links = {}
    --{
    --    prefix = {
    --           actions = {Bone}
    --          ,joystickBone = Bone
    --          ,limbBone = Bone
    --          ,layers = []
    --    }
    --}
    local skel = moho:Skeleton()
    local layer = moho.layer
    local parentLayer = layer:Parent() or moho.document
    local bonesCount = skel:CountBones()
    local bone
    local boneName
    local link


    prefix,linkType,id = string.match(moho.layer:Name(), "^(.+)%-(ZL)%-?(%d*)$")
    if (linkType ~= "ZL") then 
        return links
    end

    --search all action bones, joystick bones and limb bone
    for i = 0, bonesCount - 1 do
        bone = skel:Bone(i)
        boneName = bone:Name()

        prefix,linkType,id = string.match(boneName, "^(.+)%-([DYZ][G])%-?(%d*)$")
        --print(boneName, prefix, linkType, id)
        --get an action bone
        if (linkType == "DG") then
            link = self:getLink(links ,prefix)
            link.actions[tonumber(id)]    = {
                name    = prefix.."-KD-"..tonumber(id),
                bone    = bone
            }
            bone.dfLink = link--store link in bone temporarily

        --get a joystick bone
        elseif (linkType == "YG") then
            link = self:getLink(links ,prefix)
            link.joystickBone = bone
            bone.dfLink = link--store link in bone temporarily

        --get a limb bone
        elseif (linkType == "ZG") then
            link = self:getLink(links ,prefix)
            link.limbBone = bone
            bone.dfLink = link--store link in bone temporarily
        end
    end

    --get target bone layers
    self:visitLayer(moho, parentLayer, '', function(layer)
        prefix,linkType,id = string.match(layer:Name(), "^(.+)%-(ZC)%-?(.*)$")
        if (linkType == "ZC") then
            link = self:getLink(links ,prefix)
            table.insert(link.layers ,layer)
            layer.dfLink = link--store link in bone temporarily
        end
    end)

    return links
end

--=generate morph
--@about one layer has one joystick
--@in link
--@out morph
function DF_Joystick:generateMorph(moho ,link)
    --link =
    --{
    --       actionBones = {Bone}
    --      ,joystickBone = Bone
    --      ,limbBone = Bone
    --}
    local joystickBone = link.joystickBone
    --local limbBone = link.limbBone
    local layerName = link.layerName
    local actions = link.actions
    local str = ""
    local value = 0
    local actionBone = nil
    local JBTipVec = LM.Vector2:new_local()
    local ABBaseVec = LM.Vector2:new_local()
    local ABTipVec = LM.Vector2:new_local()
    local morph = { names = {} ,values = {}}

    if(joystickBone == nil) then return morph end

    JBTipVec:Set(joystickBone.fLength, 0)
    joystickBone.fMovedMatrix:Transform(JBTipVec)

    for id,item in pairs(actions) do
        actionBone  = item.bone

        --name
        str = LM.String:new_local()
        str:Set(item.name)
        table.insert(morph.names, str)

        --value
        ABBaseVec:Set(0, 0)
        actionBone.fMovedMatrix:Transform(ABBaseVec)

        ABTipVec:Set(actionBone.fLength, 0)
        actionBone.fMovedMatrix:Transform(ABTipVec)

        value = 1 - (JBTipVec - ABBaseVec):Mag()/(ABTipVec - ABBaseVec):Mag()
        if value < 0 then value = 0 end
        table.insert(morph.values, value)
    end

    --pprint(morph)
    return morph
end

function DF_Joystick:blend(moho ,link)
    local layer = moho.layer
    prefix,linkType,id = string.match(layer:Name(), "^(.+)%-(ZL)%-?(%d*)$")
    if (linkType ~= "ZL") then return end

    local joystickBone = link.joystickBone
    local limbBone = link.limbBone
    local layers = link.layers
    local LBBaseVec0 = LM.Vector2:new_local()
    local LBBaseVecFrame = LM.Vector2:new_local()
    local LBBaseVec = LM.Vector2:new_local()
    local LBTipVec0 = LM.Vector2:new_local()
    local LBTipVecFrame = LM.Vector2:new_local()
    local LBTipVec = LM.Vector2:new_local()
    local lVec30 = LM.Vector3:new_local()
    local lVec3Frame = LM.Vector3:new_local()
    local lVec3Tmp = LM.Vector3:new_local()
    local lVec3 = LM.Vector3:new_local()
    local LBVec = nil
    local skel = moho:Skeleton()
    local morph = self:generateMorph(moho ,link)
    local targetLayerMatrix = LM.Matrix:new_local()
    local targetLayerMatrix0 = LM.Matrix:new_local()
    local controlLayerMatrix = LM.Matrix:new_local()

    moho.layer:GetFullTransform(moho.frame, controlLayerMatrix, moho.document)
    --controlLayerMatrix:Invert()
    --pprint(morph)
    if (limbBone ~= nil ) then
        LBBaseVec0:Set(0, 0)
        limbBone.fRestMatrix:Transform(LBBaseVec0)

        LBBaseVecFrame:Set(0, 0)
        limbBone.fMovedMatrix:Transform(LBBaseVecFrame)

        LBTipVec0:Set(limbBone.fLength, 0)
        limbBone.fRestMatrix:Transform(LBTipVec0)

        LBTipVecFrame:Set(limbBone.fLength, 0)
        limbBone.fMovedMatrix:Transform(LBTipVecFrame)

        --sync joystick bone and limb bone
        LBVec = LBTipVecFrame - LBBaseVecFrame
        LBBaseVec = LBBaseVecFrame - LBBaseVec0

        if joystickBone ~= nil  then
            joystickBone.fAngle = math.atan2(LBVec.y, LBVec.x)
            joystickBone.fAnimAngle:SetValue(moho.frame , joystickBone.fAngle)
            joystickBone.fScale = LBVec:Mag()/limbBone.fLength
            joystickBone.fAnimScale:SetValue(moho.frame , joystickBone.fScale)
            skel:UpdateBoneMatrix()--just rotate bone without generate frame
        end
    end

    lVec3Tmp.x = LBBaseVec.x
    lVec3Tmp.y = LBBaseVec.y
    controlLayerMatrix:Transform(lVec3Tmp)--get global limb bone base coordinate

    for _ ,layer in pairs(layers) do
        local parent = layer
        local visible = true
        while parent ~= nil do--ÅÐ¶ÏÊÇ·ñ¸¸²ãÒþ²ØÁË
            if(not parent:IsVisible()) then
                visible = false
                break
            end
            parent = parent:Parent()
        end
        if (visible) then
            --print(layer:Name())
            --layer:DeleteKeysAtFrame(true, moho.frame)
            layer:BlendActions( moho.frame , false , #morph.values, morph.names , morph.values)
            --if true then return end
            moho.document:DepthSort()
            layer:UpdateCurFrame()
            --moho:UpdateSelectedChannels()
            --moho:UpdateBonePointSelection()
            --DF_Joystick.LayerScriptUpdate = false
            --skel:UpdateBoneMatrix()
            --DF_Joystick.LayerScriptUpdate = true


            --layer:BlendActions( moho.frame , false, 1 , morph.names, {1})

            --layer:BlendActions( moho.frame , false, 1 , morph.names , {.3})
            --local str = LM.String:new_local()
            --str:Set(MOHO.Localize("/Scripts/Tool/DFJoystick/DFJoystick=DF Joystick"))
            --str:Set(MOHO.Localize("/Scripts/Tool/DFJoystick/DFJoystick=DF Joystick"))
            --layer:BlendActions( moho.frame , false, 1 , {str}, {1})
            --layer:BlendActions( moho.frame , false, 1 , morph.names, {1})

            --lVec3.x = LBBaseVec.x - layer.fTranslation:GetValue(0).x
            --lVec3.y = LBBaseVec.y - layer.fTranslation:GetValue(0).y


            move = string.match(layer:Name(), "^.+%-ZC%-(M)$")
            if(limbBone ~= nil and move == "M") then    --ÅÐ¶ÏÊÇ·ñ°ó¶¨²ãÒÆ¶¯
                lVec3 = lVec3 + lVec3Tmp --copy vec3

                layer:GetParentTransform(moho.frame, targetLayerMatrix, moho.document)
                targetLayerMatrix:Invert()
                targetLayerMatrix:Transform(lVec3)--get local target layer coordinate
                --layer:GetFullTransform(0 , targetLayerMatrix0, moho.document)
                --targetLayerMatrix0:Invert()
                --targetLayerMatrix0:Transform(lVec30)--get local target layer coordinate

                --lVec3 = lVec3 + lVec30
                lVec3 = lVec3 + layer.fTranslation:GetValue(0)
                lVec3.z = layer.fTranslation:GetValue(moho.frame).z

                layer.fTranslation:SetValue(moho.frame ,lVec3)
                layer:UpdateCurFrame()
            end
        end
    end
end

--[[
function DF_Joystick:Update(moho)

    print('update')

    if moho == nil then return end
    local doc = moho.document
    local frame = moho.frame
    if true then return end
    local skel = moho:Skeleton()
    local layer = moho.layer
    local bonesCount = moho:CountBones()
    print(bonesCount)
    if true then return end
    local links = {}
    --{
    --  {
    --      actionBones     = {Bone},
    --      joystickBone    = Bone,
    --      limbBone        = Bone
    --  },
    --}
    --
    --

    --local meta  = moho.layer:Metadata()
    --local SelectedLayersCount   = doc:CountSelectedLayers()
    if (
           frame == 0
        or skel == nil
        or layer == nil
        or layer:CurrentAction() ~= ''
        --or SelectedLayersCount == 0
        --or (
        --        SelectedLayersCount ~= 0
        --    and doc:GetSelectedLayer(0):CurrentAction() ~= ''
        --)
    ) then return end
    if true then return end


    --search all action bones, joystick bones and limb bone
    for i = 0, bonesCount -1 do
        local bone      = skel:Bone(i)
        local boneName  = bone:Name()

        prefix,linkType,id = string.match(boneName, "^(.+)%-([DYZ][G])%-?(%d*)$")
        --print(boneName, prefix, linkType, id)
        if (linkType == "DG" or linkType == "YG" or linkType =="ZG") then
            local link = links[prefix]
            if link == nil then
                link = {
                    actionBones     = {},
                    joystickBone    = '',
                    limbBone        = '',
                    layerName       = ''
                }
                links[prefix] = link
            end
            if (linkType == "DG") then--get action bone
                link.actionBones[tonumber(id)]    = {
                    name    = prefix.."-KD-"..tonumber(id),
                    bone    = bone
                }
            elseif (linkType == "YG") then--get joystick bone
                link.joystickBone = bone
            elseif (linkType == "ZG") then--get limb bone
                link.limbBone = bone
                link.layerName = prefix.."ZC"
            end
        end
    end

    local names   = {}
    local values  = {}
    local str

    --walk links
    for prefix,link in pairs(links) do
        local joystickBone  = link.joystickBone
        local limbBone      = link.limbBone
        local layerName     = link.layerName
        local actionBones   = link.actionBones
        local LBBaseVec     = LM.Vector2:new_local()
        local LBTipVec      = LM.Vector2:new_local()

        LBBaseVec:Set(0, 0)
        LBTipVec:Set(limbBone.fLength, 0)
        limbBone.fMovedMatrix:Transform(LBBaseVec)
        limbBone.fMovedMatrix:Transform(LBTipVec)

        --layer
        local layer         = moho:LayerAsGroup(layer):LayerByName(layerName)
        if layer ~= nil then
            local vec3      = LM.Vector3:new_local()
            vec3:Set(LBBaseVec.x, LBBaseVec.y, layer.fTranslation:GetValue(moho.frame).z)
            layer.fTranslation:SetValue(moho.frame, vec3)
        end

        --joystickBone
        local vec = LBTipVec - LBBaseVec
        --sync joystickBone and limbBone
        joystickBone.fAngle = math.atan2(vec.y, vec.x)
        --joystickBone.fAnimAngle:SetValue(moho.frame , joystickBone.fAngle)
        joystickBone.fScale = vec:Mag()/limbBone.fLength
        --joystickBone.fAnimScale:SetValue(moho.frame , joystickBone.fScale)

        skel:UpdateBoneMatrix()

        --set blend morph
        local value         = 0
        local actionBone    = nil
        local JBTipVec       = LM.Vector2:new_local()
        local ABBaseVec      = LM.Vector2:new_local()
        local ABTipVec       = LM.Vector2:new_local()
        local ABLengh
        JBTipVec:Set(joystickBone.fLength, 0)
        joystickBone.fMovedMatrix:Transform(JBTipVec)

        for id,item in pairs(actionBones) do
            actionBone  = item.bone

            --name
            str = LM.String:new_local()
            str:Set(item.name)
            table.insert( names, str)

            --value
            ABBaseVec:Set(0, 0)
            ABTipVec:Set(actionBone.fLength, 0)
            actionBone.fMovedMatrix:Transform(ABBaseVec)
            actionBone.fMovedMatrix:Transform(ABTipVec)
            value       = 1 - (JBTipVec - ABBaseVec):Mag()/(ABTipVec - ABBaseVec):Mag()
            if value <0 then value = 0 end
            table.insert( values, value )

        end
    end

    --blend actions
    --local names   = {}
    --local values  = {}
    --local str
    --for k,v in pairs(actions) do
    --  --print(k)
    --  --print(v)
    --  str = LM.String:new_local()
    --  str:Set(k)

    --  if(type(v) == "number") then
    --      table.insert( names , str )
    --      table.insert( values , v )
    --  end
    --end
    --print(names[1]:Buffer())
    --print(values[1])
    DF_Joystick:visitLayer(moho, layer, '', function(_layer , pref)
        _layer:BlendActions( frame , false , #names , names , values)
        --_layer:BlendActions( frame , true , 1 , names , {1})
    end)
end
--]]

