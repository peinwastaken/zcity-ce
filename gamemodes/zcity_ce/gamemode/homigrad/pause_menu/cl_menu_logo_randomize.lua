zc = zc or {}
local zc = zc

function zc.FetchMenuLayers()
  net.Start("ZC_GetMenuLayers")
  net.SendToServer()
end

net.Receive("ZC_SendMenuLayers", function()
  local layers = net.ReadTable()
  if !layers then return end

  PrintTable(layers)

  zc.menuDrawLayers = layers
end)

hook.Add("InitPostEntity", "ZC_LoadMenuLogoLayers", function()
  zc.FetchMenuLayers()
end)