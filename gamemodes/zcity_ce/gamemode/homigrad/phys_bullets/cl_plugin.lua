hg.PhysBullet = hg.PhysBullet or {}
local PLUGIN = hg.PhysBullet

function PLUGIN.NetworkReceivedBulletCreate()
	local bullet = {}

	for _, info in ipairs(PLUGIN.NetworkTableFull) do
		local key = info[1]
		local read = info[3]
		bullet[key] = read()
	end
	
	if(PLUGIN.BulletsTable[bullet.Key])then
		PLUGIN.BulletsTable[bullet.Key]:Remove()
	end
	
	PLUGIN.CreateBullet(bullet)
end

function PLUGIN.NetworkReceivedBulletUpdate()
	local bullet = nil
	local bullet_key = nil

	for _, info in ipairs(PLUGIN.NetworkTableUpdate) do
		local key = info[1]
		local read = info[3]
		
		if(not bullet_key)then
			bullet_key = read()
			bullet = PLUGIN.BulletsTable[bullet_key]
		else
			if(bullet)then
				bullet[key] = read()
			else
				net.Start("ZC_PhysBulletCreate")
					PLUGIN.net_writekey(bullet_key)
				net.SendToServer()
			
				break
			end
		end
	end
end

net.Receive("ZC_PhysBulletCreate", function(len)
	PLUGIN.NetworkReceivedBulletCreate()
end)

net.Receive("ZC_PhysBulletUpdate", function(len)
	PLUGIN.NetworkReceivedBulletUpdate()
end)

net.Receive("ZC_PhysBulletRemove", function(len)
	local bullet_key = PLUGIN.net_readkey()
	local bullet = PLUGIN.BulletsTable[bullet_key]
	
	if(bullet)then
		bullet:Remove()
	end
end)