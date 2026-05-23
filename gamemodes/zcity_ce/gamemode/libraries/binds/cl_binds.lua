/*
BindInfo
{
  ["bind_id"] = {
    ["key"] = KEY_T,
    ["default"] = nil,
    ["label"] = "Toggle ragdoll",
    ["description"] = "Pretty self-explanatory. Press once to enter and press again to leave ragdoll.",
    ["category"] = "movement",
    ["command"] = "fake"
  }
}

BindConfig
{
  ["bind_id"] = int (keycode)
}
*/

local binds = {}

zb.binds = binds or {}

local BIND_SAVE_PATH = "zcity-ce/settings/binds.json"

local function CreateBindSave()
  local bindSave = {}

  for k,v in pairs(zb.binds.allbinds) do
    bindSave[k] = v.key
  end

  return bindSave
end

local function EnsureBindSaveDir()
  file.CreateDir("zcity-ce")
  file.CreateDir("zcity-ce/settings")
end

function binds.SaveDefaultBinds()
  EnsureBindSaveDir()
  file.Write(BIND_SAVE_PATH, util.TableToJSON(CreateBindSave(), true))
end

function binds.SaveBinds()
  EnsureBindSaveDir()
  file.Write(BIND_SAVE_PATH, util.TableToJSON(CreateBindSave(), true))

  zb.dev.DevPrint("Saved binds")
  zb.dev.DevPrint(binds.allbinds)
end

function binds.LoadBinds()
  local bindsExists = file.Exists(BIND_SAVE_PATH, "DATA")
  if !bindsExists then
    zb.dev.DevPrint("binds file not found, creating default")
    binds.SaveDefaultBinds()
  end
 
  local data = file.Read(BIND_SAVE_PATH, "DATA")
  local bindConfig = nil

  if data then
    local parsed, result = pcall(util.JSONToTable, data)
    bindConfig = parsed and result or nil
  end

  if type(bindConfig) != "table" then
    zb.dev.DevPrint("binds file could not be loaded, restoring default")
    binds.SaveDefaultBinds()
    bindConfig = CreateBindSave()
  end

  local loaded = 0
  local needsUpdate = false
  for id, bind in pairs(binds.allbinds) do
    local configBind = bindConfig[id]

    if !configBind then
      needsUpdate = true
    else
      bind.key = configBind
    end
  end
  
  if needsUpdate then
    binds.SaveBinds()
  end

  zb.dev.DevPrint(string.format("Loaded %s binds", loaded))
end

function binds.GetBind(id)
  local bind = binds[id]
  
  if IsValid(bind) then
    return bind
  end

  return nil
end

function binds.UpdateBind(id, keycode)
  if !binds.allbinds[id] then 
    if zb.dev.IsDeveloper() then
      print(string.format("failed to find bind with id %s", id))  
    end

    return
  end

  binds.allbinds[id].key = keycode

  binds.SaveBinds()
end

function binds.RemoveBind(id)
  binds.SaveBinds()
end

function binds.FindFirstBind(keycode)
  for k,v in pairs(zb.binds.allbinds) do
    if keycode == v.key then
      return v
    end
  end

  return nil
end

hook.Add("PlayerBindPress", "ZC_HandleBindsPress", function(ply, bind, pressed, number)
  local zcBind = binds.FindFirstBind(number)
  if zcBind and pressed then
    RunConsoleCommand(zcBind.command, unpack(zcBind.args or {}))

    return true
  end
end)

hook.Add("InitPostEntity", "ZC_LoadBindsAfterInit", function()
  zb.binds.LoadBinds()
end)

binds.categories = {
  { ["id"] = "movement", ["label"] = "Movement" },
  { ["id"] = "posture", ["label"] = "Stances" },
  { ["id"] = "admin", ["label"] = "Admin" }
}

binds.allbinds = {
  // movement
  ["fake"] = {
    ["key"] = KEY_T,
    ["default"] = nil,
    ["label"] = "Toggle ragdoll",
    ["description"] = "Pretty self-explanatory. Press once to enter and press again to leave ragdoll.",
    ["category"] = "movement",
    ["command"] = "fake"
  },

  // stances
  ["posture_regular"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Regular hold",
    ["description"] = "Standard weapon handling posture",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {0}
  },
  ["posture_hipfire"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Hipfire",
    ["description"] = "Wildly ineffective",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {1}
  },
  ["posture_leftshoulder"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Left shoulder",
    ["description"] = "cl_righthand 0",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {2}
  },
  ["posture_highready"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "High ready",
    ["description"] = "Weapon raised in a ready position",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {3}
  },
  ["posture_lowready"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Low ready",
    ["description"] = "Lowered ready stance",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {4}
  },
  ["posture_pointshooting"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Point shooting",
    ["description"] = "realism!",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {5}
  },
  ["posture_cover"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Shooting from cover",
    ["description"] = "Lean and shoot from cover",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {6}
  },
  ["posture_gangsta"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Gangsta",
    ["description"] = "how to shoot gangsta style",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {7}
  },
  ["posture_onehanded"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "One-handed",
    ["description"] = "Shoot with one hand",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {8}
  },
  ["posture_somalian"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "Somalian",
    ["description"] = "Overhead shooting",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {9}
  },

  // admin
  ["open_admin"] = {
    ["key"] = KEY_F6,
    ["default"] = KEY_F6,
    ["label"] = "Open admin menu",
    ["description"] = "for admin abusers",
    ["category"] = "admin",
    ["command"] = "adminmenu"
  },
  ["open_admin_config"] = {
    ["key"] = KEY_F7,
    ["default"] = KEY_F7,
    ["label"] = "Open gamemode config menu",
    ["description"] = "Opens gamemode config menu for the current gamemode (if the gamemode has configs set up)",
    ["category"] = "admin",
    ["command"] = "adminmenu_modeconfig"
  }
}