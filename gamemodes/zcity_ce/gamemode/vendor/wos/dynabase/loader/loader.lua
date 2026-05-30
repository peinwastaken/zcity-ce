--[[-------------------------------------------------------------------
	wiltOS Dynamic Animation Base:
			Powered by
						  _ _ _    ___  ____
				__      _(_) | |_ / _ \/ ___|
				\ \ /\ / / | | __| | | \___ \
				 \ V  V /| | | |_| |_| |___) |
				  \_/\_/ |_|_|\__|\___/|____/

 _____         _                 _             _
|_   _|__  ___| |__  _ __   ___ | | ___   __ _(_) ___  ___
  | |/ _ \/ __| '_ \| '_ \ / _ \| |/ _ \ / _` | |/ _ \/ __|
  | |  __/ (__| | | | | | | (_) | | (_) | (_| | |  __/\__ \
  |_|\___|\___|_| |_|_| |_|\___/|_|\___/ \__, |_|\___||___/
                                         |___/
-------------------------------------------------------------------]]--[[

	Lua Developer: King David
	Contact: http://steamcommunity.com/groups/wiltostech

----------------------------------------]]--

wOS = wOS or {}
wOS.DynaBase = wOS.DynaBase or {}

local file = file
local LUA_ROOT = "zcity_ce/gamemode/vendor/wos/dynabase/"

local function RootPath( path )
	return LUA_ROOT .. path
end

local function _AddCSLuaFile( lua )

	if SERVER then
		AddCSLuaFile( lua )
	end

end

local function _include( load_type, lua )

	if load_type then
		include( lua )
	end

end

function wOS.DynaBase:Autoloader()

	_AddCSLuaFile( RootPath( "core/sh_core.lua" ) )
	_include( SERVER, RootPath( "core/sh_core.lua" ) )
	_include( CLIENT, RootPath( "core/sh_core.lua" ) )

	_AddCSLuaFile( RootPath( "core/sh_model_operations.lua" ) )
	_include( SERVER, RootPath( "core/sh_model_operations.lua" ) )
	_include( CLIENT, RootPath( "core/sh_model_operations.lua" ) )

	_AddCSLuaFile( RootPath( "core/sh_mounting.lua" ) )
	_include( SERVER, RootPath( "core/sh_mounting.lua" ) )
	_include( CLIENT, RootPath( "core/sh_mounting.lua" ) )

	_AddCSLuaFile( RootPath( "core/cl_net.lua" ) )
	_include( CLIENT, RootPath( "core/cl_net.lua" ) )

	_AddCSLuaFile( RootPath( "core/cl_core.lua" ) )
	_include( CLIENT, RootPath( "core/cl_core.lua" ) )
	_include( SERVER, RootPath( "core/sv_core.lua" ) )

	_AddCSLuaFile( RootPath( "core/cl_local_copy.lua" ) )
	_include( CLIENT, RootPath( "core/cl_local_copy.lua" ) )

	_AddCSLuaFile( RootPath( "core/cl_config_menu.lua" ) )
	_include( CLIENT, RootPath( "core/cl_config_menu.lua" ) )

	for _,source in pairs( file.Find( RootPath( "registers/*" ), "LUA"), true ) do
		local lua = RootPath( "registers/" .. source )
		_AddCSLuaFile( lua )
		_include( SERVER, lua )
		_include( CLIENT, lua )
	end

end

wOS.DynaBase:Autoloader()
