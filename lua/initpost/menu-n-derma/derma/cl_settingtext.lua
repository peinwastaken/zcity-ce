local PANEL = {}

function PANEL:Init()
  self:SetTall(22)
  self.onChanged = nil
end

function PANEL:SetValue(val)
  self:SetText(tostring(val or ""))
end

function PANEL:SetOnChanged(func)
  self.onChanged = func
end

function PANEL:OnEnter()
  if self.onChanged then
    self.onChanged(self:GetValue())
  end
end

function PANEL:OnLoseFocus()
  if self.onChanged then
    self.onChanged(self:GetValue())
  end
end

vgui.Register("ZSettingText", PANEL, "DTextEntry")