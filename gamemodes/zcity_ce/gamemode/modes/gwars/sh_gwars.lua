local MODE = MODE

MODE.name = "gwars"
MODE.PrintName = "Gang Wars"
MODE.ForBigMaps = false
MODE.ROUND_TIME = 180
MODE.Chance = 0.02
MODE.OverideSpawnPos = true
MODE.LootSpawn = false

zb = zb or {}

MODE.Config = {
    ["id"] = MODE.name or "gwars",
    ["printname"] = MODE.PrintName or "Gang Wars",
    ["settings"] = {
        {
            ["id"] = "round_time",
            ["label"] = "Round length",
            ["description"] = "Round duration (s)",
            ["default"] = 180,
            ["value"] = MODE.ROUND_TIME,
            ["variable"] = "ROUND_TIME"
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
            ["id"] = "lootspawn",
            ["label"] = "Spawn loot",
            ["description"] = "Enables loot spawning for this gamemode",
            ["default"] = false,
            ["value"] = false,
            ["variable"] = "LootSpawn"
        },
                {
            ["id"] = "forbigmaps",
            ["label"] = "Supports large maps",
            ["description"] = "Should this gamemode be picked for big maps?",
            ["default"] = false,
            ["value"] = false,
            ["variable"] = "ForBigMaps"
        }
    }
}
--[[zb.Points = zb.Points or {}

zb.Points.HMCD_TDM_CT = zb.Points.HMCD_TDM_CT or {}
zb.Points.HMCD_TDM_CT.Color = Color(0,0,150)
zb.Points.HMCD_TDM_CT.Name = "HMCD_TDM_CT"

zb.Points.HMCD_TDM_T = zb.Points.HMCD_TDM_T or {}
zb.Points.HMCD_TDM_T.Color = Color(150,95,0)
zb.Points.HMCD_TDM_T.Name = "HMCD_TDM_T"]]
