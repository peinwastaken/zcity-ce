local MODE = MODE

MODE.name = "hl2dm"
MODE.PrintName = "Half-Life 2 Deathmatch"
MODE.Chance = 0.05
MODE.LootSpawn = false
MODE.ForBigMaps = true

MODE.Config = {
    ["id"] = MODE.name or "hl2dm",
    ["printname"] = MODE.PrintName or "Half-Life 2 Deathmatch",
    ["settings"] = {
        {
            ["id"] = "chance",
            ["label"] = "Pick chance",
            ["description"] = "Chance for this gamemode to be picked by the round system",
            ["default"] = 0.05,
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
            ["default"] = true,
            ["value"] = MODE.ForBigMaps,
            ["variable"] = "ForBigMaps"
        }
    }
}

zb = zb or {}

--[[ Ideas
    Weak eye zone on combines
    //Remove the ability for combines to wear armor
    //Give combine NVG goggles ;; They do not need to be given them; just make the functionality built into their class!!!
    //Airstrikes for elites
]]

zb = zb or {}
zb.Points = zb.Points or {}

zb.Points.HL2DM_SNIPERSPAWN = zb.Points.HL2DM_SNIPERSPAWN or {}
zb.Points.HL2DM_SNIPERSPAWN.Color = Color(243,9,9)
zb.Points.HL2DM_SNIPERSPAWN.Name = "HL2DM_SNIPERSPAWN"

zb.Points.HL2DM_CROSSBOWSPAWN = zb.Points.HL2DM_CROSSBOWSPAWN or {}
zb.Points.HL2DM_CROSSBOWSPAWN.Color = Color(243,9,9)
zb.Points.HL2DM_CROSSBOWSPAWN.Name = "HL2DM_CROSSBOWSPAWN"