local MODE = MODE

local firearmCategories = {
	["Weapons - Assault Rifles"] = true,
	["Weapons - Carbines"] = true,
	["Weapons - Machineguns"] = true,
	["Weapons - Machine-Pistols"] = true,
	["Weapons - Pistols"] = true,
	["Weapons - Shotguns"] = true,
	["Weapons - Sniper Rifles"] = true
}

local grenades = {
	"weapon_hg_rgd_tpik",
	"weapon_hg_pipebomb_tpik",
	"weapon_hg_smokenade_tpik",
	"weapon_hg_flashbang_tpik"
}

local medicine = {
	"weapon_bandage_sh",
	"weapon_bigbandage_sh",
	"weapon_medkit_sh",
	"weapon_fentanyl",
	"weapon_morphine",
	"weapon_adrenaline",
	"weapon_tourniquet"
}

local vests = {"vest1", "vest2", "vest3", "vest4"}
local helmets = {"helmet1", "helmet5", "helmet7"}
local extraArmor = {"mask1", "nightvision1"}

local function RandomFrom(tbl, fallback)
	if #tbl == 0 then return fallback end
	return tbl[math.random(#tbl)]
end

local function GetWeaponPools()
	local firearms = {}
	local pistols = {}
	local melees = {}

	for _, weapon in ipairs(weapons.GetList()) do
		if not weapon.Spawnable or not weapon.ClassName then continue end

		if firearmCategories[weapon.Category] then
			firearms[#firearms + 1] = weapon.ClassName
		end

		if weapon.Category == "Weapons - Pistols" then
			pistols[#pistols + 1] = weapon.ClassName
		elseif weapon.Category == "Weapons - Melee" then
			melees[#melees + 1] = weapon.ClassName
		end
	end

	return firearms, pistols, melees
end

local function RandomLoadout(firearms, pistols, melees)
	local loadout = {
		primary = RandomFrom(firearms, "weapon_glock17"),
		melee = RandomFrom(melees, "weapon_melee"),
		primaryAmmo = math.random(2, 5),
		secondaryAmmo = math.random(2, 4),
		armor = {},
		grenades = {},
		medicine = {}
	}

	if #pistols > 0 and math.random(2) == 1 then
		loadout.secondary = RandomFrom(pistols)
		if loadout.secondary == loadout.primary and #pistols > 1 then
			repeat
				loadout.secondary = RandomFrom(pistols)
			until loadout.secondary != loadout.primary
		end
	end

	if math.random(4) != 1 then
		loadout.armor[#loadout.armor + 1] = RandomFrom(vests)
	end
	if math.random(3) != 1 then
		loadout.armor[#loadout.armor + 1] = RandomFrom(helmets)
	end
	if math.random(4) == 1 then
		loadout.armor[#loadout.armor + 1] = RandomFrom(extraArmor)
	end

	local usedGrenades = {}
	for _ = 1, math.random(0, 2) do
		local grenade
		repeat
			grenade = RandomFrom(grenades)
		until not usedGrenades[grenade]
		usedGrenades[grenade] = true
		loadout.grenades[#loadout.grenades + 1] = grenade
	end

	for _ = 1, math.random(1, 2) do
		loadout.medicine[#loadout.medicine + 1] = RandomFrom(medicine)
	end

	return loadout
end

local function GiveGun(ply, class, magazines)
	if not class then return end

	local gun = ply:Give(class)
	if not IsValid(gun) then return end

	local ammoType = gun:GetPrimaryAmmoType()
	local clipSize = gun:GetMaxClip1()
	if ammoType >= 0 and clipSize > 0 then
		ply:GiveAmmo(clipSize * magazines, ammoType, true)
	end
end

local function GiveLoadout(ply, loadout)
	ply:SetSuppressPickupNotices(true)
	ply.noSound = true
	ply:Give("weapon_hands_sh")

	local inv = ply:GetNetVar("Inventory")
	inv["Weapons"]["hg_sling"] = true
	ply:SetNetVar("Inventory", inv)

	GiveGun(ply, loadout.primary, loadout.primaryAmmo)
	GiveGun(ply, loadout.secondary, loadout.secondaryAmmo)
	ply:Give(loadout.melee)

	for _, armor in ipairs(loadout.armor) do
		zc.AddArmor(ply, armor)
	end
	for _, grenade in ipairs(loadout.grenades) do
		ply:Give(grenade)
	end
	for _, item in ipairs(loadout.medicine) do
		ply:Give(item)
	end

	ply:Give("weapon_walkie_talkie")
	ply:SelectWeapon("weapon_hands_sh")

	if ply.organism then ply.organism.recoilmul = 0.5 end

	timer.Simple(0.1, function()
		if IsValid(ply) then ply.noSound = false end
	end)

	ply:SetSuppressPickupNotices(false)
	zc.GiveRole(ply, "Fighter", Color(190, 15, 15))
end

function MODE:RoundStart()
	local firearms, pistols, melees = GetWeaponPools()
	local sharedLoadout = self.SharedLoadout and RandomLoadout(firearms, pistols, melees)

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		GiveLoadout(ply, sharedLoadout or RandomLoadout(firearms, pistols, melees))
	end
end
