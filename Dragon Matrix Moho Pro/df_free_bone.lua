--**************************************************
-- Description: script for morph blend with control of bones
-- **************************************************
-- Version: 3.0.6
-- Author: Defims Loong

ScriptName = "DF_freebone"

-- **************************************************
-- General information about this script
-- **************************************************
DF_freebone                     = {}
DF_freebone.selBoneId           = -1
DF_freebone.selBone             = nil
DF_freebone.boneEnd             = ''
DF_freebone.boneChanged         = false

function DF_freebone:Name()
    return "free bone tool"
end

function DF_freebone:Version()
    return "3.0.6"
end

function DF_freebone:Description()
    return MOHO.Localize("/Scripts/Tool/joystickBone/Description=Click to attach bone to a new joystick (hold <alt> to select a new bone)")
end

function DF_freebone:Creator()
    return "Defims Loong"
end

function DF_freebone:UILabel()
    return(MOHO.Localize("/Scripts/Tool/DF_freebone/DF_freebone=DF free bone"))
end

-- **************************************************
-- The guts of this script
-- **************************************************

function DF_freebone:IsEnabled(moho)
    --print('Is Enabled')
    --if(moho.frame == 0) then return false end
    if(moho.layer:CurrentAction() ~= "") then return false end
    return true
end

function DF_freebone:IsRelevant(moho)
    --print('Is Relevant')
    if(moho.frame == 0) then return false end
    --local skel = moho:Skeleton()
    --if (skel == nil) then return false end
    return true
end

function DF_freebone:OnMouseDown(moho, mouseEvent)
    --print("OnMouseDown")
    
    local skel      = moho:Skeleton()
    if skel == nil then return end
    
    moho.document:PrepUndo(moho.layer)
    moho.document:SetDirty()

    self.selBoneId = mouseEvent.view:PickBone(mouseEvent.pt, mouseEvent.vec, moho.layer, false)
    self.selBone    = skel:Bone(self.selBoneId)

    for i = 0, skel:CountBones() - 1 do
        skel:Bone(i).fSelected  = (i == self.selBoneId)
    end

    local selBone   = self.selBone

    local baseVec   = LM.Vector2:new_local()
    baseVec:Set(0,0)
    selBone.fMovedMatrix:Transform(baseVec)

    local tipVec    = LM.Vector2:new_local()
    tipVec:Set(selBone.fLength, 0)
    selBone.fMovedMatrix:Transform(tipVec)

    if (baseVec - mouseEvent.startVec):Mag() > (tipVec - mouseEvent.startVec):Mag() then
        self.boneEnd    = 'tip'
    else
        self.boneEnd    = 'base'
    end
end

function DF_freebone:OnMouseMoved(moho, mouseEvent)
    --print("OnMouseMoved")

    local skel = moho:Skeleton()
    if skel == nil then return end

    local selBone   = self.selBone
    if selBone == nil then return end

    local mouseVec  = mouseEvent.vec

    local parent        = nil
    local parentM       = LM.Matrix:new_local()
    local invParentM    = LM.Matrix:new_local()
    if(selBone.fParent >= 0) then
        parent = skel:Bone(selBone.fParent)
        parentM:Set(parent.fMovedMatrix)
        invParentM:Set(parent.fMovedMatrix)
        invParentM:Invert()
    end

    if self.boneEnd == 'base' then
        local tipVec = LM.Vector2:new_local()
        --tipVec:Set(0, 0)
        tipVec:Set(selBone.fLength, 0)
        selBone.fMovedMatrix:Transform(tipVec)

        local baseVec   = LM.Vector2:new_local()
        baseVec:Set(mouseVec.x, mouseVec.y)


        local vec = tipVec - baseVec
        if(parent)then
            invParentM:Transform(baseVec)
            --because parent transform will never work on selBone's angle,scale
            --so we use the initial vector to calculate the angle and scale,
            --but parent's rotate will affect selBone, so an angle will be minused
            local angleBaseVec   = LM.Vector2:new_local()
            angleBaseVec:Set(0, 0)
            local angleTipVec   = LM.Vector2:new_local()
            angleTipVec:Set(parent.fLength, 0)
            parent.fMovedMatrix:Transform(angleTipVec)
            parent.fMovedMatrix:Transform(angleBaseVec)
            local angleVec  = angleTipVec - angleBaseVec
            selBone.fAngle  = math.atan2(vec.y, vec.x) - math.atan2(angleVec.y, angleVec.x)
        else
            selBone.fAngle  = math.atan2(vec.y, vec.x)
        end
        selBone.fAnimAngle:SetValue(moho.frame , selBone.fAngle)
        --scale
        local len           = vec:Mag()/selBone.fLength
        if len > 1 then len = 1 end
        selBone.fScale      = len
        selBone.fAnimScale:SetValue(moho.frame , selBone.fScale)
        --position
        selBone.fPos:Set(baseVec.x, baseVec.y)
        selBone.fAnimPos:SetValue(moho.frame , selBone.fPos)
        self.boneChanged    =   true

    elseif self.boneEnd == 'tip' then

        local baseVec   = LM.Vector2:new_local()
        baseVec:Set(0, 0)
        selBone.fMovedMatrix:Transform(baseVec)

        local tipVec    = mouseVec

        if(parent)then
            parentM:Scale(1/parent.fScale,1,1)--取消父骨骼的缩放影响
            parentM:Invert()
            --invParentM:Transform(vec)
            parentM:Transform(tipVec)
            parentM:Transform(baseVec)
        end
        local vec   = tipVec - baseVec
        --scale
        local len   = vec:Mag()/selBone.fLength
        if len > 1 then len = 1 end
        selBone.fScale      = len
        --angle
        selBone.fAnimScale:SetValue(moho.frame , selBone.fScale)
        selBone.fAngle      = math.atan2(vec.y, vec.x)
        selBone.fAnimAngle:SetValue(moho.frame , selBone.fAngle)
    end

    moho.document:DepthSort()
    --mouseEvent.view:RefreshView()
    moho:UpdateSelectedChannels()
    moho:UpdateBonePointSelection()
    skel:UpdateBoneMatrix()
    moho.layer:UpdateCurFrame()
    mouseEvent.view:DrawMe()

    --print("blend")
    if(moho.frame ~= 0) then
        local links = DF_Joystick.links
        for id,link in pairs(links) do
            DF_Joystick:blend(moho ,link)
        end
    end

end

function DF_freebone:OnMouseUp(moho, mouseEvent)
    --print("OnMouseUp")
    local skel = moho:Skeleton()
    if (skel == nil) then
        return
    end
    
    moho.layer:UpdateCurFrame()
    if (self.boneChanged) then
        moho:NewKeyframe(CHANNEL_BONE_T)
    end

    self.selBoneId      = -1
    self.selBone        = nil
    self.boneEnd        = ''
    self.boneChanged    = false
end

function DF_freebone:OnKeyDown(moho, keyEvent)
    --print("OnKeyDown")
end

function DF_freebone:DrawMe(moho, view)
    --print('DrawMe')
end





-- **************************************************
-- Tool options - create and respond to tool's UI
-- **************************************************

DF_freebone.CODE = MOHO.MSG_BASE
DF_freebone.APPLY = MOHO.MSG_BASE + 1

function DF_freebone:DoLayout(moho, layout)
    --print('DoLayout')
    --if (DF_Joystick) then
    --    DF_Joystick:DoLayout(moho, layout)
    --end
end

function DF_freebone:HandleMessage(moho, view, msg)
    if ( msg == self.APPLY) then
    end
end

function DF_freebone:UpdateWidgets(moho)
    --print('update widgets')
end
