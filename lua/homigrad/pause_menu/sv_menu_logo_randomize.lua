hg = hg or {}
local hg = hg

util.AddNetworkString("ZC_GetMenuLayers")
util.AddNetworkString("ZC_SendMenuLayers")

function hg.RandomizeMenuLayers()
  local baseKeys = table.GetKeys(hg.menuBaseLogos)
  table.Shuffle(baseKeys)
  
  local layerKeys = table.GetKeys(hg.menuLogoLayers)
  table.Shuffle(layerKeys)
  
  local layerCount = math.random(0, #layerKeys)
  
  local data = {
    ["base"] = baseKeys[1],
    ["layers"] = {}
  }

  for i = 1, layerCount do
    data.layers[i] = layerKeys[i]
  end

  hg.menuDrawLayers = data
end

hook.Add("InitPostEntity", "ZC_RandomizeMenuLayersOnLoad", function()
  hg.RandomizeMenuLayers()
end)

net.Receive("ZC_GetMenuLayers", function(len, ply)
  net.Start("ZC_SendMenuLayers")
  net.WriteTable(hg.menuDrawLayers)
  net.Send(ply)
end)