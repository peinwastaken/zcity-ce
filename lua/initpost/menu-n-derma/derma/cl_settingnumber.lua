local PANEL = {}

function PANEL:Init()
  self:SetTall(22)
  self.onChanged = nil
end

function PANEL:SetOnChanged(func)
  self.onChanged = func
end

function PANEL:Paint(w, h)
  surface.SetDrawColor(zc.colors.ui.errorBright)
  surface.DrawOutlinedRect(0, 0, w, h, 1)

  self:DrawTextEntryText(
    zc.colors.ui.white,
    zc.colors.ui.secondaryColor,
    zc.colors.ui.white
  )
end

function PANEL:OnValueChanged(val)
  if self.onChanged then
    self.onChanged(val)
  end
end

vgui.Register("ZSettingNumber", PANEL, "DNumberWang")