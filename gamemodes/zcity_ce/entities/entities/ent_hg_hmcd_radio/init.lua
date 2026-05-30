AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    if SERVER then
        self:SetMoveType(MOVETYPE_VPHYSICS)
    end
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:DrawShadow(true)
    self:AddEFlags(EFL_IN_SKYBOX)
    
    local phys = self:GetPhysicsObject()

    if SERVER and IsValid(phys) then
        phys:SetMass(10)
        phys:Wake()
        phys:EnableMotion(true)
    end
end

hook.Add("OnEntityCreated", "ZC_RadioCreate", function( ent )
	if ent:GetClass() == "ent_hg_hmcd_radio" then
		SetGlobalEntity("radio",ent)
	end
end)

util.AddNetworkString("ZC_RadioUrlInput")
util.AddNetworkString("ZC_RadioPlaySound")
util.AddNetworkString("ZC_RadioChangeValue")
util.AddNetworkString("ZC_RadioChangeVolume")
util.AddNetworkString("ZC_RadioPause")
util.AddNetworkString("ZC_RadioStop")
util.AddNetworkString("ZC_RadioLooping")
util.AddNetworkString("ZC_RadioPaint")

net.Receive("ZC_RadioUrlInput", function(len, ply)
	local url = net.ReadString()
	local ent = net.ReadEntity()
	
	if ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("ZC_RadioPlaySound")
	net.WriteString(url)
	net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)

net.Receive("ZC_RadioPaint", function(len, ply)
	local url = net.ReadString()
	local ent = net.ReadEntity()

	if ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	ent:SetTextureURL( url )

	
	net.Start("ZC_RadioPaint")
		net.WriteString( url )
		net.WriteEntity( ent )
	net.Broadcast()
end)

net.Receive("ZC_RadioChangeValue", function(len, ply)
	local val = net.ReadFloat()
	local index = net.ReadInt(32)
	local ent = Entity(index)

	if ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("ZC_RadioChangeValue")
	net.WriteFloat(val)
	net.WriteInt(index,32)
	net.Broadcast()
end)

net.Receive("ZC_RadioChangeVolume", function(len, ply)
	local val = net.ReadFloat()
	local index = net.ReadInt(32)
	local ent = Entity(index)
	
	if ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("ZC_RadioChangeVolume")
	net.WriteFloat(val)
	net.WriteInt(index,32)
	net.Broadcast()
end)

net.Receive("ZC_RadioPause", function(len, ply)
	local bool = net.ReadBool()
	local ent = net.ReadEntity()
	
	if ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end
	
	net.Start("ZC_RadioPause")
		net.WriteBool(bool)
		net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)

net.Receive("ZC_RadioLooping", function(len, ply)
	local bool = net.ReadBool()
	local ent = net.ReadEntity()

	if ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("ZC_RadioLooping")
		net.WriteBool(bool)
		net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)

net.Receive("ZC_RadioStop", function(len, ply)
	local ent = net.ReadEntity()

	if ent:GetClass() != "ent_hg_hmcd_radio" or (ent:GetPos():Distance(ply:EyePos()) > 75) then return end

	net.Start("ZC_RadioStop")
		net.WriteInt(ent:EntIndex(),32)
	net.Broadcast()
end)