local PANEL = {}

function PANEL:Init()
  self:SetTall(22)
  self:SetText("")
  self.enabled = false
  self.onChanged = nil
end

function PANEL:SetValue(val)
  self.enabled = tobool(val)
end

function PANEL:SetOnChanged(func)
  self.onChanged = func
end

function PANEL:DoClick()
  self.enabled = not self.enabled

  if self.onChanged then
    self.onChanged(self.enabled)
  end
end

function PANEL:Paint(w, h)
  local enabled = self.enabled
  local text = enabled and "Enabled" or "Disabled"

  surface.SetDrawColor(
    enabled and zc.colors.ui.successBright or zc.colors.ui.errorBright
  )
  surface.DrawOutlinedRect(0, 0, w, h, 1)

  draw.SimpleText(
    text,
    "DermaDefault",
    w * 0.5,
    h * 0.5,
    zc.colors.ui.white,
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_CENTER
  )
end

vgui.Register("ZSettingToggle", PANEL, "DButton")