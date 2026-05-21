local MODE = MODE

MODE.MapSize = 7500
MODE.ZoneTimeToShrink = 120
MODE.name = "dm"
MODE.PrintName = "Deathmatch"
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.randomSpawns = true
MODE.ForBigMaps = false
MODE.Chance = 0.04

MODE.Config = {
    ["id"] = "dm",
    ["printname"] = "Deathmatch",
    ["settings"] = {
        {
            ["id"] = "mapsize",
            ["label"] = "Map Size",
            ["description"] = "Defines the playable map size",
            ["default"] = 7500,
            ["value"] = 7500,
            ["variable"] = "MapSize"
        },
        {
            ["id"] = "zonetime",
            ["label"] = "Zone Shrink Time",
            ["description"] = "Time before the zone starts shrinking",
            ["default"] = 120,
            ["value"] = 120,
            ["variable"] = "ZoneTimeToShrink"
        },
        {
            ["id"] = "lootspawn",
            ["label"] = "Spawn Loot",
            ["description"] = "Enables loot spawning for this gamemode",
            ["default"] = false,
            ["value"] = false,
            ["variable"] = "LootSpawn"
        },
        {
            ["id"] = "guiltdisabled",
            ["label"] = "Disable Guilt System",
            ["description"] = "Disables guilt/karma system for this gamemode",
            ["default"] = true,
            ["value"] = true,
            ["variable"] = "GuiltDisabled"
        },
        {
            ["id"] = "randomspawns",
            ["label"] = "Random Spawns",
            ["description"] = "Enables random spawnpoints for this gamemode",
            ["default"] = true,
            ["value"] = true,
            ["variable"] = "randomSpawns"
        },
        {
            ["id"] = "forbigmaps",
            ["label"] = "Large Map Mode",
            ["description"] = "Is this gamemode designed for big maps?",
            ["default"] = false,
            ["value"] = false,
            ["variable"] = "ForBigMaps"
        },
        {
            ["id"] = "chance",
            ["label"] = "Spawn Chance",
            ["description"] = "Chance for this gamemode to be picked by the round system",
            ["default"] = 0.04,
            ["value"] = 0.04,
            ["variable"] = "Chance"
        }
    }
}

function MODE.GetZoneRadius()
	if !zonedistance or !isnumber(zonedistance) then return 0xFFFFFFFF /*UUUUUUUUUUUUUUUUUCK*/ end
	local dist = zonedistance + 2048
	
	return (dist * math.max(((zb.ROUND_START + MODE.ZoneTimeToShrink) - CurTime()) / MODE.ZoneTimeToShrink, 0.025))
end

function MODE:ZC_CalculateMovementModifiers( mul, ply, cmd, mv )
    if (zb.ROUND_START or 0) + 7.5 > CurTime() and cmd then 
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
        if mv then
            mv:RemoveKey(IN_ATTACK)
            mv:RemoveKey(IN_ATTACK2)
        end

        if IsValid(ply) and IsValid(ply:GetWeapon("weapon_hands_sh")) then
            cmd:SelectWeapon(ply:GetWeapon("weapon_hands_sh"))
            if SERVER then ply:SelectWeapon("weapon_hands_sh") end
        end
    end
end

function MODE:ZC_CanPlayerLegAttack( ply )
	if (zb.ROUND_START or 0) + 20 > CurTime() then
		return false
	end
end