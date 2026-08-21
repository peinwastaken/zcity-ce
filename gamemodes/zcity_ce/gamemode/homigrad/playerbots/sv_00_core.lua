zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

bit_bor = bit.bor
bit_band = bit.band
bit_bnot = bit.bnot
CurTime = CurTime
IsValid = IsValid
math_abs = math.abs
math_Rand = math.Rand
math_random = math.random
math_min = math.min
math_max = math.max
math_huge = math.huge
math_Clamp = math.Clamp
math_Lerp = Lerp

local CurTime, IsValid = CurTime, IsValid
local math_Clamp = math_Clamp
local select, setmetatable = select, setmetatable
local engine, player = engine, player

zc_playerbot_ai = CreateConVar("zc_playerbot_ai", "1", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Enable basic enemy AI for player bots created with the bot command.", 0, 1)
zc_playerbot_debug = CreateConVar("zc_playerbot_debug", "0", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Print player bot AI target/debug messages through DevPrint.", 0, 1)

-- Shared configuration. Only values needed by more than one AI file live here.
BOT_THINK_INTERVAL = 0.2
BOT_TARGET_TRACK_INTERVAL = 0.1
BOT_TARGET_SCAN_STAGGER_STEPS = 5
BOT_AIM_SMOOTH_TRAVEL = 0.16
BOT_AIM_SMOOTH_COMBAT = 0.24
BOT_NAV_DEST_REACH = 180
BOT_ATTACK_PULSE_RELEASE = 0.11
BOT_COMBAT_RELOAD_SHELLS = 2
BOT_CQB_MAGDUMP_RANGE = 650
BOT_MELEE_RANGE = 95
BOT_MELEE_ATTACK_RANGE = 130
BOT_MELEE_ATTACK_STAMINA_FRACTION = 0.2
BOT_SPRINT_STAMINA_FRACTION = 0.5
BOT_FAKEUP_INITIAL_DELAY = 5
BOT_FAKEUP_INTERVAL = 5
BOT_FAKEUP_COOLDOWN = 5
-- Minimum time a newly acquired combat target is kept before voluntary switching.
BOT_TARGET_LOCK_TIME = 2.5

-- Shared scratch trace data. Filter slots are filled per use.
traceData = {
	mask = MASK_SHOT,
	filter = {},
}

PlayerBotRegistry = PlayerBotRegistry or setmetatable({}, {__mode = "k"})

local cachedPlayerCandidates = {}
local cachedPlayerCandidatesTick = -1

function BotDevPrint(msg, ...)
	if not zc_playerbot_debug:GetBool() then return end
	if select("#", ...) > 0 then
		msg = string.format(msg, ...)
	end

	zc.dev.DevPrint(msg)
end

function LogBotIntentChange(bot, fromName, toName, reason)
	BotDevPrint("[Bot %s] %s -> %s: %s", bot:Name(), fromName or "none", toName or "none", reason or "unspecified")
end

function Register(bot)
	if IsValid(bot) and bot:IsPlayer() and bot:IsBot() then
		PlayerBotRegistry[bot] = true
	end
end

function Unregister(bot)
	PlayerBotRegistry[bot] = nil
end

local function CreateStateTable()
	return {
		intent = 0,
		intentStarted = 0,
		intentTarget = nil,
		intentPos = nil,
		nextThink = 0,

		target = nil,
		lastSeenPos = nil,
		lastSeenAt = 0,

		threat = nil,
		threatPos = nil,
		threatUntil = 0,

		perception = {},
		navigation = {},
		combat = {},
		inventory = {},
		-- Scratch space for optional MODE bot methods. Modes may cache small
		-- per-bot values here instead of writing fields onto the player.
		modes = {},

		command = {
			generation = 0,
			tick = -1,
			now = 0,
			mode = nil,
			resolved = false,
			sightOrigin = nil,
			eyeForward = nil,
			pos = nil,
			fakeRagdoll = nil,
			fakeRagdollResolved = false,
			aimOrigin = nil,
			aimWeapon = nil,
		},
	}
end

function GetOrCreateState(bot)
	local state = bot.ZCBotAI
	if not state then
		state = CreateStateTable()
		bot.ZCBotAI = state
	end

	return state
end

function GetState(bot)
	return IsValid(bot) and bot.ZCBotAI or nil
end

function ClearFakeControlOutput(bot)
	bot.ZCBotFakeButtons = nil
	bot.ZCBotFakeEyeAngles = nil
	bot.ZCBotFakeControlUntil = nil
end

-- Reset replaces the whole state table instead of clearing individual caches.
function Reset(bot)
	if not IsValid(bot) or not bot:IsBot() then return end

	Register(bot)
	bot.ZCBotAI = CreateStateTable()
	ClearFakeControlOutput(bot)
end

function GetBotPlayerCandidates()
	local tick = engine.TickCount()
	if cachedPlayerCandidatesTick ~= tick then
		cachedPlayerCandidates = player.GetAll()
		cachedPlayerCandidatesTick = tick
	end

	return cachedPlayerCandidates
end

function BeginBotCommandContext(bot, state, mode, now)
	Register(bot)
	now = now or CurTime()
	local command = state.command
	command.generation = command.generation + 1
	command.tick = engine.TickCount()
	command.now = now
	command.mode = mode
	command.resolved = true
	command.sightOrigin = nil
	command.eyeForward = nil
	command.pos = nil
	command.fakeRagdoll = nil
	command.fakeRagdollResolved = false
	command.aimOrigin = nil
	command.aimWeapon = nil

	return now
end

function IsBotCommandContextCurrent(bot)
	return IsValid(bot) and bot.ZCBotAI and bot.ZCBotAI.command.tick == engine.TickCount()
end

function GetBotCommandNow(bot)
	local state = bot.ZCBotAI
	if state and state.command.tick == engine.TickCount() then
		return state.command.now or CurTime()
	end

	return CurTime()
end

function SetBotViewAngles(bot, cmd, aimAng, smooth)
	smooth = smooth or BOT_AIM_SMOOTH_TRAVEL
	local current = bot:EyeAngles()
	local viewAng = LerpAngle(math_Clamp(smooth, 0, 1), current, aimAng)

	cmd:SetViewAngles(viewAng)
	bot:SetEyeAngles(viewAng)
	return viewAng
end

function GetBotStaminaFraction(bot)
	local org = bot.organism
	local stamina = org and org.stamina
	if not stamina then return 1 end

	local maxStamina = stamina.max or stamina.range or 180
	if maxStamina <= 0 then return 0 end

	return math_Clamp((stamina[1] or maxStamina) / maxStamina, 0, 1)
end

local COMBAT_BUTTONS = bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD)
BOT_MOVEMENT_BUTTONS = bit_bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP, IN_DUCK, IN_SPEED, IN_WALK)

function ClearCombatButtons(cmd)
	cmd:SetButtons(bit_band(cmd:GetButtons(), bit_bnot(COMBAT_BUTTONS)))
end

function ClearBotMovementInput(cmd)
	cmd:ClearMovement()
	cmd:SetButtons(bit_band(cmd:GetButtons(), bit_bnot(BOT_MOVEMENT_BUTTONS)))
end
