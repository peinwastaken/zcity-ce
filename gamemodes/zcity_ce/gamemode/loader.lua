zc = zc or {}
zc.Version = "1.0.0"
zc.GitHub_ReposOwner = "peinwastaken"
zc.GitHub_ReposName = "zcity-ce"
zc.Authors = {"uzelezz", "Sadsalat", "Mr.Point", "Zac90", "Deka", "Mannytko"}
zc.Authors_CE = {"pein", "NERO2k", "r4tb0y", "senvixe", "ChatGPT"}

local loadedFiles = {}

local sides = {
	["sv_"] = "sv_",
	["sh_"] = "sh_",
	["cl_"] = "cl_",
	["_sv"] = "sv_",
	["_sh"] = "sh_",
	["_cl"] = "cl_",
}

local function IncluderFunc(fileName, defaultSide)
	if loadedFiles[fileName] then return end
	loadedFiles[fileName] = true

	local shortName = string.GetFileFromFilename(fileName)
	local fileSide = string.lower(string.Left(shortName, 3))
	local fileSide2 = string.lower(string.Right(string.sub(shortName, 1, -5), 3))
	local side = sides[fileSide] or sides[fileSide2] or defaultSide

	if SERVER and side == "sv_" then
		include(fileName)
	elseif side == "sh_" then
		if SERVER then AddCSLuaFile(fileName) end
		include(fileName)
	elseif side == "cl_" then
		if SERVER then
			AddCSLuaFile(fileName)
		else
			include(fileName)
		end
	else
		if SERVER then AddCSLuaFile(fileName) end
		include(fileName)
	end
end

local function LoadFromDir(directory, foldersFirst, defaultSide)
	local files, folders = file.Find(directory .. "/*", "LUA")

	if foldersFirst then
		for _, v in ipairs(folders or {}) do
			LoadFromDir(directory .. "/" .. v, foldersFirst, defaultSide)
		end
	end

	for _, v in ipairs(files or {}) do
		if string.EndsWith(v, ".lua") then
			IncluderFunc(directory .. "/" .. v, defaultSide)
		end
	end

	if !foldersFirst then
		for _, v in ipairs(folders or {}) do
			LoadFromDir(directory .. "/" .. v, foldersFirst, defaultSide)
		end
	end
end

local function LoadIfExists(directory, foldersFirst, defaultSide)
	if !file.IsDir(directory, "LUA") then return end

	LoadFromDir(directory, foldersFirst, defaultSide)
end

local function LoadVendorFile(fileName)
	if !file.Exists(fileName, "LUA") then
		ErrorNoHalt("[Z-City] Missing gamemode vendor file: " .. fileName .. "\n")
		return
	end

	IncluderFunc(fileName, "sh_")
end

local function LoadVendorRuntime()
	LoadVendorFile("zcity_ce/gamemode/vendor/glide/sh_glide.lua")
	LoadVendorFile("zcity_ce/gamemode/vendor/glide/sh_gtav_helicopters.lua")

	LoadVendorFile("zcity_ce/gamemode/vendor/vfire/sh_misc.lua")
	LoadVendorFile("zcity_ce/gamemode/vendor/vfire/sh_creation.lua")
	LoadVendorFile("zcity_ce/gamemode/vendor/vfire/sh_game_modifications.lua")

	LoadVendorFile("zcity_ce/gamemode/vendor/wos/sh_dynabase_loader.lua")
end

zc.loaded = false

LoadVendorRuntime()
LoadIfExists("zcity_ce/gamemode/libraries/globals", true)
LoadIfExists("zcity_ce/gamemode/homigrad", false)
LoadIfExists("zcity_ce/gamemode/libraries", true)

zc.loaded = true
hook.Run("ZC_OnLoaded")

hook.Add("InitPostEntity", "ZC_LoadInitPostFiles", function()
	LoadIfExists("zcity_ce/gamemode/initpost", false)
end)

timer.Simple(5, function()
	if !istable(ulx) then
		for _ = 1, 6 do
			MsgC(Color(255, 0, 0), "WARNING: Server doesn't have ULX & ULib installed! Z-City will not work properly without it!\n")
		end
	end

	if game.SinglePlayer() then
		for _ = 1, 3 do
			MsgC(Color(255, 0, 0), "WARNING: Game started in singleplayer! Z-City may not work properly until you start multiplayer game!\n")
		end
	end
end)

zc.modesHooks = {}
zc.modes = zc.modes or {}

local function addModeHook( MODE, hookName, func )
	zc.modesHooks[MODE.name] = zc.modesHooks[MODE.name] or {}
	zc.modesHooks[MODE.name][hookName] = func

	hook.Add( hookName, "ZC_ModeHook" .. hookName, function( ... )
		local Current = zc.CROUND_MAIN or zc.CROUND or "tdm"

		local modeHooks = zc.modesHooks[Current]
		if modeHooks and modeHooks[hookName] then
			local ModeTable = zc.modes[Current]
			local a, b, c, d, e, f = modeHooks[hookName]( ModeTable, zc.round, ... )

			if a ~= nil then
				return a, b, c, d, e, f
			end
		end
	end )
end

-- Lifecycle callbacks are called by the round controller / selection code,
-- never registered as GMod hooks. Only entries inside MODE.Hooks are
-- registered as hooks.

local function RegisterModeHooks( MODE )
	-- Only explicit entries inside MODE.Hooks are registered as hooks.
	if not istable(MODE.Hooks) then return end

	for hookName, func in pairs(MODE.Hooks) do
		addModeHook(MODE, hookName, func)
	end
end

-- Modes are collected first and finalized afterwards, so a base mode does
-- not need to appear earlier alphabetically.
local pendingModes = {}
local pendingModeOrder = {}

local function CollectMode()
	if table.IsEmpty(MODE) then return end

	local name = MODE.name
	local saved = zc.modes[name] and zc.modes[name].saved or {} -- saved table is used for saving data between hotloads

	zc.modes[name] = nil
	pendingModes[name] = { def = MODE, saved = saved }
	pendingModeOrder[#pendingModeOrder + 1] = name
end

local finalizedModes = {}
local resolvingModes = {}

local function FinalizeMode(name)
	if finalizedModes[name] then return zc.modes[name] end

	local entry = pendingModes[name]
	if not entry then return nil end

	if resolvingModes[name] then
		ErrorNoHalt("[Z-City] Mode inheritance loop at '" .. tostring(name) .. "'\n")
		return nil
	end

	resolvingModes[name] = true

	local MODE = entry.def

	if MODE.base then
		local childHooks = MODE.Hooks
		local parent = FinalizeMode(MODE.base)

		if not parent then
			ErrorNoHalt("[Z-City] Mode '" .. tostring(name) .. "' inherits from missing or invalid base mode '" .. tostring(MODE.base) .. "'\n")
			resolvingModes[name] = nil
			return nil
		end

		table.Inherit(MODE, parent)

		-- Inherited tables must not share mutable state with their parent.
		for key, value in pairs(MODE) do
			if key ~= "base" and key ~= "Hooks" and istable(value) then
				MODE[key] = table.Copy(value)
			end
		end

		if istable(parent.Hooks) or istable(childHooks) then
			local hooks = istable(parent.Hooks) and table.Copy(parent.Hooks) or {}
			for hookName, func in pairs(childHooks or {}) do
				hooks[hookName] = func
			end
			MODE.Hooks = hooks
		end

		if MODE.AfterBaseInheritance then
			MODE:AfterBaseInheritance()
		end
	end

	zc.modes[name] = MODE
	zc.modes[name].saved = entry.saved
	resolvingModes[name] = nil
	finalizedModes[name] = true

	if SERVER then
		if MODE.SetupChances then
			MODE:SetupChances()
		else
			zc.ModesChances[name] = zc.ModesChances[name] or MODE.Chance
		end
	end

	RegisterModeHooks(MODE)
	return MODE
end

local function InitMode()
	if table.IsEmpty(MODE) then return end

	CollectMode()
end

local chancesfile = "config/modes_chances.json"

if SERVER then
	hook.Add("ShutDown", "ZC_SaveModeChances", function()
		zc.WriteData(chancesfile, zc.ModesChances or {}, true)
	end)

	concommand.Add("zb_getmodeschances", function(ply, cmd, args)
		ply:zChatPrint(util.TableToJSON(zc.ModesChances, true))
	end)

	concommand.Add("zb_setmodechance", function(ply, cmd, args)
		local mode = args[1]
		local chance = tonumber(args[2])

		if !zc.ModesChances[mode] or !chance then return end

		zc.ModesChances[mode] = chance
	end)

	concommand.Add("zb_savemodeschances", function(ply, cmd, args)
		zc.WriteData(chancesfile, zc.ModesChances or {}, true)
	end)
end

local function LoadModes()
	local directory = "zcity_ce/gamemode/modes"
	local files, folders = file.Find(directory .. "/*", "LUA")

	if SERVER then
		zc.ModesChances = zc.ParseDataFile(chancesfile, {})
	end

	-- Pass 1: discover and execute every mode definition.
	for _, v in ipairs(files) do
		MODE = {}
		IncluderFunc(directory .. "/" .. v)
		InitMode()
		MODE = nil
	end

	for _, v in ipairs(folders) do
		MODE = {}
		LoadFromDir(directory .. "/" .. v, true, "sv_")
		InitMode()
		MODE = nil
	end

	-- Pass 2: resolve inheritance now that every mode table exists.
	for _, name in ipairs(pendingModeOrder) do
		FinalizeMode(name)
	end

	pendingModes = {}
	pendingModeOrder = {}
	finalizedModes = {}
	resolvingModes = {}

	if SERVER and !zc.DataFileExists(chancesfile) then
		zc.WriteData(chancesfile, zc.ModesChances, true)
	end

	if SERVER then
		zc.modeconfig.LoadAll()
	end
end

LoadModes()

print("Z-City modes loaded!")
