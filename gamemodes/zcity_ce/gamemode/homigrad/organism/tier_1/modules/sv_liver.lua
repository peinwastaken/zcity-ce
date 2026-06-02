--local Organism = zc.organism
zc.organism.module.liver = {}
local module = zc.organism.module.liver
module[1] = function(org)
	org.liver = 0
end

module[2] = function(owner, org, mulTime)
	if not org.alive or org.hearstop then return end

	--fuckass
end