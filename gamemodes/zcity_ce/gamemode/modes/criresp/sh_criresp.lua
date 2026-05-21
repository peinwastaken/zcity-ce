local MODE = MODE

MODE.name = "criresp"
MODE.PrintName = "Crisis Response"
MODE.ForBigMaps = false
MODE.ROUND_TIME = 480
MODE.Chance = 0.05

MODE.Config = {
    ["id"] = MODE.name or "criresp",
    ["printname"] = MODE.PrintName or "Crisis Response",
    ["settings"] = {
        {
            ["id"] = "round_time",
            ["label"] = "Round length",
            ["description"] = "Main round duration in seconds",
            ["default"] = 480,
            ["value"] = MODE.ROUND_TIME,
            ["variable"] = "ROUND_TIME"
        },
        {
            ["id"] = "chance",
            ["label"] = "Pick chance",
            ["description"] = "Chance for this gamemode to be picked by the round system",
            ["default"] = 0.05,
            ["value"] = MODE.Chance,
            ["variable"] = "Chance"
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

zb.Points.HMCD_CRI_CT = zb.Points.HMCD_CRI_CT or {}
zb.Points.HMCD_CRI_CT.Color = Color(0,0,150)
zb.Points.HMCD_CRI_CT.Name = "HMCD_CRI_CT"

zb.Points.HMCD_CRI_T = zb.Points.HMCD_CRI_T or {}
zb.Points.HMCD_CRI_T.Color = Color(237,13,13)
zb.Points.HMCD_CRI_T.Name = "HMCD_CRI_T"