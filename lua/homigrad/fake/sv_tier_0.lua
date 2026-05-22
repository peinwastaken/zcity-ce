local PLAYER = FindMetaTable("Player")
if not HookGetRagdollEntity then HookGetRagdollEntity = PLAYER.GetRagdollEntity end
function PLAYER:GetRagdollEntity()
	local ent = self:GetNWEntity("RagdollDeath")
	return IsValid(ent) and ent or HookGetRagdollEntity(self)
end

function PLAYER:CreateRagdoll()
	return false
end

local hook_Run = hook.Run
hook.Add("OnEntityCreated", "ZC_UpdateNpcBullseyeRelationships", function(npc)
	timer.Simple(0, function()
		if IsValid(npc) then
			if npc:IsNPC() or string.Explode( "_" , npc:GetClass() ) == "terminator" then
				for _, ent in pairs(ents.FindByClass("npc_bullseye")) do
					if IsValid(ent) and IsValid(ent.ply) then npc:AddEntityRelationship(ent, npc:Disposition(ent.ply)) end
				end
			end
		end
	end)
end)
local vecZero = Vector(0,0,0)

--[[

ValveBiped.Bip01_Pelvis 12.775918006897
ValveBiped.Bip01_Spine2 24.36336517334
ValveBiped.Bip01_R_UpperArm     3.4941370487213
ValveBiped.Bip01_L_UpperArm     3.441034078598
ValveBiped.Bip01_L_Forearm      1.7655730247498
ValveBiped.Bip01_L_Hand 1.0779889822006
ValveBiped.Bip01_R_Forearm      1.7567429542542
ValveBiped.Bip01_R_Hand 1.0214320421219
ValveBiped.Bip01_R_Thigh        10.212161064148
ValveBiped.Bip01_R_Calf 4.9580898284912
ValveBiped.Bip01_Head1  5.169750213623
ValveBiped.Bip01_L_Thigh        10.213202476501
ValveBiped.Bip01_L_Calf 4.9809679985046
ValveBiped.Bip01_L_Foot 2.3848159313202
ValveBiped.Bip01_R_Foot 2.3848159313202

12.775918006897 0
24.36336517334  3
3.4941370487213 9
3.441034078598  14
1.7655730247498 15
1.0779889822006 16
1.7567429542542 10
1.0214320421219 11
10.212161064148 18
4.9580898284912 19
5.169750213623  6
10.213202476501 22
4.9809679985046 23
2.3848159313202 24
2.3848159313202 20
]]--

hg = hg or {}

hg.cachedmodels = {}

local function cacheModel(ragdoll)
	local model = ragdoll:GetModel()

	if not hg.cachedmodels[model] then
		local tbl = {}
		hg.cachedmodels[model] = {}
		for i = 0,ragdoll:GetPhysicsObjectCount()-1 do
			tbl[i] = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
		end

		for i, bone in pairs(tbl) do
			hg.cachedmodels[model][bone] = i
		end
	end
end

hg.cacheModel = cacheModel

local IdealMassPlayer = hg.IdealMassPlayer

local MAX_FAKE_TRANSITION_SPEED = 4000

local function CopyVelocity(vec)
	if not isvector(vec) then return end

	local velocity = Vector(vec.x, vec.y, vec.z)
	if velocity:LengthSqr() > MAX_FAKE_TRANSITION_SPEED * MAX_FAKE_TRANSITION_SPEED then
		velocity = velocity:GetNormalized() * MAX_FAKE_TRANSITION_SPEED
	end

	return velocity
end

function hg.QueueFakeVelocity(ply, velocity, duration)
	if not IsValid(ply) then return end

	velocity = CopyVelocity(velocity)
	if not velocity then return end

	ply.ZCFakeVelocityOverride = velocity
	ply.ZCFakeVelocityOverrideUntil = CurTime() + (duration or 0.2)
end

local function ConsumeFakeVelocity(ply)
	local velocity = ply.ZCFakeVelocityOverride
	local expires = ply.ZCFakeVelocityOverrideUntil or 0

	ply.ZCFakeVelocityOverride = nil
	ply.ZCFakeVelocityOverrideUntil = nil

	if velocity and expires >= CurTime() then
		return CopyVelocity(velocity) or vecZero
	end

	return CopyVelocity(ply:GetVelocity()) or vecZero
end

local function GetRagdollMassVelocity(ragdoll)
	if not IsValid(ragdoll) or not ragdoll.GetPhysicsObjectCount then return vecZero end

	local velocity = Vector(0, 0, 0)
	local totalMass = 0

	for physNum = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(physNum)
		if not IsValid(phys) then continue end

		local mass = math.max(phys:GetMass(), 0)
		if mass <= 0 then continue end

		velocity:Add(phys:GetVelocity() * mass)
		totalMass = totalMass + mass
	end

	if totalMass > 0 then
		velocity:Div(totalMass)
		return CopyVelocity(velocity) or vecZero
	end

	local phys = ragdoll:GetPhysicsObject()
	return IsValid(phys) and (CopyVelocity(phys:GetVelocity()) or vecZero) or vecZero
end

local fixbones = {
	["ValveBiped.Bip01_Pelvis"] = true,
	["ValveBiped.Bip01_L_Thigh"] = true,
	["ValveBiped.Bip01_R_Thigh"] = true,
	["ValveBiped.Bip01_R_Calf"] = true,
	["ValveBiped.Bip01_L_Calf"] = true,
	//["ValveBiped.Bip01_L_Hand"] = true,
}

function hg.Ragdoll_Create(ply)
	local Data = duplicator.CopyEntTable( ply )
	local ragdoll = ents.Create("prop_ragdoll")
	duplicator.DoGeneric( ragdoll, Data )

	ragdoll:SetPos(ply:GetPos())
	ragdoll:SetAngles(ply:GetAngles())
	--ragdoll:SetVelocity(ply:GetVelocity())
	ragdoll:SetModel(ply:GetModel())
	ragdoll.CurAppearance = table.Copy(ply.CurAppearance)

	ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ragdoll:Spawn()
	ragdoll:Activate()
	ragdoll:AddEFlags(EFL_NO_DAMAGE_FORCES + EFL_DONTBLOCKLOS)
	--ragdoll:AddFlags(FL_NOTARGET)
	--ply:AddFlags(FL_NOTARGET)

	hg.queue_ragdolls[ragdoll] = {}

	if IsValid(ply.bull) then ply.bull:Remove() ply.bull = nil end
	ragdoll.bull = ents.Create("npc_bullseye")
	local bull = ragdoll.bull
	bull.ply = ply
	bull.rag = ragdoll
	local bodyphy = ragdoll:GetPhysicsObjectNum(10)
	if !bodyphy then return end
	bull:SetPos(bodyphy:GetPos()+bodyphy:GetAngles():Right()*7)
	--bull:SetPos( eyeatt.Pos + eyeatt.Ang:Up() * 3.5 )
	bull:SetAngles( ragdoll:GetAngles() )
	bull:SetMoveType(MOVETYPE_OBSERVER)
	--bull:SetCollisionGroup(COLLISION_GROUP_BREAKABLE_GLASS)
	bull:SetKeyValue( "targetname", "Bullseye" )
	--bull:SetParent(ragdoll, ragdoll:LookupAttachment("eyes"))
	bull:SetKeyValue( "health","9999" )
	bull:SetKeyValue( "spawnflags","256" )
	bull:Spawn()
	bull:Activate()
	bull:SetNotSolid(true)

	--bull:SetCollisionBoundsWS(-Vector(5,5,5),Vector(5,5,5))
	--bull:SetSurroundingBounds(-Vector(50,50,50),Vector(50,50,50))
	--[[local enta = ents.Create("prop_dynamic")
	enta:SetPos(bull:GetPos())
	enta:SetAngles(bull:GetAngles())
	enta:SetModel("models/props_junk/metal_paintcan001a.mdl")
	enta:SetParent(bull)
	enta:Spawn()
	enta:SetNotSolid(true)
	bull:CallOnRemove("asdsad",function() enta:Remove() end)--]]

	for _, ent in ipairs(ents.FindByClass("npc_*")) do
		if not IsValid(ent) or not ent.AddEntityRelationship then continue end
		ent:AddEntityRelationship(bull, ent:Disposition(ply))
	end


	for _, ent in ipairs(ents.FindByClass("terminator_*")) do
		if not IsValid(ent) or not ent.AddEntityRelationship then continue end
		ent:AddEntityRelationship(bull, ent:Disposition(ply))
	end

	ragdoll:CallOnRemove("removeBull", function()
		hg.queue_ragdolls[ragdoll] = nil

		if IsValid(ragdoll.bull) then
			ragdoll.bull:Remove()
		end
	end)
	ragdoll:AddCallback("PhysicsCollide", function(outEnt, data) hook_Run("ZC_OnRagdollCollide", ragdoll, data) end)
	local velocity = ConsumeFakeVelocity(ply)
	--local phys = ragdoll:GetPhysicsObject()
	--if IsValid(phys) then --phys:SetMass(20)
	--end

	--[[local phys = ragdoll:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(20)
	end]]--


	cacheModel(ragdoll)

	local offset = ply:GetPos() - ply:GetBoneMatrix(0):GetTranslation() + vector_up * 36

	if ply:InVehicle() then
		local veh = ply:GetVehicle()
		veh.rags = veh.rags or {}
		table.insert(veh.rags, ragdoll)
	end

	for physNum = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(physNum)
		local bone = ragdoll:TranslatePhysBoneToBone(physNum)
		if bone < 0 then continue end
		local matrix = ply:GetBoneMatrix(bone)
		ply.AddForceRag = ply.AddForceRag or {}
		ply.AddForceRag[physNum] = ply.AddForceRag[physNum] or {}
		local vel = (ply.AddForceRag[physNum][2] or vecZero) * math.max(0, (ply.AddForceRag[physNum][1] or CurTime()) - CurTime()) / 0.25

		--print(ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(hg.cachedmodels[model][ragdoll:GetBoneName(bone)])),ragdoll:GetBoneName(bone),IdealMassPlayer[ragdoll:GetBoneName(bone)])

		phys:SetMass(IdealMassPlayer[ragdoll:GetBoneName(bone)] or 4)

		--phys:SetContents(bit.band(phys:GetContents(), bit.bnot(MASK_SHOT)))

		ply.AddForceRag[physNum][2] = vecZero

		/*local ent = Entity(1)
		for i=0, ent:GetNumPoseParameters() - 1 do
			local min, max = ent:GetPoseParameterRange( i )
			print( ent:GetPoseParameterName( i ) .. ' ' .. min .. " / " .. max )
		end*/

		local bonename = ragdoll:GetBoneName(bone)

		if hg.amputeetable[bonename] and ply.organism[hg.amputeetable[bonename].."amputated"] then
			--phys:SetContents(CONTENTS_EMPTY)
			Gib_RemoveBone(ragdoll, bone, physNum, true)
			--phys:SetCollisionGroup(COLLISION_GROUP_WORLD)
		end

		if ply:InVehicle() then
			local veh = ply:GetVehicle()
			local veh2 = ply.GetSimfphys and IsValid(ply:GetSimfphys()) and ply:GetSimfphys() or ply:GetVehicle()

			//ply.nocollide1 = constraint.NoCollide(ragdoll, veh, physNum, 0)
			//ply.nocollide2 = constraint.NoCollide(ragdoll, IsValid(veh:GetParent()) and veh:GetParent() or veh, physNum, 0)

			ragdoll:SetParent(IsValid(veh:GetParent()) and veh:GetParent() or veh)

			//ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

			ply:SetEyeAngles(angle_zero)


			local isVan = false
			if veh2:GetModel() == "models/vehicles/7seatvan.mdl" then
				isVan = true
			end

			local matrix = ply:GetBoneMatrix(bone)

			local pos = matrix:GetTranslation() + veh:GetAngles():Up() * 5
			if veh:GetClass() == "prop_vehicle_airboat" and veh:GetInternalVariable("EnableGun") then
				--pos:Add(veh:GetAngles():Right() * 10 + veh:GetAngles():Forward() * -10 + veh:GetAngles():Up() * -15)
				pos:Add(veh:GetAngles():Right() * 10)
			end

			local ang = matrix:GetAngles()

			//ply:GetBoneMatrix(0):GetTranslation()
			//local pos, ang = hg.RotateAroundPoint2(pos, ang, vector_origin, vector_origin, Angle(-90,0,0))
			phys:SetPos(pos)
			phys:SetAngles(ang)

			//ragdoll:SetCollisionGroup(COLLISION_GROUP_WORLD)

			if fixbones[ragdoll:GetBoneName(bone)] then
				local weld = constraint.Weld(ragdoll, IsValid(veh:GetParent()) and veh:GetParent() or veh, physNum, 0, 10000, false, false)

				ragdoll.welds = ragdoll.welds or {}
				table.insert(ragdoll.welds, weld)
				weld:CallOnRemove("removeVehicleWeld", function()
					if ragdoll.removingwelds then return end
					//hook.Run("ZC_CanExitVehicle", ply, veh)
					if !hg.leaveveh then hg.fallfromveh = true end
					hg.leaveveh = true
					if IsValid(ply) then ply:ExitVehicle() end

					table.RemoveByValue(veh.rags, ragdoll)

					timer.Simple(0.1, function()
						if IsValid(ragdoll) then
							for physNum = 0, ragdoll:GetPhysicsObjectCount() - 1 do
								local phys = ragdoll:GetPhysicsObjectNum(physNum)
								local bone = ragdoll:TranslatePhysBoneToBone(physNum)
								phys:SetMass(IdealMassPlayer[ragdoll:GetBoneName(bone)] or 4)
							end
						end
					end)

					if ragdoll.welds then
						for i, weld in pairs(ragdoll.welds) do
							if IsValid(weld) then weld:Remove() end
						end

						ragdoll.welds = nil
					end

					if IsValid(ply.nocollide1) then
						ply.nocollide1:Remove()
						ply.nocollide1 = nil
					end

					if IsValid(ply.nocollide2) then
						ply.nocollide2:Remove()
						ply.nocollide2 = nil
					end
				end)
			end

		end

		phys:SetPos(matrix:GetTranslation() + (ply:InVehicle() and vector_origin or offset))
		phys:SetAngles(matrix:GetAngles())
		if ragdoll:GetBoneName(bone) == "ValveBiped.Bip01_Head1" then
			local _,ang = LocalToWorld(vecZero,Angle(-80,0,90),vecZero,ply:EyeAngles())
			phys:SetAngles(ang)
		end
		--phys:EnableDrag(true)
		--phys:SetDragCoefficient( 1500 )
		--phys:SetDamping(0,2)
		--print(bone)
		--[[if !string.find(ragdoll:GetBoneName(bone),"L") then
			phys:EnableMotion(false)
		end--]]
		phys:SetVelocity(velocity)
		phys:ApplyForceCenter(vel)
		phys:Wake()
	end

	ragdoll:SetNWString("PlayerName", ply:GetNWString("PlayerName") or ply:Name())
	ragdoll:SetNWVector("PlayerColor", ply:GetPlayerColor())
	--print(ply:GetNetVar("Accessories","none"))
	--timer.Simple(1,function()
	--print(ragdoll:GetNetVar("Accessories","none"))
	--end)

	-- FakeRagdoll NWEntity is assigned by the lifecycle sync layer after
	-- the ragdoll gets a sequence id.

	ragdoll:SetNWEntity("ply", ply)
	--ply:SetPos(ragdoll:GetPos())

	--[[if ply.organism.LodgedEntities then
		timer.Simple(0, function()
			for lodged, settings in pairs(ragdoll.organism.LodgedEntities) do
				constraint.RemoveConstraints(lodged, "Weld")

				timer.Simple(0, function()
					local phys_obj = ragdoll:GetPhysicsObjectNum(settings.PhysBoneID)
					local pos, ang = LocalToWorld(settings.OffsetPos, settings.OffsetAng, phys_obj:GetPos(), phys_obj:GetAngles())

					lodged:SetPos(pos)
					lodged:SetAngles(ang)

					constraint.Weld(lodged, ragdoll, 0, settings.PhysBoneID, 0, true, false)

					lodged:SetPos(pos)
					lodged:SetAngles(ang)
				end)
			end
		end)
	end]]

	hook_Run("ZC_OnPlayerRagdollCreated", ply, ragdoll)

	ragdoll.ply = ply
	ApplyAppearanceRagdoll(ragdoll, ply)
	return ragdoll
end

local Ragdoll_Create = hg.Ragdoll_Create
util.AddNetworkString("ZC_PlayerRagdoll")

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
local FAKE_STATE_NAMES = {
	[FAKE_STATE_NONE] = "none",
	[FAKE_STATE_ACTIVE] = "active",
	[FAKE_STATE_RESTORING] = "restoring",
	[FAKE_STATE_DEATH] = "death",
}
local FAKE_ENTITY_INDEX_BITS = 13

local zc_fake_debug = ConVarExists("zc_fake_debug") and GetConVar("zc_fake_debug") or CreateConVar("zc_fake_debug", "0", FCVAR_ARCHIVE, "Log fake ragdoll lifecycle transitions", 0, 1)

local function NextFakeSequence(ply)
	local seq = (ply.ZCFakeSequence or 0) + 1
	if seq >= 4294967295 then seq = 1 end
	ply.ZCFakeSequence = seq

	return seq
end

function hg.GetFakeSequence(ply)
	return IsValid(ply) and (ply.ZCFakeSequence or 0) or 0
end

function hg.GetFakeState(ply)
	return IsValid(ply) and (ply.ZCFakeState or FAKE_STATE_NONE) or FAKE_STATE_NONE
end

function hg.IsFakeLifecycle(ply, state, seq)
	return IsValid(ply) and ply.ZCFakeState == state and (seq == nil or ply.ZCFakeSequence == seq)
end

local function SyncFakeLifecycle(ply, state, ragdoll, send)
	net.Start("ZC_PlayerRagdoll")
	net.WriteEntity(ply)
	net.WriteUInt(ply.ZCFakeSequence or 0, 32)
	net.WriteUInt(state, 3)
	net.WriteUInt(IsValid(ragdoll) and ragdoll:EntIndex() or 0, FAKE_ENTITY_INDEX_BITS)
	net.WriteEntity(IsValid(ragdoll) and ragdoll or NULL)

	if IsValid(send) and send:IsPlayer() then
		net.Send(send)
	else
		net.Broadcast()
	end
end

local function MirrorFakeLifecycle(ply, state, ragdoll)
	ply.ZCFakeState = state
	ply:SetNWInt("FakeRagdollSeq", ply.ZCFakeSequence or 0)
	ply:SetNWInt("FakeRagdollState", state)

	if state == FAKE_STATE_ACTIVE or state == FAKE_STATE_DEATH then
		if IsValid(ragdoll) then
			ply.FakeRagdoll = ragdoll
			hg.ragdollFake[ply] = ragdoll
			ply:SetNWEntity("FakeRagdoll", ragdoll)
			ragdoll:SetNWEntity("ply", ply)
			ragdoll.ply = ply
			ragdoll.ZCFakeSequence = ply.ZCFakeSequence
		end
	else
		ply.FakeRagdoll = nil
		hg.ragdollFake[ply] = nil
		ply:SetNWEntity("FakeRagdoll", NULL)
	end
end

local function SetFakeLifecycle(ply, state, ragdoll, send)
	if not IsValid(ply) then return 0 end

	local seq = NextFakeSequence(ply)
	MirrorFakeLifecycle(ply, state, ragdoll)
	SyncFakeLifecycle(ply, state, ragdoll, send)

	if zc_fake_debug:GetBool() then
		print(string.format("[ZC fake] %s -> %s seq=%d rag=%s", tostring(ply), FAKE_STATE_NAMES[state] or tostring(state), seq, tostring(ragdoll)))
	end

	hook_Run("ZC_FakeStateChanged", ply, state, ragdoll, seq, FAKE_STATE_NAMES[state])

	return seq
end

hg.SetFakeLifecycle = SetFakeLifecycle

hook.Add("PlayerSpawn", "ZC_HandleFakeRagdollPlayerSpawn", function(ply)
	ply:RemoveFlags(FL_NOTARGET)
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	if OverrideSpawn then return end
	if ply.gottarespawn then
		ply:SetNWEntity("RagdollDeath", NULL)
		ply.gottarespawn = nil
	end
	timer.Simple(.1, function()
		if IsValid(ply.organism) then
			ply.organism.holdingbreath = false
		end
	end)
	ply:SetCanZoom(false)
end)

-- local FrameTimeS
-- local LastTick = 0


-- hook.Add("Tick", "ZC_FPSCheck", function()
-- 	FrameTimeS = SysTime() - (LastTick or SysTime())
-- 	LastTick = SysTime()

-- 	local tps = 1 / FrameTimeS

-- 	if tps < 66 then
-- 		print(tps)
-- 	end
-- end)

hg.ragdollFake = hg.ragdollFake or {}
--local ragdollFake = hg.ragdollFake
hook.Add("DoPlayerDeath", "ZC_CreateFakeRagdollOnDeath", function(ply)
	local ragdoll = ply.FakeRagdoll
	--if not IsValid(ragdoll) then return end
	if (not ply.Removed) and not IsValid(ragdoll) then
		ragdoll = Ragdoll_Create(ply)
		SetFakeLifecycle(ply, FAKE_STATE_DEATH, ragdoll)
	end

	if not IsValid(ragdoll) then return end
	if ply.ZCFakeState ~= FAKE_STATE_DEATH then
		SetFakeLifecycle(ply, FAKE_STATE_DEATH, ragdoll)
	end

	if IsValid(ragdoll.bull) then ragdoll.bull:Remove() end

	ply:SetNWEntity("RagdollDeath", ragdoll)
	ragdoll:SetNetVar("wounds", ply:GetNetVar("wounds"))
	ragdoll:SetNetVar("arterialwounds", ply:GetNetVar("arterialwounds"))
	ply.RagdollDeath = ragdoll
end)

hook.Add("PostPlayerDeath", "ZC_ClearFakeRagdollAfterPlayerDeath", function(ply)
	local ragdoll = HookGetRagdollEntity(ply)
	if IsValid(ragdoll) then ragdoll:Remove() end

	ply:SetNWEntity("FakeRagdoll", NULL)
	--ply:SetNWEntity("RagdollDeath", ragdoll)

	ply.FakeRagdoll = nil
	hg.ragdollFake[ply] = nil

	ply.fakecd = 0
	ply.viewmode = 3
end)

local function RemoveRag(self, ply)
	if self.override then return end
	if not IsValid(ply) or ply.FakeRagdoll ~= self then return end
	if self.ZCFakeSequence and self.ZCFakeSequence ~= ply.ZCFakeSequence then return end

	ply.Removed = true
	if ply:Alive() then ply:Kill() end
	SetFakeLifecycle(ply, FAKE_STATE_NONE, NULL)
	ply.Removed = false
end

hg.queue_ragdolls = hg.queue_ragdolls or {}
hg.humans_cached = hg.humans_cached or {}

hook.Add("SetupPlayerVisibility", "ZC_RemoveRagdolls", function( ply )
	local queue = hg.queue_ragdolls

	for ent, tbl in pairs(queue) do--it probably hurts
		if not IsValid(ent) then queue[ent] = nil continue end
		if queue[ent].count == #hg.humans_cached then queue[ent] = nil continue end
		if queue[ent][ply] then continue end

		if IsValid(ent) then
			AddOriginToPVS( ent:GetPos() )
			queue[ent][ply] = true
			queue[ent].count = (queue[ent].count or 0) + 1
		end
	end

end)

hook.Add("SetupPlayerVisibility", "ZC_AddFakeRagdollToPvs", function( ply )
	local ent = IsValid(hg.ragdollFake[ply]) and hg.ragdollFake[ply] or ply:GetNWEntity("FakeRagdoll")

	if IsValid(ent) and !ent:TestPVS(ply) then
		AddOriginToPVS(ent:GetPos())
	end
end)

function hg.SavePoses(ply)
	ply.poses = {}
	if IsValid(ply.FakeRagdoll) then
		for i = 0, ply.FakeRagdoll:GetPhysicsObjectCount() - 1 do
			local obj = ply.FakeRagdoll:GetPhysicsObjectNum(i)
			local p, a = obj:GetPos(), obj:GetAngles()
			ply.poses[ply.FakeRagdoll:GetBoneName(ply.FakeRagdoll:TranslatePhysBoneToBone(i))] = {p, a}
		end
	end
end

function hg.ApplyPoses(ply)
	if IsValid(ply.FakeRagdoll) and ply.poses then
		for i, t in pairs(ply.poses) do
			local bon = ply.FakeRagdoll:TranslateBoneToPhysBone(ply.FakeRagdoll:LookupBone(i))

			local obj = ply.FakeRagdoll:GetPhysicsObjectNum(bon)

			obj:SetPos(t[1])
			obj:SetAngles(t[2])
			obj:EnableMotion(false)

			timer.Simple(0.1, function()
				if IsValid(obj) then
					obj:EnableMotion(true)
				end
			end)
		end
	end
end

function hg.Fake(ply, huyragdoll, no_freemove, force)
	ply.switchingseat = nil
	if ply:GetMoveType() == 0 then return end
	if ply.InVehicle and ply:InVehicle() and not force then return end
	if not IsValid(huyragdoll) and (not IsValid(ply) or IsValid(ply.FakeRagdoll) or not (ply:IsPlayer() and ply:Alive())) then return end
	local ragdoll = IsValid(huyragdoll) and huyragdoll or Ragdoll_Create(ply, true)

	if IsValid(huyragdoll) then
		ragdoll:SetNWEntity("ply", ply)
		hook_Run("ZC_OnPlayerRagdollCreated", ply, ragdoll)
	end
	if !IsValid(ragdoll) then return end
	ragdoll:CallOnRemove("Fake", RemoveRag, ply)
	ply.fakecd = CurTime() + 1// + ply.organism.shock / 10
	local fakeSeq = SetFakeLifecycle(ply, FAKE_STATE_ACTIVE, ragdoll)

	if IsValid(ply.FakeRagdollOld) then
		ply.FakeRagdollOld:Remove()
	end

	ply.FakeRagdollOld = nil
	ply.OldRagdoll = nil

	if timer.Exists("faking_up"..ply:EntIndex()) then
		timer.Remove("faking_up"..ply:EntIndex(), 0)
	end

	//if ragdoll:GetVelocity():LengthSqr() < (200 * 200) or ply:InVehicle() then hg.SetFreemove(ply,not no_freemove) end

	hg.ragdollFake[ply] = ragdoll
	ply.ActiveWeapon = ply:GetActiveWeapon()
	hook_Run("ZC_OnFakeRagdollCreated", ply, ragdoll, listArmor)

	--timer.Simple(0,function()
	ply:DrawWorldModel(false)
	ply:DrawShadow(false)
	local pos = ply:GetPos()
	//ply:Spectate(OBS_MODE_FREEZECAM)
	//ply:UnSpectate()
	--ply:SetSolidFlags(bit.bor(ply:GetSolidFlags(), FSOLID_NOT_SOLID, FSOLID_TRIGGER, FSOLID_USE_TRIGGER_BOUNDS))
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	ply:SetPos(pos)
	ply:SetNoDraw(false)
	ply:SetRenderMode(RENDERMODE_NONE)
	//ply:ExitVehicle()
	--end)

	timer.Simple(0, function() -- bandaid shitfix for now
		if not hg.IsFakeLifecycle(ply, FAKE_STATE_ACTIVE, fakeSeq) then return end
		ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	end)

	if ply:FlashlightIsOn() then ply:Flashlight(false) end
	ply.oldCanUseFlashlight = ply:CanUseFlashlight()
	ply:AllowFlashlight(false)
	if ply:IsOnFire() then
		timer.Simple(0.1,function()
			if not hg.IsFakeLifecycle(ply, FAKE_STATE_ACTIVE, fakeSeq) or not IsValid(ragdoll) then return end
			--ragdoll:Ignite(30 * ((ragdoll.shouldburn or 0) + 1),16)
			ply:Extinguish()
			--ragdoll.fires = ply.fires
			if ply.fires then
				for fire, pos in pairs(ply.fires) do
					fire:Remove()
					local fire = CreateVFire(ragdoll, ragdoll:GetPos(), vector_up, 50, ragdoll)
				end
			end
		end)
	end
end

local zc_ragdollcombat = ConVarExists("zc_ragdollcombat") and GetConVar("zc_ragdollcombat") or CreateConVar("zc_ragdollcombat", 0, FCVAR_REPLICATED, "Toggle ragdoll combat-like ragdoll mode (walking, running in ragdoll, etc.)", 0, 1)

function hg.SetFreemove(ply, set)
	if ply:InVehicle() or IsValid(ply.OldRagdoll) then return end
	if set then
		ply.lastFakeTime = zc_ragdollcombat:GetBool() and 9999 or 1
		ply.lastFake = CurTime() + ply.lastFakeTime
		//ply:SetNetVar("lastFake", ply.lastFake)
		ply:SetMoveType(MOVETYPE_WALK)
		local hull = Vector(5,5,5)
		ply:SetHull(-Vector(hull,hull,0),Vector(hull,hull,72))
		ply:SetHullDuck(-Vector(hull,hull,0),Vector(hull,hull,36))
		ply:SetViewOffset(Vector(0,0,64))
		ply:SetViewOffsetDucked(Vector(0,0,34))
	else
		ply.lastFake = 0
		ply.lastFakeTime = 0
		//ply:SetNetVar("lastFake",0)
		//if ply:GetMoveType() != (ply:InVehicle() and MOVETYPE_NOCLIP or MOVETYPE_NONE) then
			//ply:SetMoveType(ply:InVehicle() and MOVETYPE_NOCLIP or MOVETYPE_NONE)
		//end
		ply:SetMoveType(MOVETYPE_NOCLIP)
		local hull = Vector(1, 1, 1)
		local hull2 = Vector(1, 1, 0)
		ply:SetHull(-hull2, hull)
		ply:SetHullDuck(-hull2, hull)
		ply:SetViewOffset(vector_up)
		ply:SetViewOffsetDucked(vector_up)
	end
end

local CurTime = CurTime

hook.Add("PreCleanupMap","ZC_VehicleStats",function()
	for i, ply in player.Iterator() do
		hg.FakeUp(ply)
	end
end)

hook.Add("PlayerSpawn", "ZC_BlockOverrideSpawn", function() if OverrideSpawn then return false end end)
hook.Add("PlayerSpawn", "ZC_BlockOverrideSpawnFallback", function() if OverrideSpawn then return false end end)
hook.Add("ZC_PlayerSpawn", "ZC_BlockCustomOverrideSpawn", function() if OverrideSpawn then return false end end)
hook.Add("ZC_PlayerSpawn", "ZC_BlockCustomOverrideSpawnFallback", function() if OverrideSpawn then return false end end)

util.AddNetworkString("ZC_OverrideSpawn")
function hg.OverrideSpawn(ply)
	net.Start("ZC_OverrideSpawn")
	net.WriteEntity(ply)
	net.Broadcast()
end

local vecZero = Vector(0, 0, 0)
local tr = {
	filter = {}
}

hook.Add("ZC_ShouldRestorePlayerFromFake","ZC_UpdateSpeed",function(ply)
	if IsValid(ply.FakeRagdoll) then
		if ply.FakeRagdoll:GetVelocity():Length() > 200 then return false end
		if (ply.organism.stun - CurTime()) > 0 then return false end
		if (ply.organism.lightstun - CurTime()) > 0 then return false end
		if bit.band(ply.FakeRagdoll:GetFlags(),FL_DISSOLVING) == FL_DISSOLVING then return false end
	end
end)

hook.Add("ZC_PlayerSpawn", "ZC_RemoveRagdoll", function(ply)
	local ragdoll = ply:GetNWEntity("FakeRagdoll")

	if IsValid(ragdoll) then
		ragdoll:SetNWEntity("ply", NULL)
	end

	SetFakeLifecycle(ply, FAKE_STATE_NONE, NULL)
	ply:SetNWEntity("RagdollDeath", NULL)
end)

hook.Add("ZC_CanControlRagdoll","ZC_StunnedNoControl",function(ply,rag)
	if (ply.organism.stun - CurTime()) > 0 then return false end
end)

function hg.FakeUp(ply, forced, instant)
	local ragdoll = ply.FakeRagdoll

	if !IsValid(ragdoll) then return end

	if ragdoll.welds then
		if ply:InVehicle() then
			local veh = ply:GetVehicle()
			hg.leaveveh = true
			ply:ExitVehicle()
		end

		//ragdoll.removingwelds = true
		//for i, weld in pairs(ragdoll.welds) do
		//	if IsValid(weld) then weld:Remove() end
		//end
		//
		//ragdoll.welds = nil
		//ragdoll.removingwelds = nil
		//ragdoll:SetParent()

		--table.RemoveByValue(veh.rags, ragdoll)
	end

	if ply:InVehicle() then forced = true end
	//if ply:InVehicle() and ply:GetVehicle():WaterLevel() >= 3 then return end
	if not forced and (not IsValid(ply.FakeRagdoll) or not ply:Alive() or hook_Run("ZC_ShouldRestorePlayerFromFake", ply) ~= nil) then return false end
	ply.fakecd = CurTime() + 2

	if ply:InVehicle() then
		return
	end

	local ent = (IsValid(ragdoll) and ragdoll or ply)
	local posit = ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_Pelvis")):GetTranslation()
	local pos = hg.GetUpPos(ply, posit, 50, 50)

	if not pos and not forced then return end

	hook_Run("ZC_OnPlayerRestoredFromFake", ply, ragdoll)

	ply.FakeRagdollOld = ragdoll
	ply.OldRagdoll = ragdoll
	ply:SetNWEntity("FakeRagdollOld", ragdoll)
	local restoreSeq = SetFakeLifecycle(ply, FAKE_STATE_RESTORING, ragdoll)

	ply:ConCommand("+duck")
	timer.Simple(0.5,function()
		if IsValid(ply) then
			ply:ConCommand("-duck")
		end
	end)

	if IsValid(ragdoll) and ragdoll:IsOnFire() then
		timer.Simple(0.1,function()
			if not hg.IsFakeLifecycle(ply, FAKE_STATE_RESTORING, restoreSeq) then return end
			--ply.fires = ragdoll.fires
			--ply:Ignite(30 * ((ply.shouldburn or 0) + 1),16)
			if ragdoll.fires then
				for fire, pos in pairs(ragdoll.fires) do
					fire:Remove()
					local fire = CreateVFire(ply, ply:GetPos(), vector_up, 50, ply)
				end
			end
		end)--]]
	end

	if IsValid(ragdoll) and ragdoll.welds then
		for i, weld in pairs(ragdoll.welds) do
			if IsValid(weld) then weld:Remove() end
		end

		ragdoll.welds = nil
	end

	OverrideSpawn = true
	local hp, armor = ply:Health(), ply:Armor()
	local ang, wep = ply:EyeAngles(), ply:GetActiveWeapon()
	hg.OverrideSpawn(ply)
	//local pos = ply:GetPos()
	ply:Spawn()
	//ply:SetPos(pos)
	ply:SetRenderMode(RENDERMODE_NORMAL)
	ply.LastFakeUp = CurTime()
	ply:DrawWorldModel(true)
	ply:SetHealth(hp)
	ply:SetArmor(armor)
	ply:SetEyeAngles(ang)
	if IsValid(wep) then ply:SelectWeapon(wep:GetClass()) else ply:SelectWeapon("weapon_hands_sh") end

	if IsValid(ragdoll) and ragdoll.rope_attach then
		ply:PickupWeapon(ragdoll.rope_attach)
		ragdoll.rope_attach = nil
	end

	OverrideSpawn = nil

	if IsValid(ragdoll) then
		local restoreVelocity = GetRagdollMassVelocity(ragdoll)
		--hg.SetFreemove(ply, true)

		if pos then
			ply:SetPos(pos)
		end

		ply:SetVelocity(-ply:GetVelocity() + restoreVelocity)

		ragdoll.override = true

		if not instant then
			ply:SetRenderMode(RENDERMODE_NORMAL)
			--ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			--ply:SetSolidFlags(bit.bor(ply:GetSolidFlags(), FSOLID_NOT_SOLID, FSOLID_TRIGGER, FSOLID_USE_TRIGGER_BOUNDS))
			ply:DrawShadow(false)

			timer.Create("faking_up"..ply:EntIndex(), 1, 1, function()
				if not hg.IsFakeLifecycle(ply, FAKE_STATE_RESTORING, restoreSeq) then return end

				if IsValid(ragdoll) then
					local posit = ragdoll:GetBoneMatrix(ragdoll:LookupBone("ValveBiped.Bip01_Spine4")):GetTranslation()
					//pos = hg.GetUpPos(ply, posit, 50, 50) or oldpos
				end

				if IsValid(ragdoll) then
					ragdoll:Remove()
				end

				SetFakeLifecycle(ply, FAKE_STATE_NONE, NULL)

				ply:DrawShadow(true)
				ply:SetRenderMode(RENDERMODE_NORMAL)
				ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)

				--ply:SetSolidFlags(bit.band(ply:GetSolidFlags(), bit.bnot(FSOLID_NOT_SOLID), bit.bnot(FSOLID_TRIGGER), bit.bnot(FSOLID_USE_TRIGGER_BOUNDS)))
				ply:SetMoveType(MOVETYPE_WALK)

				if pos then
					--ply:SetPos(pos)
				end
			end)
		else
			ply:DrawShadow(true)
			ply:SetRenderMode(RENDERMODE_NORMAL)
			ply:SetCollisionGroup(ply.switchingseat and COLLISION_GROUP_IN_VEHICLE or COLLISION_GROUP_PLAYER)
			ply:SetMoveType(ply.switchingseat and MOVETYPE_NONE or MOVETYPE_WALK)

			--ply:SetSolidFlags(bit.band(ply:GetSolidFlags(), bit.bnot(FSOLID_NOT_SOLID), bit.bnot(FSOLID_TRIGGER), bit.bnot(FSOLID_USE_TRIGGER_BOUNDS)))
			SetFakeLifecycle(ply, FAKE_STATE_NONE, NULL)

			if IsValid(ragdoll) then
				ragdoll:Remove()
			end
		end
	end

	if IsValid(ragdoll) then ragdoll:SetNWEntity("ply", NULL) end
	if ply.oldCanUseFlashlight and not ply:CanUseFlashlight() then ply:AllowFlashlight(true) end
	--[[timer.Simple(time,function()
		if IsValid(ply) then
			ply:ConCommand("-duck")
		end
	end)--]]

	return true
end

function hg.GetCurrentCharacter(ply)
	if not IsValid(ply) then return false end
	local rag = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or IsValid(ply:GetNWEntity("FakeRagdoll",NULL)) and ply:GetNWEntity("FakeRagdoll",NULL)
	return (IsValid(rag) and rag) or ply
end

hook.Add("PlayerDisconnected", "ZC_ClearFakeRagdollOnDisconnect", function(ply) hg.ragdollFake[ply] = nil end)
hook.Add("PlayerFootstep", "ZC_CustomFootstep", function(ply) if IsValid(ply.FakeRagdoll) then return true end end)
function hg.RagdollOwner(ragdoll)
	if not IsValid(ragdoll) then return end
	local ply = ragdoll.ply
	return IsValid(ply) and ply.FakeRagdoll == ragdoll and ply
end

hook.Add("PlayerDisconnected", "ZC_CleanupDisconnectingFakeRagdoll", function(ply)
	if ply:Alive() then
		ply:Kill()
		local ragdoll = ply:GetNWEntity("RagdollDeath")
		if IsValid(ragdoll) then
			local newOrg = hg.organism.Add(ragdoll)
			table.Merge(newOrg,ply.organism)
			newOrg.alive = false
			newOrg.owner = ragdoll
			ragdoll:CallOnRemove("organism", hg.organism.Remove, ragdoll)
		end
		hg.organism.Clear(ply.organism)
	end
end)

function hg.RemoveDeadBodies(veh)
	local anydeadbodies = false

	if veh.rags then
		for _, ragdoll in pairs(veh.rags) do
			if ragdoll.organism and ragdoll.organism.isPly then continue end
			ragdoll.removingwelds = true
			if ragdoll.welds then
				for i, weld in pairs(ragdoll.welds) do
					if IsValid(weld) then weld:Remove() end
				end

				ragdoll.welds = nil
			end
			ragdoll.removingwelds = nil

			anydeadbodies = true
		end
	end

	return anydeadbodies
end

hook.Add("Glide_CanSwitchSeat", "ZC_SlowDownMotion", function(ply, seat)
	if ply.lastswitched and ply.lastswitched > CurTime() then return false end

	ply.lastswitched = CurTime() + 1.5
end)

hook.Add("CanPlayerEnterVehicle","ZC_FakeEnterVehicle",function(ply, veh)
	if hg.RemoveDeadBodies(veh) then return false end

	local parent = veh:GetParent()
	if IsValid(parent) and parent:GetVelocity():LengthSqr() > 256 * 256 and !ply.switchingseat then return false end

	return true//not IsValid(ply.FakeRagdoll)// or IsValid(ply.wasveh)
end)
local zc_no_fake_in_cars = CreateConVar("zc_no_fake_in_cars","0",FCVAR_ARCHIVE + FCVAR_REPLICATED, "disables fake in cars", 0, 1)
hook.Add("PlayerEnteredVehicle","ZC_AllowWeapons",function(ply,veh,role)
	if zc_no_fake_in_cars:GetBool() then return end
	ply:SetEyeAngles(angle_zero)
	//local veh2 = veh:GetParent()

	timer.Create("EnterVehicleRag"..ply:EntIndex(), (veh:GetVehicleClass() == "Pod") and 0.5 or 1, 1, function()
		if not IsValid(ply) or not IsValid(veh) or not ply:Alive() or not ply:InVehicle() or ply:GetVehicle() ~= veh then return end
		if hg.GetFakeState(ply) ~= FAKE_STATE_NONE then return end

		ply:SetEyeAngles(angle_zero)
		hg.Fake(ply, nil, nil, true)

		ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		--ply:SetSolidFlags(bit.band(ply:GetSolidFlags(), bit.bnot(FSOLID_NOT_SOLID), bit.bnot(FSOLID_TRIGGER), bit.bnot(FSOLID_USE_TRIGGER_BOUNDS)))
	end)

	if (role != 0) or (veh:GetClass() == "prop_vehicle_prisoner_pod") then
		ply:SetAllowWeaponsInVehicle(true)
	else
		ply:SetAllowWeaponsInVehicle(true)
	end
end)

hook.Add("ZC_OnPlayerWakeFromUnconscious", "ZC_EnterVehicle", function(ply)
	//if Glide and IsValid(ply.glideveh) then
	//	Glide.ActivateInput(ply, ply.glideveh, ply.seat)
	//
	//end
	//if IsValid(ply.wasveh) then
	//	ply:EnterVehicle(ply.wasveh)
	//	ply.wasveh = nil
	//end
end)

hook.Add("ZC_OnPlayerUnconscious", "ZC_LeaveVehicle", function(ply)
	if ply:InVehicle() then
		local veh = ply:GetVehicle()

		//if Glide and veh.IsGlideVehicle then
		//	Glide.DeactivateInput(ply)
		//	ply.glideveh = veh
		//	ply.seat = ply:GlideGetSeatIndex()
		//end
		//ply.wasveh = veh
		//hg.leaveveh = true
		//ply:ExitVehicle()
	end
end)

hook.Add("PlayerLeaveVehicle","ZC_AllowWeapons",function(ply,veh)
	ply:SetAllowWeaponsInVehicle(false)

	if timer.Exists("EnterVehicleRag"..ply:EntIndex()) then
		timer.Remove("EnterVehicleRag"..ply:EntIndex())
	end

	//if !hg.fallfromveh then
	//	hg.FakeUp(ply, true)
	//end
	local ragdoll = ply.FakeRagdoll
	local fast = IsValid(ragdoll) and ragdoll:GetVelocity():Length() > 200

	if (!fast or ply.switchingseat) and ply:Alive() then
		hg.FakeUp(ply, true, ply.switchingseat)
	else
		if ragdoll then
			ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
			--ply:SetSolidFlags(bit.bor(ply:GetSolidFlags(), FSOLID_NOT_SOLID, FSOLID_TRIGGER, FSOLID_USE_TRIGGER_BOUNDS))
			ragdoll.removingwelds = true

			if ragdoll.welds then
				for i, weld in pairs(ragdoll.welds) do
					if IsValid(weld) then weld:Remove() end
				end
			end

			ragdoll.welds = nil
			ragdoll.removingwelds = nil
			ragdoll:SetParent()

			if fast then
				ragdoll:GetPhysicsObject():ApplyForceCenter(ragdoll:GetVelocity():GetNormalized() * 10000)
				ragdoll:GetPhysicsObject():ApplyForceCenter(vector_up * 10000)

				veh:EmitSound("zbattle/glass_shatter.ogg")
			end
		else
			ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			--ply:SetSolidFlags(bit.band(ply:GetSolidFlags(), bit.bnot(FSOLID_NOT_SOLID), bit.bnot(FSOLID_TRIGGER), bit.bnot(FSOLID_USE_TRIGGER_BOUNDS)))
		end
	end

	hg.fallfromveh = nil
end)

/*
local PLAYER = FindMetaTable("Player")

hg.ExitVehicle = hg.ExitVehicle or PLAYER.ExitVehicle

function PLAYER:ExitVehicle()
	//if hg.leaveveh then hg.ExitVehicle(self) hg.leaveveh = nil end
	hg.ExitVehicle(self)
end
*/

hook.Add("ZC_CanExitVehicle","ZC_UpdateWeaponThink",function(ply, veh)
	//return false
end)

local poses = {}

function hg.GetUpPos(target,pos,tries,starttries)
	if not IsValid(target) then return pos end

	local hull = 10
	local mins,maxs = -Vector(hull,hull,0),Vector(hull,hull,36)

	if tries <= 0 then
		table.sort(poses,function(a,b) return a[2] < b[2] end)

		local vec = (#poses > 0 and Vector(poses[1][1],poses[1][2],poses[1][3])) or target:GetPos() -- or pos - vector_up * 72

		poses = {}

		if vec then
			local t = {}
			t.start = vec
			t.endpos = vec - vector_up * 128
			t.mins = mins
			t.maxs = maxs
			t.filter = {target,target.FakeRagdoll,target.ply}
			--t.mask = MASK_PLAYERSOLID
			t.collisiongroup = COLLISION_GROUP_PLAYER
			local tr = util.TraceHull( t )

			return tr.HitPos
		end

		return vec
	end
	tries = tries - 1


	local offset = tries == starttries and vector_origin or VectorRand(-32,32)
	local newpos = pos + offset

	local t = {}
	t.start = pos
	t.endpos = newpos
	t.filter = {target,target.FakeRagdoll,target.ply}
	--t.mask = MASK_PLAYERSOLID
	t.collisiongroup = COLLISION_GROUP_PLAYER

	local tr = util.TraceLine( t )

	if not tr.Hit then
		local t = {}
		t.start = newpos
		t.endpos = newpos
		t.mins = mins
		t.maxs = maxs
		t.filter = {target,target.FakeRagdoll,target.ply}
		--t.mask = MASK_PLAYERSOLID
		t.collisiongroup = COLLISION_GROUP_PLAYER
		local tr = util.TraceHull( t )

		if not tr.Hit then
			table.insert(poses,{newpos,(tr.HitPos - pos):LengthSqr()})
		end
	end

	return hg.GetUpPos(target,pos,tries,starttries)
end
/*
local ent = Entity(1)
local ragdoll = ents.Create("prop_ragdoll")
ragdoll.Appearance = ent.Appearance
ragdoll:SetModel(ent:GetModel())
ragdoll:SetPos(ent:GetPos())
ragdoll:Spawn()
ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
ent:SetRenderMode(RENDERMODE_NONE)
ent:SetNWEntity("huy",ragdoll)
ApplyAppearanceRagdoll(ent,ragdoll)
hook.Add("Think","ZC_DebugRagdollBoneSync",function()
	local ragbonecount = ragdoll:GetBoneCount()
	for i = 0, ragbonecount - 1 do
		local bonename = ragdoll:GetBoneName(i)
		local boneent = ent:LookupBone(bonename)
		--[[ for _,name in ipairs(boneDamage) do
			if name==bonename and gotdamaged==true then return end
		end]]
		if boneent then
			local bonepos,boneang = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))
			if bonepos and boneang then
				local bonerag = ragdoll:LookupBone(bonename)
				if bonerag then
					if bonerag == 0 then bonepos = ent:GetPos() end
					local physobj = ragdoll:GetPhysicsObjectNum(bonerag)
					if IsValid(physobj) then
						local p = {}
						p.secondstoarrive = 0.01
						p.pos = bonepos
						p.angle = boneang
						p.maxangular = 650
						p.maxangulardamp = 500
						p.maxspeed = 45
						p.maxspeeddamp = 35
						p.teleportdistance = 0

						physobj:Wake()
						physobj:ComputeShadowControl(p)
					end
				end
			end
		end
	end
end)
*/
--[[local ents_FindInSphere = ents.FindInSphere
local sphereRadius = 25
hook.Add("Move","ZC_PushAwayRagdolls",function(ply, mv)
	do return end
	if not ply:Alive() or not hg.GetCurrentCharacter(ply):IsPlayer() then return end
    local sphereCenter = ply:GetPos()
    local entities = ents_FindInSphere(sphereCenter, sphereRadius)

    for _, ent in ipairs(entities) do
		if ent:GetCollisionGroup() == COLLISION_GROUP_WEAPON then
			for i = 0, ent:GetPhysicsObjectCount() - 1 do
				local physObj = ent:GetPhysicsObjectNum(i)
				local limbPos = physObj:GetPos()

				local pushDir = (limbPos - sphereCenter):GetNormalized()
				if limbPos:Distance(sphereCenter) < sphereRadius then
					physObj:ApplyForceCenter(pushDir * math.min(ply:GetVelocity():Length()/3,200) *  (physObj:GetMass()/5))
				end
				--ply:SetVelocity(-pushDir * 2)
			end
		end

		if not ent:IsRagdoll() then continue end
		ent.pushCooldown = ent.pushCooldown or 0
		if ent.pushCooldown < CurTime() then
			if ply:GetVelocity():Length() > 200 then
				--print(ply:EyeAngles()[1])
				if math.random(1,ply:EyeAngles()[1] < 20 and 3 or 10) == 2 then
					hg.LightStunPlayer(ply,2)
				else
					--ply:SetVelocity(-ply:GetVelocity())
					ply:SetVelocity(-ply:GetVelocity()*0.5)
				end
			end
		end
		ent.pushCooldown = CurTime() + 0.5
    end
end)]]

local mRandom = math.random
hook.Add("ZC_OnRagdollCollide", "ZC_FallSounds", function(rag, data)
	if not IsValid(rag) then return end
	if not data.HitEntity:IsWorld() then return end
	if data.OurOldVelocity:LengthSqr() < 165000 or (rag.NextSND or 0) > data.DeltaTime then return end
	rag:EmitSound("player/falling_foley/fall_foley"..mRandom(13)..".wav", 60, mRandom(95, 115), 1, CHAN_AUTO)
	if mRandom(3) == 2 then
		rag:EmitSound("physics/flesh/flesh_impact_hard"..mRandom(6)..".wav", 55, mRandom(85, 105), 1, CHAN_AUTO)
	end

	--[[local ply = rag:GetNWEntity("ply")
	if IsValid(ply) and ply:Alive() and not ply.organism.unconscious then
		local mul = math.Clamp(data.OurOldVelocity:LengthSqr() / 240000, 0.25, 1.2)
		ply:ViewPunch(AngleRand(-20 * mul, 20 * mul))
	end]]

	rag.NextSND = data.DeltaTime + 1
end)

local zc_shitty_fake = CreateConVar("zc_shitty_fake", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "enable shitty fake", 0, 1)
SetGlobalBool("zc_shitty_fake", zc_shitty_fake:GetBool())
cvars.AddChangeCallback("zc_shitty_fake", function(convar_name, value_old, value_new)
	SetGlobalBool("zc_shitty_fake", zc_shitty_fake:GetBool())
end)
