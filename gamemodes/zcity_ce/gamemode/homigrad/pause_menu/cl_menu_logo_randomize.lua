hg = hg or {}
local hg = hg

function hg.FetchMenuLayers()
  net.Start("ZC_GetMenuLayers")
  net.SendToServer()
end

net.Receive("ZC_SendMenuLayers", function()
  local layers = net.ReadTable()
  if !layers then return end

  PrintTable(layers)

  hg.menuDrawLayers = layers
end)

hook.Add("InitPostEntity", "ZC_LoadMenuLogoLayers", function()
  hg.FetchMenuLayers()
end)