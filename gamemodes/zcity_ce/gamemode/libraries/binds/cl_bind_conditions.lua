zc.binds = zc.binds or {}

local function IsAlive()
  local ply = LocalPlayer()
  return IsValid(ply) and ply:Alive()
end

local function IsStanding()
  local ply = LocalPlayer()
  return IsValid(ply) and ply:Alive() and !ply:IsFakeRagdolled()
end

local function IsRagdolled()
  local ply = LocalPlayer()
  return IsValid(ply) and ply:Alive() and ply:IsFakeRagdolled()
end

local function HasActiveWeapon()
  local ply = LocalPlayer()
  if not IsValid(ply) or not ply:Alive() then return false end

  local wep = ply:GetActiveWeapon()
  return IsValid(wep) and not wep.NoDrop
end

local function HasHomigradWeapon()
  local ply = LocalPlayer()
  return IsStanding() and ishgweapon(ply:GetActiveWeapon())
end

local function HasUnderbarrelAttachment()
  local ply = LocalPlayer()
  if not IsValid(ply) or not ply:Alive() then return false end

  local wep = ply:GetActiveWeapon()
  return IsValid(wep) and wep.attachments and wep.HasAttachment and wep:HasAttachment("underbarrel")
end

local function CanOpenRadial()
  local ply = LocalPlayer()
  return IsValid(ply) and ply:Alive() and not (ply.organism and ply.organism.unconscious)
end

local function IsAdmin()
  local ply = LocalPlayer()
  return IsValid(ply) and ply:IsAdmin()
end

local function CanOpenAdminConfig()
  if not IsAdmin() then return false end

  local mode = CurrentRound()
  return mode and mode.Config ~= nil
end

zc.binds.bindConditions = {
  ["kick"] = IsStanding,
  ["zoom"] = function()
    return IsValid(LocalPlayer())
  end,
  ["lean_left"] = IsAlive,
  ["lean_right"] = IsAlive,
  ["altlook"] = IsAlive,
  ["suicide"] = IsAlive,
  ["drop_weapon"] = HasActiveWeapon,
  ["hold_breath"] = function()
    local ply = LocalPlayer()
    return IsAlive() and ply.organism ~= nil
  end,
  ["toggle_laser"] = HasUnderbarrelAttachment,
  ["fake"] = IsAlive,
  ["fake_grab_left"] = IsRagdolled,
  ["fake_grab_right"] = IsRagdolled,
  ["ragdoll_aim"] = IsRagdolled,
  ["fake_aim_toggle"] = function()
    local alwaysRagdollAim = GetConVar("zc_always_ragdoll_aim")
    return IsRagdolled() and alwaysRagdollAim and alwaysRagdollAim:GetBool()
  end,
  ["posture_regular"] = HasHomigradWeapon,
  ["posture_hipfire"] = HasHomigradWeapon,
  ["posture_leftshoulder"] = HasHomigradWeapon,
  ["posture_highready"] = HasHomigradWeapon,
  ["posture_lowready"] = HasHomigradWeapon,
  ["posture_pointshooting"] = HasHomigradWeapon,
  ["posture_cover"] = HasHomigradWeapon,
  ["posture_gangsta"] = HasHomigradWeapon,
  ["posture_onehanded"] = HasHomigradWeapon,
  ["posture_somalian"] = HasHomigradWeapon,
  ["open_radial"] = CanOpenRadial,
  ["open_admin"] = IsAdmin,
  ["open_admin_config"] = CanOpenAdminConfig
}
