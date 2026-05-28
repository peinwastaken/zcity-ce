hg = hg or {}
hg.PlayerBots = hg.PlayerBots or {}
local _ENV = hg.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

function GetStoredWeaponBase(class)
	local stored = weapons.GetStored and weapons.GetStored(class) or weapons.Get(class)
	return stored and stored.Base
end

function WeaponInheritsBase(wep, baseName)
	if not IsValid(wep) then return false end
	if wep.Base == baseName then return true end
	if (wep.ishgwep or wep.ishgweapon) and baseName == "homigrad_base" then return true end

	local seen = {}
	local base = GetStoredWeaponBase(wep:GetClass()) or wep.Base
	while isstring(base) and base ~= "" and not seen[base] do
		if base == baseName then return true end

		seen[base] = true
		base = GetStoredWeaponBase(base)
	end

	return false
end

function IsMedicineWeapon(wep)
	return IsValid(wep) and MEDICINE_CLASSES[wep:GetClass()]
end

function GetBotFakeWeapon(bot)
	if not IsValid(bot) then return nil end

	local ragdoll = IsValid(bot.FakeRagdoll) and bot.FakeRagdoll or hg.ragdollFake and hg.ragdollFake[bot]
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

function ShouldReloadWeapon(bot, wep)
	if not IsValid(wep) or wep:Clip1() >= wep:GetMaxClip1() then return false end
	if wep:GetMaxClip1() == 0 then return false end

	return HasReserveAmmoForWeapon(bot, wep)
end

function ShouldCycleManualAction(wep)
	if not IsValid(wep) or wep.drawBullet ~= false then return false end
	if wep:Clip1() <= 0 then return false end

	local nextCycle = wep.GetNetVar and wep:GetNetVar("shootgunReload", 0) or 0
	return nextCycle <= CurTime()
end

function IsAutomaticWeapon(wep)
	if not IsValid(wep) then return false end

	local primary = wep.Primary
	if primary and (primary.Automatic or primary.RealAutomatic) then return true end

	local stored = weapons.GetStored and weapons.GetStored(wep:GetClass()) or weapons.Get(wep:GetClass())
	return stored and stored.Primary and stored.Primary.Automatic or false
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

function IsSingleRoundReloadWeapon(wep)
	return WeaponInheritsBase(wep, "homigrad_base_shotgun")
end

function IsWeaponDry(wep)
	if not IsValid(wep) then return false end
	if ShouldCycleManualAction(wep) then return true end
	if wep:Clip1() <= 0 then return true end

	return wep.drawBullet == false
end

function GetReloadGoalClip(bot, wep, enemyNearby)
	local maxClip = wep:GetMaxClip1()
	if not IsSingleRoundReloadWeapon(wep) or not enemyNearby then return maxClip end

	local reserve = GetBotWeaponReserveAmmo(bot, wep)
	local targetClip = (bot.ZCBotReloadStartClip or wep:Clip1()) + BOT_COMBAT_RELOAD_SHELLS
	return math_min(maxClip, targetClip, wep:Clip1() + reserve)
end

function BotPressReload(bot, cmd, wep)
	if IsSingleRoundReloadWeapon(wep) then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
		return true
	end

	if (bot.ZCBotReloadPulseUntil or 0) > CurTime() then return false end
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
	bot.ZCBotReloadPulseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

function BotPressAttack(bot, cmd, wep, dist)
	if IsAutomaticWeapon(wep) then
		if dist and dist > BOT_CQB_MAGDUMP_RANGE and (bot.ZCBotAutoBurstUntil or 0) <= CurTime() then
			if (bot.ZCBotAutoBurstPauseUntil or 0) > CurTime() then return false end

			bot.ZCBotAutoBurstUntil = CurTime() + BOT_AUTO_BURST_TIME
			bot.ZCBotAutoBurstPauseUntil = bot.ZCBotAutoBurstUntil + BOT_AUTO_BURST_PAUSE
		end

		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return true
	end

	if (bot.ZCBotAttackReleaseUntil or 0) > CurTime() then return false end
	if not IsWeaponReadyToFire(wep) then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	bot.ZCBotAttackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

function BotPressMeleeAttack(bot, cmd, wep)
	if (bot.ZCBotAttackReleaseUntil or 0) > CurTime() then return false end
	if IsValid(wep) and (wep.reload or wep.deploy) then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	bot.ZCBotAttackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

function BotTapAttack(bot, cmd, wep)
	if (bot.ZCBotTapAttackUntil or 0) > CurTime() then return false end
	if not IsWeaponReadyToFire(wep) then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	bot.ZCBotTapAttackUntil = CurTime() + BOT_UNCONSCIOUS_TAP_INTERVAL
	bot.ZCBotAttackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

function IsRangedWeapon(wep)
	if not IsValid(wep) or IsMedicineWeapon(wep) then return false end

	local primary = wep.Primary
	if not primary or primary.Ammo == "none" then return false end

	return WeaponInheritsBase(wep, "homigrad_base")
end

function IsHandsWeapon(wep)
	return IsValid(wep) and wep:GetClass() == "weapon_hands_sh"
end

function IsSecondaryRangedWeapon(wep)
	if not IsRangedWeapon(wep) then return false end
	if wep.SecondaryWeapon or wep.IsSecondaryWeapon or wep.IsPistol then return true end

	local class = wep:GetClass()
	if SECONDARY_WEAPON_CLASSES[class] then return true end

	return class:find("pistol", 1, true) or class:find("revolver", 1, true)
end

function IsPrimaryRangedWeapon(wep)
	return IsRangedWeapon(wep) and not IsSecondaryRangedWeapon(wep)
end

function SelectWeaponIfNeeded(bot, active, wep)
	if not IsValid(wep) then return active end
	if active ~= wep then bot:SelectWeapon(wep:GetClass()) end

	return wep
end

function IsMeleeWeapon(wep)
	if not IsValid(wep) then return true end
	if IsRangedWeapon(wep) then return false end

	local class = wep:GetClass()
	return class == "weapon_hands_sh" or class == "weapon_melee" or class:find("hands", 1, true) or class:find("melee", 1, true) or WeaponInheritsBase(wep, "homigrad_base_melee")
end

function GetMeleeWeaponAttackRange(wep)
	if not IsValid(wep) then return BOT_MELEE_ATTACK_RANGE end

	local attackLen = math.max(wep.AttackLen1 or 0, wep.AttackLen2 or 0)
	if attackLen <= 0 then return BOT_MELEE_ATTACK_RANGE end

	return math_Clamp(attackLen + 20, BOT_MELEE_RANGE, BOT_MELEE_ATTACK_RANGE)
end

function IsBotPickupWeapon(bot, ent)
	if not IsValid(bot) or not IsValid(ent) or not ent:IsWeapon() then return false end
	if IsValid(ent:GetOwner()) or IsMedicineWeapon(ent) then return false end
	if not IsRangedWeapon(ent) or not HasAmmoForWeapon(bot, ent) then return false end
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

function FindNearbyPickupWeapon(bot, maxRange)
	local botPos = bot:GetPos()
	local bestWeapon
	local bestDistSqr = (maxRange or BOT_WEAPON_PICKUP_SCAN_RANGE) ^ 2

	for _, ent in ipairs(ents.FindInSphere(botPos, maxRange or BOT_WEAPON_PICKUP_SCAN_RANGE)) do
		if not IsBotPickupWeapon(bot, ent) then continue end
		if not BotCanSeePickup(bot, ent) then continue end

		local distSqr = botPos:DistToSqr(ent:GetPos())
		if distSqr < bestDistSqr then
			bestDistSqr = distSqr
			bestWeapon = ent
		end
	end

	return bestWeapon, bestDistSqr
end

function TryBotPickupNearbyWeapon(bot, cmd, aimAng)
	local weapon, distSqr = FindNearbyPickupWeapon(bot, BOT_WEAPON_PICKUP_SCAN_RANGE)
	if not IsValid(weapon) then return false end

	local weaponPos = weapon:GetPos()
	if distSqr <= BOT_WEAPON_PICKUP_USE_RANGE * BOT_WEAPON_PICKUP_USE_RANGE then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_USE))
		bot.force_pickup = true
		bot:PickupWeapon(weapon)
		bot.force_pickup = nil
		return true
	end

	local lookAng = (weapon:WorldSpaceCenter() - bot:EyePos()):Angle()
	lookAng = SetBotViewAngles(bot, cmd, lookAng, BOT_AIM_SMOOTH_COMBAT)

	local followedPath = FollowBotPath(bot, cmd, weaponPos, aimAng or lookAng, 420, true, false)
	if not followedPath then
		SetBotMovementToward(bot, cmd, weaponPos, aimAng or lookAng, 360)
		ApplyBotUnstuckMove(bot, cmd)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng or lookAng)
		UpdateBotStuckState(bot, cmd, weaponPos)
	end

	if distSqr <= BOT_WEAPON_PICKUP_REPATH_RANGE * BOT_WEAPON_PICKUP_REPATH_RANGE then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_USE))
	end

	return true
end

function SelectBotWeapon(bot)
	local active = GetBotActiveWeapon(bot)
	if IsPrimaryRangedWeapon(active) and HasAmmoForWeapon(bot, active) then return active end

	local primary
	local secondary
	local melee
	local hands = IsHandsWeapon(active) and active or nil

	for _, wep in ipairs(bot:GetWeapons()) do
		if not IsValid(wep) or IsMedicineWeapon(wep) then continue end

		if IsHandsWeapon(wep) then
			hands = hands or wep
		elseif IsPrimaryRangedWeapon(wep) and HasAmmoForWeapon(bot, wep) then
			primary = primary or wep
		elseif IsSecondaryRangedWeapon(wep) and HasAmmoForWeapon(bot, wep) then
			secondary = secondary or wep
		elseif IsMeleeWeapon(wep) then
			melee = melee or wep
		end
	end

	return SelectWeaponIfNeeded(bot, active, primary or secondary or melee or hands or active)
end

function HasUsableMedicine(wep, bot, needsTourniquet)
	if not IsValid(wep) then return false end

	local values = wep.modeValues
	if istable(values) and (values[1] or 0) <= 0 then return false end
	if needsTourniquet then return wep:GetClass() == "weapon_tourniquet" and bot.organism and istable(bot.organism.arterialwounds) and #bot.organism.arterialwounds > 0 end
	if wep.CanHeal then return wep:CanHeal(bot) ~= false end

	return true
end

function HasAmputatedLimb(org)
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

function FindBotMedicine(bot, classList, needsTourniquet)
	local active = bot:GetActiveWeapon()
	if IsValid(active) and table.HasValue(classList, active:GetClass()) and HasUsableMedicine(active, bot, needsTourniquet) then
		return active
	end

	for _, class in ipairs(classList) do
		local wep = bot:GetWeapon(class)
		if HasUsableMedicine(wep, bot, needsTourniquet) then return wep end
	end
end

function TryBotSelfCare(bot, cmd)
	local needsTourniquet, needsBandage = GetBotWoundState(bot)
	if not needsTourniquet and not needsBandage then
		bot.ZCBotNextHealTry = 0
		return false
	end

	local active = bot:GetActiveWeapon()
	if HasUsableMedicine(active, bot, needsTourniquet) and (needsTourniquet or table.HasValue(BANDAGE_CLASSES, active:GetClass())) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return true
	end

	if (bot.ZCBotNextHealTry or 0) > CurTime() then return false end

	local wep
	if needsTourniquet then
		wep = FindBotMedicine(bot, {"weapon_tourniquet"}, true)
	end

	if not IsValid(wep) and needsBandage then
		wep = FindBotMedicine(bot, BANDAGE_CLASSES, false)
	end

	bot.ZCBotNextHealTry = CurTime() + BOT_HEAL_INTERVAL
	if not IsValid(wep) then return false end

	bot:SelectWeapon(wep:GetClass())
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))

	BotDevPrint(string.format("%s self-care=%s", bot:Name(), wep:GetClass()))
	return true
end

function TryBotFakeUp(bot)
	if not hg.GetFakeState or not hg.FAKE_STATE then return false end
	if (bot.ZCBotFakeUpCooldownUntil or 0) > CurTime() then return true end
	if (bot.LastFakeUp or 0) + BOT_FAKEUP_COOLDOWN > CurTime() then return true end

	local fakeState = hg.GetFakeState(bot)
	if fakeState == hg.FAKE_STATE.NONE then
		bot.ZCBotFakeUpAllowedAt = nil
		return false
	end

	if fakeState == hg.FAKE_STATE.ACTIVE then
		if not bot.ZCBotFakeUpAllowedAt then
			bot.ZCBotFakeUpAllowedAt = CurTime() + BOT_FAKEUP_INITIAL_DELAY
		end

		if bot.ZCBotFakeUpAllowedAt > CurTime() then
			return true
		end
	end

	if fakeState == hg.FAKE_STATE.ACTIVE and (bot.ZCBotNextFakeUpTry or 0) <= CurTime() then
		bot.ZCBotNextFakeUpTry = CurTime() + BOT_FAKEUP_INTERVAL
		if hg.FakeUp and hg.FakeUp(bot) then
			bot.ZCBotFakeUpCooldownUntil = CurTime() + BOT_FAKEUP_COOLDOWN
			BotDevPrint(string.format("%s fakeup", bot:Name()))
		end
	end

	return true
end

function GetCurrentRound()
	return CurrentRound and CurrentRound() or nil
end

function IsDeathmatchRoundActive(round)
	round = round or GetCurrentRound()
	return round and round.name == "dm" and zb and zb.ROUND_STATE == 1
end

