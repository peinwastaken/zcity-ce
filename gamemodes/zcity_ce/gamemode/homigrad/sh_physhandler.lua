local function SetAbsVelocity(pEntity, vAbsVelocity)
	if (pEntity:GetInternalVariable("m_vecAbsVelocity") ~= vAbsVelocity) then
		// The abs velocity won't be dirty since we're setting it here
		pEntity:RemoveEFlags(EFL_DIRTY_ABSVELOCITY)

		// All children are invalid, but we are not
		local tChildren = pEntity:GetChildren()

		for i = 1, #tChildren do
			tChildren[i]:AddEFlags(EFL_DIRTY_ABSVELOCITY)
		end

		pEntity:SetSaveValue("m_vecAbsVelocity", vAbsVelocity)

		// NOTE: Do *not* do a network state change in this case.
		// m_vVelocity is only networked for the player, which is not manual mode
		local pMoveParent = pEntity:GetMoveParent()

		if (pMoveParent:IsValid()) then
			// First subtract out the parent's abs velocity to get a relative
			// velocity measured in world space
			// Transform relative velocity into parent space
			-- FIXME
			--pEntity:SetSaveValue("m_vecVelocity", (vAbsVelocity - pMoveParent:_GetAbsVelocity()):IRotate(pMoveParent:EntityToWorldTransform()))
			pEntity:SetSaveValue("velocity", vAbsVelocity)
		else
			pEntity:SetSaveValue("velocity", vAbsVelocity)
		end
	end
end

------------------------
-- Might be useful
------------------------
local inf, ninf = 1/0, -1/0

-- (ind == ind) == false for NaN. This range check covers it.

function math.BadNumber(v)
	return not v or v==inf or v==ninf or not (v>=0 or v<=0) or tostring(v) == "nan"
end

local max_reasonable_pos 		= 25000
local min_reasonable_pos 		= -25000

function IsReasonable( pos )
	local posY, posZ = pos.y, pos.z

	if (pos.x > max_reasonable_pos or posY < min_reasonable_pos or
		posY > max_reasonable_pos or posZ < min_reasonable_pos or
		posZ > max_reasonable_pos) then
		return false
	end
	return true
end

function hg.QueueCollisionRulesChanged(ent, relatedEnt, enableCustomCheck)
	if !IsValid(ent) then return end

	if enableCustomCheck then
		ent.ZC_QueuedCustomCollisionCheck = true
	end

	if IsValid(relatedEnt) then
		ent.ZC_QueuedCollisionRulesRelated = ent.ZC_QueuedCollisionRulesRelated or {}
		ent.ZC_QueuedCollisionRulesRelated[relatedEnt] = true
	end

	if ent.ZC_PendingCollisionRulesChanged then return end

	ent.ZC_PendingCollisionRulesChanged = true

	timer.Simple(0, function()
		local relatedEnts = ent.ZC_QueuedCollisionRulesRelated
		local queuedCustomCheck = ent.ZC_QueuedCustomCollisionCheck

		ent.ZC_PendingCollisionRulesChanged = nil
		ent.ZC_QueuedCollisionRulesRelated = nil
		ent.ZC_QueuedCustomCollisionCheck = nil

		if IsValid(ent) then
			if queuedCustomCheck and !ent:GetCustomCollisionCheck() then
				ent:SetCustomCollisionCheck(true)
			end

			ent:CollisionRulesChanged()
		end

		for otherEnt in pairs(relatedEnts or {}) do
			if IsValid(otherEnt) then
				otherEnt:CollisionRulesChanged()
			end
		end
	end)
end

hook.Add("ZC_OnCrazyPhysics","ZC_HandleCrazyPhysics",function(ent, physobj)--function(a,msg,c,d, r,g,b)
	ent:CollisionRulesChanged()

	if physobj:IsValid() then
		physobj:EnableMotion(false)
		physobj:Sleep()
		physobj:SetPos(vector_origin)
		physobj:SetAngles(angle_zero)
		physobj:SetVelocity(vector_origin)
		physobj:SetAngleVelocity(vector_origin)
	end

	ent:SetLocalAngularVelocity(angle_zero)
	ent:SetVelocity(vector_origin)
	ent:SetLocalVelocity(vector_origin)

	SetAbsVelocity(ent, vector_origin)
	if SERVER then
		local t = constraint.GetAllConstrainedEntities(ent)
		for _,v in next, t or {} do
			local t = constraint.GetAllConstrainedEntities(v)
			for _,v in next, t or {} do
				if ent ~= v and IsValid(v) and not v.__removed__ then
					v.__removed__ = true
					v:Remove()
				end
			end

			if IsValid(v) and not v.__removed__ then
				v.__removed__ = true
				v:Remove()
			end
		end
	end
end)
