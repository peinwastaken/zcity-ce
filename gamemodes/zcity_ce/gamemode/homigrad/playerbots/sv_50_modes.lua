zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid

-- The AI reads the active mode through this bridge. General AI code never
-- compares exact mode names; modes provide optional methods instead:
--   MODE:IsBotTeammate(bot, other) -> bool
--   MODE:GetBotGoal(bot)           -> vector or nil
--   MODE:AdjustBotGoal(bot, pos)   -> adjusted position
--   MODE:AdjustBotStrafe(bot, cmd, aimAng) -> optional strafe movement bias

function GetCurrentMode()
	if zc.round and zc.round.GetCurrent then
		return zc.round.GetCurrent()
	end

	return CurrentRound and CurrentRound() or nil
end

function GetRoundState()
	if zc.round and zc.round.state ~= nil then return zc.round.state end

	local legacy = zc.ROUND_STATE
	if legacy == 1 then return ROUND_ACTIVE or 2 end
	if legacy == 3 then return ROUND_ENDING or 3 end
	return ROUND_WAITING or 0
end

function IsRoundActive()
	return GetRoundState() == (ROUND_ACTIVE or 2)
end

-- A mode owns its spawn-protection window; bots separate from enemies during it.
function IsSafeTime(mode)
	mode = mode or GetCurrentMode()
	if not mode then return false end
	if mode.IsBotSafeTime then return mode:IsBotSafeTime() and true or false end
	if mode.IsSpawnProtectionActive then return mode:IsSpawnProtectionActive() and true or false end
	if mode.SpawnProtectionTime then
		return (zc.ROUND_START or 0) + mode.SpawnProtectionTime > CurTime()
	end

	return false
end

-- Default teammate behavior uses normal player teams. Modes whose relationships
-- differ must implement MODE:IsBotTeammate.
function IsBotTeammate(bot, other)
	if not IsValid(bot) or not IsValid(other) or not bot:IsPlayer() or not other:IsPlayer() then return false end
	if bot == other then return true end

	local mode = GetCurrentMode()
	if istable(mode) and mode.IsBotTeammate then
		return mode:IsBotTeammate(bot, other) and true or false
	end

	local botTeam = GetBotTeamId(bot)
	local otherTeam = GetBotTeamId(other)
	return botTeam ~= nil and botTeam == otherTeam
end

function GetBotGoal(bot)
	local mode = GetCurrentMode()
	if istable(mode) and mode.GetBotGoal then
		return mode:GetBotGoal(bot)
	end

	return nil
end

function AdjustBotGoal(bot, pos)
	local mode = GetCurrentMode()
	if istable(mode) and mode.AdjustBotGoal then
		return mode:AdjustBotGoal(bot, pos) or pos
	end

	return pos
end

function AdjustBotStrafe(bot, cmd, aimAng)
	local mode = GetCurrentMode()
	if istable(mode) and mode.AdjustBotStrafe then
		return mode:AdjustBotStrafe(bot, cmd, aimAng)
	end
end

-- Hostility override. The mode returns true/false when it owns who may be
-- targeted, or nil to fall through to normal teammate rules. This controls
-- eligibility only; perception still requires real line of sight.
function CanBotTarget(bot, other)
	local mode = GetCurrentMode()
	if istable(mode) and mode.CanBotTarget then
		return mode:CanBotTarget(bot, other)
	end

	return nil
end

-- Optional bounded hostile-candidate list for modes with NPC enemies.
-- Returns nil when the default cached player list should be used.
function GetBotTargetCandidates(bot)
	local mode = GetCurrentMode()
	if istable(mode) and mode.GetBotTargetCandidates then
		return mode:GetBotTargetCandidates(bot)
	end

	return nil
end

-- Damage hook bridge so modes can record learned hostility per bot.
function NotifyBotDamaged(bot, attacker)
	local mode = GetCurrentMode()
	if istable(mode) and mode.OnBotDamaged then
		mode:OnBotDamaged(bot, attacker)
	end
end
