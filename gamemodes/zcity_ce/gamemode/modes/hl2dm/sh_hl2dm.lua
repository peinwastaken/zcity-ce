local MODE = MODE

MODE.name = "hl2dm"
MODE.PrintName = "Half-Life 2 Deathmatch"
MODE.Chance = 0.05
MODE.LootSpawn = false
MODE.ForBigMaps = true

MODE.Intro = {
    Title = "ZBattle | Half-Life 2 Deathmatch",
    Sound = "hl2mode1.wav"
}

function MODE:GetPlayerIntroData(ply)
    if ply:Team() == 1 then
        return {
            Role = "Combine Soldier",
            Objective = "Destroy all rebel forces.",
            Color = Color(0, 200, 220)
        }
    end

    return {
        Role = "Rebel",
        Objective = "Destroy the Combine and survive.",
        Color = Color(230, 100, 5)
    }
end

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

zc = zc or {}

--[[ Ideas
    Weak eye zone on combines
    //Remove the ability for combines to wear armor
    //Give combine NVG goggles ;; They do not need to be given them; just make the functionality built into their class!!!
    //Airstrikes for elites
]]

zc = zc or {}
zc.Points = zc.Points or {}

zc.Points.HL2DM_SNIPERSPAWN = zc.Points.HL2DM_SNIPERSPAWN or {}
zc.Points.HL2DM_SNIPERSPAWN.Color = Color(243,9,9)
zc.Points.HL2DM_SNIPERSPAWN.Name = "HL2DM_SNIPERSPAWN"

zc.Points.HL2DM_CROSSBOWSPAWN = zc.Points.HL2DM_CROSSBOWSPAWN or {}
zc.Points.HL2DM_CROSSBOWSPAWN.Color = Color(243,9,9)
zc.Points.HL2DM_CROSSBOWSPAWN.Name = "HL2DM_CROSSBOWSPAWN"
