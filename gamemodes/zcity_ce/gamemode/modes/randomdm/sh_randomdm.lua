local MODE = MODE

MODE.base = "dm"
MODE.name = "randomdm"
MODE.PrintName = "Random Deathmatch"
MODE.SharedLoadout = false

MODE.Config = {
	["id"] = "randomdm",
	["printname"] = "Random Deathmatch",
	["settings"] = {
		{
			["id"] = "sharedloadout",
			["label"] = "Shared loadout",
			["description"] = "Give every player the same random loadout",
			["default"] = false,
			["value"] = false,
			["variable"] = "SharedLoadout"
		}
	}
}
