concommand.Add("fake", function(ply)
	if not ply:Alive() then return end
	if ply.fakecd and ply.fakecd > CurTime() then return end
	if ply:IsFlagSet( FL_FROZEN ) then return end
	--ply.fakecd = CurTime() + cooldown
	if not IsValid(ply.FakeRagdoll) then
		hg.Fake(ply)
	else
		hg.FakeUp(ply)
	end
end)

hook.Add("PlayerInitialSpawn", "ZC_PlayerCollideCallback", function(ply) ply:AddCallback("PhysicsCollide", function(phys, data) hook.Run("ZC_PlayerCollide", ply, data.HitEntity, data) end) end)
hook.Add("ZC_PlayerCollide", "ZC_HandleFakeRagdollPropCollision", function(ply, ent, data)
	if (not ent:IsPlayerHolding()) and data.Speed > math.max(700 - ent:GetPhysicsObject():GetMass(), 200) and ent:GetPhysicsObject():GetMass() > 20 and ent:GetClass() ~= "prop_ragdoll" and ent:GetPhysicsObject():GetVelocity():Length() > 50 then		--[[local d = DamageInfo()
		d:SetDamageType(DMG_CRUSH)
		d:SetAttacker(data.HitEntity)
		d:SetDamage(data.Speed / 40)
		ply:TakeDamageInfo(d)]]
		--
		timer.Simple(0,function()
			hg.LightStunPlayer(ply, 2)
		end)
	end
end)

-- LightStunPlayer may create a ragdoll, so defer it out of hit-ground contact handling.
local function LightStunPlayerNextTick(ply, time)
	timer.Simple(0, function()
		if IsValid(ply) and ply:IsPlayer() then
			hg.LightStunPlayer(ply, time)
		end
	end)
end

hook.Add("OnPlayerHitGround","ZC_FallStun",function(ply,inwater,onfloater,speed)
	if IsValid(ply.FakeRagdoll) then return true end
	local tr = {}
	tr.start = ply:GetPos()
	tr.endpos = ply:GetPos() - vector_up * 2
	tr.filter = ply
	local bottom, top = ply:GetHull()
	bottom[3] = bottom[3] - 5
	tr.mins = bottom
	tr.maxs = top

	tr = util.TraceHull(tr)

	if ply:IsBerserk() then
		return
	end

	if ply.GetPlayerClass and ply:GetPlayerClass() and ply:GetPlayerClass().FallDmgFunc then
		ply:PlayerClassEvent("FallDmgFunc", speed, tr)

		return
	end

	local hitPlayer = tr.Entity
	if speed > 250 and IsValid(hitPlayer) and hitPlayer:IsPlayer() then
		hg.drop(hitPlayer)
		LightStunPlayerNextTick(hitPlayer,2)
		--tr.Entity:TakeDamage(speed / 5,ply,ply)
	end

	if speed > 600 then
		LightStunPlayerNextTick(ply,2)
	end
end)

concommand.Add("force_fake", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	ply = Player(tonumber(args[1]))
	if not IsValid(ply.FakeRagdoll) then
		hg.Fake(ply)
	else
		hg.FakeUp(ply)
	end
end)
