local botNameColor = Color(255, 185, 70)
local botInfoColor = Color(220, 220, 220)
local botDeadColor = Color(150, 150, 150)
local botStateColor = Color(135, 210, 255)
local botTargetColor = Color(255, 130, 130)
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
		local state = bot:GetNWString("ZCBotAIState", "")
		local detail = bot:GetNWString("ZCBotAIDetail", "")
		local target = bot:GetNWEntity("ZCBotAITarget")
		local weapon = bot:GetNWString("ZCBotAIWeapon", "")
		local targetDist = bot:GetNWFloat("ZCBotAITargetDist", 0)
		local targetText = IsValid(target) and string.format("target: %s (%dm)", target:Nick(), math.floor(targetDist * 0.01905)) or "target: none"
		local stateText = state ~= "" and (detail ~= "" and (state .. " - " .. detail) or state) or "idle"
		local weaponText = weapon ~= "" and ("weapon: " .. weapon) or "weapon: none"

		draw.SimpleTextOutlined(name, "TargetIDSmall", screen.x, screen.y - 12, nameColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, shadowColor)
		draw.SimpleTextOutlined(info, "TargetIDSmall", screen.x, screen.y + 2, botInfoColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, shadowColor)
		draw.SimpleTextOutlined(stateText, "TargetIDSmall", screen.x, screen.y + 16, botStateColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, shadowColor)
		draw.SimpleTextOutlined(targetText, "TargetIDSmall", screen.x, screen.y + 30, botTargetColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, shadowColor)
		draw.SimpleTextOutlined(weaponText, "TargetIDSmall", screen.x, screen.y + 44, botInfoColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, shadowColor)
	end
end)
