zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid
local ipairs, setmetatable = ipairs, setmetatable
local ents, util, weapons = ents, util, weapons

-- These caches deliberately live in this file's local scope. Re-running the file
-- replaces both the tables and the generation token, so stale entity state cannot
-- survive an autorefresh with values produced by an older version of the code.
local CACHE_MISS = {}
local WEAPON_CACHE_GENERATION = {}
local storedWeaponCache = {}
local weaponBaseCache = {}
local weaponAncestryCache = {}
local weaponTraitCache = {}
local classListMembershipCache = setmetatable({}, {__mode = "k"})

local MEDICINE_CLASSES = {
	weapon_bandage_sh = true,
	weapon_bigbandage_sh = true,
	weapon_tourniquet = true,
}

local BANDAGE_CLASSES = {
	"weapon_bandage_sh",
	"weapon_bigbandage_sh",
}

local TOURNIQUET_CLASSES = {"weapon_tourniquet"}

local SECONDARY_WEAPON_CLASSES = {
	weapon_ab10 = true,
	weapon_browninghp = true,
	weapon_colt9mm = true,
	weapon_cz75 = true,
	weapon_cz75a = true,
	weapon_deagle = true,
	weapon_fn45 = true,
	weapon_glock17 = true,
	weapon_glock18c = true,
	weapon_glock26 = true,
	weapon_hk_usp = true,
	weapon_m1911 = true,
	weapon_m45 = true,
	weapon_m9beretta = true,
	weapon_makarov = true,
	weapon_mac11 = true,
	weapon_mp_80 = true,
	["weapon_mp-80"] = true,
	weapon_osapb = true,
	weapon_p22 = true,
	weapon_pl15 = true,
	weapon_pm9 = true,
	weapon_px4beretta = true,
	weapon_revolver2 = true,
	weapon_revolver357 = true,
	weapon_ruger = true,
	weapon_skorpion = true,
	weapon_taser = true,
	weapon_tec9 = true,
	weapon_tmp = true,
	weapon_tokarev = true,
	weapon_uzi = true,
	weapon_zoraki = true,
}

local BOT_WEAPON_SELECTION_CACHE_TIME = 0.15
local BOT_HEAL_INTERVAL = 0.35
local BOT_PICKUP_SCAN_INTERVAL = 0.35
local BOT_PICKUP_FAILED_SCAN_INTERVAL = 0.5
local BOT_PICKUP_VISIBILITY_INTERVAL = 0.25
local BOT_PICKUP_BLOCKED_TIME = 0.75
local BOT_PICKUP_NO_PROGRESS_TIME = 3.5
local BOT_PICKUP_UNREACHABLE_TIME = 4
local BOT_PICKUP_PROGRESS_DISTANCE = 24
local BOT_WEAPON_PICKUP_SCAN_RANGE = 650
local BOT_WEAPON_PICKUP_USE_RANGE = 95
local BOT_WEAPON_PICKUP_REPATH_RANGE = 120
local BOT_AUTO_BURST_TIME = 0.35
local BOT_AUTO_BURST_PAUSE = 0.45
local BOT_CQB_MAGDUMP_RANGE = 650
local BOT_UNCONSCIOUS_TAP_INTERVAL = 0.65

local function ClearWeaponClassCaches()
	storedWeaponCache = {}
	weaponBaseCache = {}
	weaponAncestryCache = {}
	weaponTraitCache = {}
	classListMembershipCache = setmetatable({}, {__mode = "k"})
end

local function GetStoredWeapon(class)
	if not isstring(class) or class == "" then return nil end

	local cached = storedWeaponCache[class]
	if cached ~= nil then return cached ~= CACHE_MISS and cached or nil end

	local stored = weapons.GetStored and weapons.GetStored(class) or weapons.Get(class)
	storedWeaponCache[class] = stored or CACHE_MISS
	return stored
end

local function GetStoredWeaponBase(class)
	if not isstring(class) or class == "" then return nil end

	local cached = weaponBaseCache[class]
	if cached ~= nil then return cached ~= CACHE_MISS and cached or nil end

	local stored = GetStoredWeapon(class)
	local base = stored and stored.Base
	weaponBaseCache[class] = base or CACHE_MISS
	return base
end

local function WeaponInheritsBase(wep, baseName)
	if not IsValid(wep) or not isstring(baseName) then return false end
	if wep.Base == baseName then return true end
	if (wep.ishgwep or wep.ishgweapon) and baseName == "homigrad_base" then return true end

	local class = wep:GetClass()
	local firstBase = GetStoredWeaponBase(class) or wep.Base
	local cached = weaponAncestryCache[class]
	if cached and cached.firstBase == firstBase then
		return cached.bases[baseName] or false
	end

	local bases = {}
	local base = firstBase
	while isstring(base) and base ~= "" and not bases[base] do
		bases[base] = true
		base = GetStoredWeaponBase(base)
	end

	weaponAncestryCache[class] = {
		firstBase = firstBase,
		bases = bases,
	}

	return bases[baseName] or false
end

local function GetWeaponTraits(wep)
	if not IsValid(wep) then return nil end

	local class = wep:GetClass()
	local cached = weaponTraitCache[class]
	if cached then return cached end

	local primary = wep.Primary
	local stored = GetStoredWeapon(class)
	local storedPrimary = stored and stored.Primary
	local medicine = MEDICINE_CLASSES[class] == true
	local ranged = not medicine and primary ~= nil and primary.Ammo ~= "none" and WeaponInheritsBase(wep, "homigrad_base")
	local secondary = ranged and (
		wep.SecondaryWeapon or wep.IsSecondaryWeapon or wep.IsPistol or
		SECONDARY_WEAPON_CLASSES[class] or class:find("pistol", 1, true) or class:find("revolver", 1, true)
	) or false
	local hands = class == "weapon_hands_sh"
	local unarmed = hands or class:find("hands", 1, true) ~= nil
	local melee = not ranged and (
		hands or class == "weapon_melee" or unarmed or class:find("melee", 1, true) or
		WeaponInheritsBase(wep, "homigrad_base_melee")
	) or false

	cached = {
		medicine = medicine,
		ranged = not not ranged,
		secondary = not not secondary,
		primary = not not ranged and not secondary,
		automatic = not not (
			primary and (primary.Automatic or primary.RealAutomatic) or
			storedPrimary and (storedPrimary.Automatic or storedPrimary.RealAutomatic)
		),
		singleRoundReload = WeaponInheritsBase(wep, "homigrad_base_shotgun"),
		melee = not not melee,
		hands = hands,
		unarmed = not not unarmed,
	}

	weaponTraitCache[class] = cached
	return cached
end

local function GetClassListMembership(classList)
	if not istable(classList) then return nil end

	local cached = classListMembershipCache[classList]
	local count = #classList
	if cached and cached.count == count then return cached.classes end

	local classes = {}
	for index = 1, count do
		classes[classList[index]] = true
	end

	classListMembershipCache[classList] = {
		count = count,
		classes = classes,
	}

	return classes
end

local function ClassListContains(classList, class)
	local classes = GetClassListMembership(classList)
	return classes and classes[class] or false
end

function GetBotFakeWeapon(bot)
	if not IsValid(bot) then return nil end

	local ragdoll = IsValid(bot.FakeRagdoll) and bot.FakeRagdoll or zc.ragdollFake and zc.ragdollFake[bot]
	if not IsValid(ragdoll) then return nil end

	local fakeGun = ragdoll.fakeGun
	if IsValid(fakeGun) and IsValid(fakeGun.fakeOwner) then return fakeGun.fakeOwner end

	return nil
end

function GetBotActiveWeapon(bot)
	if not IsValid(bot) then return NULL end

	local active = bot:GetActiveWeapon()
	if IsValid(active) then return active end

	return GetBotFakeWeapon(bot) or active
end

function IsMeleeWeapon(wep)
	if not IsValid(wep) then return true end

	local traits = GetWeaponTraits(wep)
	return traits and traits.melee or false
end

function IsUnarmedWeapon(wep)
	if not IsValid(wep) then return true end

	local traits = GetWeaponTraits(wep)
	return traits and traits.unarmed or false
end

function IsRangedWeapon(wep)
	local traits = GetWeaponTraits(wep)
	return traits and traits.ranged or false
end

local function IsHandsWeapon(wep)
	local traits = GetWeaponTraits(wep)
	return traits and traits.hands or false
end

function IsMeaningfullyArmedWeapon(wep)
	local traits = GetWeaponTraits(wep)
	return traits and not traits.medicine and not traits.unarmed or false
end

function IsBotMeaningfullyArmed(bot)
	local wep = SelectBotWeapon(bot)
	return IsValid(wep) and not IsUnarmedWeapon(wep)
end

function GetMeleeWeaponAttackRange(wep)
	if not IsValid(wep) then return BOT_MELEE_ATTACK_RANGE end

	local attackLen = math.max(wep.AttackLen1 or 0, wep.AttackLen2 or 0)
	if attackLen <= 0 then return BOT_MELEE_ATTACK_RANGE end

	return math_Clamp(attackLen + 20, BOT_MELEE_RANGE, BOT_MELEE_ATTACK_RANGE)
end

-- Broad fire categories used for combat range selection: melee, shotgun,
-- pistol, rifle. Base inheritance is preferred; explicit exception sets cover
-- weapons the bases cannot classify (bolt rifles share the shotgun base).
local SHOTGUN_CLASSES = {
	weapon_ks23 = true,
	weapon_m4super = true,
	weapon_m590a1 = true,
	weapon_remington870 = true,
	["weapon_remington870_roullet"] = true,
	weapon_spas12 = true,
	weapon_toz106 = true,
	weapon_winchester = true,
	weapon_xm1014 = true,
}

local RIFLE_CLASSES = {
	weapon_kar98 = true,
	weapon_m98b = true,
	weapon_mosin = true,
	weapon_musket = true,
	weapon_sks = true,
}

function GetWeaponFireCategory(wep)
	if not IsValid(wep) then return "melee" end

	local traits = GetWeaponTraits(wep)
	if not traits then return "melee" end
	if traits.melee or traits.unarmed then return "melee" end
	if not traits.ranged then return "melee" end

	local class = wep:GetClass()
	if SHOTGUN_CLASSES[class] then return "shotgun" end
	if RIFLE_CLASSES[class] then return "rifle" end
	if traits.singleRoundReload and not traits.secondary then
		-- Unclassified single-round firearm: treat as shotgun-range unless named like a rifle.
		if class:find("snip", 1, true) or class:find("scop", 1, true) or class:find("kar98", 1, true) then
			return "rifle"
		end
		return "shotgun"
	end

	if class:find("snip", 1, true) or class:find("scop", 1, true) then return "rifle" end
	if traits.secondary then return "pistol" end

	return "rifle"
end

function GetBotWeaponAmmoOwner(bot, wep)
	if IsValid(wep) and wep.GetOwner then
		local owner = wep:GetOwner()
		if IsValid(owner) and owner.GetAmmoCount then return owner end
	end

	if IsValid(bot) and bot.GetAmmoCount then return bot end
end

function GetBotWeaponReserveAmmo(bot, wep)
	local owner = GetBotWeaponAmmoOwner(bot, wep)
	if not owner or not IsValid(wep) then return 0 end

	local ammoType = wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType()
	if ammoType and ammoType >= 0 then return owner:GetAmmoCount(ammoType) end

	local primary = wep.Primary
	local ammoName = primary and primary.Ammo
	if ammoName and ammoName ~= "none" then return owner:GetAmmoCount(ammoName) end

	return 0
end

function HasAmmoForWeapon(bot, wep)
	if not IsValid(wep) then return false end
	if wep:Clip1() > 0 then return true end

	return GetBotWeaponReserveAmmo(bot, wep) > 0
end

function HasReserveAmmoForWeapon(bot, wep)
	if not IsValid(wep) then return false end

	return GetBotWeaponReserveAmmo(bot, wep) > 0
end

function IsSingleRoundReloadWeapon(wep)
	local traits = GetWeaponTraits(wep)
	return traits and traits.singleRoundReload or false
end

function IsWeaponReadyToFire(wep)
	if not IsValid(wep) then return true end

	local primary = wep.Primary
	if primary then
		if (primary.Next or 0) > CurTime() then return false end
		if (primary.NextFire or 0) > CurTime() then return false end
	end

	if wep.reload or wep.deploy then return false end
	if wep.CanPrimaryAttack and wep:CanPrimaryAttack() == false then return false end

	return true
end

-- Trigger control -----------------------------------------------------------

function BotPressAttack(bot, cmd, wep, dist)
	local traits = GetWeaponTraits(wep)
	if traits and traits.automatic then
		local combat = bot.ZCBotAI.combat
		if dist and dist > BOT_CQB_MAGDUMP_RANGE and (combat.autoBurstUntil or 0) <= CurTime() then
			if (combat.autoBurstPauseUntil or 0) > CurTime() then return false end

			combat.autoBurstUntil = CurTime() + BOT_AUTO_BURST_TIME
			combat.autoBurstPauseUntil = combat.autoBurstUntil + BOT_AUTO_BURST_PAUSE
		end

		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return true
	end

	local combat = bot.ZCBotAI.combat
	if (combat.attackReleaseUntil or 0) > CurTime() then return false end
	if not IsWeaponReadyToFire(wep) then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	combat.attackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

function BotPressMeleeAttack(bot, cmd, wep)
	local combat = bot.ZCBotAI.combat
	if (combat.attackReleaseUntil or 0) > CurTime() then return false end
	if IsValid(wep) and (wep.reload or wep.deploy) then return false end
	if GetBotStaminaFraction(bot) <= BOT_MELEE_ATTACK_STAMINA_FRACTION then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	combat.attackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

function BotTapAttack(bot, cmd, wep)
	local combat = bot.ZCBotAI.combat
	if (combat.tapAttackUntil or 0) > CurTime() then return false end
	if not IsWeaponReadyToFire(wep) then return false end
	if IsMeleeWeapon(wep) and GetBotStaminaFraction(bot) <= BOT_MELEE_ATTACK_STAMINA_FRACTION then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	combat.tapAttackUntil = CurTime() + BOT_UNCONSCIOUS_TAP_INTERVAL
	combat.attackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

function BotPressReload(bot, cmd, wep)
	local combat = bot.ZCBotAI.combat
	if IsSingleRoundReloadWeapon(wep) then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
		return true
	end

	if (combat.reloadPulseUntil or 0) > CurTime() then return false end
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
	combat.reloadPulseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

-- Weapon selection ----------------------------------------------------------

local function SelectWeaponIfNeeded(bot, active, wep)
	if not IsValid(wep) then return active end
	if active ~= wep then bot:SelectWeapon(wep:GetClass()) end

	return wep
end

function ResetInventoryCaches(bot)
	GetOrCreateState(bot).inventory.generation = WEAPON_CACHE_GENERATION
	InvalidateWeaponSelection(bot)
end

function InvalidateWeaponSelection(bot)
	if not IsValid(bot) then return end

	local inventory = GetOrCreateState(bot).inventory
	inventory.selectedWeapon = nil
	inventory.selectionUntil = nil
	inventory.selectionEmpty = nil
end

function OnWeaponInventoryChanged(wep, owner)
	if not IsValid(owner) or not owner:IsPlayer() or not owner:IsBot() then return end
	ResetInventoryCaches(owner)
end

function OnWeaponDropped(bot)
	if IsValid(bot) and bot:IsBot() then ResetInventoryCaches(bot) end
end

function OnWeaponClassesReloaded()
	ClearWeaponClassCaches()
end

local function IsWeaponOwnedByBot(bot, wep, active)
	if wep == active or wep == GetBotFakeWeapon(bot) then return true end
	return bot:HasWeapon(wep:GetClass())
end

local function IsCachedBotWeaponUsable(bot, wep, active)
	if not IsValid(wep) or not IsWeaponOwnedByBot(bot, wep, active) then return false end

	local traits = GetWeaponTraits(wep)
	if not traits or traits.medicine then return false end
	if traits.ranged then return HasAmmoForWeapon(bot, wep) end

	return true
end

function SelectBotWeapon(bot)
	if not IsValid(bot) then return NULL end

	local inventory = GetOrCreateState(bot).inventory
	if inventory.generation ~= WEAPON_CACHE_GENERATION then
		inventory.generation = WEAPON_CACHE_GENERATION
		InvalidateWeaponSelection(bot)
	end

	local now = CurTime()
	local active = GetBotActiveWeapon(bot)
	local activeTraits = GetWeaponTraits(active)
	if activeTraits and activeTraits.primary and HasAmmoForWeapon(bot, active) then
		inventory.selectedWeapon = active
		inventory.selectionEmpty = nil
		inventory.selectionUntil = now + BOT_WEAPON_SELECTION_CACHE_TIME
		return active
	end

	if (inventory.selectionUntil or 0) > now then
		local cachedWeapon = inventory.selectedWeapon
		if IsCachedBotWeaponUsable(bot, cachedWeapon, active) then
			return SelectWeaponIfNeeded(bot, active, cachedWeapon)
		end

		if inventory.selectionEmpty then return active end
		InvalidateWeaponSelection(bot)
	end

	local primary
	local secondary
	local melee
	local hands = IsHandsWeapon(active) and active or nil

	for _, wep in ipairs(bot:GetWeapons()) do
		local traits = GetWeaponTraits(wep)
		if not traits or traits.medicine then continue end

		if traits.hands then
			hands = hands or wep
		elseif traits.ranged then
			if HasAmmoForWeapon(bot, wep) then
				if traits.primary then
					primary = primary or wep
				else
					secondary = secondary or wep
				end
			end
		elseif traits.melee then
			melee = melee or wep
		end
	end

	local selected = primary or secondary or melee or hands
	inventory.selectionUntil = now + BOT_WEAPON_SELECTION_CACHE_TIME
	inventory.selectedWeapon = selected
	inventory.selectionEmpty = not IsValid(selected)

	return SelectWeaponIfNeeded(bot, active, selected or active)
end

-- Weapon pickups ------------------------------------------------------------

local function IsBotPickupBlacklisted(bot, ent, now)
	local blacklist = GetOrCreateState(bot).inventory.pickupBlacklist
	local blockedUntil = blacklist and blacklist[ent]
	if not blockedUntil then return false end
	if blockedUntil > now then return true end

	blacklist[ent] = nil
	return false
end

function IsBotPickupWeapon(bot, ent)
	if not IsValid(bot) or not IsValid(ent) or not ent:IsWeapon() then return false end
	if IsValid(ent:GetOwner()) then return false end

	local traits = GetWeaponTraits(ent)
	if not traits or traits.medicine or not traits.ranged then return false end
	if not HasAmmoForWeapon(bot, ent) then return false end
	if bot:HasWeapon(ent:GetClass()) then return false end

	return true
end

function BotCanSeePickup(bot, ent)
	if not IsValid(bot) or not IsValid(ent) then return false end

	traceData.start = bot:EyePos()
	traceData.endpos = ent:WorldSpaceCenter()
	traceData.filter[1] = bot
	traceData.filter[2] = bot.FakeRagdoll

	local tr = util.TraceLine(traceData)
	return (not tr.Hit) or tr.Entity == ent
end

local function ClearPickupTarget(bot, nextScan)
	local inventory = GetOrCreateState(bot).inventory
	inventory.pickupWeapon = nil
	inventory.pickupVisibleUntil = nil
	inventory.pickupBestDistance = nil
	inventory.pickupLastProgressAt = nil
	inventory.pickupNextScan = nextScan
end

local function BlacklistPickup(bot, ent, duration, now)
	if not IsValid(ent) then return end

	local inventory = GetOrCreateState(bot).inventory
	inventory.pickupBlacklist = inventory.pickupBlacklist or setmetatable({}, {__mode = "k"})
	inventory.pickupBlacklist[ent] = (now or CurTime()) + duration
	if inventory.pickupWeapon == ent then
		ClearPickupTarget(bot, 0)
	end
end

local function ValidateCachedPickup(bot, ent, botPos, maxDistSqr, now)
	if not IsValid(ent) or IsBotPickupBlacklisted(bot, ent, now) then return false end
	if not IsBotPickupWeapon(bot, ent) then return false end

	local distSqr = botPos:DistToSqr(ent:GetPos())
	if distSqr > maxDistSqr then return false end

	return true, distSqr
end

function FindNearbyPickupWeapon(bot, maxRange)
	if not IsValid(bot) then return nil end

	maxRange = maxRange or BOT_WEAPON_PICKUP_SCAN_RANGE
	local inventory = GetOrCreateState(bot).inventory
	local now = CurTime()
	local botPos = bot:GetPos()
	local maxDistSqr = maxRange * maxRange
	local cachedWeapon = inventory.pickupWeapon

	if cachedWeapon ~= nil and not IsValid(cachedWeapon) then
		ClearPickupTarget(bot, 0)
	elseif IsValid(cachedWeapon) then
		local usable, distSqr = ValidateCachedPickup(bot, cachedWeapon, botPos, maxDistSqr, now)
		if usable then
			if (inventory.pickupVisibleUntil or 0) <= now then
				if not BotCanSeePickup(bot, cachedWeapon) then
					BlacklistPickup(bot, cachedWeapon, BOT_PICKUP_BLOCKED_TIME, now)
				else
					inventory.pickupVisibleUntil = now + BOT_PICKUP_VISIBILITY_INTERVAL
					return cachedWeapon, distSqr
				end
			else
				return cachedWeapon, distSqr
			end
		else
			ClearPickupTarget(bot, 0)
		end
	end

	if (inventory.pickupNextScan or 0) > now and (inventory.pickupScanRange or 0) >= maxRange then
		return nil
	end

	local bestWeapon
	local bestDistSqr = maxDistSqr

	for _, ent in ipairs(ents.FindInSphere(botPos, maxRange)) do
		if IsBotPickupBlacklisted(bot, ent, now) then continue end
		if not IsBotPickupWeapon(bot, ent) then continue end

		local distSqr = botPos:DistToSqr(ent:GetPos())
		if distSqr >= bestDistSqr then continue end
		if not BotCanSeePickup(bot, ent) then continue end

		bestDistSqr = distSqr
		bestWeapon = ent
	end

	inventory.pickupScanRange = maxRange
	inventory.pickupNextScan = now + (IsValid(bestWeapon) and BOT_PICKUP_SCAN_INTERVAL or BOT_PICKUP_FAILED_SCAN_INTERVAL)
	if IsValid(bestWeapon) then
		inventory.pickupWeapon = bestWeapon
		inventory.pickupVisibleUntil = now + BOT_PICKUP_VISIBILITY_INTERVAL
		inventory.pickupBestDistance = math.sqrt(bestDistSqr)
		inventory.pickupLastProgressAt = now
	end

	return bestWeapon, bestDistSqr
end

function ExecuteWeaponPickup(bot, cmd, aimAng)
	local weapon, distSqr = FindNearbyPickupWeapon(bot, BOT_WEAPON_PICKUP_SCAN_RANGE)
	if not IsValid(weapon) then return false end

	local now = CurTime()
	local inventory = GetOrCreateState(bot).inventory
	local distance = math.sqrt(distSqr)
	local bestDistance = inventory.pickupBestDistance or distance
	local madeProgress = distance <= bestDistance - BOT_PICKUP_PROGRESS_DISTANCE
	if madeProgress then
		inventory.pickupBestDistance = distance
		inventory.pickupLastProgressAt = now
	elseif distance > BOT_WEAPON_PICKUP_USE_RANGE and
		(inventory.pickupLastProgressAt or now) + BOT_PICKUP_NO_PROGRESS_TIME <= now then
		BlacklistPickup(bot, weapon, BOT_PICKUP_UNREACHABLE_TIME, now)
		return false
	end

	if distSqr <= BOT_WEAPON_PICKUP_USE_RANGE * BOT_WEAPON_PICKUP_USE_RANGE then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_USE))
		bot.force_pickup = true
		bot:PickupWeapon(weapon)
		bot.force_pickup = nil
		InvalidateWeaponSelection(bot)
		ClearPickupTarget(bot, now + BOT_PICKUP_SCAN_INTERVAL)
		BotDevPrint("%s picked up %s", bot:Name(), weapon:GetClass())
		return true
	end

	local lookAng = (weapon:WorldSpaceCenter() - bot:EyePos()):Angle()
	lookAng = SetBotViewAngles(bot, cmd, lookAng, BOT_AIM_SMOOTH_COMBAT)

	MoveTo(bot, cmd, weapon:GetPos(), {aimAng = aimAng or lookAng, speed = 420, facePath = true})

	if distSqr <= BOT_WEAPON_PICKUP_REPATH_RANGE * BOT_WEAPON_PICKUP_REPATH_RANGE then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_USE))
	end

	return true
end

-- A bot looks for a new weapon while unarmed or stuck with a melee weapon.
function ShouldSeekPickup(bot)
	local wep = SelectBotWeapon(bot)
	return IsUnarmedWeapon(wep) or IsMeleeWeapon(wep)
end

-- Self care -----------------------------------------------------------------

local function HasUsableMedicine(wep, bot, needsTourniquet)
	if not IsValid(wep) then return false end

	local values = wep.modeValues
	if istable(values) and (values[1] or 0) <= 0 then return false end
	if needsTourniquet then return wep:GetClass() == "weapon_tourniquet" and bot.organism and istable(bot.organism.arterialwounds) and #bot.organism.arterialwounds > 0 end
	if wep.CanHeal then return wep:CanHeal(bot) ~= false end

	return true
end

local function HasAmputatedLimb(org)
	return org and (org.llegamputated or org.rlegamputated or org.larmamputated or org.rarmamputated)
end

function GetBotWoundState(bot)
	local org = bot.organism
	if not org then return false, false end

	local arterialWounds = org.arterialwounds
	local wounds = org.wounds
	local hasArterialWound = istable(arterialWounds) and #arterialWounds > 0
	local hasBleed = (org.bleed or 0) > 0.05 and istable(wounds) and #wounds > 0

	return HasAmputatedLimb(org) and hasArterialWound, hasBleed
end

local function FindBotMedicine(bot, classList, needsTourniquet)
	local active = bot:GetActiveWeapon()
	if IsValid(active) and ClassListContains(classList, active:GetClass()) and HasUsableMedicine(active, bot, needsTourniquet) then
		return active
	end

	for _, class in ipairs(classList) do
		local wep = bot:GetWeapon(class)
		if HasUsableMedicine(wep, bot, needsTourniquet) then return wep end
	end
end

function NeedsSelfCare(bot)
	local needsTourniquet, needsBandage = GetBotWoundState(bot)
	return needsTourniquet or needsBandage, needsTourniquet, needsBandage
end

function ApplySelfCare(bot, cmd, needsTourniquet, needsBandage)
	if not needsTourniquet and not needsBandage then
		GetOrCreateState(bot).inventory.nextHealTry = 0
		return false
	end

	local inventory = GetOrCreateState(bot).inventory
	local active = bot:GetActiveWeapon()
	if HasUsableMedicine(active, bot, needsTourniquet) and (needsTourniquet or ClassListContains(BANDAGE_CLASSES, active:GetClass())) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return true
	end

	if (inventory.nextHealTry or 0) > CurTime() then return false end

	local wep
	if needsTourniquet then
		wep = FindBotMedicine(bot, TOURNIQUET_CLASSES, true)
	end

	if not IsValid(wep) and needsBandage then
		wep = FindBotMedicine(bot, BANDAGE_CLASSES, false)
	end

	inventory.nextHealTry = CurTime() + BOT_HEAL_INTERVAL
	if not IsValid(wep) then return false end

	bot:SelectWeapon(wep:GetClass())
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))

	BotDevPrint("%s self-care=%s", bot:Name(), wep:GetClass())
	return true
end
