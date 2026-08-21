local MODE = MODE

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true--returning true so guilt bans
end

function MODE:CanLaunch()
	return true
	--[[local points = zc.GetMapPoints( "HMCD_TDM_T" )
	local points2 = zc.GetMapPoints( "HMCD_TDM_CT" )
    return (#points > 0) and (#points2 > 0)]] -- can work without them
end

MODE.ForBigMaps = true

util.AddNetworkString("ZC_TeamDeathmatchStart")
-- Old Intermission() + GiveEquipment().
function MODE:Prepare(round)
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		ply:SetupTeam(ply:Team())

		ply:SetNWInt( "TDM_Money", self.StartMoney )
	end

	net.Start("ZC_TeamDeathmatchStart")
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

function MODE:Start(round)
	for _,ply in player.Iterator() do
		ply:Freeze(false)
	end
end

local tblweps = {
	[0] = {
		"weapon_akm",
	},
	[1] = {
		"weapon_m4a1",
	},
}



-- local giveweapons = CreateConVar("zc_tdm_giveweapon","1",FCVAR_LUA_SERVER,"TDMSPAWNS",0,1)

function MODE:GetPlySpawn(ply)
end

function MODE:GiveEquipment()
	timer.Simple(0.1,function()
		math.random(#tblweps[0])

		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end

			local inv = ply:GetNetVar("Inventory")
			inv["Weapons"]["hg_sling"] = true
			ply:SetNetVar("Inventory",inv)

			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			if ply:Team() == 1 then
				ply:SetPlayerClass("swat")
				zc.GiveRole(ply, "Counter Terrorist", Color(0,0,190))
			else
				ply:SetPlayerClass("terrorist")
				zc.GiveRole(ply, "Terrorist", Color(190,0,0))
			end

			--[[if giveweapons:GetBool() then
				local gun = ply:Give(tblweps[ply:Team()][mrand])
				ply:GiveAmmo(gun:GetMaxClip1() * 3,gun:GetPrimaryAmmoType(),true)

				zc.AddAttachmentForce(ply,gun,tblatts[ply:Team()][mrand])
				zc.AddArmor(ply, tblarmors[ply:Team()][mrand])


				ply:Give("weapon_hg_rgd_tpik")
				ply:Give("weapon_walkie_talkie")
				ply:Give("weapon_bandage_sh")
				ply:Give("weapon_tourniquet")
			end--]]

			//ply:Give("weapon_melee")

			ply:Give("weapon_melee")
			ply:Give("weapon_bandage_sh")
			ply:Give("weapon_tourniquet")
			ply.organism.allowholster = true

			local Radio = ply:Give("weapon_walkie_talkie")
			Radio.Frequency = (ply:Team() == 1 and math.Round(math.Rand(88,95),1)) or math.Round(math.Rand(100,108),1)
			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")

			timer.Simple(0.1,function()
				ply.noSound = false
			end)

			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:GetTeamSpawn()
	return zc.TranslatePointsToVectors(zc.GetMapPoints( "HMCD_TDM_T" )), zc.TranslatePointsToVectors(zc.GetMapPoints( "HMCD_TDM_CT" ))
end

function MODE:CanSpawn()
end

util.AddNetworkString("ZC_TeamDeathmatchRoundEnd")
-- Old EndRound().
function MODE:Finish(round, result)
	timer.Simple(2,function()
		net.Start("ZC_TeamDeathmatchRoundEnd")
		net.Broadcast()
	end)
	local _, winner = zc:CheckWinner(self:CheckAlivePlayers())
	for _,ply in player.Iterator() do
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

util.AddNetworkString( "ZC_TeamDeathmatchOpenBuyMenu" )
MODE.Hooks = MODE.Hooks or {}

MODE.Hooks.ShowSpare1 = function(self, round, ply) -- OpenMenu
	if not ply:Alive() then return end
	net.Start( "ZC_TeamDeathmatchOpenBuyMenu" )
	net.Send( ply )
end
util.AddNetworkString( "ZC_TeamDeathmatchBuyItem" )

local AttachmentPrice = 50
net.Receive("ZC_TeamDeathmatchBuyItem",function(len,ply)
	if !CurrentRound().buymenu then return end
	if ((zc.ROUND_START or 0) + 40 < CurTime()) then ply:ChatPrint(zc.locale.GetLocalized("tdm/time_up")) return end
	local tItem = net.ReadTable()
	if not istable(tItem) then return end
	local category = tItem[1]
	local index = tItem[2]
	if not category or not index then return end
	local buyItems = CurrentRound().BuyItems
	if not buyItems or not buyItems[category] or not buyItems[category][index] then return end
	local item = buyItems[category][index]

	if not item then return end

	if tItem[3] then
		if not ply:HasWeapon(item.ItemClass) then ply:ChatPrint(zc.locale.GetLocalized("tdm/cant_buy_attachment_without_weapon")) return end
		if ((ply:GetNWInt("TDM_Money",0) - AttachmentPrice) < 0) then ply:ChatPrint(zc.locale.GetLocalized("tdm/not_enough_money")) return end

		local wep = ply:GetWeapon(item.ItemClass)
		zc.AddAttachmentForce( ply,wep,tItem[3] )
		ply:SetNWInt( "TDM_Money", ply:GetNWInt("TDM_Money",0) - AttachmentPrice )
		ply:EmitSound("items/itempickup.wav")

		return
	end

	if ((ply:GetNWInt("TDM_Money",0) - item.Price) < 0) then ply:ChatPrint(zc.locale.GetLocalized("tdm/not_enough_money")) return end
	local ent = ply:Give(item.ItemClass)

	if ent.Use and IsValid(ent) then
		ent:Use( ply )
	end

	if IsValid(ent) and ent:GetClass() == "weapon_bloodbag" then
		ent.bloodtype = "o-"
		ent.modeValues[1] = 1
	end

	if item.Amount then
		ent.AmmoCount = item.Amount
	end

	if ent.GetPrimaryAmmoType then
		ply:GiveAmmo(ent:GetMaxClip1() * 1,ent:GetPrimaryAmmoType(),true)
	end

	ply:SetNWInt( "TDM_Money", ply:GetNWInt("TDM_Money",0) - item.Price )
	ply:EmitSound("items/itempickup.wav")
end)
