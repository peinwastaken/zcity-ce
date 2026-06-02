zc = zc or {}
zc.CoopPersistence = zc.CoopPersistence or {}

local SAVE_PATH = "coop/session_data.json"

function zc.CoopPersistence.GetSavePath()
    return SAVE_PATH
end

function zc.CoopPersistence.SaveAllPlayers()
    local data = {}

    for steamid, playerData in pairs(zc.CoopPersistence.PendingSave or {}) do
        data[steamid] = playerData
    end

    if table.Count(data) > 0 then
        zc.WriteData(zc.CoopPersistence.GetSavePath(), data, true)
    end
end

function zc.CoopPersistence.LoadAllPlayers()
    local path = zc.CoopPersistence.GetSavePath()
    local data = zc.ParseDataFile(path, {})

    zc.CoopPersistence.LoadedData = data
    return data
end


function zc.CoopPersistence.ClearSavedData()
    zc.CoopPersistence.PendingSave = {}
    zc.CoopPersistence.LoadedData = {}
    zc.DeleteDataFile(zc.CoopPersistence.GetSavePath())
end


function zc.CoopPersistence.SavePlayerData(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local steamid = ply:SteamID()
    zc.CoopPersistence.PendingSave = zc.CoopPersistence.PendingSave or {}

    local weaponsData = {}
    local inv = ply:GetNetVar("Inventory", {})

    if inv.Weapons then
        for wepClass, wepData in pairs(inv.Weapons) do
            if wepClass == "hg_sling" or wepClass == "hg_brassknuckles" or wepClass == "hg_flashlight" then
                weaponsData[wepClass] = true
            elseif IsValid(wepData) and wepData:IsWeapon() then
                if wepData.GetInfo then
                    weaponsData[wepClass] = wepData:GetInfo()
                else
                    weaponsData[wepClass] = {
                        Clip1 = wepData:Clip1(),
                        Clip2 = wepData:Clip2()
                    }
                end
            else
                weaponsData[wepClass] = true
            end
        end
    end

    for _, wep in ipairs(ply:GetWeapons()) do
        local wepClass = wep:GetClass()
        if wepClass == "weapon_hands_sh" or wepClass == "weapon_zombclaws" then continue end

        if not weaponsData[wepClass] then
            if wep.GetInfo then
                weaponsData[wepClass] = wep:GetInfo()
            else
                weaponsData[wepClass] = {
                    Clip1 = wep:Clip1(),
                    Clip2 = wep:Clip2()
                }
            end
        end
    end

    local ammoData = {}
    for ammoID, count in pairs(ply:GetAmmo()) do
        if count > 0 then
            local ammoName = game.GetAmmoName(ammoID)
            if ammoName then
                ammoData[ammoName] = count
            end
        end
    end

    local armorData = {}
    if ply.armors then
        for placement, armorName in pairs(ply.armors) do
            armorData[placement] = armorName
        end
    end

    local armorHealthData = {}
    if ply.armors_health then
        for placement, health in pairs(ply.armors_health) do
            armorHealthData[placement] = health
        end
    end

    local role = ply.role or {}
    local roleName = role.name or "Refugee"
    local roleColor = role.color or Color(255, 155, 0)

    local playerClass = ply.PlayerClassName or "Refugee"
    local subClass = ply.subClass

    local hevData = nil
    if ply.HEV and ply:GetNetVar("HEVSuit") then
        hevData = {
            Power = ply.HEV.Power,
            Medicine = ply.HEV.Medicine,
            Morphine = ply.HEV.Morphine
        }
    end

    zc.CoopPersistence.PendingSave[steamid] = {
        Weapons = weaponsData,
        Ammo = ammoData,
        Armor = armorData,
        Armor_health = armorHealthData,
        Attachments = inv.Attachments or {},
        Role = roleName,
        RoleColor = {roleColor.r, roleColor.g, roleColor.b},
        PlayerClass = playerClass,
        SubClass = subClass,
        Health = ply:Health(),
        MaxHealth = ply:GetMaxHealth(),
        HEV = hevData,
        Nick = ply:Nick()
    }
end


function zc.CoopPersistence.RestorePlayerData(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    local steamid = ply:SteamID()
    local data = zc.CoopPersistence.LoadedData and zc.CoopPersistence.LoadedData[steamid]

    if not data then return false end


    ply:SetSuppressPickupNotices(true)
    ply.noSound = true

    local inv = ply:GetNetVar("Inventory", {})
    inv.Weapons = inv.Weapons or {}
    inv.Ammo = inv.Ammo or {}
    inv.Attachments = data.Attachments or {}

    if data.Weapons["hg_sling"] then
        inv.Weapons["hg_sling"] = true
    end
    if data.Weapons["hg_brassknuckles"] then
        inv.Weapons["hg_brassknuckles"] = true
    end
    if data.Weapons["hg_flashlight"] then
        inv.Weapons["hg_flashlight"] = true
    end

    ply:SetNetVar("Inventory", inv)

    for wepClass, wepData in pairs(data.Weapons) do
        if wepClass == "hg_sling" or wepClass == "hg_brassknuckles" or wepClass == "hg_flashlight" then
            continue
        end

        local wep = ply:Give(wepClass)
        if IsValid(wep) then
            if istable(wepData) then
                if wep.SetInfo then
                    wep:SetInfo(wepData)
                else
                    if wepData.Clip1 then wep:SetClip1(wepData.Clip1) end
                    if wepData.Clip2 then wep:SetClip2(wepData.Clip2) end
                end
            end
        end
    end

    for ammoName, count in pairs(data.Ammo or {}) do
        ply:GiveAmmo(count, ammoName, true)
    end

    if data.Armor and zc.AddArmor then
        for _, armorName in pairs(data.Armor) do
            zc.AddArmor(ply, armorName)
        end
    end

    if data.Armor_health then
        ply.armors_health = ply.armors_health or {}
        for placement, health in pairs(data.Armor_health) do
            ply.armors_health[placement] = health
        end
    end

    if data.Health then
        ply:SetHealth(math.max(data.Health, 50))
    end

    if data.HEV then
        ply.HEV = ply.HEV or {}
        ply.HEV.Power = data.HEV.Power or 75
        ply.HEV.Medicine = data.HEV.Medicine or 600
        ply.HEV.Morphine = data.HEV.Morphine or 4
    end

    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply.noSound = false
            ply:SetSuppressPickupNotices(false)
        end
    end)

    return true, data
end

function zc.CoopPersistence.HasSurvivedGordon()
    local loadedData = zc.CoopPersistence.LoadedData or {}

    for steamid, data in pairs(loadedData) do
        if data.PlayerClass == "Gordon" or data.Role == "Freeman" then
            return true, steamid
        end
    end

    return false, nil
end

function zc.CoopPersistence.GetPlayerData(steamid)
    return zc.CoopPersistence.LoadedData and zc.CoopPersistence.LoadedData[steamid]
end

function zc.CoopPersistence.MarkPlayerRestored(steamid)
    if zc.CoopPersistence.LoadedData then
        zc.CoopPersistence.LoadedData[steamid] = nil
    end
end

hook.Add("ShutDown", "ZC_CoopPersistenceSaveOnShutdown", function()
    if CurrentRound and CurrentRound().name == "coop" and zc.MapCompleted then
        zc.CoopPersistence.SaveAllPlayers()
    end
end)

hook.Add("InitPostEntity", "ZC_CoopPersistenceLoadOnStart", function()
    timer.Simple(1, function()
        zc.CoopPersistence.LoadAllPlayers()
    end)
end)

hook.Add("ZC_PreRoundStart", "ZC_CoopPersistenceClearOnModeChange", function()
    local nextRound = zc.nextround or "hmcd"
    local nextMode = zc:GetMode(nextRound)

    if nextMode ~= "coop" then
        zc.CoopPersistence.ClearSavedData()
    end
end)

hook.Add("ZC_StartRound", "ZC_CoopPersistenceClearPending", function()
    if CurrentRound and CurrentRound().name == "coop" then
        zc.CoopPersistence.PendingSave = {}
    end
end)


hook.Add("PlayerSpawn", "ZC_CoopPersistenceMidRoundSpawn", function(ply)
    if not CurrentRound or CurrentRound().name ~= "coop" then return end
    if not zc or zc.ROUND_STATE ~= 1 then return end
    timer.Simple(0.5, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local hasWeapons = #ply:GetWeapons() > 1
        if hasWeapons then return end
        if CurrentRound().GetPlySpawn then
            CurrentRound():GetPlySpawn(ply)
        end

        local steamid = ply:SteamID()
        local savedData = zc.CoopPersistence.GetPlayerData(steamid)

        if savedData then

            local restored, data = zc.CoopPersistence.RestorePlayerData(ply)

            if restored and data then
                local savedPlayerClass = data.PlayerClass
                local savedRole = data.Role
                local savedRoleColor = data.RoleColor and Color(data.RoleColor[1], data.RoleColor[2], data.RoleColor[3]) or Color(255, 155, 0)
                local savedSubClass = data.SubClass


                if savedPlayerClass == "Gordon" or savedRole == "Freeman" then
                    ply:SetPlayerClass("Gordon", {bRestored = true})
                    zc.GiveRole(ply, "Freeman", Color(255, 155, 0))
                elseif savedSubClass == "medic" then
                    ply.subClass = "medic"
                    ply:SetPlayerClass(savedPlayerClass or "Rebel", {bNoEquipment = true})
                    zc.GiveRole(ply, "Medic", Color(190, 0, 0))
                else
                    ply:SetPlayerClass(savedPlayerClass or "Rebel", {bNoEquipment = true})
                    zc.GiveRole(ply, savedRole or "Rebel", savedRoleColor)
                end

                zc.CoopPersistence.MarkPlayerRestored(steamid)

                ply:Give("weapon_hands_sh")
                ply:SelectWeapon("weapon_hands_sh")

            end
        else
            local currentMap = game.GetMap()
            local mapData = CurrentRound().Maps[currentMap] or {PlayerEquipment = "rebel"}
            local playerClass = mapData.PlayerEquipment

            local inv = ply:GetNetVar("Inventory", {})
            inv["Weapons"] = inv["Weapons"] or {}
            inv["Weapons"]["hg_sling"] = true
            inv["Weapons"]["hg_flashlight"] = true
            ply:SetNetVar("Inventory", inv)

            if playerClass == "refugee" or playerClass == "citizen" then
                ply:SetPlayerClass("Refugee", {bNoEquipment = playerClass == "citizen"})
                zc.GiveRole(ply, "Refugee", Color(255, 155, 0))
            elseif playerClass == "rebel" then
                ply:SetPlayerClass("Rebel")
                zc.GiveRole(ply, "Rebel", Color(255, 155, 0))
            end

            ply:Give("weapon_hands_sh")
            ply:SelectWeapon("weapon_hands_sh")
        end
    end)
end)
