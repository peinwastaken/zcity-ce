--

util.AddNetworkString("ZC_DynamicAnimGesture")

local PLAYER = FindMetaTable("Player")
function PLAYER:PlayCustomAnims(anim, autoStop, speed, needForceLook, autostopAdjust, tSvCallbacks, holdTime)
	local _, animDelay = self:LookupSequence(anim)
	self:SetNWString("hg_CustomAnim", anim)
	self:SetNWFloat("hg_CustomAnimDelay", speed or animDelay)
	self:SetNWFloat("hg_CustomAnimStartTime", CurTime())
	self:SetNWFloat("hg_CustomAnimHoldUntil", holdTime and (CurTime() + holdTime) or 0)
	self:SetNWBool("hg_NeedAutoStop", autoStop)
	self:SetNWFloat("hg_AutoStopAdjust", autostopAdjust or 0)
	self:SetCycle(0)
	self:DoAnimationEvent(0)

	self.CustomAnimCallbacks = tSvCallbacks or nil

    if needForceLook then
        local ang = self:EyeAngles()
        ang[1] = 0
        self:SetVelocity(ang:Forward() * 15)
    end

	return animDelay
end

hook.Add("PlayerDeath", "ZC_StopWhenDieCustomAnim", function(ply)
	ply:PlayCustomAnims("")
end)

hook.Add("CalcMainActivity", "ZC_CustomAnimActivity", function(ply, vel)
	local str = ply:GetNWString("hg_CustomAnim", "")
	local num = ply:GetNWFloat("hg_CustomAnimDelay")
	local st = ply:GetNWFloat("hg_CustomAnimStartTime")
	local holdUntil = ply:GetNWFloat("hg_CustomAnimHoldUntil", 0)
	local needAutoStop = ply:GetNWBool("hg_NeedAutoStop", false)
	local autostopAdjust = ply:GetNWFloat("hg_AutoStopAdjust", 0)

	if str ~= nil and str ~= "" then
		local animStart = holdUntil > 0 and holdUntil or st
		local cycle = holdUntil > CurTime() and 0 or (CurTime() - animStart) / num

		ply:SetCycle(cycle)
		local timing = math.Truncate(math.Round(cycle, 3),2)
		ply.OldCustomAnimCallbackTime = ply.OldCustomAnimCallbackTime or timing
		if ply.CustomAnimCallbacks and ply.CustomAnimCallbacks[ timing ] and ply.OldCustomAnimCallbackTime != timing then
			ply.CustomAnimCallbacks[ timing ]( ply )
			ply.OldCustomAnimCallbackTime = timing
		end

		if needAutoStop and animStart + (num - autostopAdjust) <= CurTime() then
			ply:PlayCustomAnims("")
		end

		return -1, ply:LookupSequence(str)
	end
end)

-- PlayAnimAsGesture
-- https://gmodwiki.com/Player:AddVCDSequenceToGestureSlot
-- https://gmodwiki.com/Entity:SetLayerBlendIn
function PLAYER:PlayCustomAnimAsGesture(anim, weight, anim_time, start_time, autokill)
	local AnimID, AnimDuration = self:LookupSequence(anim)
	anim_time = anim_time or AnimDuration

	if !AnimID then ErrorNoHalt("[Dynamic Anim] No sequence!\n") return end

	self:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
	self:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, AnimID, start_time or 0, autokill)
	self:AnimSetGestureWeight(GESTURE_SLOT_CUSTOM, weight or 1)

	net.Start("ZC_DynamicAnimGesture")
		net.WriteEntity(self)
		net.WriteInt(AnimID, 16)
		net.WriteFloat(weight or 1)
		net.WriteFloat(CurTime())
		net.WriteFloat(start_time or 0)
		net.WriteFloat(anim_time)
		net.WriteFloat(AnimDuration)
		net.WriteBool(autokill or false)
	net.SendPVS(self:GetPos())
end
