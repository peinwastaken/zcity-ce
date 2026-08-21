local MODE = MODE

function MODE:ChanceFunction(info)
    if info.rounds then
        for i = #info.rounds, #info.rounds - self.CooldownRounds + 1, -1 do
            if info.rounds[i] == self.name then
                return 0
            else
                continue
            end
        end
    end

    return zc.ModesChances["cstrike"] or self.Chance
end

util.AddNetworkString("ZC_CStrikeRoundIntermission")

function MODE:DontKillPlayer(ply)
    return zc.RoundsLeft and (zc.RoundsLeft != self.Rounds)
end

function MODE:CanLaunch()
	local points = zc.GetMapPoints( "HMCD_TDM_T" )
	local points2 = zc.GetMapPoints( "HMCD_TDM_CT" )
	local points3 = zc.GetMapPoints( "BOMB_ZONE_A" )
	local points4 = zc.GetMapPoints( "BOMB_ZONE_B" )

    local points5 = zc.GetMapPoints( "HOSTAGE_DELIVERY_ZONE" )

    return (#points > 0) and (#points2 > 0) and (((#points3 > 1) or (#points4 > 1)) or (#points5 > 1))
end

function MODE:OverrideBalance()--return true to keep alive players
    return zc.RoundsLeft and (zc.RoundsLeft != self.Rounds)
end

function MODE:Start(round)
    for _, ply in player.Iterator() do
        ply:Freeze(false)
    end

    if zc.RoundsLeft and zc.RoundsLeft > 1 then
        NextRound(self.name)
    end
end



function MODE:Prepare(round)
	game.CleanUpMap()

    zc.RoundsLeft = zc.RoundsLeft or self.Rounds
    zc.Winners = zc.Winners or {}

    self.GameStarted = zc.RoundsLeft == self.Rounds
    zc.rtype = zc.rtype or "bomb"

    zc.hostagepoints = zc.GetMapPoints( "HOSTAGE_DELIVERY_ZONE" )

    if self.GameStarted then
        zc.Winners = {}
        zc.bombexploded = nil
        zc.bomb = nil
        --zc.rtype = zc.nextcsround or (math.random(2) == 1 and "bomb" or "hostage")
        zc.rtype = (
            (#zc.GetMapPoints( "BOMB_ZONE_A" ) > 0 or #zc.GetMapPoints( "BOMB_ZONE_B" ) > 0) and  "bomb") or
            (zc.hostagepoints and #zc.hostagepoints > 0 and "hostage")
        zc.nextcsround = nil
    end

    if !zc.rtype then
        zc.rtype = (
            (#zc.GetMapPoints( "BOMB_ZONE_A" ) > 0 or #zc.GetMapPoints( "BOMB_ZONE_B" ) > 0) and  "bomb") or
            (zc.hostagepoints and #zc.hostagepoints > 0 and "hostage")
    end

    zc.SendSpecificPointsToPly(nil, "BOMB_ZONE_A", false)
    zc.SendSpecificPointsToPly(nil, "BOMB_ZONE_B", false)
    zc.SendSpecificPointsToPly(nil, "HOSTAGE_DELIVERY_ZONE", false)

	self.CTPoints = {}
	self.TPoints = {}
	table.CopyFromTo( zc.GetMapPoints( "HMCD_TDM_T" ), self.TPoints)
	table.CopyFromTo( zc.GetMapPoints( "HMCD_TDM_CT" ), self.CTPoints)

	for _, ply in player.Iterator() do
		ply:SetupTeam(ply:Team())

        if self.GameStarted then
            ply:SetNWInt( "TDM_Money", self.StartMoney )
        end
        net.Start("ZC_CStrikeRoundIntermission")
        net.WriteBool(ply:Team() == 0)
        net.WriteInt(MODE.Rounds - zc.RoundsLeft or 0,6)
        net.Send(ply)
    end

    if zc.rtype == "bomb" then
        timer.Simple(3,function()
            local team_t = team.GetPlayers(0)
            local ply = team_t[math.random(#team_t)]

            local ent = ents.Create("bomb")
            ent:SetPos(ply:EyePos())
            ent:Spawn()

            zc.bomb = ent
            ent.tbl = self
        end)
    elseif zc.rtype == "hostage" then
        timer.Simple(3,function()
            local ent = ents.Create("prop_ragdoll")
            local team_t = team.GetPlayers(0)
            local ply = team_t[math.random(#team_t)]
			--ent:SetModel("models/humans/group01/"..(math.random(2) == 1 and "fe" or "").."male_0"..math.random(9)..".mdl")
            ent:SetModel("models/player/hostage/hostage_0"..math.random(4)..".mdl")
            ent:SetPos(ply:GetPos())
            ent:Spawn()
            ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
            zc.organism.Add(ent)
            zc.organism.Clear(ent.organism)
            ent.organism.fakePlayer = true

            zc.hostage = ent

            timer.Simple(1, function()
                zc.handcuff(ent)
            end)
        end)
    end

    PrintMessage(HUD_PRINTTALK, zc.locale.GetLocalized("cstrike/round_out_of", self.Rounds - zc.RoundsLeft, self.Rounds))

	net.Start("ZC_TeamDeathmatchStart")
        net.WriteString(zc.rtype or "bomb")
        net.Broadcast()

    self.GameStarted = nil

    self:GiveEquipment()
end

concommand.Add("tdm_setrounds", function(ply, cmd, args)
    if not ply:IsAdmin() then return end--idiot
	if not args[1] then return end
	local oldRounds = MODE.Rounds
    local oldLeft = zc.RoundsLeft or oldRounds
    local played = oldRounds - oldLeft
    MODE.Rounds = math.max(tonumber(args[1]) or oldRounds, 1)
    zc.RoundsLeft = math.max(MODE.Rounds - played, 0)
    PrintMessage(HUD_PRINTTALK, zc.locale.GetLocalized("cstrike/tdm_rounds_set", MODE.Rounds, zc.RoundsLeft))
end)

COMMANDS.nextcsround = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint(zc.locale.GetLocalized("common/no_access")) return end
		if string.lower(args[1]) == "bomb" then
            zc.nextcsround = "bomb"
            PrintMessage(HUD_PRINTTALK, zc.locale.GetLocalized("cstrike/chosen_bomb"))
        end

        if string.lower(args[1]) == "hostage" then
            zc.nextcsround = "hostage"
            PrintMessage(HUD_PRINTTALK, zc.locale.GetLocalized("cstrike/chosen_hostage"))
        end
	end,
	0
}


function MODE:Finish(round, result)
    zc.RoundsLeft = zc.RoundsLeft or self.Rounds
    zc.Winners = zc.Winners or {}

	timer.Simple(2,function()
		net.Start("ZC_TeamDeathmatchRoundEnd")
		net.Broadcast()
	end)

    local winner = 3

	local tbl = zc:CheckAliveTeams(true)

    if zc.rtype == "bomb" then
        if not IsValid(zc.bomb) then
            winner = 1
        end

        if zc.bombexploded then
            winner = 0
            zc.bombexploded = nil
        else
            winner = 1
        end

        if IsValid(zc.bomb) and #tbl[0] == 0 and not zc.bomb.active then
            winner = 1
        end

        if IsValid(zc.bomb) and #tbl[1] == 0 and #tbl[0] > 0 then
            winner = 0
        end

        if IsValid(zc.bomb) and #tbl[1] == 0 and #tbl[0] == 0 and zc.bomb.active then
            winner = 0
        end

        if IsValid(zc.bomb) and #tbl[0] == 0 and #tbl[1] == 0 and not zc.bomb.active then
            winner = 1
        end
    elseif zc.rtype == "hostage" then
        if not IsValid(zc.hostage) then
            winner = 3

            if IsValid(zc.hostageLastTouched) then
                winner = zc.hostageLastTouched:Team() == 0 and 1 or 0
            end
        end

        if IsValid(zc.hostage) and not zc.hostage.organism.alive then
            local max, maxTeam = 0
            if zc.HarmDoneDetailed[zc.hostage:EntIndex()] then
                for _, tbl in pairs(zc.HarmDoneDetailed[zc.hostage:EntIndex()]) do
                    if tbl.harm > max then
                        max = tbl.harm
                        maxTeam = tbl.teamAttacker
                    end
                end

                winner = maxTeam == 0 and 1 or 0
                PrintMessage(HUD_PRINTTALK, zc.locale.GetLocalized("cstrike/hostage_killed", zc.locale.GetLocalized(maxTeam == 0 and "tdm/team/terrorists" or "tdm/team/counter_terrorists")))
            else
                winner = 3
            end
        end

        if IsValid(zc.hostage) and zc.hostage.organism.alive then
            winner = 0

            if #tbl[0] == 0 then
                winner = 1
            end
        end

        if IsValid(zc.hostage) and zc.hostage.organism.alive and HostageInZone(zc.hostage:GetPos()) then
            zc.hostage:Remove()
            winner = 1
        end
    end

    local winnerprt = zc.locale.GetLocalized((winner == 1 and "tdm/team/counter_terrorists") or (winner == 0 and "tdm/team/terrorists") or "common/nobody")

    PrintMessage(HUD_PRINTTALK, zc.locale.GetLocalized("cstrike/won_round", winnerprt))

	for _, ply in player.Iterator() do
		if ply:Team() == winner then
			ply:GiveExp(math.random(15,30))
			ply:GiveSkill(math.Rand(0.1,0.15))

            ply:SetNWInt( "TDM_Money", math.max(ply:GetNWInt( "TDM_Money" ) + 2500, 0) )
		else
			ply:GiveSkill(-math.Rand(0.05,0.1))

            ply:SetNWInt( "TDM_Money", math.max(ply:GetNWInt( "TDM_Money" ) + 1750, 0) )
		end
	end

	local winsTeam0 = zc.Winners[0] or 0
	local winsTeam1 = zc.Winners[1] or 0
	if winsTeam0 > winsTeam1 then
		for _, ply in ipairs(team.GetPlayers(1)) do
			ply:SetNWInt("TDM_Money", math.max(ply:GetNWInt("TDM_Money") + 1000, 0))
			ply:ChatPrint(zc.locale.GetLocalized("cstrike/losing_compensation"))
		end
	elseif winsTeam1 > winsTeam0 then
		for _, ply in ipairs(team.GetPlayers(0)) do
			ply:SetNWInt("TDM_Money", math.max(ply:GetNWInt("TDM_Money") + 1000, 0))
			ply:ChatPrint(zc.locale.GetLocalized("cstrike/losing_compensation"))
		end
	end


    if zc.nextround != self.name then
        zc.Winners = {}
        zc.bombexploded = nil
        zc.bomb = nil
        zc.rtype = nil
        zc.nextcsround = nil
        zc.RoundsLeft = nil

        return
    end

    if zc.RoundsLeft > 0 then
        zc.RoundsLeft = zc.RoundsLeft - 1

        zc.Winners[winner] = (zc.Winners[winner] or 0) + 1
    else
        local winner
        local min = 0
        for team_, roundswon in pairs(zc.Winners) do
            if roundswon > min then
                winner = team_
                min = roundswon
            end
        end

        if winner then
            local winnerprt = zc.locale.GetLocalized((winner == 1 and "tdm/team/counter_terrorists") or (winner == 0 and "tdm/team/terrorists") or "common/nobody")

            PrintMessage(HUD_PRINTTALK, zc.locale.GetLocalized("cstrike/won_game", winnerprt))
        end

        zc.RoundsLeft = nil
    end
end

function HostageInZone(pos)
	local pts = zc.hostagepoints

	local vec1
	local vec2
	local vec3
	local vec4

	if #pts >= 2 then
		vec1 = -(-pts[1].pos)
		vec1[3] = vec1[3] - 256
		vec2 = -(-pts[2].pos)
		vec2[3] = vec2[3] + 256
	end

    if #pts >= 4 then
        vec3 = -(-pts[3].pos)
		vec3[3] = vec3[3] - 256
		vec4 = -(-pts[4].pos)
		vec4[3] = vec4[3] + 256
    end

	return (#pts >= 2 and pos:WithinAABox(vec1,vec2)) or (#pts >= 4 and pos:WithinAABox(vec3,vec4))
end

function MODE:CheckEnd(round)
    if zc.ROUND_START + 5 > CurTime() then return nil end

	local tbl = zc:CheckAliveTeams(true)

    if zc.rtype == "bomb" then
        if zc.bombexploded then
            return { reason = "bomb_exploded" }
        end

        if not IsValid(zc.bomb) then
            return { reason = "bomb_gone" }
        end

        if #tbl[0] == 0 and not zc.bomb.active then
            return { reason = "team_wiped" }
        end

        if #tbl[1] == 0 and #tbl[0] > 0 then
            return { reason = "team_wiped" }
        end

        if #tbl[1] == 0 and #tbl[0] == 0 and zc.bomb.active then
            return { reason = "team_wiped" }
        end

        if #tbl[0] == 0 and #tbl[1] == 0 and not zc.bomb.active then
            return { reason = "team_wiped" }
        end
    elseif zc.rtype == "hostage" then
        if not IsValid(zc.hostage) then
            return { reason = "hostage_gone" }
        end

        if #tbl[0] == 0 or #tbl[1] == 0 or not zc.hostage.organism.alive then
            return { reason = "team_wiped" }
        end

        if zc.hostage.organism.alive and HostageInZone(zc.hostage:GetPos()) then
            return { reason = "hostage_rescued" }
        end
    end

    return nil
end

hook.Add("ZC_OnHarmDone", "ZC_GiveMoneyForDamage", function(ply, victim, amt)
    if not CurrentRound().KillMoney then return end
    if not victim:IsPlayer() then return end
    if ply == victim then return end

    local add = amt * MODE.KillMoney * (ply:Team() == victim:Team() and -1 or 1)

    add = math.Round(add,0)

    --print(add,ply,ply:GetNWInt("TDM_Money"),victim)

    ply:SetNWInt( "TDM_Money", math.max(ply:GetNWInt( "TDM_Money" ) + add, 0) )

    if (ply:Team() == victim:Team()) and add <= 0 then
        victim:SetNWInt( "TDM_Money", math.max(victim:GetNWInt( "TDM_Money" ) - add, 0) )
    end
end)
