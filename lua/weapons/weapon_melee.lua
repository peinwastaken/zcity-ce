if SERVER then AddCSLuaFile() end

SWEP.Base = "homigrad_base_melee"
SWEP.PrintName = "Combat Knife"
SWEP.Instructions = "This is your trusty carbon-steel fixed-blade knife.\n\nLMB to attack.\nR + LMB to change attack mode.\nRMB to block."
SWEP.Category = "Weapons - Melee"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.UseKnifeMode = true
SWEP.DisableSecondaryAttack = true

SWEP.WorldModel = "models/weapons/combatknife/tactical_knife_iw7_wm.mdl"
SWEP.WorldModelReal = "models/weapons/combatknife/tactical_knife_iw7_vm.mdl"
SWEP.WorldModelExchange = false

SWEP.AnimList = {
    ["idle"] = "vm_knifeonly_idle",
    ["deploy"] = "vm_knifeonly_raise",
    ["attack"] = "vm_knifeonly_stab",
    ["attack2"] = "vm_knifeonly_swipe",
}

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/hud/tfa_iw7_tactical_knife")
	SWEP.IconOverride = "vgui/hud/tfa_iw7_tactical_knife.png"
	SWEP.BounceWeaponIcon = false
end
