MODE.name = "hl2dm"
MODE.PrintName = "Half-Life 2 Deathmatch"

MODE.Chance = 0.05

MODE.LootSpawn = false

MODE.ForBigMaps = true

function MODE:ClearPlayerRoles() -- Thanks to Deka!!
    for _, ply in player.Iterator() do
        ply:SetNWString("PlayerRole", "")
    end
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
	return 1, true--returning true so guilt bans
end

util.AddNetworkString("ZC_HL2DeathmatchStart")
function MODE:Intermission()
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		ply:SetupTeam(ply:Team())
	end

	net.Start("ZC_HL2DeathmatchStart")
	net.Broadcast()
end

function MODE:CheckAlivePlayers()
	return zb:CheckAliveTeams(true)
end

function MODE:ShouldRoundEnd()
	local endround, _ = zb:CheckWinner(self:CheckAlivePlayers())
	--print("ShouldRoundEnd", endround, winner)
	return endround
end

function MODE:RoundStart()
end

function MODE:GetPlySpawn(ply)
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		local elites = 1
		local medics = 1
		local grenadiers = 1
		local shotgunners = 1
		local snipersC = 1
		local snipersR = 1

		local players_alive = zb:CheckPlaying()
		local leader = false
		for _, ply in RandomPairs(players_alive) do
			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			local hands = ply:Give("weapon_hands_sh")
			ply:SelectWeapon(hands)

			if ply:Team() == 1 then
				if elites > 0 and not ply.subClass then
					elites = elites - 1
					ply.subClass = "elite"
					if not leader then
						ply.leader = true
						ply:SetNWString("PlayerRole", "Elite")
						leader = true
					end
				end

				if shotgunners > 0 and not ply.subClass then
					shotgunners = shotgunners - 1
					ply.subClass = "shotgunner"
					ply:SetNWString("PlayerRole", "Shotgunner")
				end

				if snipersC > 0 and (#players_alive > 6) and not ply.subClass then
					snipersC = snipersC - 1
					ply.subClass = "sniper"
					local points = zb.GetMapPoints( "HL2DM_SNIPERSPAWN" )
					if #points > 0 then
						ply:SetPos(points[math.random(#points)].pos)
					end
				end
			else
				if medics > 0 and not ply.subClass then
					medics = medics - 1
					ply.subClass = "medic"
				end

				if grenadiers > 0 and (#players_alive > 6) and not ply.subClass then
					grenadiers = grenadiers - 1
					ply.subClass = "grenadier"
				end

				if snipersR > 0 and (#players_alive > 6) and not ply.subClass then
					snipersR = snipersR - 1
					ply.subClass = "sniper"
					local points = zb.GetMapPoints( "HL2DM_CROSSBOWSPAWN" )
					if #points > 0 then
						ply:SetPos(points[math.random(#points)].pos)
					end
				end
			end

			local inv = ply:GetNetVar("Inventory",{})
			inv["Weapons"]["hg_sling"] = true
			ply:SetNetVar("Inventory",inv)

			ply:SetPlayerClass(ply:Team() == 1 and "Combine" or "Rebel")

			timer.Simple(0.1,function()
				ply.noSound = false
			end)

			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:RoundThink()
end

function MODE:GetTeamSpawn()
	return zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_T" )), zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_CT" ))
end

function MODE:CanSpawn()
end

util.AddNetworkString("ZC_HL2DeathmatchRoundEnd")
function MODE:EndRound()
	self:ClearPlayerRoles()
	timer.Simple(2,function()
		net.Start("ZC_HL2DeathmatchRoundEnd")
		net.Broadcast()
	end)
end

function MODE:PlayerDeath(ply)
end

function MODE:CanLaunch()
	return true
    --[[local TPoints = zb.GetMapPoints("HMCD_TDM_T")
    local CTPoints = zb.GetMapPoints("HMCD_TDM_CT")
    if TPoints and #TPoints > 0 and CTPoints and #CTPoints > 0 then
        return true
    end
    return false]]
end

util.AddNetworkString("ZC_AirStrikeRequest")

local ACD_NextAirstrikeTime = 0
local ACD_MaxStrikes = 2
local ACD_StrikesLeft = {}


local function FindAccessibleAngle(pos)
    for _ = 1, 50 do
        local ang = AngleRand()
        local trace = util.QuickTrace(pos, ang:Forward() * 10000)
        if trace.HitSky then
            return ang
        end
    end
    return nil
end


local function FindCanisterPos(pos, normal, dist)
    local offsetPos = pos + normal * 10
    local trace = util.QuickTrace(offsetPos, -normal * dist * 2)

    if trace.Hit and util.PointContents(offsetPos) ~= CONTENTS_SOLID then
        local ang = FindAccessibleAngle(trace.HitPos + normal * 7)
        if ang then
            return {
                Pos = trace.HitPos + normal * 7,
                Ang = ang
            }
        end
    end
    return nil
end


local function AirStrike(pos, normal, ply)
    if CurTime() < ACD_NextAirstrikeTime then return end
    local canisterData = FindCanisterPos(pos, normal, 1000)

    if canisterData then
        local ent = ents.Create("env_headcrabcanister")
        ent:SetPos(canisterData.Pos)
        ent:SetAngles(canisterData.Ang)
        ent:SetKeyValue("spawnflags", 8192)
        ent:Spawn()
        ent:Activate()
        ent:SetKeyValue("FlightSpeed", 5000)
        ent:SetKeyValue("FlightTime", 5)
        ent:SetKeyValue("SmokeLifetime", 30)
        ent:SetKeyValue("HeadcrabType", math.random(0, 2))
        ent:SetKeyValue("HeadcrabCount", 0)
        ent:SetKeyValue("Damage", 200)
        ent:SetKeyValue("DamageRadius", 300)
        ent:Fire("FireCanister")

        ACD_NextAirstrikeTime = CurTime() + 70
        ACD_StrikesLeft[ply] = (ACD_StrikesLeft[ply] or ACD_MaxStrikes) - 1
    end
end


net.Receive("ZC_AirStrikeRequest", function(len, ply)
	if not ply.leader then return end

    if ACD_StrikesLeft[ply] == nil then
        ACD_StrikesLeft[ply] = ACD_MaxStrikes
    end

    if ACD_StrikesLeft[ply] > 0 then
        local pos = ply:GetEyeTrace().HitPos
        local normal = ply:GetEyeTrace().HitNormal
        AirStrike(pos, normal, ply)
    else
        ply:ChatPrint("Access denied.")
    end
end)

hook.Add("PostCleanupMap", "ZC_ACDResetAirstrikes", function()
    ACD_StrikesLeft = {}
    ACD_NextAirstrikeTime = 0
end)

