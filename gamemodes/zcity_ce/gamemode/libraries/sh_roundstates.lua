ROUND_WAITING = 0
ROUND_PREPARING = 1
ROUND_ACTIVE = 2
ROUND_ENDING = 3

zc = zc or {}

zc.RoundStateNames = zc.RoundStateNames or {
	[ROUND_WAITING] = "WAITING",
	[ROUND_PREPARING] = "PREPARING",
	[ROUND_ACTIVE] = "ACTIVE",
	[ROUND_ENDING] = "ENDING",
}

function zc.RoundStateName(state)
	return zc.RoundStateNames[state] or tostring(state)
end

function zc.LegacyRoundState(state)
	if state == ROUND_ACTIVE then return 1 end
	if state == ROUND_ENDING then return 3 end
	return 0
end
