zc.organism = zc.organism or {}
--local Organism = zc.organism
zc.organism.list = zc.organism.list or {}
local hook_Run = hook.Run
function zc.organism.Add(ent)
	ent.organism = {
		owner = ent
	}

	local org = ent.organism
	org.owner = ent
	zc.organism.list[ent] = org
	return org
end

function zc.organism.Clear(org)
	hook_Run("ZC_OrganismClear", org)//.owner.organism_internal)
	if IsValid(org.owner) then org.owner.fullsend = true end
	zc.send_organism(org)
end

function zc.organism.Remove(ent)
	local org = zc.organism.list[ent]
	if org then org.owner = nil end
	zc.organism.list[ent] = nil
end

hook.Add("PlayerInitialSpawn", "ZC_AddOrganismOnInitialSpawn", function(ply) zc.organism.Add(ply) end)
hook.Add("ZC_PlayerSpawn", "ZC_ClearOrganismOnPlayerSpawn", function(ply) zc.organism.Clear(ply.organism) end)
hook.Add("PlayerDisconnected", "ZC_RemoveOrganismOnDisconnect", function(ply) zc.organism.Remove(ply) end)
hook.Add("PostPlayerDeath", "ZC_MoveOrganismToDeathRagdoll", function(ply)
	local ragdoll = ply:GetNWEntity("RagdollDeath")
	
	if not IsValid(ragdoll) then ragdoll = ply.FakeRagdoll end

	if IsValid(ragdoll) then
		local newOrg = zc.organism.Add(ragdoll)
		table.Merge(newOrg, ply.organism)

		hook.Run("ZC_OnRagdollDeath", ply, ragdoll)

		table.Merge(zc.net.list[ragdoll], zc.net.list[ply])

		newOrg.alive = false
		newOrg.owner = ragdoll
		ragdoll:CallOnRemove("organism", zc.organism.Remove, ragdoll)
		newOrg.owner.fullsend = true
		zc.send_bareinfo(newOrg)
	end

	zc.organism.Clear(ply.organism)

	hook.Run("ZC_AfterPostPlayerDeath", ply, ragdoll)
end)

local tickrate = 1 / 10
local delay = 0
local time, mulTime, start
local CurTime = CurTime
local SysTime = SysTime
hook.Add("Think", "ZC_UpdateOrganismThinkLoop", function()
	time = CurTime()
	local tickrate2 = tickrate// / math.max(game.GetTimeScale(), 0.01)
	//print(delay ,time + tickrate)
	if delay + tickrate2 > time then return end

	delay = time

	if not start then
		start = SysTime()
		return
	end
	
	mulTime = (SysTime() - start) * game.GetTimeScale()

	start = SysTime()
	for owner, org in pairs(zc.organism.list) do -- now it is clear why corpses cause lag...
		if not IsValid(owner) then
			zc.organism.list[owner] = nil
			continue
		end

		if org.godmode then continue end
		hook_Run("ZC_OrganismThink", owner, org, mulTime)
	end
end)

local lastcall = SysTime()
hook.Add("ZC_OrganismThinkCall", "ZC_RunOrganismThink", function(owner, org)
	if not IsValid(owner) then
		if owner ~= nil then zc.organism.list[owner] = nil end
		return
	end
	if not org then return end

	if (SysTime() - lastcall) < tickrate then return end
	lastcall = SysTime()
	hook_Run("ZC_OrganismThink", owner, org, 0.00001)
end)


hook.Add("ZC_OnFakeRagdollCreated", "ZC_Organism", function(ply, ragdoll)
	ragdoll.organism = ply.organism
	--zc.net.list[ragdoll] = zc.net.list[ply]
end)
