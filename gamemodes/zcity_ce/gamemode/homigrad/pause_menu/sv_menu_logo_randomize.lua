zc = zc or {}
local zc = zc

util.AddNetworkString("ZC_GetMenuLayers")
util.AddNetworkString("ZC_SendMenuLayers")

function zc.RandomizeMenuLayers()
  local baseKeys = table.GetKeys(zc.menuBaseLogos)
  table.Shuffle(baseKeys)
  
  local layerKeys = table.GetKeys(zc.menuLogoLayers)
  table.Shuffle(layerKeys)
  
  local layerCount = math.random(0, #layerKeys)
  
  local data = {
    ["base"] = baseKeys[1],
    ["layers"] = {}
  }

  for i = 1, layerCount do
    data.layers[i] = layerKeys[i]
  end

  zc.menuDrawLayers = data
end

hook.Add("InitPostEntity", "ZC_RandomizeMenuLayersOnLoad", function()
  zc.RandomizeMenuLayers()
end)

net.Receive("ZC_GetMenuLayers", function(len, ply)
  net.Start("ZC_SendMenuLayers")
  net.WriteTable(zc.menuDrawLayers)
  net.Send(ply)
end)