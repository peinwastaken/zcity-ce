local modeconfig = {}
zb.modeconfig = modeconfig or {}

net.Receive("ZC_SendModeConfig", function()
  local id = net.ReadString()
  local settings = net.ReadTable()

  local mode = zb.modes[id]
  if !mode then print(string.format("could not find mode %s", id)) return end

  zb.dev.DevPrint("received config data")
  zb.dev.DevPrint(settings)

  for id, value in pairs(settings) do
    if mode[id] != nil then
      mode[id] = value
    end
  end
end)

net.Receive("ZC_SendAllModeConfigs", function()
  local modeSettings = net.ReadTable()

  local loaded = 0
  for id, settings in pairs(modeSettings) do
    local mode = zb.modes[id]
    if !mode then continue end

    for settingId, settingValue in pairs(settings) do
      if mode[settingId] == nil then continue end

      mode[settingId] = settingValue
      loaded = loaded + 1

      print(mode[settingId])
    end
  end

  zb.dev.DevPrint(string.format("loaded %s mode configs from server", loaded))
end)

hook.Add("InitPostEntity", "ZC_RequestModeConfigsOnJoin", function()
  net.Start("ZC_RequestModeConfigsOnJoin")
  net.SendToServer()
end)