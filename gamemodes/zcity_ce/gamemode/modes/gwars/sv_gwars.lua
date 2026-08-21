local MODE = MODE

function MODE:CanLaunch()
	return true
	--[[local points = zc.GetMapPoints( "HMCD_TDM_T" )
	local points2 = zc.GetMapPoints( "HMCD_TDM_CT" )
    return (#points > 0) and (#points2 > 0)--]]
end
function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true--returning true so guilt bans
end

util.AddNetworkString("ZC_GangWarsStart")
-- Old Intermission() + GiveEquipment().
function MODE:Prepare(round)
	game.CleanUpMap()

	self.CTPoints = {}
	table.CopyFromTo(zc.GetMapPoints( "HMCD_TDM_CT" ),self.CTPoints)
	self.TPoints = {}
	table.CopyFromTo(zc.GetMapPoints( "HMCD_TDM_T" ),self.TPoints)

	for _, ply in player.Iterator() do
		ply:SetupTeam(ply:Team())
	end

	net.Start("ZC_GangWarsStart")
	net.Broadcast()

	self:GiveEquipment()
end

function MODE:CheckAlivePlayers()
	return zc:CheckAliveTeams(true)
end

-- Returns nil to continue or a result table to end the round.
function MODE:CheckEnd(round)
	local endround, _ = zc:CheckWinner(self:CheckAlivePlayers())

	if endround then
		return { reason = "team_wiped" }
	end
end

function MODE:BoringRoundFunction()
	timer.Simple(2, function()
		//PrintMessage(HUD_PRINTTALK, "IT IS A GANG SHOOTOUT FFS...")
	end)
end

local swatSpawned = false

function MODE:Start(round)
    swatSpawned = false
end

local tblweps = {
	[0] = {
		"weapon_cz75",
		"weapon_deagle",
		"weapon_glock17",
		"weapon_glock18c",
		"weapon_revolver2",
		"weapon_hk_usp",
		"weapon_p22",
		"weapon_doublebarrel_short",
		"weapon_skorpion",
		//"weapon_uzi",
		"weapon_mac11",
		//"weapon_draco",
		//"weapon_ar_pistol",
	},
	[1] = {
		"weapon_cz75",
		"weapon_deagle",
		"weapon_glock17",
		"weapon_glock18c",
		"weapon_revolver2",
		"weapon_hk_usp",
		"weapon_p22",
		"weapon_doublebarrel_short",
		"weapon_skorpion",
		//"weapon_uzi",
		"weapon_mac11",
		//"weapon_draco",
		//"weapon_ar_pistol",
	}
}


--[[local tblatts = {
	[0] = {
		{"optic4"},
	},
	[1] = {
		{"holo14","laser2","grip3"}
	}
}]]


function MODE:GetPlySpawn(ply)
end

function MODE:GiveEquipment()
	self.CTPoints = {}
	table.CopyFromTo(zc.GetMapPoints( "HMCD_TDM_CT" ),self.CTPoints)
	self.TPoints = {}
	table.CopyFromTo(zc.GetMapPoints( "HMCD_TDM_T" ),self.TPoints)
	timer.Simple(0.1,function()

		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end
			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			if ply:Team() == 0 then
				ply:SetPlayerClass("bloodz")
				zc.GiveRole(ply, "Bloodz", Color(190,0,0))
			else
				ply:SetPlayerClass("groove")
				zc.GiveRole(ply, "Groove", Color(0,190,0))
			end

			local tbl = tblweps[ply:Team()]
			local wep = ply:Give(tbl[math.random(#tbl)])
			ply:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType())

			if wep.SetDeagleSkin then
				//wep:SetDeagleSkin(4)
				//wep:SetDeagleBodygroup(1)
			end

			ply:Give("weapon_bandage_sh")
			ply:Give("weapon_tourniquet")
			ply:Give("weapon_fentanyl")

			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")

			timer.Simple(0.1,function()
				ply.noSound = false
			end)

			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:Think(round)
    if not swatSpawned and (CurTime() - zc.ROUND_BEGIN) >= 120 then
        local deadPlayers = {}

        for _, ply in player.Iterator() do
            if not ply:Alive() and ply:Team() != TEAM_SPECTATOR then
                table.insert(deadPlayers, ply)
            end
        end

		local startpos = self.TPoints and #self.TPoints > 0 and self.TPoints[1].pos or zc:GetRandomSpawn()

		for i = 1, math.min(4, #deadPlayers) do
            local ply = deadPlayers[i]

            //if self.TPoints and #self.TPoints > 0 then
                ply:Spawn()
				ply:SetTeam(2)
				if !startpos then
					startpos = ply:GetPos()
				else
					zc.tpPlayer(startpos, ply, i, 0)
				end

                ply:SetPlayerClass("swat")
				zc.GiveRole(ply, "SWAT", Color(0,0,122))
				local gun = ply:Give("weapon_ar15")
                ply:GiveAmmo(gun:GetMaxClip1() * 3, gun:GetPrimaryAmmoType(), true)
                ply:Give("weapon_medkit_sh")
                ply:Give("weapon_tourniquet")
                ply:Give("weapon_walkie_talkie")
                ply:Give("weapon_hg_flashbang_tpik")
                zc.AddArmor(ply, "ent_armor_helmet1")
                zc.AddArmor(ply, "ent_armor_vest4")

                ply:Give("weapon_hands_sh")
                ply:SelectWeapon("weapon_hands_sh")
            //end
        end

        swatSpawned = true
    end
end

function MODE:GetTeamSpawn()
	return zc.TranslatePointsToVectors(zc.GetMapPoints( "HMCD_TDM_T" )), zc.TranslatePointsToVectors(zc.GetMapPoints( "HMCD_TDM_CT" ))
end

function MODE:CanSpawn()
end

util.AddNetworkString("ZC_GangWarsRoundEnd")
-- Old EndRound().
function MODE:Finish(round, result)
	timer.Simple(2,function()
		net.Start("ZC_GangWarsRoundEnd")
		net.Broadcast()
	end)

	local _, winner = zc:CheckWinner(self:CheckAlivePlayers())
	for _, ply in player.Iterator() do
		if ply:Team() == winner then
			ply:GiveExp(math.random(15,30))
			ply:GiveSkill(math.Rand(0.1,0.15))
			--print("give",ply)
		else
			--print("take",ply)
			ply:GiveSkill(-math.Rand(0.05,0.1))
		end
	end
end
