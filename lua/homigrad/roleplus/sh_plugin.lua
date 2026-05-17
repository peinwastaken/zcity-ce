--\\
--; TODO
--; The traitor sees other players' subroles at round start
--; The traitor gets time to choose their subrole

--; Traitor subroles:
--=\\Jack of all Trades
--; Everything is standard like now
--=//
--=\\Assassin - OP
--; Weapons:
--; Paralyzing dart spitter (3 darts)
--; Abilities:
--; Take a weapon from the back (even if it is being used), Trip (knocks down)
--; Passives:
--; Expert with any weapon (especially with fists), paralyzes the victim for 3 seconds with a fist hit from behind
--=//

--=\\Saw +- engineer
--; Weapons:
--; Knife, IED
--; Abilities:
--; Hihihihihihihi
--; Passives:
--; Crafting from any props on the map and items
--=//

--=\\Saboteur
--; Weapons:
--; Knife, IED, Grenade, Smoke, Adrenaline, Bear trap???, Door blockers
--; Abilities:
--; Hide in a suitable prop, fully change appearance to a corpse's appearance (including skin), Break neck from behind
--=//

--; Break neck from behind
--//

--\\Translate plugin things into your things
hg.RolePlus = hg.RolePlus or {}
local PLUGIN = hg.RolePlus
PLUGIN.ID = "RolePlus"

function PLUGIN:AddHook(id, func)
	hook.Add(id, "HG.Plugin.List[" .. self.ID .. "].Hooks[" .. id .. "]", func)
end

function PLUGIN:RunHook(id, ...)
	return hook.Run("HG.Plugin.List[" .. self.ID .. "].Hooks[" .. id .. "]", ...)
end
--//

PLUGIN.Name = "RolePlus"
PLUGIN.Description = "Adds subroles"
PLUGIN.Version = 1

