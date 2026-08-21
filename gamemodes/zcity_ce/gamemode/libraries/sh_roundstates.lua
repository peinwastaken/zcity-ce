-- Named round states used by the zc.round controller.
-- These are the controller's internal states and are networked verbatim
-- inside "ZC_RoundState". They are intentionally distinct from the legacy
-- numeric zc.ROUND_STATE global, which the controller keeps in sync for
-- unmigrated code (PREPARING/WAITING -> 0, ACTIVE -> 1, ENDING -> 3).

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

-- Map a controller state to the legacy numeric ROUND_STATE values that
-- existing systems expect. Kept in one place so the mapping stays obvious.
function zc.LegacyRoundState(state)
	if state == ROUND_ACTIVE then return 1 end
	if state == ROUND_ENDING then return 3 end
	return 0
end
