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
MODE.SpawnProtectionTime = 7.5

MODE.Config = {
    ["id"] = "dm",
    ["printname"] = "Deathmatch",
    ["settings"] = {
        {
            ["id"] = "zonetime",
            ["label"] = "Zone shrink time",
            ["description"] = "Time for the zone to fully shrink",
            ["default"] = 120,
            ["value"] = 120,
            ["variable"] = "ZoneTimeToShrink"
        },
        {
            ["id"] = "spawnprotection",
            ["label"] = "Spawn protection time",
            ["description"] = "Length of time during which players are unable to equip weapons",
            ["default"] = 7.5,
            ["value"] = 7.5,
            ["variable"] = "SpawnProtectionTime"
        },
        {
            ["id"] = "lootspawn",
            ["label"] = "Spawn loot",
            ["description"] = "Enables loot spawning for this gamemode",
            ["default"] = false,
            ["value"] = false,
            ["variable"] = "LootSpawn"
        },
        {
            ["id"] = "guiltdisabled",
            ["label"] = "Disable guilt system",
            ["description"] = "Disables guilt/karma system for this gamemode",
            ["default"] = true,
            ["value"] = true,
            ["variable"] = "GuiltDisabled"
        },
        {
            ["id"] = "forbigmaps",
            ["label"] = "Supports large maps",
            ["description"] = "Should this gamemode be picked for big maps?",
            ["default"] = false,
            ["value"] = false,
            ["variable"] = "ForBigMaps"
        },
        {
            ["id"] = "chance",
            ["label"] = "Pick chance",
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

function MODE:IsSpawnProtectionActive()
    return (zb.ROUND_START or 0) + MODE.SpawnProtectionTime > CurTime()
end

function MODE:ZC_CanPlayerLegAttack( ply )
	if (zb.ROUND_START or 0) + 20 > CurTime() then
		return false
	end
end