-- Point system, spawns, and everything else that needs map coordinates.
zc = zc or {}

zc.Points = zc.Points or {}

zc.Points.Example = zc.Points.Example or {}

function zc.CreateMapDir()
    local map = game.GetMap()
    if not file.Exists( "zbattle", "DATA" ) then file.CreateDir( "zbattle/mappoints" ) end
    if not file.Exists( "zbattle/mappoints/" .. map, "DATA" ) then file.CreateDir( "zbattle/mappoints/" .. map ) end
    if file.Exists( "zbattle/mappoints/" .. map, "DATA" ) then return true end
end

function zc.GetMapPoints( pointGroup, forceupdatepoints ) -- Load points into game memory... The client will have roughly the same function.
    if not zc.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exist?" ) return false end
    if not zc.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    forceupdatepoints = forceupdatepoints or false
    if (not forceupdatepoints) and zc.Points[pointGroup].Points then
        local newTbl = {}
        table.CopyFromTo(zc.Points[pointGroup].Points,newTbl)
        return newTbl
    end

    local map = game.GetMap()

    zc.Points[pointGroup].Points = util.JSONToTable( file.Read( "zbattle/mappoints/" .. map .. "/"..pointGroup..".json", "DATA" ) or "" )

    local newTbl = {}
    if zc.Points[pointGroup].Points then
        table.CopyFromTo(zc.Points[pointGroup].Points,newTbl)
    end

    return newTbl
end--undebiled this function no need to thank me

-- pointsData = zc.Points[pointGroup].Points  // Points table
function zc.SaveMapPoints( pointGroup, pointsData ) -- Saves all points in the group
    if not zc.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exists?" ) return false end
    if not zc.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    local map = game.GetMap()

    file.Write( "zbattle/mappoints/" .. map .. "/" .. pointGroup .. ".json", util.TableToJSON( pointsData, true ) )
end

-- pointData = { pos = Vector(), ang = Angle() } // Point table
function zc.CreateMapPoint( pointGroup, pointData, needsave ) -- Create a point on the map, and should it be saved?
    if not zc.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exists?" ) return false end
    if not zc.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    zc.Points[pointGroup].Points = zc.Points[pointGroup].Points or zc.GetMapPoints( pointGroup )

    zc.Points[pointGroup].Points[ #zc.Points[pointGroup].Points + 1 ] = pointData
    needsave = needsave or true
    if needsave then
        zc.SaveMapPoints( pointGroup, zc.Points[pointGroup].Points )
    end
end

function zc.RemoveMapPoint( pointGroup, pointNum, needsave, removeall ) -- Create a point on the map, and should it be saved?
    if not zc.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder dosen't exists?" ) return false end
    if not zc.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    zc.Points[pointGroup].Points = zc.Points[pointGroup].Points or zc.GetMapPoints( pointGroup )
    --zc.Points[pointGroup].Points[ math.Clamp(pointNum, 1, #zc.Points[pointGroup].Points) ]
    removeall = removeall or false
    if removeall then zc.Points[pointGroup].Points = {} else
        if not zc.Points[pointGroup].Points[ math.Clamp(pointNum or 0, 1, #zc.Points[pointGroup].Points) ] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point dosen't exist." ) return false end
        table.remove( zc.Points[pointGroup].Points, math.Clamp(pointNum or 0, 1, #zc.Points[pointGroup].Points) )
    end

    needsave = needsave or true
    if needsave then
        zc.SaveMapPoints( pointGroup, zc.Points[pointGroup].Points )
    end
    return true
end

function zc.SetMapPoint( pointGroup, pointNum, pointData, needsave ) -- Create a point on the map, and should it be saved?
    if not zc.CreateMapDir() then PrintMessage( HUD_PRINTTALK, "sv_points.lua: map folder couldn't be created." ) return false end
    if not zc.Points[pointGroup] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point group " .. "\"" .. pointGroup .. "\"" .. " doesn't exist." ) return false end

    zc.Points[pointGroup].Points = zc.Points[pointGroup].Points or zc.GetMapPoints( pointGroup )
    if not zc.Points[pointGroup].Points[ math.Clamp(pointNum, 1, #zc.Points[pointGroup].Points) ] then PrintMessage( HUD_PRINTTALK, "sv_points.lua: point dosen't exist." ) return false end

    zc.Points[pointGroup].Points[ math.Clamp(pointNum, 1, #zc.Points[pointGroup].Points) ] = pointData

    if needsave then
        zc.SaveMapPoints( pointGroup, zc.Points[pointGroup].Points )
    end
    return true
end

function zc.GetAllPoints(forceupdate)
    forceupdate = forceupdate or true--ALWAYS TRUE LMAOOOOOO
    allpoints = {}
    for k, _ in pairs(zc.Points) do
        pointgroups = zc.GetMapPoints( k, forceupdate )
        if not pointgroups then continue end
        allpoints[k] = pointgroups
    end

    hook.Run("ZC_AfterMapPointsLoaded",zc.Points)

    return allpoints
end

hook.Add("InitPostEntity", "ZC_InitMapPoints", function()
    zc.GetAllPoints(true)
end)

//zc.GetAllPoints()

hook.Add( "Initialize", "ZC_LoadMapPoints", zc.CreateMapDir )
--PrintTable(zc.Points.Example.Points)
-- pointData = { pos = Vector(), ang = Angle() } // Point table
COMMANDS.pointnew = {function(ply,args)
    if not args[1] then
        ply:ChatPrint("Usage: !pointnew <pointGroup>")
        return
    end
    local ang = ply:EyeAngles()
    ang.x = 0
    local pointData = {
        pos = ply:GetPos(),
        ang = ang
    }

    zc.CreateMapPoint( args[1], pointData )

    ply:ConCommand("zb_pointsupdate")

end,1,"Creates a new point on the map\nArgs - pointGroup"}

COMMANDS.pointset = {function(ply,args)
    if not args[1] or not args[2] then
        ply:ChatPrint("Usage: !pointset <pointGroup> <pointNumber>")
        return
    end

    zc.SetMapPoint( args[1], args[2], args[3] )

    ply:ConCommand("zb_pointsupdate")

end,1,"Sets a point on the map\nArgs - pointGroup, pointNumber"}

COMMANDS.pointremove = {function(ply,args)
    if not args[1] then
        ply:ChatPrint("Usage: !pointremove <pointGroup> <pointNumber|*>\nUse * to remove all points")
        return
    end

    zc.RemoveMapPoint( args[1], args[2], true, args[2] == "*" )

    ply:ConCommand("zb_pointsupdate")

end,1,"Remove point (points) on the map\nArgs - pointGroup, pointNumber ( * - allpoints )"}

-- Send points to the client

function zc.SendPointsToPly(ply, shouldprint)
    net.Start("ZC_MapPointsGetAll")
        net.WriteTable(zc.GetAllPoints())
    net.Send(ply)

    if shouldprint then
        ply:ChatPrint("Points: Points transferred")
    end
end

function zc.SendPoints()
    local rf = RecipientFilter()

    for _, v in player.Iterator() do
        rf:AddPlayer(v)
    end

    net.Start("ZC_MapPointsGetAll")
        net.WriteTable(zc.GetAllPoints())
    net.Send(rf)
end

function zc.SendSpecificPointsToPly(ply, pointGroup, shouldprint)
    net.Start("ZC_MapPointsGetSpecific")
        net.WriteString(pointGroup)
        net.WriteTable(zc.GetAllPoints()[pointGroup])
    if IsValid(ply) then
        net.Send(ply)

        if shouldprint then
            ply:ChatPrint("Points: Points transferred")
        end
    else
        net.Broadcast()
    end
end

local angZero = Angle(0,0,0)

function zc.TranslateVectorsToPoints(tbl)
	local newtbl = {}
	for _,val in pairs(tbl) do
		if istable(val) then
			if val.pos and val.ang and isvector(val.pos) and isangle(val.ang) then table.insert(newtbl,val) end
		end
		if isvector(val) then table.insert(newtbl,{pos = val,ang = angZero}) end
	end
	return newtbl
end

function zc.TranslatePointsToVectors(tbl)
	local newtbl = {}

	for _,val in pairs(tbl) do
		if istable(val) then
			if val.pos and val.ang and isvector(val.pos) and isangle(val.ang) then
                table.insert(newtbl,val.pos)
            end
		end

		if isvector(val) then table.insert(newtbl, val) end
	end

	return newtbl
end

net.Receive("ZC_MapPointsGetAll",function(len,ply)
    if not ply:IsAdmin() then ply:ChatPrint("Points: Access denied") return end

    zc.SendPointsToPly(ply, true)
end)

function zc.tdm_checkpoints()
    local vecs = {}
    local points = zc.GetMapPoints( "HMCD_TDM_T" )
    for _,ent in pairs(ents.FindByClass("info_player_terrorist")) do
        table.insert(vecs,ent:GetPos())
    end

    local points = #points == 0 and zc.TranslateVectorsToPoints(vecs) or points

    if #zc.GetMapPoints( "HMCD_TDM_T" ) == 0 then
        zc.SaveMapPoints( "HMCD_TDM_T", points )
    end
    if #zc.GetMapPoints( "RIOT_TDM_RIOTERS" ) == 0 then
        zc.SaveMapPoints( "RIOT_TDM_RIOTERS", points )
    end
    if #zc.GetMapPoints( "HMCD_CRI_T" ) == 0 then
        zc.SaveMapPoints( "HMCD_CRI_T", points )
    end

    --||

    local vecs = {}
    local points = zc.GetMapPoints( "HMCD_TDM_CT" )
    for _, ent in pairs(ents.FindByClass("info_player_counterterrorist")) do
        table.insert(vecs, ent:GetPos())
    end

    local points = #points == 0 and zc.TranslateVectorsToPoints(vecs) or points

    if #zc.GetMapPoints( "HMCD_TDM_CT" ) == 0 then
        zc.SaveMapPoints( "HMCD_TDM_CT", points )
    end
    if #zc.GetMapPoints( "HMCD_CRI_CT" ) == 0 then
        zc.SaveMapPoints( "HMCD_CRI_CT", points )
    end
    if #zc.GetMapPoints( "RIOT_TDM_LAW" ) == 0 then
        zc.SaveMapPoints( "RIOT_TDM_LAW", points )
    end

    --||

    local foundA
    local foundB
    for _, ent in ipairs(ents.FindByClass("func_bomb_target")) do
        local vecs = {}
        local min, max = ent:WorldSpaceAABB()

        vecs[1] = min
        vecs[2] = max

        if not foundB then
            local points = zc.TranslateVectorsToPoints(vecs)
            zc.SaveMapPoints( "BOMB_ZONE_B", points )
            foundB = true
            continue
        end

        if not foundA then
            local points = zc.TranslateVectorsToPoints(vecs)
            zc.SaveMapPoints( "BOMB_ZONE_A", points )
            foundA = true
            continue
        end
    end

    local points = {}
    for _, ent in pairs(ents.FindByClass("func_hostage_rescue")) do

        local min, max = ent:WorldSpaceAABB()

        table.insert(points, min)
        table.insert(points, max)
    end

    points = zc.TranslateVectorsToPoints(points)

    if #zc.GetMapPoints( "HOSTAGE_DELIVERY_ZONE" ) == 0 then
        zc.SaveMapPoints( "HOSTAGE_DELIVERY_ZONE", points )
    end
end

--[[for i,ent in pairs(ents.FindInSphere(Entity(1):GetPos(),60)) do
    local enta = ents.Create("prop_physics")
	enta:SetModel("models/props_c17/lampShade001a.mdl")
	enta:SetPos(ent:GetPos())
	enta:Spawn()
	enta:SetSolidFlags(FSOLID_NOT_SOLID)
	enta:GetPhysicsObject():EnableMotion(false)
    print(ent)
end--]]


hook.Add("PostCleanupMap","ZC_ClearTeamSpawnPoints",function()
    zc.tdm_checkpoints()
end)
