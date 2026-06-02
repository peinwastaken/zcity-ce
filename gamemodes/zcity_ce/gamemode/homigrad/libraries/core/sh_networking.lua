zc = zc or {}

if (CLIENT) then
    local entityMeta = FindMetaTable("Entity")
    local playerMeta = FindMetaTable("Player")

    zc.net = zc.net or {}
    zc.net.globals = zc.net.globals or {}

    net.Receive("ZC_GlobalVarSet", function()
        local key, var = net.ReadString(), net.ReadType()

    	zc.net.globals[key] = var

        hook.Run("ZC_OnGlobalVarSet", key, var)
    end)

    net.Receive("ZC_NetVarSet", function()
        local index = net.ReadUInt(16)

		local key = net.ReadString()
    	local var = net.ReadType()
		
        zc.net[index] = zc.net[index] or {}
        zc.net[index][key] = var

		-- print(index, key)
		
		if IsValid(Entity(index)) then
			hook.Run("ZC_OnNetVarSet", index, key, var)
		else
			zc.net[index].waiting = true
		end
    end)
	
    net.Receive("ZC_NetVarDelete", function()
    	zc.net[net.ReadUInt(16)] = nil
    end)

    net.Receive("ZC_LocalVarSet", function()
    	local key = net.ReadString()
    	local var = net.ReadType()

    	zc.net[LocalPlayer():EntIndex()] = zc.net[LocalPlayer():EntIndex()] or {}
    	zc.net[LocalPlayer():EntIndex()][key] = var

		hook.Run("ZC_OnLocalVarSet", key, var)
    end)

    function GetNetVar(key, default) -- luacheck: globals GetNetVar
    	local value = zc.net.globals[key]

    	return value != nil and value or default
    end

    function entityMeta:GetNetVar(key, default)
    	local index = self:EntIndex()

    	if (zc.net[index] and zc.net[index][key] != nil) then
    		return zc.net[index][key]
    	end

    	return default
    end

    playerMeta.GetLocalVar = entityMeta.GetNetVar

	hook.Add("InitPostEntity", "ZC_OnRequestFullUpdateZb", function()
		LocalPlayer():SyncVars()
	end)

	function playerMeta:SyncVars()
		net.Start("ZC_FullUpdateRequest")
		net.SendToServer()
	end
else
	util.AddNetworkString("ZC_FullUpdateRequest")

	net.Receive("ZC_FullUpdateRequest",function(len,ply)
		ply.cooldown_sendnet = ply.cooldown_sendnet or 0
		if ply.cooldown_sendnet < CurTime() then
			ply.cooldown_sendnet = CurTime() + 1

			ply:SyncVars()
		end
	end)

	gameevent.Listen( "OnRequestFullUpdate" )
	hook.Add("OnRequestFullUpdate", "ZC_OnRequestFullUpdateZb", function(data)
		local id = data.userid
		local ply = Player(id)
		
		ply:SyncVars()
	end)
	
	
    local entityMeta = FindMetaTable("Entity")
    local playerMeta = FindMetaTable("Player")

    zc.net = zc.net or {}
    zc.net.list = zc.net.list or {}
    zc.net.locals = zc.net.locals or {}
    zc.net.globals = zc.net.globals or {}

    util.AddNetworkString("ZC_GlobalVarSet")
    util.AddNetworkString("ZC_LocalVarSet")
    util.AddNetworkString("ZC_NetVarSet")
    util.AddNetworkString("ZC_NetVarDelete")

    local function CheckBadType(name, object)
		return false
    	--[[if (isfunction(object)) then
    		ErrorNoHalt("Net var '" .. name .. "' contains a bad object type!")

    		return true
    	elseif (istable(object)) then
    		for k, v in pairs(object) do
    			if (CheckBadType(name, k) or CheckBadType(name, v)) then
    				return true
    			end
    		end
    	end--]]
    end

    function GetNetVar(key, default)
    	local value = zc.net.globals[key]

    	return value != nil and value or default
    end

    function SetNetVar(key, value, receiver, unreliable)
    	if (CheckBadType(key, value)) then return end
    	--if (GetNetVar(key) == value) then return end
		
    	zc.net.globals[key] = value

    net.Start("ZC_GlobalVarSet", unreliable)
    	net.WriteString(key)
    	net.WriteType(value)

    	if (receiver == nil) then
    		net.Broadcast()
    	else
    		net.Send(receiver)
    	end
    end
	
    function playerMeta:SyncVars()
    	for k, v in pairs(zc.net.globals) do
        net.Start("ZC_GlobalVarSet")
    			net.WriteString(k)
    			net.WriteType(v)
    		net.Send(self)
    	end

    	for k, v in pairs(zc.net.locals[self] or {}) do
        net.Start("ZC_LocalVarSet")
    			net.WriteString(k)
    			net.WriteType(v)
    		net.Send(self)
    	end

    	for entity, data in pairs(zc.net.list) do
    		if (IsValid(entity)) then
    			local index = entity:EntIndex()

    			for k, v in pairs(data) do
                net.Start("ZC_NetVarSet")
    					net.WriteUInt(index, 16)
    					net.WriteString(k)
    					net.WriteType(v)
    				net.Send(self)
    			end
			else
				zc.net.list[entity] = nil
    		end
    	end
    end
	
    function playerMeta:GetLocalVar(key, default)
    	if (zc.net.locals[self] and zc.net.locals[self][key] != nil) then
    		return zc.net.locals[self][key]
    	end

    	return default
    end

    function playerMeta:SetLocalVar(key, value)
    	if (CheckBadType(key, value)) then return end

    	zc.net.locals[self] = zc.net.locals[self] or {}
    	zc.net.locals[self][key] = value

    net.Start("ZC_LocalVarSet")
    		net.WriteString(key)
    		net.WriteType(value)
    	net.Send(self)
    end

    function entityMeta:GetNetVar(key, default)
    	if (zc.net.list[self] and zc.net.list[self][key] != nil) then
    		return zc.net.list[self][key]
    	end

    	return default
    end

    function entityMeta:SetNetVar(key, value, receiver)
    	if (CheckBadType(key, value)) then return end

		zc.net.list[self] = zc.net.list[self] or {}

		--if not zc.IsChanged(value, key, zc.net.list[self]) then return end

    	if (zc.net.list[self][key] != value) then
    		zc.net.list[self][key] = value 
    	end
		
		self:SendNetVar(key, receiver)
	end

    function entityMeta:SendNetVar(key, receiver)
    net.Start("ZC_NetVarSet")
    	net.WriteUInt(self:EntIndex(), 16)
    	net.WriteString(key)
    	net.WriteType(zc.net.list[self] and zc.net.list[self][key])

    	if (receiver == nil) then
    		net.Broadcast()
    	else
    		net.Send(receiver)
    	end
    end

    function entityMeta:ClearNetVars(receiver)
    	zc.net.list[self] = nil
    	zc.net.locals[self] = nil

    net.Start("ZC_NetVarDelete")
    	net.WriteUInt(self:EntIndex(), 16)

    	if (receiver == nil) then
    		net.Broadcast()
    	else
    		net.Send(receiver)
    	end
    end
	
	hook.Add("EntityRemoved","ZC_ClearEntityNetVars",function(ent,fullUpdate)
		ent:ClearNetVars()
	end)

	hook.Add("PlayerDisconnected","ZC_ClearPlayerNetVarsOnDisconnect",function(ply)
		ply:ClearNetVars()
	end)
end
