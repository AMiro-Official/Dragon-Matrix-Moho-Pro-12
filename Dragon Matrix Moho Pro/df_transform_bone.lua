-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "DF_TransformBone"

-- **************************************************
-- General information about this script
-- **************************************************

DF_TransformBone = {}

DF_TransformBone.BASE_STR = 2365

function DF_TransformBone:Name()
	return "Transform Bone"
end

function DF_TransformBone:Version()
	return "6.0"
end

function DF_TransformBone:Description()
	return MOHO.Localize("/Scripts/Tool/TransformBone/Description=Move bone (hold <shift> to constrain, <alt> to force translation, <ctrl/cmd> to force scale)")
end

function DF_TransformBone:Creator()
	return "Smith Micro Software, Inc."
end

function DF_TransformBone:UILabel()
	return(MOHO.Localize("/Scripts/Tool/TransformBone/TransformBone=Transform Bone"))
end

function DF_TransformBone:LoadPrefs(prefs)
	self.showPath = prefs:GetBool("DF_TransformBone.showPath", true)
end

function DF_TransformBone:SavePrefs(prefs)
	prefs:SetBool("DF_TransformBone.showPath", self.showPath)
end

function DF_TransformBone:ResetPrefs()
	self.showPath = true
end

function DF_TransformBone:NonDragMouseMove()
	return true -- Call MouseMoved() even if the mouse button is not down
end

-- **************************************************
-- Recurring values
-- **************************************************

DF_TransformBone.dragging = false
DF_TransformBone.keyMovement = false
DF_TransformBone.mode = 0 -- 0:translate, 1:rotate, 2:scale, 3:manipulate bones
DF_TransformBone.numSel = 0
DF_TransformBone.selID = -1
DF_TransformBone.mousePickedID = -1
DF_TransformBone.boneEnd = -1
DF_TransformBone.lastVec = LM.Vector2:new_local()
DF_TransformBone.boneChanged = false
DF_TransformBone.showPath = true
DF_TransformBone.translationFrame = 0
DF_TransformBone.trPathBone = nil
DF_TransformBone.TOLERANCE = 10

-- **************************************************
-- The guts of this script
-- **************************************************

function DF_TransformBone:IsEnabled(moho)
	if (moho:CountBones() < 1) then
		return false
	end
	return true
end

function DF_TransformBone:IsRelevant(moho)
	local skel = moho:Skeleton()
	if (skel == nil) then
		return false
	end
	return true
end

function DF_TransformBone:TestMousePoint(moho, mouseEvent)
	self.trPathBone = nil

	if (self.keyMovement) then
		return 0
	end

	local skel = moho:Skeleton()
	if (skel == nil) then
		return 1
	end

	if (mouseEvent.altKey) then
		return 0
	elseif (mouseEvent.ctrlKey) then
		return 2
	end

	local markerR = 6
	local v = LM.Vector2:new_local()
	local pt = LM.Point:new_local()
	local m = LM.Matrix:new_local()

	moho.layer:GetFullTransform(moho.frame, m, moho.document)

	-- first test for translation, as it's more common than scaling
	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)
		if ((bone.fSelected or i == self.mousePickedID) and not bone.fHidden) then
			v:Set(bone.fLength * 0.075, 0)
			if (moho.frame == 0) then
				bone.fRestMatrix:Transform(v)
			else
				bone.fMovedMatrix:Transform(v)
			end
			m:Transform(v)
			mouseEvent.view:Graphics():WorldToScreen(v, pt)
			if (math.abs(pt.x - mouseEvent.pt.x) < markerR and math.abs(pt.y - mouseEvent.pt.y) < markerR) then
				return 0
			end
		end
	end

	-- next test for scaling
	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)
		if ((bone.fSelected or i == self.mousePickedID) and not bone.fHidden) then
			v:Set(bone.fLength - bone.fLength * 0.075, 0)
			if (moho.frame == 0) then
				bone.fRestMatrix:Transform(v)
			else
				bone.fMovedMatrix:Transform(v)
			end
			m:Transform(v)
			mouseEvent.view:Graphics():WorldToScreen(v, pt)
			if (math.abs(pt.x - mouseEvent.pt.x) < markerR and math.abs(pt.y - mouseEvent.pt.y) < markerR) then
				return 2
			end
		end
	end

	-- finally, test for translation by dragging a curve
	local selCount = 0
	local selBone = nil
	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)
		if (bone.fSelected) then
			selCount = selCount + 1
			selBone = bone
			if (selCount > 1) then
				break
			end
		end
	end
	if (selCount == 1 and selBone ~= nil and self.showPath) then
		local translationWhen = -20000
		local g = mouseEvent.view:Graphics()
		local m = LM.Matrix:new_local()
		local vec = LM.Vector2:new_local()
		local pt = LM.Point:new_local()
		local totalTimingOffset = moho.layer:TotalTimingOffset()
		moho.layer:GetFullTransform(moho.frame, m, moho.document)
		-- First see if any keyframes were picked
		for i = 0, selBone.fAnimPos:CountKeys() - 1 do
			local frame = selBone.fAnimPos:GetKeyWhen(i)
			vec = selBone.fAnimPos:GetValue(frame)
			m:Transform(vec)
			g:WorldToScreen(vec, pt)
			if (math.abs(pt.x - mouseEvent.pt.x) < self.TOLERANCE and math.abs(pt.y - mouseEvent.pt.y) < self.TOLERANCE) then
				translationWhen = frame
				self.trPathBone = selBone
				break
			end
		end
		-- If no keyframes were picked, try picking a random point along the curve.
		if (translationWhen <= -10000) then
			local startFrame = selBone.fAnimPos:GetKeyWhen(0)
			local endFrame = selBone.fAnimPos:Duration()
			if (endFrame > startFrame) then
				local oldVec = LM.Vector2:new_local()
				g:Clear(0, 0, 0, 0)
				g:SetColor(255, 255, 255)
				g:BeginPicking(mouseEvent.pt, 4)
				for frame = startFrame, endFrame do
					vec = selBone.fAnimPos:GetValue(frame)
					m:Transform(vec)
					if (frame > startFrame) then
						g:DrawLine(oldVec.x, oldVec.y, vec.x, vec.y)
					end
					if (g:Pick()) then
						translationWhen = frame
						self.trPathBone = selBone
						break
					end
					oldVec:Set(vec)
				end
			end
		end
		if (translationWhen > -10000) then
			self.translationFrame = translationWhen
			return 0
		end
	end

	-- if no handle was clicked on, default to rotation
	return 1
end

function DF_TransformBone:OnMouseDown(moho, mouseEvent)
	local skel = moho:Skeleton()
	if (skel == nil) then
		return
	end
	self.dragging = true

	self.translationFrame = moho.layerFrame

	if (self.selID < 0) then
		self.mode = self:TestMousePoint(moho, mouseEvent)
		if (moho.frame == 0 and self.mode == 2) then
			self.mode = 0
		end
	else
		-- If selID already has a value, then this function is being called by DF_AddBone.
		-- In that case, the mode has already been determined.
		self.mode = 0
	end

	if (self.mode == 3) then
		LM_ManipulateBones:OnMouseDown(moho, mouseEvent)
		return
	end

	self.numSel = moho:CountSelectedBones(true)
	self.lastVec:Set(mouseEvent.vec)
	self.boneChanged = false

	if (self.mode == 0) then
		self:OnMouseDown_T(moho, mouseEvent)
	elseif (self.mode == 1) then
		self:OnMouseDown_R(moho, mouseEvent)
	else
		self:OnMouseDown_S(moho, mouseEvent)
	end

	self.numSel = moho:CountSelectedBones(true)

	moho.layer:UpdateCurFrame()
	moho:UpdateBonePointSelection()
	mouseEvent.view:DrawMe()
	moho:UpdateSelectedChannels()
end

function DF_TransformBone:OnMouseMoved(moho, mouseEvent)
	if (self.mode == 3) then
		LM_ManipulateBones:OnMouseMoved(moho, mouseEvent)
		return
	end

	local skel = moho:Skeleton()
	if (skel == nil) then
		return
	end
	if (not self.dragging) then
		if (moho:CountSelectedBones(true) < 2) then
			self.mousePickedID = mouseEvent.view:PickBone(mouseEvent.pt, mouseEvent.vec, moho.layer, false)
		else
			self.mousePickedID = -1
		end
		local mode = self:TestMousePoint(moho, mouseEvent)

		if (mode == 0) then
			mouseEvent.view:SetCursor(MOHO.moveCursor)
			if (self.trPathBone ~= nil) then
				self.mousePickedID = skel:BoneID(self.trPathBone)
			end
		elseif (mode == 2) then
			mouseEvent.view:SetCursor(MOHO.scaleCursor)
			--mouseEvent.view:SetCursor(MOHO.moveCursor)
		else
			mouseEvent.view:SetCursor(MOHO.rotateCursor)
		end
		mouseEvent.view:DrawMe()
		return
	end
	if (self.numSel < 1) then
		return
	end

	if (self.mode == 0) then
		self:OnMouseMoved_T(moho, mouseEvent)
	elseif (self.mode == 1) then
		self:OnMouseMoved_R(moho, mouseEvent)
	else
		--self:OnMouseMoved_TT(moho, mouseEvent)
		self:OnMouseMoved_S(moho, mouseEvent)
	end

	moho.layer:UpdateCurFrame()
	mouseEvent.view:DrawMe()
	if (self.mode ~= 0 or self.boneEnd ~= 1) then
		self.lastVec:Set(mouseEvent.vec)
	end

    --print("blend")
    if(moho.frame ~= 0) then
        local links = DF_Joystick.links
        for id,link in pairs(links) do
            DF_Joystick:blend(moho ,link)
        end
    end
end

function DF_TransformBone:OnMouseUp(moho, mouseEvent)
	if (self.mode == 3) then
		LM_ManipulateBones:OnMouseUp(moho, mouseEvent)
		return
	end

	local skel = moho:Skeleton()
	if (skel == nil) then
		self.dragging = false
		return
	end

	if (self.mode == 0) then
		self:OnMouseUp_T(moho, mouseEvent)
	elseif (self.mode == 1) then
		self:OnMouseUp_R(moho, mouseEvent)
	else
		self:OnMouseUp_S(moho, mouseEvent)
	end

	self.selID = -1
	self.boneEnd = -1
	self.dragging = false
end

function DF_TransformBone:OnMouseDown_T(moho, mouseEvent)
	local skel = moho:Skeleton()

	if (self.selID < 0) then
		-- If selID already has a value, then this function is being called by DF_AddBone.
		-- In that case, PrepUndo has already been called, and the bone has been picked.
		moho.document:PrepUndo(moho.layer)
		moho.document:SetDirty()
		if (self.numSel > 1) then
			self.selID = -2
			self.boneEnd = 0
		elseif (self.trPathBone ~= nil) then
			self.selID = skel:BoneID(self.trPathBone)
		else
			self.selID = mouseEvent.view:PickBone(mouseEvent.pt, mouseEvent.vec, moho.layer, false)
		end
	end

	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)

		if (moho.frame == 0) then
			bone.fTempPos:Set(bone.fAnimPos:GetValue(self.translationFrame))
			bone.fTempLength = bone.fLength
			bone.fTempAngle = bone.fAnimAngle:GetValue(moho.layerFrame)
		else
			--bone.fTempPos:Set(bone.fPos)
			bone.fTempPos:Set(bone.fAnimPos:GetValue(self.translationFrame))
		end

		if (self.numSel < 2) then
			if (i == self.selID) then
				bone.fSelected = true
				if (self.boneEnd < 0) then
					if (moho.frame == 0 and self.trPathBone == nil) then
						local boneVec = LM.Vector2:new_local()
						boneVec:Set(0, 0)
						bone.fRestMatrix:Transform(boneVec)
						boneVec = boneVec - mouseEvent.startVec
						local d = boneVec:Mag()
						self.boneEnd = 0
						boneVec:Set(bone.fLength, 0)
						bone.fRestMatrix:Transform(boneVec)
						boneVec = boneVec - mouseEvent.startVec
						if (boneVec:Mag() < d) then
							self.boneEnd = 1
						end
					else
						self.boneEnd = 0
					end
				end
			else
				bone.fSelected = false
			end
		end
		
		if (self.translationFrame ~= 0 and bone.fSelected) then
			self.boneChanged = true
			bone.fAnimPos:SetValue(self.translationFrame, bone.fTempPos)
		end
	end
end

function DF_TransformBone:OnMouseMoved_T(moho, mouseEvent)
	local skel = moho:Skeleton()

	for boneID = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(boneID)
		if (bone.fSelected and (not skel:IsAncestorSelected(boneID))) then
			if (moho.frame == 0) then
				bone.fAnimPos:SetValue(self.translationFrame, bone.fTempPos)
				bone.fLength = bone.fTempLength
				bone.fAnimAngle:SetValue(moho.layerFrame, bone.fTempAngle)
				self.boneChanged = true
			else
				bone.fPos:Set(bone.fTempPos)
			end
			skel:UpdateBoneMatrix(boneID)
		
			local offset = mouseEvent.vec
			if (self.boneEnd == 0) then
				offset = offset - mouseEvent.startVec
			elseif (self.boneEnd == 1) then
				offset = offset - self.lastVec
			end
		
			local boneVec = LM.Vector2:new_local()
			local inverseM = LM.Matrix:new_local()
		
			if (self.boneEnd == 0) then -- move the base of the bone
				local parent = nil
				boneVec:Set(0, 0)
				if (bone.fParent >= 0) then
					parent = skel:Bone(bone.fParent)
					if (moho.frame == 0) then
						parent.fRestMatrix:Transform(boneVec)
					else
						parent.fMovedMatrix:Transform(boneVec)
					end
				end
				boneVec = boneVec + offset
				if (parent) then
					if (moho.frame == 0) then
						inverseM:Set(parent.fRestMatrix)
					else
						inverseM:Set(parent.fMovedMatrix)
					end
					inverseM:Invert()
					inverseM:Transform(boneVec)
				end
		
				if (mouseEvent.shiftKey) then
					if (math.abs(boneVec.x) > math.abs(boneVec.y)) then
						boneVec.y = 0
					else
						boneVec.x = 0
					end
				end
		
				local v = nil
				if (moho.frame == 0) then
					v = bone.fAnimPos:GetValue(self.translationFrame) + boneVec
				else
					v = bone.fPos + boneVec
				end
				if (moho.gridOn) then
					if (parent) then
						parent.fMovedMatrix:Transform(v)
					end
					moho:SnapToGrid(v)
					if (parent) then
						inverseM:Set(parent.fMovedMatrix)
						inverseM:Invert()
						inverseM:Transform(v)
					end
				end
		
				bone.fAnimPos:SetValue(self.translationFrame, v)
				self.boneChanged = true
			elseif (self.boneEnd == 1) then -- move the tip of the bone
				boneVec:Set(bone.fLength, 0)
				bone.fRestMatrix:Transform(boneVec)
				boneVec = boneVec + offset
				if (moho.gridOn) then
					moho:SnapToGrid(boneVec)
					self.lastVec:Set(boneVec)
				else
					self.lastVec:Set(mouseEvent.vec)
				end
		
				inverseM:Set(bone.fRestMatrix)
				inverseM:Invert()
				inverseM:Transform(boneVec)
				local dL = boneVec:Mag() - bone.fLength
				bone.fLength = bone.fLength + dL
				local angle = bone.fAnimAngle:GetValue(moho.layerFrame)
				angle = angle + math.atan2(boneVec.y, boneVec.x)
				while angle > 2 * math.pi do
					angle = angle - 2 * math.pi
				end
				while angle < 0 do
					angle = angle + 2 * math.pi
				end
				bone.fTempAngle = angle
				bone.fTempLength = bone.fLength
				if (mouseEvent.shiftKey) then
					angle = angle / (math.pi / 4)
					angle = (math.pi / 4) * LM.Round(angle)
				end
				bone.fAnimAngle:SetValue(moho.layerFrame, angle)
				self.boneChanged = true
				for i = 0, skel:CountBones() - 1 do
					bone = skel:Bone(i)
					if (bone.fParent == boneID) then
						boneVec:Set(bone.fTempPos)
						boneVec.x = boneVec.x + dL
						bone.fAnimPos:SetValue(moho.layerFrame, boneVec)
					end
				end
			end
		end -- if bone selected
	end -- for all bones
end

function DF_TransformBone:OnMouseUp_T(moho, mouseEvent)
	local skel = moho:Skeleton()

	if (self.numSel > 0 or self.boneChanged) then
		--for i = 0, skel:CountBones() - 1 do
		--	bone = skel:Bone(i)
		--	if (bone.fSelected and (not skel:IsAncestorSelected(i))) then
		--		bone.fAnimPos:SetValue(moho.layerFrame, bone.fPos)
		--	end
		--end
		moho.layer:UpdateCurFrame()
		if (self.boneChanged) then
			moho:NewKeyframe(CHANNEL_BONE_T)
		end
	end
end

function DF_TransformBone:OnMouseDown_R(moho, mouseEvent)
	local skel = moho:Skeleton()

	moho.document:PrepUndo(moho.layer)
	moho.document:SetDirty()
	if (moho:CountSelectedBones(true) < 2) then
		for i = 0, skel:CountBones() - 1 do
			skel:Bone(i).fSelected = false
		end
		local id = mouseEvent.view:PickBone(mouseEvent.pt, mouseEvent.vec, moho.layer, false)
		skel:Bone(id).fSelected = true
	end

	local selCount = 0
	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)

		if (bone.fSelected) then
			self.selID = i
			selCount = selCount + 1
			if (moho.frame == 0) then
				bone.fTempPos:Set(bone.fAnimPos:GetValue(moho.layerFrame))
				bone.fTempLength = bone.fLength
				bone.fTempAngle = bone.fAnimAngle:GetValue(moho.layerFrame)
			else
				self.boneChanged = true
				bone.fTempAngle = bone.fAnimAngle:GetValue(moho.layerFrame)--bone.fAngle
				bone.fAnimAngle:SetValue(moho.layerFrame, bone.fTempAngle)
			end
		end
	end

	if (selCount > 1) then
		self.selID = -1
	end
end

function DF_TransformBone:OnMouseMoved_R(moho, mouseEvent)
	local riggingFrame = 0
	local skel = moho:Skeleton()

	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)
		if (bone.fSelected) then
			if (moho.frame == 0) then
				bone.fAnimPos:SetValue(moho.layerFrame, bone.fTempPos)
				bone.fLength = bone.fTempLength
				bone.fAnimAngle:SetValue(moho.layerFrame, bone.fTempAngle)
				self.boneChanged = true
			else
				bone.fAngle = bone.fTempAngle
			end
		end
	end
	skel:UpdateBoneMatrix()

	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)
		if (bone.fSelected) then
			local origin = LM.Vector2:new_local()
			if (moho:CountSelectedBones(true) < 2) then
				origin:Set(0, 0)
				if (moho.frame == 0) then
					bone.fRestMatrix:Transform(origin)
				else
					bone.fMovedMatrix:Transform(origin)
				end
			else
				origin = moho.layer:Origin()
			end
			local v1 = self.lastVec - origin
			local v2 = mouseEvent.vec - origin
			v2:Rotate(-math.atan2(v1.y, v1.x))
			if (moho.frame == 0) then
				local angle = bone.fAnimAngle:GetValue(moho.layerFrame) + math.atan2(v2.y, v2.x)
				bone.fAnimAngle:SetValue(moho.layerFrame, angle)
				self.boneChanged = true
			else
				bone.fAngle = bone.fAngle + math.atan2(v2.y, v2.x)
			end

			if (moho.frame == 0) then
				local angle = bone.fAnimAngle:GetValue(moho.layerFrame)
				while angle > 2 * math.pi do
					angle = angle - 2 * math.pi
				end
				while angle < 0 do
					angle = angle + 2 * math.pi
				end
				bone.fTempAngle = angle
				if (mouseEvent.shiftKey) then
					angle = angle / (math.pi / 4)
					angle = (math.pi / 4) * LM.Round(angle)
				end
				bone.fAnimAngle:SetValue(moho.layerFrame, angle)
				self.boneChanged = true
			else
				bone.fTempAngle = bone.fAngle
				if (mouseEvent.shiftKey) then
					bone.fAngle = bone.fAngle / (math.pi / 4)
					bone.fAngle = (math.pi / 4) * LM.Round(bone.fAngle)
				end
				bone.fAnimAngle:SetValue(moho.layerFrame, bone.fAngle)
				self.boneChanged = true
				if (bone.fConstraints and (not bone.fFixedAngle)) then
					local min = bone.fAnimAngle:GetValue(riggingFrame)
					local max = min + bone.fMaxConstraint
					min = min + bone.fMinConstraint
					bone.fAngle = LM.Clamp(bone.fAngle, min, max)
					bone.fAnimAngle:SetValue(moho.layerFrame, bone.fAngle)
				end
				moho.layer:UpdateCurFrame()
			end

			bone.fAngle = bone.fAnimAngle.value
			if (moho.frame ~= 0 and (not bone.fFixedAngle)) then
				if (bone.fConstraints) then
					local min = bone.fAnimAngle:GetValue(riggingFrame)
					local max = min + bone.fMaxConstraint
					min = min + bone.fMinConstraint
					bone.fAngle = LM.Clamp(bone.fAngle, min, max)
				end
			end
		end
	end
end

function DF_TransformBone:OnMouseUp_R(moho, mouseEvent)
	local skel = moho:Skeleton()

	--if ((moho.frame > 0) and (moho:CountSelectedBones(true) > 0)) then
	if (moho:CountSelectedBones(true) > 0) then
		--for i = 0, skel:CountBones() - 1 do
		--	local bone = skel:Bone(i)
		--	if (bone.fSelected) then
		--		bone.fAnimAngle:SetValue(moho.layerFrame, bone.fAngle)
		--	end
		--end
		moho.layer:UpdateCurFrame()
		if (self.boneChanged) then
			moho:NewKeyframe(CHANNEL_BONE)
		end
	end
end

function DF_TransformBone:OnMouseDown_S(moho, mouseEvent)
	local skel = moho:Skeleton()

	moho.document:PrepUndo(moho.layer)
	moho.document:SetDirty()
	if (moho:CountSelectedBones(true) < 2) then
		for i = 0, skel:CountBones() - 1 do
			skel:Bone(i).fSelected = false
		end
		local id = mouseEvent.view:PickBone(mouseEvent.pt, mouseEvent.vec, moho.layer, false)
		skel:Bone(id).fSelected = true
	end

	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)

		if (bone.fSelected) then
			if (moho.frame == 0) then
				bone.fTempScale = bone.fAnimScale:GetValue(moho.layerFrame)
			else
				self.boneChanged = true
				bone.fTempScale = bone.fAnimScale:GetValue(moho.layerFrame)--bone.fScale
				bone.fAnimScale:SetValue(moho.layerFrame, bone.fTempScale)
			end
		end
	end
end

function DF_TransformBone:OnMouseMoved_S(moho, mouseEvent)
	local skel = moho:Skeleton()

	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)
		if (bone.fSelected) then
			local scaleFactor = (mouseEvent.pt.x - mouseEvent.startPt.x) / 100
			if (scaleFactor < 0) then
				scaleFactor = 1 / (-scaleFactor + 1)
			else
				scaleFactor = scaleFactor + 1
			end
			bone.fScale = bone.fTempScale * scaleFactor

			bone.fAnimScale:SetValue(moho.layerFrame, bone.fScale)
			self.boneChanged = true
		end
	end
end

function DF_TransformBone:OnMouseUp_S(moho, mouseEvent)
	local skel = moho:Skeleton()

	if ((moho.frame > 0) and (moho:CountSelectedBones(true) > 0)) then
		--for i = 0, skel:CountBones() - 1 do
		--	local bone = skel:Bone(i)
		--	if (bone.fSelected) then
		--		bone.fAnimScale:SetValue(moho.layerFrame, bone.fScale)
		--	end
		--end
		moho.layer:UpdateCurFrame()
		if (self.boneChanged) then
			moho:NewKeyframe(CHANNEL_BONE_S)
		end
	end
end

function DF_TransformBone:OnKeyDown(moho, keyEvent)
	local skel = moho:Skeleton()
	if (skel == nil) then
		return
	end

	LM_SelectBone:OnKeyDown(moho, keyEvent)
	if (keyEvent.ctrlKey) then
		local inc = 1
		if (keyEvent.shiftKey) then
			inc = 10
		end

		local m = LM.Matrix:new_local()
		moho.layer:GetFullTransform(moho.frame, m, moho.document)

		local fakeME = {}
		fakeME.view = keyEvent.view
		fakeME.pt = LM.Point:new_local()
		fakeME.pt:Set(keyEvent.view:Graphics():Width() / 2, keyEvent.view:Graphics():Height() / 2)
		fakeME.startPt = LM.Point:new_local()
		fakeME.startPt:Set(fakeME.pt)
		fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
		fakeME.startVec = keyEvent.view:Point2Vec(fakeME.pt, m)
		fakeME.shiftKey = false
		fakeME.ctrlKey = false
		fakeME.altKey = keyEvent.altKey
		fakeME.penPressure = 0

		self.keyMovement = true

		if (keyEvent.keyCode == LM.GUI.KEY_UP) then
			self.selID = self:SelIDForNudge(moho, skel)
			self:OnMouseDown(moho, fakeME)
			self.boneEnd = 0
			fakeME.pt.y = fakeME.pt.y - inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		elseif (keyEvent.keyCode == LM.GUI.KEY_DOWN) then
			self.selID = self:SelIDForNudge(moho, skel)
			self:OnMouseDown(moho, fakeME)
			self.boneEnd = 0
			fakeME.pt.y = fakeME.pt.y + inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		elseif (keyEvent.keyCode == LM.GUI.KEY_LEFT) then
			self.selID = self:SelIDForNudge(moho, skel)
			self:OnMouseDown(moho, fakeME)
			self.boneEnd = 0
			fakeME.pt.x = fakeME.pt.x - inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		elseif (keyEvent.keyCode == LM.GUI.KEY_RIGHT) then
			self.selID = self:SelIDForNudge(moho, skel)
			self:OnMouseDown(moho, fakeME)
			self.boneEnd = 0
			fakeME.pt.x = fakeME.pt.x + inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		end

		self.keyMovement = false
	end
end

function DF_TransformBone:DrawMe(moho, view)
	if ((self.dragging or moho:IsPlaying()) and not self.showPath) then
		return
	end
	local skel = moho:Skeleton()
	if (skel == nil) then
		return
	end

	local markerR = 6
	local v = LM.Vector2:new_local()
	local g = view:Graphics()
	local layerMatrix = LM.Matrix:new_local()
	local vc1 = LM.ColorVector:new_local()
	local vc2 = LM.ColorVector:new_local()

	vc1:Set(MOHO.MohoGlobals.SelCol)
	vc2:Set(MOHO.MohoGlobals.BackCol)
	--vc1 = (vc1 * 3 + vc2 * 4) / 7
	vc1 = (vc1 + vc2) / 2
	local fillCol = vc1:AsColorStruct()

	moho.layer:GetFullTransform(moho.frame, layerMatrix, moho.document)
	g:Push()
	g:ApplyMatrix(layerMatrix)
	g:SetSmoothing(true)
	g:SetBezierTolerance(2)

	for i = 0, skel:CountBones() - 1 do
		local bone = skel:Bone(i)

		if (bone.fSelected and self.showPath and bone.fParent < 0) then
			-- draw path
			local startFrame = bone.fAnimPos:GetKeyWhen(0)
			local endFrame = bone.fAnimPos:Duration()

			if (endFrame > startFrame) then
				local vec = LM.Vector2:new_local()
				local oldVec = LM.Vector2:new_local()
				local totalTimingOffset = moho.layer:TotalTimingOffset()

				g:SetColor(102, 152, 203)
				for frame = startFrame, endFrame do
					vec = bone.fAnimPos:GetValue(frame)
					if (frame > startFrame) then
						g:DrawLine(oldVec.x, oldVec.y, vec.x, vec.y)
					end
					if (bone.fAnimPos:HasKey(frame)) then
						g:DrawFatMarker(vec.x, vec.y, 3)
					end
					oldVec:Set(vec)
				end
			end
		end

		if (((bone.fSelected and self.mousePickedID == -1) or i == self.mousePickedID) and not bone.fHidden) then
			-- draw handles
			if (not (self.dragging or moho:IsPlaying())) then
				v:Set(bone.fLength - bone.fLength * 0.075, 0)
				if (moho.frame == 0) then
					bone.fRestMatrix:Transform(v)
				else
					bone.fMovedMatrix:Transform(v)
				end
				g:SetColor(fillCol)
				g:FillCirclePixelRadius(v, markerR)
				g:SetColor(MOHO.MohoGlobals.SelCol)
				g:FrameCirclePixelRadius(v, markerR)

				v:Set(bone.fLength * 0.075, 0)
				if (moho.frame == 0) then
					bone.fRestMatrix:Transform(v)
				else
					bone.fMovedMatrix:Transform(v)
				end
				g:SetColor(fillCol)
				g:FillCirclePixelRadius(v, markerR)
				g:SetColor(MOHO.MohoGlobals.SelCol)
				g:FrameCirclePixelRadius(v, markerR)
			end
		end
	end
	
	g:Pop()
end

function DF_TransformBone:SelIDForNudge(moho, skel)
	for i = 0, skel:CountBones() - 1 do
		if (skel:Bone(i).fSelected) then
			return i
		end
	end
	return -1
end

-- **************************************************
-- Tool options - create and respond to tool's UI
-- **************************************************

DF_TransformBone.CHANGE_T_X = MOHO.MSG_BASE
DF_TransformBone.CHANGE_T_Y = MOHO.MSG_BASE + 1
DF_TransformBone.RESET_T = MOHO.MSG_BASE + 2
DF_TransformBone.CHANGE_L = MOHO.MSG_BASE + 3
DF_TransformBone.CHANGE_S = MOHO.MSG_BASE + 4
DF_TransformBone.RESET_S = MOHO.MSG_BASE + 5
DF_TransformBone.CHANGE_R = MOHO.MSG_BASE + 6
DF_TransformBone.RESET_R = MOHO.MSG_BASE + 7
DF_TransformBone.SHOW_PATHS = MOHO.MSG_BASE + 8
DF_TransformBone.DUMMY = MOHO.MSG_BASE + 9
DF_TransformBone.SELECTITEM = MOHO.MSG_BASE + 10

function DF_TransformBone:DoLayout(moho, layout)
	self.menu = LM.GUI.Menu(MOHO.Localize("/Scripts/Tool/TransformBone/SelectBone=Select Bone"))

	self.popup = LM.GUI.PopupMenu(128, false)
	self.popup:SetMenu(self.menu)
	layout:AddChild(self.popup)

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/TransformBone/Position=Position")))

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/TransformBone/X=X:")))
	self.textX = LM.GUI.TextControl(0, "00.0000", self.CHANGE_T_X, LM.GUI.FIELD_FLOAT)
	self.textX:SetWheelInc(0.1)
	layout:AddChild(self.textX)

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/TransformBone/Y=Y:")))
	self.textY = LM.GUI.TextControl(0, "00.0000", self.CHANGE_T_Y, LM.GUI.FIELD_FLOAT)
	self.textY:SetWheelInc(0.1)
	layout:AddChild(self.textY)

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/TransformBone/Length=Length:")))
	self.textL = LM.GUI.TextControl(0, "00.0000", self.CHANGE_L, LM.GUI.FIELD_FLOAT)
	self.textL:SetWheelInc(0.1)
	layout:AddChild(self.textL)

	self.resetT = LM.GUI.Button(MOHO.Localize("/Scripts/Tool/TransformBone/Reset=Reset"), self.RESET_T)
	layout:AddChild(self.resetT)

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/TransformBone/Scale=Scale:")))
	self.scale = LM.GUI.TextControl(0, "00.0000", self.CHANGE_S, LM.GUI.FIELD_FLOAT)
	self.scale:SetWheelInc(0.1)
	layout:AddChild(self.scale)

	self.resetS = LM.GUI.Button(MOHO.Localize("/Scripts/Tool/TransformBone/Reset=Reset"), self.RESET_S)
	layout:AddChild(self.resetS)

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/TransformBone/Angle=Angle:")))
	self.angle = LM.GUI.TextControl(0, "000.0000", self.CHANGE_R, LM.GUI.FIELD_FLOAT)
	self.angle:SetWheelInc(5)
	layout:AddChild(self.angle)

	self.resetR = LM.GUI.Button(MOHO.Localize("/Scripts/Tool/TransformBone/Reset=Reset"), self.RESET_R)
	layout:AddChild(self.resetR)

	self.pathCheck = LM.GUI.CheckBox(MOHO.Localize("/Scripts/Tool/TransformBone/ShowPath=Show path"), self.SHOW_PATHS)
	layout:AddChild(self.pathCheck)
end

function DF_TransformBone:UpdateWidgets(moho)
	local skel = moho:Skeleton()
	if (skel == nil) then
		return
	end

	local selID = skel:SelectedBoneID()

	MOHO.BuildBoneMenu(self.menu, skel, self.SELECTITEM, self.DUMMY)

	if (selID >= 0) then
		local bone = skel:Bone(selID)
		self.textX:SetValue(bone.fPos.x)
		self.textY:SetValue(bone.fPos.y)
		self.textL:SetValue(bone.fLength)
	else
		self.textX:SetValue("")
		self.textY:SetValue("")
		self.textL:SetValue("")
	end

	if (moho:CountSelectedBones(true) > 0) then
		local selCount = 0
		local scale = 0
		for i = 0, skel:CountBones() - 1 do
			local bone = skel:Bone(i)
			if (bone.fSelected) then
				selCount = selCount + 1
				scale = scale + bone.fScale
			end
		end
		self.scale:SetValue(scale / selCount)
	else
		self.scale:SetValue("")
	end

	if (moho:CountSelectedBones(true) > 0) then
		local selCount = 0
		local angle = 0
		for i = 0, skel:CountBones() - 1 do
			local bone = skel:Bone(i)
			if (bone.fSelected) then
				selCount = selCount + 1
				angle = angle + bone.fAngle
			end
		end
		self.angle:SetValue(math.deg(angle) / selCount)
	else
		self.angle:SetValue("")
	end

	if (moho.frame == 0) then
		self.textL:Enable(true)
		self.scale:Enable(false)
		self.resetT:Enable(false)
		self.resetS:Enable(false)
		self.resetR:Enable(false)
	else
		self.textL:Enable(false)
		self.scale:Enable(true)
		self.resetT:Enable(true)
		self.resetS:Enable(true)
		self.resetR:Enable(true)
	end

	self.pathCheck:SetValue(self.showPath)
end

function DF_TransformBone:HandleMessage(moho, view, msg)
	local skel = moho:Skeleton()
	if (skel == nil) then
		return
	end

	if (msg == self.RESET_T) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fAnimPos:SetValue(moho.layerFrame, bone.fAnimPos:GetValue(0))
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE_T)
			self:UpdateWidgets(moho)
		end
	elseif (msg == self.CHANGE_T_X) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fPos.x = self.textX:FloatValue()
					bone.fAnimPos:SetValue(moho.layerFrame, bone.fPos)
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE)
		end
	elseif (msg == self.CHANGE_T_Y) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fPos.y = self.textY:FloatValue()
					bone.fAnimPos:SetValue(moho.layerFrame, bone.fPos)
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE)
		end
	elseif (msg == self.CHANGE_L) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fLength = self.textL:FloatValue()
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE)
		end
	elseif (msg == self.RESET_S) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fAnimScale:SetValue(moho.layerFrame, bone.fAnimScale:GetValue(0))
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE_S)
			self:UpdateWidgets(moho)
		end
	elseif (msg == self.CHANGE_S) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fScale = self.scale:FloatValue()
					bone.fAnimScale:SetValue(moho.layerFrame, bone.fScale)
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE_S)
		end
	elseif (msg == self.RESET_R) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fAnimAngle:SetValue(moho.layerFrame, bone.fAnimAngle:GetValue(0))
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE)
			self:UpdateWidgets(moho)
		end
	elseif (msg == self.CHANGE_R) then
		if (moho:CountSelectedBones(true) > 0) then
			moho.document:PrepUndo(moho.layer)
			moho.document:SetDirty()
			for i = 0, skel:CountBones() - 1 do
				local bone = skel:Bone(i)
				if (bone.fSelected) then
					bone.fAngle = math.rad(self.angle:FloatValue())
					bone.fAnimAngle:SetValue(moho.layerFrame, bone.fAngle)
				end
			end
			moho.layer:UpdateCurFrame()
			moho:NewKeyframe(CHANNEL_BONE)
		end
	elseif (msg == self.SHOW_PATHS) then
		self.showPath = self.pathCheck:Value()
		moho:UpdateUI()
	elseif (msg >= self.SELECTITEM) then
		for i = 0, skel:CountBones() - 1 do
			skel:Bone(i).fSelected = (i == msg - self.SELECTITEM)
		end
		moho:UpdateUI()
	end
end
