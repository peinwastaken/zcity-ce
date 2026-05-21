local MODE = MODE

MODE.KillMoney = 1000
MODE.StartMoney = 1000
MODE.start_time = 20
MODE.Rounds = 5
MODE.ROUND_TIME = 240
MODE.ForBigMaps = false -- if it can launch, then it doesn't really matter
MODE.CooldownRounds = 5 -- 5 rounds of cs, 5 rounds without cs (at least 5)
MODE.base = "tdm"
MODE.PrintName = "Counter-Strike"
MODE.name = "cstrike"

MODE.Config = {
    ["id"] = MODE.name or "cstrike",
    ["printname"] = MODE.PrintName or "Counter-Strike",
    ["settings"] = {
        {
            ["id"] = "killmoney",
            ["label"] = "Kill money",
            ["description"] = "Money awarded for a kill",
            ["default"] = 1000,
            ["value"] = MODE.KillMoney,
            ["variable"] = "KillMoney"
        },
        {
            ["id"] = "startmoney",
            ["label"] = "Start money",
            ["description"] = "Money players start with",
            ["default"] = 1000,
            ["value"] = MODE.StartMoney,
            ["variable"] = "StartMoney"
        },
        {
            ["id"] = "rounds",
            ["label"] = "Rounds",
            ["description"] = "Number of rounds per match",
            ["default"] = 5,
            ["value"] = MODE.Rounds,
            ["variable"] = "Rounds"
        },
        {
            ["id"] = "start_time",
            ["label"] = "Round start delay",
            ["description"] = "Delay before round start (s)",
            ["default"] = 20,
            ["value"] = MODE.start_time,
            ["variable"] = "start_time"
        },
        {
            ["id"] = "round_time",
            ["label"] = "Round length",
            ["description"] = "Round duration (s)",
            ["default"] = 240,
            ["value"] = MODE.ROUND_TIME,
            ["variable"] = "ROUND_TIME"
        },
        {
            ["id"] = "forbigmaps",
            ["label"] = "Supports large maps",
            ["description"] = "Should this gamemode be picked for big maps?",
            ["default"] = false,
            ["value"] = MODE.ForBigMaps,
            ["variable"] = "ForBigMaps"
        },
        {
            ["id"] = "cooldown_rounds",
            ["label"] = "Cooldown rounds",
            ["description"] = "Number of rounds before this mode can run again (cooldown)",
            ["default"] = 5,
            ["value"] = MODE.CooldownRounds,
            ["variable"] = "CooldownRounds"
        }
    }
}

zb.Points.BOMB_ZONE_A = zb.Points.BOMB_ZONE_A or {}
zb.Points.BOMB_ZONE_A.Color = Color(0,50,70)
zb.Points.BOMB_ZONE_A.Name = "BOMB_ZONE_A"

zb.Points.BOMB_ZONE_B = zb.Points.BOMB_ZONE_B or {}
zb.Points.BOMB_ZONE_B.Color = Color(70,50,0)
zb.Points.BOMB_ZONE_B.Name = "BOMB_ZONE_B"

zb.Points.HOSTAGE_DELIVERY_ZONE = zb.Points.HOSTAGE_DELIVERY_ZONE or {}
zb.Points.HOSTAGE_DELIVERY_ZONE.Color = Color(150,150,150)
zb.Points.HOSTAGE_DELIVERY_ZONE.Name = "HOSTAGE_DELIVERY_ZONE"