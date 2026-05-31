local MODE = MODE

local color = Color(0, 162, 255, 255)
local white = Color(255, 255, 255, 255)

function MODE:HUDPaint()
	if not lply:Alive() then return end
  if zb.ROUND_START + 8.5 < CurTime() then return end

	zb.RemoveFade()
  
  local fade = math.Clamp(zb.ROUND_START + 8 - CurTime(), 0, 1)
  color.a = 255 * fade
  white.a = 255 * fade

  draw.SimpleText("Sandbox", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  draw.SimpleText("You are a sandboxer", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
  draw.SimpleText("Do whatever you want!", "ZB_HomicideMedium", sw * 0.5, sh * 0.9, white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end