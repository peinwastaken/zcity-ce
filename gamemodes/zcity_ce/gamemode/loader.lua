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
			local a, b, c, d, e, f = modeHooks[hookName]( ModeTable, ... )

			if a ~= nil then
				return a, b, c, d, e, f
			end
		end
	end )
end

local function InitMode()
	if table.IsEmpty(MODE) then return end

	local name = MODE.name
	local saved = zc.modes[name] and zc.modes[name].saved or {} -- saved table is used for saving data between hotloads

	if MODE.base then
		table.Inherit(MODE, zc.modes[MODE.base])

		for i in pairs(MODE) do
			if istable(MODE[i]) and istable(zc.modes[MODE.base][i]) then
				tbl2 = {}

				table.CopyFromTo(MODE[i], tbl2)

				MODE[i] = tbl2
			end
		end

		if MODE.AfterBaseInheritance then
			MODE:AfterBaseInheritance()
		end
	end

	zc.modes[name] = MODE
	zc.modes[name].saved = saved

	if SERVER then
		if MODE.SetupChances then
			MODE:SetupChances()
		else
			zc.ModesChances[name] = zc.ModesChances[name] or MODE.Chance
		end
	end

	for k, v2 in pairs(MODE) do
		if isfunction(v2) then
			addModeHook(MODE, k, v2)
		end
	end
end

local chancesfile = "zbattle/modeschances.json"

if SERVER then
	hook.Add("ShutDown", "ZC_SaveModeChances", function()
		file.Write(chancesfile, util.TableToJSON(zc.ModesChances or {}, true))
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
		file.Write(chancesfile, util.TableToJSON(zc.ModesChances or {}, true))
	end)
end

local function LoadModes()
	local directory = "zcity_ce/gamemode/modes"
	local files, folders = file.Find(directory .. "/*", "LUA")

	if SERVER then
		zc.ModesChances = util.JSONToTable(file.Read(chancesfile,  "DATA") or "") or {}
	end

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

	if SERVER and !file.Exists(chancesfile,  "DATA") then
		file.Write(chancesfile, util.TableToJSON(zc.ModesChances, true))
	end

	if SERVER then
		zc.modeconfig.LoadAll()
	end
end

LoadModes()

print("Z-City modes loaded!")
