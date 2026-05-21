local MODE = MODE

MODE.name = "riot"
MODE.PrintName = "Riot"
MODE.OverideSpawnPos = true
MODE.LootSpawn = false
MODE.ForBigMaps = false
MODE.Chance = 0.03

zb = zb or {}
zb.Points = zb.Points or {}

zb.Points.RIOT_TDM_LAW = zb.Points.RIOT_TDM_LAW or {}
zb.Points.RIOT_TDM_LAW.Color = Color(0,0,150)
zb.Points.RIOT_TDM_LAW.Name = "RIOT_TDM_LAW"

zb.Points.RIOT_TDM_RIOTERS = zb.Points.RIOT_TDM_RIOTERS or {}
zb.Points.RIOT_TDM_RIOTERS.Color = Color(150,95,0)
zb.Points.RIOT_TDM_RIOTERS.Name = "RIOT_TDM_RIOTERS"

MODE.Config = {
    ["id"] = MODE.name or "riot",
    ["printname"] = MODE.PrintName or "Riot",
    ["settings"] = {
        {
            ["id"] = "chance",
            ["label"] = "Pick chance",
            ["description"] = "Chance for this gamemode to be picked by the round system",
            ["default"] = 0.03,
            ["value"] = MODE.Chance,
            ["variable"] = "Chance"
        },
        {
            ["id"] = "lootspawn",
            ["label"] = "Spawn loot",
            ["description"] = "Enable loot spawning for this gamemode",
            ["default"] = false,
            ["value"] = MODE.LootSpawn,
            ["variable"] = "LootSpawn"
        },
        {
            ["id"] = "forbigmaps",
            ["label"] = "Supports large maps",
            ["description"] = "Should this gamemode be picked for big maps?",
            ["default"] = false,
            ["value"] = false,
            ["variable"] = "ForBigMaps"
        },
    }
}

