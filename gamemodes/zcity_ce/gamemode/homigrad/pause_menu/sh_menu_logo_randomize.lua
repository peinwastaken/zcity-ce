zc = zc or {}

zc.menuBaseLogos = {
  ["base"] = Material("gui/logo_pause.png"),
  ["shrapnel"] = Material("gui/logo_pause_shrapnel.png")
}

zc.menuLogoLayers = {
  ["blood"] = Material("gui/pause_layers/logo_blood.png"),
  ["bulletholes"] = Material("gui/pause_layers/logo_bulletholes.png"),
  ["bullets_and_smoke"] = Material("gui/pause_layers/logo_bullets.png"),
  ["fire"] = Material("gui/pause_layers/logo_fire.png"),
}

zc.menuLayerOrder = {"blood", "bulletholes", "bullets_and_smoke", "fire"}

zc.menuDrawLayers = {
  ["base"] = "base",
  ["layers"] = {}
}