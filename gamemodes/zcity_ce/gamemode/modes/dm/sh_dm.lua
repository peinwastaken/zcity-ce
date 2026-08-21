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

-- New round API (see docs/gamemode-system-rewrite.md).
MODE.MinPlayers = 2
MODE.RoundTime = 300
MODE.SetupTime = 0
MODE.EndTime = 5

MODE.Intro = {
	Title = "Deathmatch",
	Objective = "Kill everyone.",
	Role = "Fighter",
	Color = Color(190, 15, 15),
	Sound = "snd_jack_hmcd_deathmatch.mp3"
}

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
	
	return (dist * math.max(((zc.ROUND_START + MODE.ZoneTimeToShrink) - CurTime()) / MODE.ZoneTimeToShrink, 0.025))
end

function MODE:IsSpawnProtectionActive()
    return zc.round and zc.round.state == ROUND_PREPARING
end

MODE.Hooks = MODE.Hooks or {}

MODE.Hooks.ZC_CanPlayerLegAttack = function(self, round, ply)
	if round.state == ROUND_PREPARING then
		return false
	end
end
