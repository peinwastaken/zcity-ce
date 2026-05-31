local MODE = MODE

MODE.name = "sandbox"
MODE.PrintName = "Sandbox"
MODE.Chance = 0
MODE.ForBigMaps = true
MODE.randomSpawns = true
MODE.LootSpawn = false
MODE.GuiltDisabled = true
MODE.DisableRoundTimer = true
MODE.AllowSpawnMenu = true
MODE.AllowContextMenu = true
MODE.AllowRespawn = true
MODE.RespawnTimer = 5
MODE.ROUND_TIME = 3600

MODE.Config = {
	["id"] = MODE.name,
	["printname"] = MODE.PrintName,
	["settings"] = {
		{
			["id"] = "disable_round_timer",
			["label"] = "Disable round timer",
			["description"] = "Prevents the round system from ending this mode because the normal round timer expired",
			["default"] = true,
			["value"] = MODE.DisableRoundTimer,
			["variable"] = "DisableRoundTimer"
		},
		{
			["id"] = "allow_spawnmenu",
			["label"] = "Allow spawn menu",
			["description"] = "Allows all players to open and use the spawn menu in this mode",
			["default"] = true,
			["value"] = MODE.AllowSpawnMenu,
			["variable"] = "AllowSpawnMenu"
		},
		{
			["id"] = "allow_contextmenu",
			["label"] = "Allow context menu",
			["description"] = "Allows all players to open and use context menu properties in this mode",
			["default"] = true,
			["value"] = MODE.AllowContextMenu,
			["variable"] = "AllowContextMenu"
		},
		{
			["id"] = "allow_respawn",
			["label"] = "Allow respawn",
			["description"] = "Allows dead players to respawn during the active round",
			["default"] = true,
			["value"] = MODE.AllowRespawn,
			["variable"] = "AllowRespawn"
		},
		{
			["id"] = "respawn_timer",
			["label"] = "Respawn delay",
			["description"] = "Delay before players respawn after death",
			["default"] = 5,
			["value"] = MODE.RespawnTimer,
			["variable"] = "RespawnTimer"
		},
		{
			["id"] = "chance",
			["label"] = "Pick chance",
			["description"] = "Chance for this gamemode to be picked by the round system",
			["default"] = 0,
			["value"] = MODE.Chance,
			["variable"] = "Chance"
		}
	}
}
