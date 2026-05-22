local function CreateConfigRow(mode, setting, settingPairs, parent)
  local row = vgui.Create("DPanel", parent)
  row:DockPadding(15, 5, 15, 5)
  row.Paint = function(self, w, h)
    surface.SetDrawColor(zc.colors.ui.blackOverlay)
    surface.DrawRect(0, 0, w, h)
  end

  local infoPanel = vgui.Create("DPanel", row)
  infoPanel:DockPadding(0, 5, 0, 5)
  infoPanel:Dock(FILL)
  infoPanel.Paint = function() end

  local settingName = vgui.Create("DLabel", infoPanel)
  settingName:SetText(setting.label)
  settingName:Dock(TOP)

  local settingDesc = vgui.Create("DLabel", infoPanel)
  settingDesc:SetColor(Color(180, 180, 180, 255))
  settingDesc:SetText(setting.description)
  settingDesc:Dock(TOP)

  local variable = setting.variable
  local settingType = type(settingPairs[variable])
  if settingType == "boolean" then
    local btn = vgui.Create("ZSettingToggle", row)
    btn:DockMargin(15, 10, 0, 10)
    btn:Dock(RIGHT)
    btn:SetValue(settingPairs[variable])
    btn:SetOnChanged(function(val)
      settingPairs[variable] = val
    end)
  elseif settingType == "number" then
    local num = vgui.Create("ZSettingNumber", row)
    num:DockMargin(15, 10, 0, 10)
    num:Dock(RIGHT)
    num:SetMinMax(-99999, 99999)
    num:SetValue(settingPairs[variable])
    num:SetOnChanged(function(val)
      settingPairs[variable] = val
    end)
  elseif settingType == "string" then
    local txt = vgui.Create("ZSettingText", row)
    txt:DockMargin(15, 10, 0, 10)
    txt:Dock(RIGHT)
    txt:SetValue(settingPairs[variable])
    txt:SetOnChanged(function(val)
      settingPairs[variable] = val
    end)
  end

  // fix layout
  infoPanel:InvalidateLayout(true)
  infoPanel:SizeToChildren(true, true)

  row:InvalidateLayout()
  row:SizeToChildren(false, true)

  return row
end

local function SaveSettings(mode, settingPairs)
  net.Start("ZC_SendModeConfig", false)
  net.WriteString(mode.name)
  net.WriteTable(settingPairs)
  net.SendToServer()
end

local openMenu = nil
local function OpenAdminConfigMenu(modeId)
  local lply = LocalPlayer()
  if !lply:IsAdmin() then print("not admin") return end
  if openMenu then return end

  local id = modeId or zb.CROUND
  local mode = zb.modes[id]
  if !mode then
    print(string.format("Could not find gamemode with id %s", id))
    return
  end

  local modeConfig = mode.Config
  if !modeConfig then
    print(string.format("Gamemode %s (%s) has no MODE.Config", mode.PrintName, id))
    return
  end

  local settingPairs = GetSettingVariablePairsFromMode(mode)

  local parent = vgui.Create("ZFrame")
  parent:SetTitle("Current mode config")
  parent:SetWide(500)
  parent:DockPadding(15, parent.lblTitle:GetTall() + 10, 15, 15)
  parent:MakePopup()
  parent.OnRemove = function()
    openMenu = nil
  end

  local nameLabel = vgui.Create("DLabel", parent)
  nameLabel:SetText(string.format("Current gamemode: %s (%s)", mode.PrintName, mode.name))
  nameLabel:SizeToContents()
  nameLabel:DockMargin(0, 0, 0, 10)
  nameLabel:Dock(TOP)

  local scrollPanel = vgui.Create("DScrollPanel", parent)
  scrollPanel:SetTall(300)
  scrollPanel:Dock(TOP)
  scrollPanel.Paint = function() end

  for _, setting in ipairs(modeConfig.settings) do
    local row = CreateConfigRow(mode, setting, settingPairs, scrollPanel)
    row:SetWide(scrollPanel:GetWide())
    row:DockMargin(0, 0, 0, 5)
    row:Dock(TOP)
  end

  local controlsPanel = vgui.Create("DPanel", parent)
  controlsPanel:SetTall(64)
  controlsPanel:DockMargin(0, 5, 0, 0)
  controlsPanel:Dock(TOP)
  controlsPanel.Paint = function(self, w, h)
    surface.SetDrawColor(zc.colors.ui.blackOverlay)
    surface.DrawRect(0, 0, w, h)
  end

  local saveButton = vgui.Create("ZButton", controlsPanel)
  saveButton:SetText("Save settings")
  saveButton:SetTall(40)
  saveButton:SetWide(100)
  saveButton:Center()
  saveButton.DoClick = function()
    parent:Close()
    SaveSettings(mode, settingPairs)
  end

  function controlsPanel:PerformLayout(w, h)
    local posX = (w - saveButton:GetWide()) / 2
    local posY = (h - saveButton:GetTall()) / 2
    saveButton:SetPos(posX, posY)
  end

  parent:InvalidateLayout(true)
  parent:SizeToChildren(false, true)
  parent:Center()

  openMenu = parent
end

concommand.Add("adminmenu_modeconfig", function(ply, cmd, args)
  local mode = args[1] or nil
  OpenAdminConfigMenu(mode)
end, function() end, "Opens gamemode config menu (admin only)", nil)