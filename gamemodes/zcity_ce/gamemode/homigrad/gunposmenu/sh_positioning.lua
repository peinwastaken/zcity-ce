if CLIENT then
    zc.GunPositions = zc.GunPositions or {}
    zc.GunPositions[LocalPlayer()] = zc.GunPositions[LocalPlayer()] or {}

    cvars.AddChangeCallback("zc_gunorigin_x", function(convar_name, value_old, value_new)
        zc.GunPositions[LocalPlayer()][1] = value_new
    end,"cback1")
    cvars.AddChangeCallback("zc_gunorigin_y", function(convar_name, value_old, value_new)
        zc.GunPositions[LocalPlayer()][2] = value_new
    end,"cback2")
    cvars.AddChangeCallback("zc_gunorigin_z", function(convar_name, value_old, value_new)
        zc.GunPositions[LocalPlayer()][3] = value_new
    end,"cback3")
end

if SERVER then
    local time = 0
    zc.GunPositions = zc.GunPositions or {}


    util.AddNetworkString("ZC_GunPositioningSync")
    hook.Add("Think","ZC_GunPositionChanged",function()
        if time > CurTime() then return end
        time = CurTime() + 1
        local NetworkingTable = {}

        for _, ply in player.Iterator() do
            local v1 = math.Clamp(ply:GetInfoNum("zc_gunorigin_x",0),-4,4)
            local v2 = math.Clamp(ply:GetInfoNum("zc_gunorigin_y",0),-4,4)
            local v3 = math.Clamp(ply:GetInfoNum("zc_gunorigin_z",0),-4,4)
            local changedtable = zc.GunPositions[ply].ChangedTable or {}
            local gunpostable = {v1,v2,v3,ChangedTable = changedtable}
            zc.GunPositions[ply] = gunpostable

            local val1 = zc.IsChanged(v1,1,zc.GunPositions[ply])
            local val2 = zc.IsChanged(v2,2,zc.GunPositions[ply])
            local val3 = zc.IsChanged(v3,3,zc.GunPositions[ply])

            if val1 or val2 or val3 then
                NetworkingTable[ply] = zc.GunPositions[ply]
            end
        end

        net.Start("ZC_GunPositioningSync",true)
            net.WriteTable(NetworkingTable)
        net.Broadcast()
    end)

    hook.Add("PlayerInitialSpawn", "ZC_SendGunPos", function(ply)
        zc.GunPositions[ply] = {ply:GetInfoNum("zc_gunorigin_x",0),ply:GetInfoNum("zc_gunorigin_y",0),ply:GetInfoNum("zc_gunorigin_z",0)}
        timer.Simple(1, function()
            net.Start("ZC_GunPositioningSync")
                net.WriteTable(zc.GunPositions)
            net.Send(ply)
        end)
    end)
else
    net.Receive("ZC_GunPositioningSync",function()
        local net_tbl = net.ReadTable()
        zc.GunPositions = table.Merge(zc.GunPositions,net_tbl)
    end)
end