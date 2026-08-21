zc.round = zc.round or {}
zc.round.id = zc.round.id or 0
zc.round.state = zc.round.state or ROUND_WAITING
zc.round.stateStarted = zc.round.stateStarted or 0

net.Receive("ZC_RoundState", function()
	local r = zc.round

	local id = net.ReadUInt(16)
	local modeName = net.ReadString()
	local state = net.ReadUInt(3)
	local stateStarted = net.ReadFloat()
	local stateEnds = net.ReadFloat()
	local hasResult = net.ReadBool()

	r.id = id
	r.modeName = modeName
	r.stateStarted = stateStarted
	r.stateEnds = stateEnds > 0 and stateEnds or nil

	if hasResult then
		r.result = {
			reason = net.ReadString(),
			winner = net.ReadEntity(),
		}
	else
		net.ReadString()
		net.ReadEntity()
		if state ~= ROUND_ENDING then r.result = nil end
	end

	local oldState = r.state
	r.state = state

	zc.CROUND = modeName ~= "" and modeName or zc.CROUND
	zc.ROUND_STATE = zc.LegacyRoundState(state)

	if state == ROUND_WAITING then
		zc.round.intro = nil
	end

	local mode = modeName ~= "" and zc.modes[modeName] or nil
	if mode and mode.OnClientStateChanged then
		local ok, err = pcall(mode.OnClientStateChanged, mode, r, oldState)
		if not ok then
			ErrorNoHalt("[zc.round] OnClientStateChanged error: " .. tostring(err) .. "\n")
		end
	end
end)
