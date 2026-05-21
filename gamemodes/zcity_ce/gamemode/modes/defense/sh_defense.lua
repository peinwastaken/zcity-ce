local MODE = MODE

MODE.Timers = MODE.Timers or {}
MODE.name = "defense"
MODE.PrintName = "NPC Defense"
MODE.randomSpawns = true
MODE.ROUND_TIME = 10000
MODE.TotalWaves = 6
MODE.CurrentSubMode = "STANDARD"
MODE.LootSpawn = true
MODE.ForBigMaps = true
MODE.Chance = 0.02
MODE.VoteTime = 15

MODE.Config = {
    ["id"] = MODE.name or "defense",
    ["printname"] = MODE.PrintName or "NPC Defense",
    ["settings"] = {
        {
            ["id"] = "round_time",
            ["label"] = "Round length",
            ["description"] = "Round duration (s)",
            ["default"] = 10000,
            ["value"] = MODE.ROUND_TIME,
            ["variable"] = "ROUND_TIME"
        },
        {
            ["id"] = "lootspawn",
            ["label"] = "Spawn loot",
            ["description"] = "Enable loot spawning for this mode",
            ["default"] = true,
            ["value"] = MODE.LootSpawn,
            ["variable"] = "LootSpawn"
        },
        {
            ["id"] = "chance",
            ["label"] = "Pick chance",
            ["description"] = "Chance to pick this mode",
            ["default"] = 0.02,
            ["value"] = MODE.Chance,
            ["variable"] = "Chance"
        },
        {
            ["id"] = "randomspawns",
            ["label"] = "Random spawns",
            ["description"] = "Whether players spawn at random locations",
            ["default"] = true,
            ["value"] = MODE.randomSpawns,
            ["variable"] = "randomSpawns"
        },
        {
            ["id"] = "totalwaves",
            ["label"] = "Total waves",
            ["description"] = "Total number of waves in this mode",
            ["default"] = 6,
            ["value"] = MODE.TotalWaves,
            ["variable"] = "TotalWaves"
        },
        {
            ["id"] = "votetime",
            ["label"] = "Vote time",
            ["description"] = "Duration allowed for map/mode votes",
            ["default"] = 15,
            ["value"] = MODE.VoteTime,
            ["variable"] = "VoteTime"
        },
        {
            ["id"] = "forbigmaps",
            ["label"] = "Supports large maps",
            ["description"] = "Should this gamemode be picked for big maps?",
            ["default"] = false,
            ["value"] = MODE.ForBigMaps,
            ["variable"] = "ForBigMaps"
        }
    }
}

zb = zb or {}
zb.Points = zb.Points or {}

zb.Points.NPC_DEFENSE_SPAWN= zb.Points.NPC_DEFENSE_SPAWN or {}
zb.Points.NPC_DEFENSE_SPAWN.Color = Color(243,9,9)
zb.Points.NPC_DEFENSE_SPAWN.Name = "NPC_DEFENSE_SPAWN"

zb.Points.PLY_DEFENSE_SPAWN = zb.Points.PLY_DEFENSE_SPAWN or {}
zb.Points.PLY_DEFENSE_SPAWN.Color = Color(51,243,9)
zb.Points.PLY_DEFENSE_SPAWN.Name = "PLY_DEFENSE_SPAWN"

zb.Points.DEFENSE_POINT = zb.Points.DEFENSE_POINT or {}
zb.Points.DEFENSE_POINT.Color = Color(13,9,243)
zb.Points.DEFENSE_POINT.Name = "DEFENSE_POINT"


MODE.SUBMODES = {
    STANDARD = {
        name = "Standard",
        description = "Classic 6 waves of combine attacks",
        waves = 6,
        enemy_type = "combine"
    },
    EXTENDED = {
        name = "Extended",
        description = "Extended mode: 12 waves with bosses and special enemies",
        waves = 12,
        enemy_type = "combine"
    },
    ZOMBIE = {
        name = "Zombie",
        description = "6 waves of zombie apocalypse",
        waves = 6,
        enemy_type = "zombie"
    }
}