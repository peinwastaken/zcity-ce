ENT.Base = "base_brush"
ENT.Type = "brush"


-- Called when the entity first spawns
function ENT:Initialize()

	local w = self.max.x - self.min.x
	local l = self.max.y - self.min.y
	local h = self.max.z - self.min.z

	local min = Vector( 0 - ( w / 2 ), 0 - ( l / 2 ), 0 - ( h / 2 ) )
	local max = Vector( w / 2, l / 2, h / 2 )

	self:DrawShadow( false )
	self:SetCollisionBounds( min, max )
	self:SetSolid( SOLID_BBOX )
	self:SetCollisionGroup( COLLISION_GROUP_WORLD )
	self:SetMoveType( 0 )
	self:SetTrigger( true )

end

zc = zc or {}

-- Called when an entity touches me :D
function ENT:StartTouch( ent )
	local ent = ent:IsRagdoll() and zc.RagdollOwner(ent) or ent
	if ( IsValid( ent ) && ent:IsPlayer() && ent:Alive() ) then
		--if zc.CheckMapCompleted(self.map) then return end

		--ent.CompletedMap = true
	
		-- Remove their vehicle
		if ( IsValid( ent:GetVehicle() ) ) then
		
			
			--ent:GetVehicle():Remove()
			ent:ExitVehicle()
		end
	
		--;; oops
		if zc.CoopPersistence and zc.CoopPersistence.SavePlayerData then
			zc.CoopPersistence.SavePlayerData(ent)
		end
	
		-- Freeze them and make sure they don't push people away
        ent:KillSilent()
	
		zc.MapCompleted = true
		zc.NextMap = self.map or ""
	end

end


-- Checks to see if we should go to the next map
