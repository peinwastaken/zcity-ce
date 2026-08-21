local MODE = MODE

MODE.name = "coop"
MODE.GuiltDisabled = true
MODE.PrintName = "CO-OP"
MODE.randomSpawns = false
MODE.LootSpawn = false
MODE.ForBigMaps = true
MODE.Chance = 1
MODE.ROUND_TIME = 9000

MODE.Intro = {
    Title = "Homicide | CO-OP",
    Objective = "Reach the end of the map.",
    Role = "Rebel",
    Color = Color(155, 55, 0),
    Sound = "hl2mode1.wav"
}

function MODE:GetPlayerIntroData(ply)
    local gordon = ply.PlayerClassName == "Gordon"
    return {
        Role = gordon and "Gordon" or "Rebel",
        Objective = gordon and "Lead the resistance to victory!" or "Follow Gordon!"
    }
end

zc = zc or {}
zc.Points = zc.Points or {}

zc.Points.HMCD_COOP_SPAWN = zc.Points.HMCD_COOP_SPAWN or {}
zc.Points.HMCD_COOP_SPAWN.Color = Color(255,255,255)
zc.Points.HMCD_COOP_SPAWN.Name = "HMCD_COOP_SPAWN"

MODE.Maps = {
    ["d1_trainstation_01"] = {PlayerEquipment = "citizen"},
    ["d1_trainstation_02"] = {PlayerEquipment = "citizen"},
    ["d1_trainstation_03"] = {PlayerEquipment = "citizen"},
    ["d1_trainstation_04"] = {PlayerEquipment = "citizen"},
    ["d1_trainstation_05"] = {PlayerEquipment = "citizen"},
    ["d1_trainstation_06"] = {PlayerEquipment = "refugee"},
    ["d1_canals_01"] = {PlayerEquipment = "refugee"},
    ["d1_canals_01a"] = {PlayerEquipment = "refugee"},
    ["d1_canals_02"] = {PlayerEquipment = "refugee"},
    ["d1_canals_03"] = {PlayerEquipment = "refugee"},
    ["d1_canals_05"] = {PlayerEquipment = "refugee"},
    ["d1_canals_06"] = {PlayerEquipment = "refugee"},
    ["d1_canals_07"] = {PlayerEquipment = "refugee"},
    ["d1_canals_08"] = {PlayerEquipment = "refugee"},
    ["d1_canals_09"] = {PlayerEquipment = "refugee"},
    ["d1_canals_10"] = {PlayerEquipment = "refugee"},
    ["d1_canals_11"] = {PlayerEquipment = "refugee"},
    ["d1_canals_12"] = {PlayerEquipment = "refugee"},
    ["d1_canals_13"] = {PlayerEquipment = "refugee"},
    ["d1_eli_01"] = {PlayerEquipment = "refugee"},
    ["d1_town_01"] = {PlayerEquipment = "rebel"},
    ["d1_town_01a"] = {PlayerEquipment = "rebel"},
    ["d1_town_02"] = {PlayerEquipment = "rebel"},
    ["d1_town_02a"] = {PlayerEquipment = "rebel"},
    ["d1_town_03"] = {PlayerEquipment = "rebel"},
    ["d1_town_04"] = {PlayerEquipment = "rebel"},
    ["d1_town_05"] = {PlayerEquipment = "rebel"},
    ["d2_*"] = {PlayerEquipment = "rebel"}
}

MODE.Config = {
    ["id"] = "coop",
    ["printname"] = "Co-op",
    ["settings"] = {
		{
			["id"] = "randomspawns",
			["label"] = "Random spawns",
			["description"] = "If players spawn in random positions on the map",
			["default"] = false,
			["value"] = MODE.randomSpawns,
			["variable"] = "randomSpawns"
		},
		{
			["id"] = "round_time",
			["label"] = "Round length",
			["description"] = "Main round duration in seconds; used by round end checks and HUD timers (MODE.ROUND_TIME)",
			["default"] = 600,
			["value"] = MODE.ROUND_TIME,
			["variable"] = "ROUND_TIME"
		},
		{
			["id"] = "chance",
			["label"] = "Pick chance",
			["description"] = "Chance for this gamemode (and its subtypes) to be picked by the round system",
			["default"] = 1,
			["value"] = MODE.Chance,
			["variable"] = "Chance"
		},
		{
			["id"] = "lootspawn",
			["label"] = "Spawn loot",
			["description"] = "Enables loot spawning for this gamemode",
			["default"] = false,
			["value"] = MODE.LootSpawn,
			["variable"] = "LootSpawn"
		},
		{
			["id"] = "guiltdisabled",
			["label"] = "Disable guilt system",
			["description"] = "Disables guilt/karma system for this gamemode",
			["default"] = true,
			["value"] = MODE.GuiltDisabled,
			["variable"] = "GuiltDisabled"
		}
    }
}
