function GetModeConfig(modeId)
  local mode = zb.modes[modeId]
  if !mode then return nil end

  local config = mode.Config
  if !config then return nil end

  return config
end

function GetCurrentModeId()
  return CurrentRound().name
end

function GetSettingVariablePairsFromMode(mode)
  local config = mode.Config
  if !config then return nil end

  local settings = mode.Config.settings
  local result = {}

  for _, setting in pairs(settings) do
    result[setting.variable] = mode[setting.variable]
  end

  return result
end