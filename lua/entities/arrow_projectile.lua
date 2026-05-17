if SERVER then AddCSLuaFile() end
ENT.Base = "projectile_nonexplosive_base"
ENT.Author = "Mannytko"
ENT.Category = "ZCity Other"
ENT.PrintName = "Arrow Projectile"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Model = "models/z_city/nmrih/items/arrow/ammo_arrow_single.mdl"
ENT.HitSound = "weapons/impact/concrete_impact_bullet4.wav"

ENT.Damage = 50
ENT.Force = 3

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetMass(1)
			phys:Wake()
		end
	end

	function ENT:Use(ply)
		ply:GiveAmmo(1, "Arrow", true)
		ply:EmitSound("weapons/bow_deerhunter/arrow_load_0"..math.random(3)..".wav", 55)

		if IsValid(self.HitEntity) and self.HitEntity.organism then
			if self.HitEntity.organism.LodgedEntities then
				self.HitEntity.organism.LodgedEntities[self] = nil
			end

			local mat = self.HitEntity:GetBoneMatrix(self.HitEntity:TranslatePhysBoneToBone(self.phys_bone_id or 0))

			if mat then
				for _ = 1, 5 do
					hg.organism.AddWoundManual(self.HitEntity.organism.owner, 50, vector_origin, AngleRand(-180, 180), self.HitEntity:GetBoneName(self.HitEntity:TranslatePhysBoneToBone(self.phys_bone_id)), CurTime() + math.Rand(0, 2))
				end
			end

			self:EmitSound("arrow_tear.wav")
		end

		self:Remove()
	end
end
