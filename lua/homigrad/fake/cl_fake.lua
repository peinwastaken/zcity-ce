local att
local vecZero, vecFull = Vector(0, 0, 0), Vector(1, 1, 1)
local vecPochtiZero = Vector(0.1, 0.1, 0.1)
local view = {}
local ang
local att_Ang
local firstPerson

local deathLocalAng = Angle(0, 0, 0)

local zc_coolcamera = ConVarExists("zc_coolcamera") and GetConVar("zc_coolcamera") or CreateConVar("zc_coolcamera", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Cool camera movement", 0, 1)
local zc_coolcameralerpmult = ConVarExists("zc_coolcameralerpmult") and GetConVar("zc_coolcameralerpmult") or CreateConVar("zc_coolcameralerpmult", 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Cool camera movement lerp multiplier", 0, 5)
function GetCoolCameraBool()
	return zc_coolcamera:GetBool() and !lply:InVehicle() and lply:Alive()
end
local vpangs

hook.Add("CreateMove", "ZC_ApplyCoolCameraCreateMove", function(cmd)
	if hg.InGame() or !GetCoolCameraBool() then return end

	hook.Run("InputMouseApply", cmd, 0, 0, (realanglelerp or Angle()) + (vpangs or Angle()))
end)

local diff = Angle()
hook.Add("InputMouseApply", "ZC_FakeCameraAngles", function(cmd, x, y, angle)
	local tbl = {}
	local cc = GetCoolCameraBool()
	if cc then
		realanglelerp = realanglelerp or angle
		vpangs = GetViewPunchAngles2() * 1 + GetViewPunchAngles() * 1 + GetViewPunchAngles3() * 1 + GetViewPunchAngles4() * 1
		diff = diff + realanglelerp + vpangs - angle
		diff.r = 0
		realangle = realangle and (realangle - diff) or angle
		realangle:Normalize()
		angle = realangle
	end

	tbl.cmd = cmd
	tbl.x = x
	tbl.y = y
	tbl.angle = angle

	if cc then
		tbl.angle = realangle
	end

	hook.Run("ZC_InputMouseApply", tbl)

	if !lply:Alive() then
		tbl.angle.r = 0
	end

	cmd = tbl.cmd
	x = tbl.x
	y = tbl.y
	angle = tbl.angle

	if cc then
		realangle = tbl.angle
	end

	if not tbl.override_angle then
		angle.pitch = math.Clamp(angle.pitch + y / 50, -89, 89)
		angle.yaw = angle.yaw - x / 50
	end

	if cc then
		realanglelerp = LerpAngleFT(0.09 * (zc_coolcameralerpmult:GetFloat() or 1), realanglelerp, realangle)
		angle = realanglelerp + vpangs
		if !IsValid(lply.FakeRagdoll) then angle[1] = math.Clamp(angle[1], -89, 89) end
		realangle = realangle + diff
		diff = LerpAngleFT(0.02 / game.GetTimeScale(), diff, angle_zero)
		cmd:SetViewAngles(angle)
	else
		cmd:SetViewAngles(angle)
	end

	lply.fakeangles = angle

	return true
end)

local turned = false
Quaternion()
if not ConVarExists("zc_newfakecam") then
	CreateConVar("zc_newfakecam", 0, FCVAR_ARCHIVE, "New camera rotate", 0, 1)
end
local rollang = 0
local ctime
local vecUpX, vecUpY, vecUpZ = Vector(1, 0, 0), Vector(0, 1, 0), Vector(0, 0, 1)
hook.Add("ZC_InputMouseApply", "ZC_FakeCameraAngles2", function(tbl)
	if IsValid(follow) and ctime != CurTime() then
		ctime = CurTime()

		hook.Run("ZC_ViewPunchThink", tbl)
	end

	local x = tbl.x
	local y = tbl.y
	local angle = tbl.angle

	local wep = lply:GetActiveWeapon()

	local consmul = 1 - hg.CalculateConsciousnessMul()

	if (wep.weight or wep.visualweight) and ((wep.weight and wep.weight > 0 or wep.visualweight and wep.visualweight > 0) or lply.organism.larmamputated or consmul > 0.3) then
		ViewPunch3(Angle(-y / 50 / 16, x / 50 / 16, 0) * math.min(((wep.visualweight ~= nil and wep.visualweight > 0) and wep.visualweight) or wep.weight, 10) / 3 / (1 - consmul * 0.5) * (lply.organism.larmamputated and 4 or 1) * (lply.organism.rarmamputated and 2 or 1))
	end

	ViewPunch4(Angle(y / 50 / 16, -x / 50 / 16, -x / 50 / 1) * 0.1)

	if !IsValid(lply) or !lply:Alive() then return end

	if lply.lean and math.abs(lply.lean) < 0.01 then
		oldlean = 0
		lean_lerp = 0
	end

	--[[local follow
	if not lply:OnGround() and lply:GetMoveType() ~= MOVETYPE_NOCLIP then
		follow = follow or lply
	end]]

	if lply:InVehicle() and not IsValid(follow) then
		tbl.override_angle = true
		tbl.angle = angle_zero
		return true
	end

	if !IsValid(follow) then
		tbl.angle.roll = lean_lerp * 10

		return
	end

	local att = follow:GetAttachment(follow:LookupAttachment("eyes"))
	if not att or not istable(att) then return end
	local vel = follow:GetVelocity()
	local huy = vel:Dot(angle:Right()) / 1500

	angle.roll = angle.roll
	angle.roll = math.NormalizeAngle(angle.roll)

	local angle2 = -(-angle)
	rollang = follow == lply.OldRagdoll and 0 or rollang
	angle2.roll = rollang

	if GetGlobalBool("zc_shitty_fake", true) and math.abs(math.AngleDifference(rollang, angle.roll)) < 60 then
		angle = LerpAngleFT(follow == lply.OldRagdoll and 0.1 or 0.01, angle, angle2)--math.Approach(angle.roll, rollang, adda * ftlerped * 80)
	end

	local fucke = false--!zc_newfakecam:GetBool()
	local oldroll = angle.roll
	angle.roll = fucke and 0 or angle.roll - (tbl.vpangle and tbl.vpangle.roll or 0)

	rollang = rollang + lean_lerp * 0.5
	local leanAng = lean_lerp * 0.5 + huy + x / 50 * math.abs(angle.pitch / 90)

	local q = Quaternion():SetAngle(angle)
	local q_pitch = Quaternion():SetAngleAxis(y / 50, vecUpY)
	local q_yaw = Quaternion():SetAngleAxis(-x / 50, vecUpZ)
	local q_roll = Quaternion():SetAngleAxis(leanAng, vecUpX)

	q = q * q_pitch * q_yaw * q_roll

	--oldangs = oldangs or q
	--local diffq = -(-q):Invert() * oldangs * 1
	--oldangs = -(-q)
	--if diffq then lerpedq:SLerp(diffq, 0.1) end

	--q = q * lerpedq

	local newAng = q:Angle()

	angle.pitch = newAng.p
    angle.yaw = newAng.y
    angle.roll = fucke and oldroll + lean_lerp * 0.5 or newAng.r

	if wep.IsResting and wep:IsResting() then
		angle.roll = math.Clamp(angle.roll, -15, 15)
	end

	if lply:InVehicle() then
		angle.roll = 0
	end

	if (lply.bGetUp) then
		local speed = 4 * FrameTime()
		tbl.angle.roll = Lerp(speed, tbl.angle.roll, 0)
	end

	tbl.override_angle = true
	tbl.angle = angle
end)

local zc_cshs_fake = CreateConVar("zc_cshs_fake", "0", FCVAR_ARCHIVE, "Toggle C'SHS-like ragdoll camera view", 0, 1)
local zc_firstperson_death = CreateClientConVar("zc_firstperson_death", "0", true, false, "Toggle first-person death camera view", 0, 1)
local zc_firstperson_ragdoll = CreateConVar("zc_firstperson_ragdoll", "0", FCVAR_ARCHIVE, "Toggle first-person ragdoll camera view", 0, 1)
local zc_fov = CreateClientConVar("zc_fov", "70", true, false, "Change first-person field of view", 75, 100)
local zc_gopro = CreateClientConVar("zc_gopro", "0", true, false, "Toggle GoPro-like camera view", 0, 1)
local zc_thirdperson = CreateConVar("zc_thirdperson", "0", FCVAR_REPLICATED, "Toggle third-person camera view", 0, 1)

hg.FAKE_STATE = hg.FAKE_STATE or {
	NONE = 0,
	ACTIVE = 1,
	RESTORING = 2,
	DEATH = 3,
}

local FAKE_STATE_NONE = hg.FAKE_STATE.NONE
local FAKE_STATE_ACTIVE = hg.FAKE_STATE.ACTIVE
local FAKE_STATE_RESTORING = hg.FAKE_STATE.RESTORING
local FAKE_STATE_DEATH = hg.FAKE_STATE.DEATH
local FAKE_ENTITY_INDEX_BITS = 13
local FAKE_CAMERA_BLEND_TIME = 0.16
local fakeCamera = {}

function hg.GetFakeState(ply)
	return IsValid(ply) and (ply.ZCFakeState or ply:GetNWInt("FakeRagdollState", FAKE_STATE_NONE)) or FAKE_STATE_NONE
end

function hg.GetFakeSequence(ply)
	return IsValid(ply) and (ply.ZCFakeSequence or ply:GetNWInt("FakeRagdollSeq", 0)) or 0
end

local function CopyCameraView(src)
	if not src or not isvector(src.origin) or not isangle(src.angles) then return end

	return {
		origin = Vector(src.origin.x, src.origin.y, src.origin.z),
		angles = Angle(src.angles.p, src.angles.y, src.angles.r),
		fov = src.fov,
		znear = src.znear,
		zfar = src.zfar,
		drawviewer = src.drawviewer,
	}
end

local function CurrentEyeView(ply)
	if not IsValid(ply) then return end

	return {
		origin = ply:EyePos(),
		angles = ply:EyeAngles(),
		fov = zc_fov:GetFloat(),
	}
end

local function BeginFakeCameraBlend(target, fromView)
	if lply ~= LocalPlayer() then lply = LocalPlayer() end
	local previousTarget = fakeCamera.target
	fakeCamera.target = target
	fakeCamera.blendFrom = CopyCameraView(fromView) or (IsValid(previousTarget) and CopyCameraView(fakeCamera.last)) or CurrentEyeView(lply)
	fakeCamera.blendStart = RealTime()
end

local function BeginFakeCameraBlendOut()
	if not IsValid(fakeCamera.target) and not fakeCamera.blendFrom and not fakeCamera.outFrom then
		fakeCamera.last = nil
		fakeCamera.lastValidTime = nil
		return
	end

	local canUseLast = fakeCamera.last and fakeCamera.lastValidTime and RealTime() - fakeCamera.lastValidTime <= 0.25
	fakeCamera.outFrom = (canUseLast and CopyCameraView(fakeCamera.last)) or CurrentEyeView(lply)
	fakeCamera.outStart = RealTime()
	fakeCamera.target = nil
	fakeCamera.blendFrom = nil
end

local function BlendCameraView(view, fromView, startedAt)
	if not fromView or not startedAt then return view end
	if not isvector(view.origin) or not isangle(view.angles) then return true end

	local k = math.Clamp((RealTime() - startedAt) / FAKE_CAMERA_BLEND_TIME, 0, 1)
	view.origin = LerpVector(k, fromView.origin, view.origin)
	view.angles = LerpAngle(k, fromView.angles, view.angles)
	if fromView.fov and view.fov then view.fov = Lerp(k, fromView.fov, view.fov) end

	return k >= 1
end

local function IsUsableFakeCameraTarget(ent)
	if not IsValid(ent) or ent:IsDormant() then return false end
	if not ent.LookupBone or not ent.GetBoneMatrix then return false end

	local head = ent:LookupBone("ValveBiped.Bip01_Head1")
	if not head then return false end

	local mat = ent:GetBoneMatrix(head)
	if not mat or mat:GetTranslation():IsEqualTol(ent:GetPos(), 0.01) then return false end

	local eyes = ent:LookupAttachment("eyes")
	if not eyes or eyes <= 0 then return false end

	local att = ent:GetAttachment(eyes)
	return istable(att) and isvector(att.Pos) and isangle(att.Ang)
end

local function GetRecentFakeCameraView()
	if fakeCamera.last and fakeCamera.lastValidTime and RealTime() - fakeCamera.lastValidTime <= 0.25 then
		return CopyCameraView(fakeCamera.last)
	end
end

function hg.ApplyFakeCameraBlend(ply, view, target)
	if ply ~= lply or not istable(view) then return view end

	if fakeCamera.target ~= target then
		BeginFakeCameraBlend(target)
	end

	if fakeCamera.blendFrom then
		local done = BlendCameraView(view, fakeCamera.blendFrom, fakeCamera.blendStart)
		if done then fakeCamera.blendFrom = nil end
	end

	fakeCamera.last = CopyCameraView(view)
	fakeCamera.lastValidTime = RealTime()

	return view
end

function hg.ApplyFakeCameraBlendOut(ply, view)
	if ply ~= lply or not istable(view) or not fakeCamera.outFrom then return view end

	local done = BlendCameraView(view, fakeCamera.outFrom, fakeCamera.outStart)
	if done then
		fakeCamera.outFrom = nil
		fakeCamera.outStart = nil
		fakeCamera.last = nil
		fakeCamera.lastValidTime = nil
	end

	return view
end

local function ApplyFakeHeadScale(ent, scale)
	if not IsValid(ent) or not ent.LookupBone or not ent.GetManipulateBoneScale then return end

	local head = ent:LookupBone("ValveBiped.Bip01_Head1")
	if not head then return end
	if ent:GetManipulateBoneScale(head):IsEqualTol(scale, 0.001) then return end

	ent:ManipulateBoneScale(head, scale)
end

function hg.SetFakeHeadHidden(ent, hidden)
	ApplyFakeHeadScale(ent, hidden and vecPochtiZero or vecFull)
end

function hg.RestoreFakeHead(ent)
	ApplyFakeHeadScale(ent, vecFull)
end

local k = 0
local CalcView
local angleZero = Angle(0,0,0)

local deathlerp = 0
local tblfollow = {}
local lerpasad = 0
CalcView = function(ply, origin, angles, fov, znear, zfar)
	if GetViewEntity() ~= (ply or LocalPlayer()) then return end
	local oldangles = -(-angles)
	fov = zc_fov:GetInt()
	lerpfovadd2 = LerpFT(0.1, lerpfovadd2, zooming and -25 or 0)

	if not lply:Alive() then
		fakeTimer = fakeTimer or CurTime() + 30
	end

	if not lply:Alive() and follow and ((fakeTimer < CurTime()) or lply:KeyPressed(IN_RELOAD) or lply:KeyPressed(IN_ATTACK) or lply:KeyPressed(IN_ATTACK2)) then
		BeginFakeCameraBlendOut()
		follow = nil

		return
	end

	if not lply:Alive() and not follow then
		return hook.Run("ZC_CalculateView", ply, origin, angles, fov, znear, zfar)
	end

	if LocalPlayer().lean and math.abs(LocalPlayer().lean) < 0.01 then
		oldlean = 0
		lean_lerp = 0
	end

	angles.roll = (turned and 180 or 0) + lean_lerp * 10

	if ply:InVehicle() then
		local ex = ply:GetAimVector():AngleEx(ply:GetVehicle():GetUp())
		ex[3] = 0
		angles = ex

		if ply:GetVehicle():GetParent().MovePlayerView then
			ply.lockcamera = false
			ply:GetVehicle():GetParent().MovePlayerView = function() end
		end
	end


	if not lply:Alive() and hg.DeathCam and hg.DeathCamAvailable(ply) then return hg.DeathCam(ply,origin,angles,fov,znear,zfar) end

	if not IsValid(ply) then return end
	if not IsValid(follow) then return end
	if not IsUsableFakeCameraTarget(follow) then return GetRecentFakeCameraView() end

	local vpang = GetViewPunchAngles2() + GetViewPunchAngles3()
	vpang[3] = 0

	view.fov = GetConVar("zc_fov"):GetInt()
	firstPerson = GetViewEntity() == lply

	if not firstPerson then return end

	att = follow:GetAttachment(follow:LookupAttachment("eyes"))
	if not att or not istable(att) then return end
	ang = angles
	ang:Normalize()

	att_Ang = att.Ang
	att_Ang:Normalize()

	local _, ot = WorldToLocal(vector_origin, ang, vector_origin, att_Ang)
	ot:Normalize()

	ot[2] = math.Clamp(ot[2], -90, 90)
	ot[1] = math.Clamp(ot[1], -90, 90)

	local _, angEye = LocalToWorld(vector_origin, ot, vector_origin, att_Ang)
	angEye:Normalize()

	angEye[3] = false--[[!zc_newfakecam:GetBool()]] and (math.Round(ply.fakeangles[3] / 180) * 180) or (ply.fakeangles and ply.fakeangles[3] or 0)
	--angEye = ang
	--angEye = att_Ang

	if ply:InVehicle() then
		angEye = angles
	end

	if ply.organism and ply.organism.unconscious then
		angEye = att_Ang
	end

	local alwaysRagdollAim = GetConVar("zc_always_ragdoll_aim")
	local inUse = (alwaysRagdollAim and alwaysRagdollAim:GetBool()) or hg.KeyDown(ply, IN_USE)
	local inVehicle = ply:InVehicle()
	local unconscious = ply.organism and ply.organism.unconscious
	local freeRagdollView = not inUse and not inVehicle
	local movingTooFastForControl = follow:GetVelocity():Length() > 350 and not inVehicle
	local cshs_fake = zc_cshs_fake:GetBool() or unconscious or freeRagdollView or movingTooFastForControl
	
	if IsValid(ply.OldRagdoll) then DrawPlayerRagdoll(follow, ply) end

	local pos = hg.eye(ply, 10, follow, att_Ang)

	--local dot = ang:Forward():Dot((pos - att.Pos):GetNormalized())


	if cshs_fake then
		deathlerp = LerpFT(0.1,deathlerp,not ply.bGetUp and 1 or 0)
		att_Ang:Normalize()
	else
		deathlerp = LerpFT( 0.1, deathlerp, 0 )
	end

	local angdeath = LerpAngle(deathlerp, angEye, att_Ang)
	angEye = angdeath

	view.angles = angEye

	if ply:Alive() then
		deathLocalAng:Set(view.angles)
	end

	hg.cam_things(ply, view, angleZero)

	if zc_thirdperson:GetBool() or hg.RagdollCombatInUse(ply) or (fakeTimer and fakeTimer > CurTime()) then
		if zc_firstperson_death:GetBool() then
			deathlerp = LerpFT(0.05,deathlerp,1)
			LerpAngle(deathlerp,deathLocalAng,att_Ang)

			hg.SetFakeHeadHidden(follow, firstPerson)

			view.origin = pos
			view.angles = att_Ang
		else
			hg.SetFakeHeadHidden(follow, lerpasad <= 0.9)

			lerpasad = Lerp(0.1, lerpasad, (IsAimingNoScope(ply) and 0 or 1))

			local ang = ply:EyeAngles()

			if !zc_firstperson_ragdoll:GetBool() then
				local tr = {}
				tr.start = pos
				tr.endpos = pos - ang:Forward() * 60 * lerpasad + ang:Right() * 15 * lerpasad
				tr.filter = {ply, follow}
				tr.mask = MASK_SOLID

				view.origin = util.TraceLine(tr).HitPos + ((tr.endpos - tr.start):GetNormalized() * -5) * lerpasad
			else
				view.origin = pos
			end

			view.angles = ang
		end
	else
		view.origin = pos
	end

	view.angles:Add(ply:GetViewPunchAngles())
	//view.origin, view.angles = HGAddView(lply, view.origin, view.angles, 0)

	view.angles:Add(-vpang)
	view.angles[3] = view.angles[3] + GetViewPunchAngles4()[3]
	view.angles:RotateAroundAxis(view.angles:Up(),-LookX)
	view.angles:RotateAroundAxis(view.angles:Right(),-LookY)
	view.fov = math.Clamp(zc_fov:GetFloat(),75,100) + lerpfovadd + lerpfovadd2
	view.znear = 1

	local getUpLerpTime = ply.gettingup_lerp or 0.3
	if ply.gettingup_into_getup and ply.gettingup and (ply.gettingup + getUpLerpTime - CurTime()) > 0 then
		local k = (CurTime() - ply.gettingup) / getUpLerpTime
		local k2 = math.max(k - 0.5, 0) * 2
		//view.origin = LerpVector(k2, view.origin, oldorigin)
		view.angles = LerpAngle(k2, view.angles, oldangles)
	end
	//view.angles = angles

	view = hook.Run("ZC_CalculateCameraView", ply, view.origin, view.angles, view, vector_origin) or view

	if GetCoolCameraBool() and !zc_cshs_fake:GetBool() and ply:Alive() then
		local angcool = realangle + GetViewPunchAngles() * 0.2 - vpang
		view.angles = LerpAngle(deathlerp,angcool,deathLocalAng)
		view.angles:RotateAroundAxis(view.angles:Up(),-LookX)
		view.angles:RotateAroundAxis(view.angles:Right(),-LookY)
		view.angles[3] = view.angles[3]
	else
		view.angles = view.angles + GetViewPunchAngles() * 0.2
	end


	k = Lerp(0.1, k, ply:KeyDown(IN_JUMP) and 1 or 0)
	--[[if wep.GetMuzzleAtt then
		wep:WorldModel_Transform()
		wep:DrawAttachments()
	end--]]

	if ply.organism and ply.organism.unconscious then view.angles = att_Ang end

	if zc_gopro:GetBool() then
		return SpecCam(follow, origin, angles, fov, znear, zfar)
	end

	hook.Run("ZC_PostCalculateView", ply, view)

	result = hook.Run("ZC_PostPostCalculateView", ply, view)
	if result then
		return result
	end

	view = hg.ApplyFakeCameraBlend(ply, view, follow) or view

	return view
end

hg.CalcViewFake = CalcView

--hook.Add("EntityNetworkedVarChanged","ZC_DebugFakeRagdollNetVarChange",function()

--end)

local hook_Run = hook.Run
local queuedRagdolls = {}

local function IsStaleFakeMessage(ply, seq)
	return seq and seq > 0 and (ply.ZCFakeSequence or 0) > seq
end

local function AddRagdollIndexToQueue(ply, seq, state, index)
	if not IsValid(ply) or not index or index <= 0 then return end
	if IsStaleFakeMessage(ply, seq) then return end

	queuedRagdolls[ply] = {
		seq = seq or 0,
		state = state or FAKE_STATE_ACTIVE,
		index = index,
		expires = CurTime() + 5,
	}
end

local function ClearRagdollIndexForPlayer(ply)
	queuedRagdolls[ply] = nil
end

local function MarkFakeSequence(ply, seq, state)
	if seq and seq > 0 then ply.ZCFakeSequence = seq end
	ply.ZCFakeState = state
end

local function BeginClientFakeRestore(ply, ragdoll, seq, state)
	if IsStaleFakeMessage(ply, seq) then return end

	MarkFakeSequence(ply, seq, state)
	ClearRagdollIndexForPlayer(ply)

	local oldrag = IsValid(ragdoll) and ragdoll or ply.FakeRagdoll
	if IsValid(oldrag) then
		hg.RestoreFakeHead(oldrag)

		if state == FAKE_STATE_RESTORING then
			ply.gettingup = CurTime()
			ply.gettingup_lerp = 0.3
			ply.gettingup_into_getup = true
			ply.OldRagdoll = oldrag
			ply.FakeRagdollOld = oldrag
		end
	end

	if ply == lply then
		if state == FAKE_STATE_RESTORING and IsValid(oldrag) then
			fakeCamera.outFrom = nil
			fakeCamera.outStart = nil
			follow = oldrag
		else
			BeginFakeCameraBlendOut()
			follow = nil
		end
	end

	if state == FAKE_STATE_RESTORING then
		ply.ragdoll_index = 0

		if IsValid(ply) then
			ply:SetNoDraw(false)
			ply:SetRenderMode(RENDERMODE_NORMAL)
		end

		hook_Run("ZC_OnPlayerRestoredFromFake", ply, oldrag)
		return
	end

	ply.gettingup_into_getup = nil
	ply.HGLastCustomAnim = nil

	if IsValid(ply.FakeRagdoll) then
		ply.FakeRagdoll.ply = nil
		ply.FakeRagdoll.HGClientFakeBound = nil
	end

	ply.FakeRagdoll = nil
	ply.ragdoll_index = 0

	if IsValid(ply) then
		ply:SetNoDraw(false)
		ply:SetRenderMode(RENDERMODE_NORMAL)
	end

	hook_Run("ZC_OnPlayerRestoredFromFake", ply, oldrag)
end

local function ApplyFakeLifecycleMessage(ply, seq, state, ragdoll, ragdollIndex)
	if !IsValid(ply) or IsStaleFakeMessage(ply, seq) then return end

	ragdollIndex = IsValid(ragdoll) and ragdoll:EntIndex() or ragdollIndex or 0

	if state == FAKE_STATE_RESTORING and not IsValid(ragdoll) and not IsValid(ply.FakeRagdoll) and (ragdollIndex or 0) > 0 then
		MarkFakeSequence(ply, seq, state)
		AddRagdollIndexToQueue(ply, seq, state, ragdollIndex)
		return
	end

	if state == FAKE_STATE_NONE or state == FAKE_STATE_RESTORING then
		BeginClientFakeRestore(ply, ragdoll, seq, state)
		return
	end

	if not IsValid(ragdoll) then
		MarkFakeSequence(ply, seq, state)
		AddRagdollIndexToQueue(ply, seq, state, ragdollIndex)
		return
	end

	MarkFakeSequence(ply, seq, state)
	ClearRagdollIndexForPlayer(ply)

	ply.ragdoll_index = ragdollIndex
	hook_Run("ZC_OnRagdollEntityCreated", ply, ragdoll, state == FAKE_STATE_DEATH and "RagdollDeath" or "FakeRagdoll")
end

hook.Add("Think", "ZC_TryResolvePlayerRagdollIndex", function()
	for ply, pending in pairs(queuedRagdolls) do
		if not IsValid(ply) or pending.expires < CurTime() or IsStaleFakeMessage(ply, pending.seq) then
			ClearRagdollIndexForPlayer(ply)
			continue
		end

		local ragdoll = Entity(pending.index)

		if IsValid(ragdoll) then
			ClearRagdollIndexForPlayer(ply)
			ApplyFakeLifecycleMessage(ply, pending.seq, pending.state, ragdoll, pending.index)
		end
	end
end)

net.Receive("ZC_PlayerRagdoll", function()
	local ply = net.ReadEntity()
	if !IsValid(ply) then print(tostring(ply) .. " is not valid") return end

	local seq = net.ReadUInt(32)
	local state = net.ReadUInt(3)
	local ragdollIndex = net.ReadUInt(FAKE_ENTITY_INDEX_BITS)
	local ragdoll = net.ReadEntity()

	ApplyFakeLifecycleMessage(ply, seq, state, ragdoll, ragdollIndex)
end)

hook.Add("NetworkEntityCreated", "ZC_GiveRenderOverride", function(ragdoll)
	if ragdoll:GetClass() == "prop_ragdoll" then
		if !IsValid(ragdoll:GetNWEntity("ply")) then
			ragdoll.RenderOverride = function(self, flags)
				if not IsValid(self) or self:IsDormant() then return end
				if not self:GetBonePosition(1) or self:GetBonePosition(1):IsEqualTol(self:GetPos(), 0.01) then return end
				if not self:GetNWString("PlayerName") then return end
				local ply = self:GetNWEntity("ply")
				local ply = (IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply.FakeRagdoll == self) and ply or self

				hg.renderOverride(ply, self, flags)
			end
		end

		for _, v in ipairs(ents.FindInSphere(ragdoll:GetPos(),16)) do
			if IsValid(v) and v:IsPlayer() and v:GetModel() == ragdoll:GetModel() then
				--ragdoll:SetNWString("PlayerName", v:Name())
				ragdoll:SetNWVector("PlayerColor", v:GetPlayerColor())
				ragdoll.PredictedAccessories = v:GetNetVar("Accessories","none")
				ragdoll.PredictedArmor = v:GetNetVar("Armor",{})
				ragdoll.PredictedHideArmorRender = v:GetNetVar("HideArmorRender", false)

				hook.Run("ZC_OnPredictedRagdollCreated",ragdoll,v)
				break
			end
		end
	end
end)

--h
hook.Add("ZC_OnRagdollEntityCreated", "ZC_RagdollFinder", function(ply, ent, key)
	if not IsValid(ply) then return end
	--print(ply)
	local oldrag = ply.FakeRagdoll
	ply.bGetUp = false

	if IsValid(ent) then
		ent.RenderOverride = function(self, flags)
			if not IsValid(self) or self:IsDormant() then return end
			if not self:GetBonePosition(1) or self:GetBonePosition(1):IsEqualTol(self:GetPos(), 0.01) then return end
			local ply = (IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply.FakeRagdoll == self) and ply or self

			hg.renderOverride(ply, self, flags)
		end
	end

	ply.FakeRagdoll = (key == "FakeRagdoll" and ent or ply.FakeRagdoll)-- or (key == "RagdollDeath" and IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ent)

	if key == "RagdollDeath" and ply == LocalPlayer() then
		ply.FakeRagdoll = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ent
	end

	--if key == "RagdollDeath" then ply.FakeRagdoll = nil return end

	--ply:SetNWEntity("FakeRagdoll", ent)
	--if not IsValid(oldrag) then oldrag = ent end
	hook.Run("ZC_TransferServerRagdollDecals", ply, ent)

	local ragdoll = ply.FakeRagdoll

	ragdoll = IsValid(ragdoll) and ragdoll

	if ragdoll and ragdoll.HGClientFakeBound == ply then
		if ply == lply then follow = ragdoll end
		return
	end

	if ply == lply then
		follow = ragdoll

		if follow and hg.IsChanged(follow,1,tblfollow) then
			if IsValid(tblfollow[1]) then
				//tblfollow[1]:ManipulateBoneScale(tblfollow[1]:LookupBone("ValveBiped.Bip01_Head1"),vecFull)
			elseif IsValid(follow) and not follow:GetManipulateBoneScale(follow:LookupBone("ValveBiped.Bip01_Head1")):IsEqualTol(vecZero,0.001) then
				//follow:ManipulateBoneScale(follow:LookupBone("ValveBiped.Bip01_Head1"),vecPochtiZero)
			end

			tblfollow[1] = follow
		end
	end

	if ragdoll then
		ragdoll.HGClientFakeBound = ply
		--ragdoll:SetPredictable(true)--causes ragdoll to shake bruh lol
		ragdoll.ply = ply
		ragdoll.organism = ply.organism

		hg.ragdolls[#hg.ragdolls + 1] = ragdoll

		ragdoll:CallOnRemove("RagdollRemove",function()
			hook.Run("ZC_OnRagdollRemoved",ply,ragdoll)
		end)

		//ply.FakeRagdollOld = nil

		ply.FakeRagdoll = ragdoll
		hook_Run("ZC_OnFakeRagdollCreated", ply, ragdoll)
	else
		if IsValid(ply.FakeRagdoll) then
			ply.fakecd = CurTime() + 2
		end

		if IsValid(ply) then ply:SetNoDraw(false) end
		ply:SetRenderMode(RENDERMODE_NORMAL)

		if IsValid(oldrag) then
			oldrag.ply = nil
			oldrag.HGClientFakeBound = nil
		end
		//ply.FakeRagdollOld = oldrag

		ply.FakeRagdoll = nil

		hook_Run("ZC_OnPlayerRestoredFromFake", ply, ragdoll)
	end

	--if IsValid(ply) and ply.BoneScaleChange then ply:BoneScaleChange() end

	ply.ragdollindex = nil
end)

local vec123 = Vector(0,0,0)
local entityMeta = FindMetaTable("Entity")

function entityMeta:GetPlayerColor()
	return self:GetNWVector("PlayerColor",vec123)
end

function entityMeta:GetPlayerName()
	return self:GetNWString("PlayerName","")
end

local playerMeta = FindMetaTable("Player")

function playerMeta:GetPlayerViewEntity()
	return (IsValid(self:GetNWEntity("spect")) and self:GetNWEntity("spect")) or (IsValid(self.FakeRagdoll) and self.FakeRagdoll) or self
end

function playerMeta:GetPlayerName()
	return self:GetNWString("PlayerName","")
end

function playerMeta:IsFirstPerson()
	if IsValid(self:GetNWEntity("spect",NULL)) then
		return self:GetNWInt("viewmode",viewmode or 1) == 1
	else
		return (GetViewEntity() == self)
	end
end

-- local ents_FindByClass = ents.FindByClass
-- function playerMeta:BoneScaleChange()
-- 	do return end
-- 	local firstPerson = LocalPlayer():IsFirstPerson()
-- 	local viewEnt = LocalPlayer():GetPlayerViewEntity()

-- 	for i,ent in ipairs(ents_FindByClass("prop_ragdoll")) do
-- 		if not ent:LookupBone("ValveBiped.Bip01_Head1") then continue end
-- 		if ent:GetManipulateBoneScale(ent:LookupBone("ValveBiped.Bip01_Head1")) == vector_origin then continue end
-- 		--if not hg.RagdollOwner(ent) then continue end
-- 		if ent == viewEnt then
-- 			ent:ManipulateBoneScale(ent:LookupBone("ValveBiped.Bip01_Head1"),firstPerson and vecPochtiZero or vecFull)
-- 		else
-- 			ent:ManipulateBoneScale(ent:LookupBone("ValveBiped.Bip01_Head1"),vecFull)
-- 		end
-- 	end

-- 	for i,ent in player.Iterator() do
-- 		if not ent:LookupBone("ValveBiped.Bip01_Head1") then continue end
-- 		if ent:GetManipulateBoneScale(ent:LookupBone("ValveBiped.Bip01_Head1")) == vector_origin then continue end
-- 		if ent == viewEnt then
-- 			ent:ManipulateBoneScale(ent:LookupBone("ValveBiped.Bip01_Head1"),firstPerson and vecPochtiZero or vecFull)
-- 		else
-- 			ent:ManipulateBoneScale(ent:LookupBone("ValveBiped.Bip01_Head1"),vecFull)
-- 		end
-- 	end
-- end

-- hook.Add("PostCleanupMap","ZC_ResetLocalBoneScaleOnCleanup",function()
-- 	LocalPlayer():BoneScaleChange()
-- end)

local function funcrag(ply, name, oldval, ragdoll)
	if not IsValid(ply) then return end

	local seq = ply:GetNWInt("FakeRagdollSeq", ply.ZCFakeSequence or 0)
	local state = ply:GetNWInt("FakeRagdollState", name == "RagdollDeath" and FAKE_STATE_DEATH or FAKE_STATE_ACTIVE)
	local ragdollIndex = IsValid(ragdoll) and ragdoll:EntIndex() or 0

	if name == "RagdollDeath" and state ~= FAKE_STATE_DEATH then
		state = FAKE_STATE_DEATH
	end

	if IsValid(ragdoll) then
		ApplyFakeLifecycleMessage(ply, seq, state, ragdoll, ragdollIndex)
	elseif ragdollIndex > 0 then
		AddRagdollIndexToQueue(ply, seq, state, ragdollIndex)
	end
end

hook.Add("PlayerInitialSpawn","ZC_SetupFakeRagdollNetVarProxy",function(ply)
	ply:SetNWVarProxy("RagdollDeath",funcrag)
	ply:SetNWVarProxy("FakeRagdoll", funcrag)
end)

hook.Add("InitPostEntity","ZC_SetupExistingFakeRagdollNetVarProxies",function()
	for _, ply in player.Iterator() do
		ply:SetNWVarProxy("RagdollDeath",funcrag)
		ply:SetNWVarProxy("FakeRagdoll", funcrag)
	end
end)

hook.Add("ZC_PlayerGetUp", "ZC_ResetLocalFakeRagdollState", function(ply)
	if ply == lply then
		ply.bGetUp = true
		fakeTimer = nil
		ply.lean = 0
		oldlean = 0
		lean_lerp = 0
		rollang = 0
	end

	ply:SetNWVarProxy("RagdollDeath", funcrag)
	ply:SetNWVarProxy("FakeRagdoll", funcrag)
end)

function hg.RagdollOwner(ragdoll)
	if not IsValid(ragdoll) then return end
	local ply = ragdoll:GetNWEntity("ply")
	return IsValid(ply) and ply:GetNWEntity("FakeRagdoll") == ragdoll and ply
end

hook.Add("ZC_PlayerDeath", "ZC_StartLocalFakeDeathTimer", function(ply)
	if ply != lply then return end

	fakeTimer = CurTime() + 5

	hg.override[ply] = nil

	-- timer.Simple(0.5 * math.max(ply:Ping() / 30,1),function()
	-- 	//ply:BoneScaleChange()
	-- end)
end)

function hg.GetCurrentCharacter(ply)
	if not IsValid(ply) then return end

	return (IsValid(ply.FakeRagdoll) and ply.FakeRagdoll) or ply
end

hook.Add("ZC_PlayerSpawn", "ZC_RemoveRagdoll", function(ply)
	local ragdoll = ply:GetNWEntity("FakeRagdoll")

	if IsValid(ragdoll) then
		ragdoll:SetNWEntity("ply", NULL)
		hg.RestoreFakeHead(ragdoll)
	end
	--FUCKING SHIT
	if IsValid(ply.FakeRagdoll) then
		ply.FakeRagdoll.ply = nil
		ply.FakeRagdoll = nil
	end

	if ply == lply then
		fakeTimer = nil
		BeginFakeCameraBlendOut()
		follow = nil
	end

	ply:SetNWEntity("FakeRagdoll", NULL)
	ply:SetNWEntity("RagdollDeath", NULL)
end)

local override = {}
hg.override = override
net.Receive("ZC_OverrideSpawn", function() override[net.ReadEntity()] = true end)
hook.Add("ZC_PlayerSpawn", "ZC_BlockOverrideSpawnClient", function(ply)
	if override[ply] then
		override[ply] = nil
		return false
	end
end)

hook.Add("ZC_PlayerSpawn", "ZC_BlockOverrideSpawnClientFallback", function(ply)
	if override[ply] then
		override[ply] = nil
		return false
	end
end)

hook.Add("PlayerFootstep", "ZC_CustomFootstep", function(ply) if IsValid(ply.FakeRagdoll) then return true end end)

hook.Add("EntityRemoved", "ZC_RestoreRagdollModelInstance", function(ent)
	if IsValid(ent.ply) then
		ent.ply:SnatchModelInstance(ent)
	end
end)

hook.Add("ZC_TransferServerRagdollDecals","ZC_TransferRagdollDecals", function(ent, rag)
    if IsValid(ent) && IsValid(rag) && !rag.DecalTransferDone then
        rag:SnatchModelInstance( ent )
        rag.DecalTransferDone = true
    end
end)


--[[hook.Add("OnEntityCreated", "ZC_TryCopyAppearanceNow", function( ent )
	--if not ent:IsRagdoll() then return end
	--for k,ply in ipairs(ents.FindInSphere(ent:GetPos(),15)) do
	--	if ply:IsPlayer() then
	--		ent:SetPlayerColor(ply:GetPlayerColor())
	--		local copy = duplicator.CopyEntTable(ply)
	--		duplicator.DoGeneric(ent,copy)
--
	--		ent:SetNWString("PlayerName",ply:Name())
	--		--ent:SetNWVector("PlayerColor",ply:GetPlayerColor())
	--		ent:SetNetVar("Armor", ply:GetNetVar("Armor",{}))
	--		ent:SetNetVar("Accessories", ply:GetNetVar("Accessories","none"))
	--	end
	--end
end)]]

--[[local sphereRadius = 12
hook.Add("Move","ZC_PushAwayRagdolls",function(ply) --// lagging
	do return end
	if not ply:Alive() and not hg.GetCurrentCharacter(ply):IsPlayer() then return end
	local playerPos = ply:GetPos()
    local sphereCenter = playerPos
    local entities = ents.FindInSphere(sphereCenter, sphereRadius)
    for _, ent in ipairs(entities) do
		if not ent:IsRagdoll() then continue end
		ent.pushCooldown = ent.pushCooldown or 0
		if ent.pushCooldown < CurTime() then
			if ply:GetVelocity():Length() > 200 then
				ViewPunch(Angle(15,math.random(-1,1),0))
			end
		end
		ent.pushCooldown = CurTime() + 0.1
    end
end)]]
