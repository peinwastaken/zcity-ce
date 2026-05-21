util.AddNetworkString("ZC_SendModeConfig")
util.AddNetworkString("ZC_RequestModeConfig")
util.AddNetworkString("ZC_RequestModeConfigsOnJoin")
util.AddNetworkString("ZC_SendAllModeConfigs")

/*
  ["mode_id"] = {
    ["variable1"] = "value",
    ["variable2"] = 123
  }
*/
local MODES_CONFIG_PATH = "zcity-ce/config/modes.json"

local modeconfig = {}
zb.modeconfig = modeconfig or {}

local modes = zc.modes
// local dm = modes["dm"]
// local config = dm.Config

net.Receive("ZC_SendModeConfig", function(len, ply)
  if !ply:IsAdmin() then return end
  local dev = zb.dev.IsDeveloper()

  local id = net.ReadString()
  local settings = net.ReadTable()

  if dev then
    zb.dev.DevPrint("received mode data")
    zb.dev.DevPrint(settings)
  end

  local mode = zb.modes[id]
  if !mode then
    print(string.format("could not save config for mode with id %s because it doesn't exist", id))
  end

  for variable, value in pairs(settings) do
    print("looking for variable " .. variable .." in mode ".. mode.name)
    print(value)
    if mode[variable] == nil then print(string.format("could not find variable %s for mode %s", variable, id)) continue end
    mode[variable] = value
  end

  if dev then
    zb.dev.DevPrint(string.format("updated config for mode %s", id))
  end

  modeconfig.BroadcastConfig(mode, settings)
  modeconfig.SaveAll()
end)

net.Receive("ZC_RequestModeConfigsOnJoin", function(len, ply)
  modeconfig.SendAllToPlayer(ply)
end)

function modeconfig.SendAllToPlayer(ply)
  local data = {}

  for id, mode in pairs(zb.modes) do
    data[id] = GetSettingVariablePairsFromMode(mode)
  end

  net.Start("ZC_SendAllModeConfigs")
  net.WriteTable(data)
  net.Send(ply)
end

function modeconfig.BroadcastConfig(mode, config)
  local settingPairs = GetSettingVariablePairsFromMode(mode)

  net.Start("ZC_SendModeConfig")
  net.WriteString(mode.name)
  net.WriteTable(settingPairs)
  net.Broadcast()
end

function modeconfig.BroadcastAll()
  for _, mode in ipairs(zb.modes) do
    if !mode.Config then continue end

    local settingPairs = GetSettingVariablePairsFromMode(mode)

    net.Start("ZC_SendModeConfig")
    net.WriteString(mode.name)
    net.WriteTable(settingPairs)
    net.Broadcast()
  end
end

function modeconfig.LoadAll()
  local configFile = file.Exists(MODES_CONFIG_PATH, "DATA")
  if !configFile then
    modeconfig.CreateDefault()
  end

  local json = file.Read(MODES_CONFIG_PATH, "DATA")
  local configs = util.JSONToTable(json)

  for id, settings in pairs(configs) do
    local mode = zb.modes[id]
    if !mode then continue end

    for settingId, settingValue in pairs(settings) do
      if mode[settingId] == nil then continue end

      mode[settingId] = settingValue
    end
  end
end

function modeconfig.SaveAll()
  local modes = zb.modes
  
  local result = {}
  for id, mode in pairs(modes) do
    local config = mode.Config
    if !config then
      print(string.format("mode %s (%s) does not have a config defined, skipping...", mode.name, id))
      continue
    end

    local settings = config.settings
    for _, setting in pairs(settings) do
      local variable = setting.variable
      local value = mode[variable]

      if value != nil then
        result[id] = result[id] or {}
        result[id][variable] = value
      end
    end
  end

  local json = util.TableToJSON(result)
  local success = file.Write(MODES_CONFIG_PATH, json)

  if (success) then
    print("mode configs saved successfully")
    return result
  end

  print("failed to save mode configs")
  return result
end

function modeconfig.CreateDefault()
  local dirExists = file.IsDir("zcity-ce/config", "DATA")
  if !dirExists then
    file.CreateDir("zcity-ce/config")
  end

  file.Write(MODES_CONFIG_PATH, "{}")
end