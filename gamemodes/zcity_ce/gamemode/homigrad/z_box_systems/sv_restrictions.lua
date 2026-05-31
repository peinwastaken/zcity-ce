-- Spawn restrictions for items and other unnecessary shit.
ZBox = ZBox or {}
ZBox.Plugins = ZBox.Plugins or {}
ZBox.Plugins["Restrictions"] = ZBox.Plugins["Restrictions"] or {}
local PLUGIN = ZBox.Plugins["Restrictions"]

PLUGIN.Name = "Restrictions"

PLUGIN.Hooks = {}
local Hook = PLUGIN.Hooks
local DisableHookSpawns = {
    "PlayerSpawnVehicle",
    "PlayerSpawnRagdoll",
    "PlayerSpawnNPC",
    "PlayerSpawnEffect"
}
for _, v in pairs(DisableHookSpawns) do
    Hook[v] = function(ply)
        local mode = CurrentRound and CurrentRound()
        if game.SinglePlayer() or ply:IsAdmin() or (mode and mode.AllowSpawnMenu) then return true end
        --if ply:IsAdmin() then
            --return true
        --else
            return false
        --end
    end
end


-- Shit delivery!

function Hook.PlayerSpawnProp(ply, model)
    --if ply:IsAdmin() and (ply:GetActiveWeapon():GetClass() == "gmod_tool" or ply:GetActiveWeapon():GetClass() == "weapon_physgun") then
    --    return
    --end
--
    --ply.PropCD = ply.PropCD or 0
    --ply.Props = ply.Props or 0
    --if ply.PropCD < CurTime() then
    --    ply.PropCD = CurTime() + 1 + math.min(ply.Props / 15, 5)
    --    local pos = hg.eyeTrace(ply).HitPos
    --    local tr = util.TraceLine({
    --        start = pos,
    --        endpos = pos + vector_up * 9999,
    --        mask = MASK_SOLID_BRUSHONLY,
    --    })
    --    if tr.HitSky then
    --        ply.Props = ply.Props + 1
    --        ply:ChatPrint("Prop was called, estimated time of delivery 5-7 seconds.")
    --        timer.Create("SendProp" .. ply:EntIndex() .. model .. CurTime(), math.random(5, 7), 1, function()
    --            if not IsValid(ply) then return end
    --            local ent = ents.Create("prop_physics")
    --            ent:SetModel(model)
    --            if ent:BoundingRadius() > 200 then ply:ChatPrint("This shit so big, we can't deliver big PROPS.") ent:Remove() return false end
    --            ent:SetPos(tr.HitPos - tr.HitNormal * ent:BoundingRadius())
    --            ent:Spawn()
    --            ply:ChatPrint("Prop delivered!")
    --        end)
    --    end
    --    return false
    --else
    --    ply:ChatPrint(ply.Props < 15 and "Eh... Can you wait? We don't have time to prepare the delivery..." or table.Random(RandomPrashe))
    --    return false
    --end
end

--Weapon restriction...
function Hook.PlayerSpawnSWEP(ply, class)
    local mode = CurrentRound and CurrentRound()
    if game.SinglePlayer() or ply:IsAdmin() or (mode and mode.AllowSpawnMenu) then return true end
    --if ply:IsAdmin() and (class == "gmod_tool" or class == "weapon_physgun") then
    --    return
    --end
    if not ply:IsAdmin() then return false end
    --if weaponRestrict[class] and not ply:IsAdmin() then return false end
    --ply.WeaponCD = ply.WeaponCD or 0
    --if ply.WeaponCD < CurTime() then
    --    ply.WeaponCD = CurTime() + 5
    --    local pos = hg.eyeTrace(ply).HitPos
    --    local tr = util.TraceLine({
    --        start = pos,
    --        endpos = pos + vector_up * 9999,
    --        mask = MASK_SOLID_BRUSHONLY,
    --    })
    --    if tr.HitSky then
    --        ply:ChatPrint("Weapon was called, estimated time of delivery 5-7 seconds.")
    --        timer.Create("SendWeapon" .. ply:EntIndex() .. class .. CurTime(), math.random(5, 7), 1, function()
    --            if not IsValid(ply) then return end
    --            local ent = ents.Create(class)
    --            ent.IsSpawned = true
    --            ent:SetPos(tr.HitPos - tr.HitNormal * ent:BoundingRadius())
    --            ent:Spawn()
    --            ply:ChatPrint("Weapon delivered!")
    --        end)
    --    end
    --    return false
    --else
    --    ply:ChatPrint("Eh... Can you wait? We don't have time to prepare the delivery...")
    --    return false
    --end
end


function Hook.PlayerGiveSWEP(ply,class)
    local mode = CurrentRound and CurrentRound()
    if game.SinglePlayer() or ply:IsAdmin() or (mode and mode.AllowSpawnMenu) then return true end
    --if ply:IsAdmin() and (class == "gmod_tool" or class == "weapon_physgun") then
       -- return
    --end
    if not ply:IsAdmin() then return false end
    --if weaponRestrict[class] and !ply:IsAdmin() then return false end
    --ply.WeaponCD = ply.WeaponCD or 0
    --if ply.WeaponCD < CurTime() then
    --    ply.WeaponCD = CurTime() + 5
    --    local pos = hg.eyeTrace(ply).HitPos
    --    local tr = util.TraceLine({
    --        start = pos,
    --        endpos = pos + vector_up * 9999,
    --        mask = MASK_SOLID_BRUSHONLY,
    --    })
    --    if tr.HitSky then
    --        ply:ChatPrint("Weapon was called, estimated time of delivery 5-7 seconds.")
    --        timer.Create("SendWeapon"..ply:EntIndex()..class..CurTime(),math.random(5,7),1,function()
    --            if not IsValid(ply) then return end
    --            local ent = ents.Create(class)
    --            ent:SetPos(tr.HitPos - tr.HitNormal * ent:BoundingRadius())
    --            ent:Spawn()
    --            ent.Spawned = true
    --            ply:ChatPrint("Weapon delivered!")
    --        end)
    --    end
    --    return false
    --else
    --    ply:ChatPrint("Eh... Can you wait? We don't have time to prepare the delivery...")
    --    return false
    --end
end


function Hook.PlayerSpawnSENT(ply,class)
    local mode = CurrentRound and CurrentRound()
    if game.SinglePlayer() or ply:IsAdmin() or (mode and mode.AllowSpawnMenu) then return true end
    if not ply:IsAdmin() then return false end
    --if entsRestrict[class] and !ply:IsAdmin() then return false end
    --ply.ThingCD = ply.ThingCD or 0
    --if ply.ThingCD < CurTime() then
    --    ply.ThingCD = CurTime() + 5
    --    local pos = hg.eyeTrace(ply).HitPos
    --    local tr = util.TraceLine({
    --        start = pos,
    --        endpos = pos + vector_up * 9999,
    --        mask = MASK_SOLID_BRUSHONLY,
    --    })
    --    if tr.HitSky then
    --        ply:ChatPrint("Thing was called, estimated time of delivery 5-7 seconds.")
    --        timer.Create("SendEnt"..ply:EntIndex()..class..CurTime(),math.random(5,7),1,function()
    --            if not IsValid(ply) then return end
    --            local ent = ents.Create(class)
    --            ent:SetPos(tr.HitPos - tr.HitNormal * ent:BoundingRadius())
    --            ent:Spawn()
    --            ent.Spawned = true
    --            ply:ChatPrint("Things delivered!")
    --        end)
    --    end
    --    return false
    --else
    --    ply:ChatPrint("Eh... Can you wait? We don't have time to prepare the delivery...")
    --    return false
    --end
end

function Hook.PlayerNoClip(ply, desiredState)
    if ply:IsAdmin() then
        return true
    else
        return false
    end
end

