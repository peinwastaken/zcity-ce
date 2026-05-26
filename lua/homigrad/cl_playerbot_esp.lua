local botNameColor = Color(255, 185, 70)
local botInfoColor = Color(220, 220, 220)
local botDeadColor = Color(150, 150, 150)
local shadowColor = Color(0, 0, 0, 220)

local function IsDeveloperEnabled()
	if zb and zb.dev and zb.dev.IsDeveloper then
		return zb.dev.IsDeveloper()
	end

	local convar = GetConVar("zc_developer")
	return convar and convar:GetBool()
end

hook.Add("HUDPaint", "ZC_DrawDeveloperBotESP", function()
	if not IsDeveloperEnabled() then return end

	local lply = LocalPlayer()
	if not IsValid(lply) then return end

	for _, bot in ipairs(player.GetAll()) do
		if not IsValid(bot) or not bot:IsBot() or bot == lply then continue end

		local pos = bot:EyePos()
		if pos == vector_origin then
			pos = bot:WorldSpaceCenter()
		end

		local screen = pos:ToScreen()
		if not screen.visible then continue end

		local dist = math.floor(lply:GetPos():Distance(bot:GetPos()) * 0.01905)
		local alive = bot:Alive()
		local nameColor = alive and botNameColor or botDeadColor
		local name = bot:Nick()
		local info = string.format("%dm%s", dist, alive and "" or " DEAD")

		draw.SimpleTextOutlined(name, "TargetIDSmall", screen.x, screen.y - 12, nameColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, shadowColor)
		draw.SimpleTextOutlined(info, "TargetIDSmall", screen.x, screen.y + 2, botInfoColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, shadowColor)
	end
end)
