local MODE = MODE

MODE.base = "dm"
MODE.name = "randomdm"
MODE.PrintName = "Random Deathmatch"
MODE.SharedLoadout = false

MODE.Intro = {
	Title = "Random Deathmatch",
	Objective = "Kill everyone.",
	Role = "Fighter",
	Color = Color(190, 15, 15),
	Sound = "snd_jack_hmcd_deathmatch.mp3"
}

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
