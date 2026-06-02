local loaded = false

local modeconfig = {}
zc.modeconfig = modeconfig or {}

net.Receive("ZC_SendModeConfig", function()
  if loaded then return end
  local id = net.ReadString()
  local settings = net.ReadTable()

  local mode = zc.modes[id]
  if !mode then print(string.format("could not find mode %s", id)) return end

  zc.dev.DevPrint("received config data")
  zc.dev.DevPrint(settings)

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
    local mode = zc.modes[id]
    if !mode then continue end

    for settingId, settingValue in pairs(settings) do
      if mode[settingId] == nil then continue end

      mode[settingId] = settingValue
      loaded = loaded + 1
    end
  end

  zc.dev.DevPrint(string.format("loaded %s mode configs from server", loaded))
end)

hook.Add("InitPostEntity", "ZC_RequestModeConfigsOnJoin", function()
  net.Start("ZC_RequestModeConfigsOnJoin")
  net.SendToServer()
end)

net.Start("ZC_RequestModeConfigsOnJoin")
net.SendToServer()