zc.round = zc.round or {}

surface.CreateFont("ZC_RoundIntroTitle", {
	font = "Bahnschrift",
	size = ScreenScale(20),
	weight = 400,
	antialias = true,
})

surface.CreateFont("ZC_RoundIntroRole", {
	font = "Bahnschrift",
	size = ScreenScale(14),
	weight = 400,
	antialias = true,
})

surface.CreateFont("ZC_RoundIntroObjective", {
	font = "Bahnschrift",
	size = ScreenScale(10),
	weight = 400,
	antialias = true,
})

local lastSoundRound

net.Receive("ZC_RoundIntro", function()
	local id = net.ReadUInt(16)
	zc.round.intro = {
		id = id,
		introStart = net.ReadFloat(),
		introEnd = net.ReadFloat(),
		Title = net.ReadString(),
		Objective = net.ReadString(),
		Role = net.ReadString(),
		Color = net.ReadColor(),
		Sound = net.ReadString(),
		soundPlayed = false,
	}
end)

hook.Add("HUDPaint", "ZC_RoundIntro", function()
	local intro = zc.round.intro
	if not intro then return end

	local now = CurTime()
	if now < intro.introStart or now > intro.introEnd then return end

	if not intro.soundPlayed then
		intro.soundPlayed = true
		if lastSoundRound ~= intro.id and intro.Sound and intro.Sound ~= "" then
			lastSoundRound = intro.id
			surface.PlaySound(intro.Sound)
		end
	end

	if zc.RemoveFade then zc.RemoveFade() end

	local elapsed = now - intro.introStart
	local remaining = intro.introEnd - now
	local alpha = math.Clamp(elapsed / 0.5, 0, 1) * math.Clamp(remaining, 0, 1)

	local col = intro.Color or Color(190, 15, 15)
	local sw, sh = ScrW(), ScrH()

	surface.SetAlphaMultiplier(alpha)
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, sw, sh)

	draw.SimpleText(intro.Title ~= "" and intro.Title or "", "ZC_RoundIntroTitle",
		sw * 0.5, sh * 0.1, Color(col.r, col.g, col.b, 255),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if intro.Role and intro.Role ~= "" then
		draw.SimpleText("You are a " .. intro.Role, "ZC_RoundIntroRole",
			sw * 0.5, sh * 0.5, Color(col.r, col.g, col.b, 255),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if intro.Objective and intro.Objective ~= "" then
		draw.SimpleText(intro.Objective, "ZC_RoundIntroObjective",
			sw * 0.5, sh * 0.9, Color(col.r, col.g, col.b, 255),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText(string.FormattedTime(remaining, "%02i:%02i"), "ZC_RoundIntroObjective",
		sw * 0.5, sh * 0.16, color_white,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetAlphaMultiplier(1)
end)
