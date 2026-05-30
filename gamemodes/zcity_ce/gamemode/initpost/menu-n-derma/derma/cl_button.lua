local PANEL = {}

function PANEL:Init()
  self:SetTall(22)
  self:SetText("")
  self.label = ""
  self.onClick = nil
end

function PANEL:SetLabel(text)
  self.label = text or ""
  self:SetText(text)
end

function PANEL:SetOnClick(func)
  self.onClick = func
end

function PANEL:DoClick()
  if self.onClick then
    self.onClick()
  end
end

function PANEL:Paint(w, h)
  surface.SetDrawColor(zc.colors.ui.errorBright)
  surface.DrawOutlinedRect(0, 0, w, h, 1)

  draw.SimpleText(
    self.label,
    "DermaDefault",
    w * 0.5,
    h * 0.5,
    zc.colors.ui.white,
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_CENTER
  )
end

vgui.Register("ZButton", PANEL, "DButton")