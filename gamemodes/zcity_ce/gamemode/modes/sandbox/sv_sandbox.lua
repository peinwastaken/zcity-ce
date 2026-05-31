local MODE = MODE

local sandboxWeapons = {
	"weapon_physgun",
	"gmod_tool",
	"weapon_physcannon",
	"weapon_hands_sh"
}

function MODE:CanLaunch()
	return true
end

function MODE:CanSpawn()
	return true
end

function MODE:ShouldRoundEnd()
end

function MODE:Intermission()
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		ply:SetupTeam(ply:Team())
	end
end

function MODE:RoundStart()
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		if not ply:Alive() then ply:Spawn() end

		ply:SetMoveType(MOVETYPE_WALK)
		ply:Freeze(false)
	end
end

function MODE:GivePlayerEquipment(ply)
	if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR or not ply:Alive() then return end

	ply:SetSuppressPickupNotices(true)

	for _, class in ipairs(sandboxWeapons) do
		if not IsValid(ply:GetWeapon(class)) then
			ply:Give(class)
		end
	end

	ply:SelectWeapon("weapon_physgun")
	ply:SetSuppressPickupNotices(false)
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		local currentMode = CurrentRound and CurrentRound()
		if not currentMode or currentMode.name ~= MODE.name then return end

		for _, ply in player.Iterator() do
			self:GivePlayerEquipment(ply)
		end
	end)
end

function MODE:EndRound()
end

function MODE:GetTeamSpawn()
	// do nuffin
end
