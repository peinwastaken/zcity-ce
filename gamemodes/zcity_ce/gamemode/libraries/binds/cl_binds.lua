concommand.Add("zc_binds_default", function()
  zb.binds.SaveDefaultBinds()
  print("resetting binds...")
end)

/*
BindInfo
{
  ["bind_id"] = {
    ["key"] = KEY_T, // current bind
    ["default"] = KEY_NONE, // what the bind defaults to when the player first joins
    ["label"] = "Toggle ragdoll", // bind label in binds menu
    ["description"] = "Bind description", // bind description in binds menu
    ["category"] = "movement", // category, id from binds.categories
    ["command"] = "fake", // command that is executed
    ["args"] = {0}, // args passed to the command being executed (optional)
    ["should_override"] = true // should bind override the console bind? (bind k "kill" would be overriden by our bind) 
    ["default_override"] = true // what the override value defaults to when the player first joins
  }
}

BindConfig
{
  ["bind_id"] = {
    ["key"] = int, // (KEY_CODE)
    ["should_override"] = bool
  }
}
*/

local binds = {}

zb.binds = binds or {}

local BIND_SAVE_PATH = "zcity-ce/settings/binds.json"

local function CreateBindSave(default)
  default = default or false
  local bindSave = {}

  for k,v in pairs(zb.binds.allbinds) do
    local key = default and v.default or v.key
    local override = default and v.default_override or v.should_override

    bindSave[k] = {
      ["key"] = key,
      ["should_override"] = override
    }

    if default then
      v.key = v.default
      v.should_override = v.default_override
    end
  end

  return bindSave
end

local function EnsureBindSaveDir()
  file.CreateDir("zcity-ce")
  file.CreateDir("zcity-ce/settings")
end

function binds.SaveDefaultBinds()
  EnsureBindSaveDir()
  file.Write(BIND_SAVE_PATH, util.TableToJSON(CreateBindSave(true), true))
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
      bind.key = configBind.key
      bind.should_override = configBind.should_override
    end
  end
  
  if needsUpdate then
    binds.SaveBinds()
  end

  zb.dev.DevPrint(string.format("Loaded %s binds", loaded))
end

function binds.GetBind(id)
  local bind = binds.allbinds[id]

  if bind then
    return bind
  end

  if zb.dev.IsDeveloper() then
    print(string.format("failed to find bind with id %s", id))  
  end

  return nil
end

function binds.UpdateBind(id, keycode)
  local bind = binds.GetBind(id)
  if !bind then return end

  bind.key = keycode
  binds.SaveBinds()
end

function binds.UpdateBindOverride(id, override)
  local bind = binds.GetBind(id)
  if !bind then return end

  bind.should_override = override
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

hook.Add("PlayerBindPress", "ZC_PlayerBindPressed", function(ply, bind, pressed, key)
  local zcBind = binds.FindFirstBind(key)
  if !zcBind then return end
  if zcBind.key == KEY_NONE then return end

  local command = zcBind.command or ""

  if pressed then
    RunConsoleCommand(command, unpack(zcBind.args or {}))
  end

  if zcBind.should_override == true then
    return true
  end
end)

hook.Add("PlayerButtonUp", "ZC_PlayerBindUnpressed", function(ply, key)
  local zcBind = binds.FindFirstBind(key)
  if !zcBind then return end

  local command = zcBind.command or ""

  if string.StartsWith(command, "+") then
    RunConsoleCommand("-" .. string.TrimLeft(command, "+"), unpack(zcBind.args or {}))
  end
end)

hook.Add("InitPostEntity", "ZC_LoadBindsAfterInit", function()
  zb.binds.LoadBinds()
end)

binds.categories = {
  { ["id"] = "movement", ["label"] = "binds/category/movement" },
  { ["id"] = "weapon", ["label"] = "binds/category/weapon" },
  { ["id"] = "ragdoll", ["label"] = "binds/category/ragdoll" },
  { ["id"] = "posture", ["label"] = "binds/category/posture" },
  { ["id"] = "misc", ["label"] = "binds/category/misc"},
  { ["id"] = "admin", ["label"] = "binds/category/admin" }
}

binds.allbinds = {
  // movement
  ["kick"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/kick",
    ["description"] = "binds/kick/desc",
    ["category"] = "movement",
    ["command"] = "hg_kick",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["zoom"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/zoom",
    ["description"] = "binds/zoom/desc",
    ["category"] = "movement",
    ["command"] = "+hg_zoom",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["lean_left"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/lean_left",
    ["description"] = "binds/lean_left/desc",
    ["category"] = "movement",
    ["command"] = "+alt1",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["lean_right"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/lean_right",
    ["description"] = "binds/lean_right/desc",
    ["category"] = "movement",
    ["command"] = "+alt2",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["altlook"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/altlook",
    ["description"] = "binds/altlook/desc",
    ["category"] = "movement",
    ["command"] = "+altlook",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["suicide"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/suicide",
    ["description"] = "binds/suicide/desc",
    ["category"] = "movement",
    ["command"] = "suicide",
    ["should_override"] = false,
    ["default_override"] = false
  },

  // weapons
  ["drop_weapon"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/drop_weapon",
    ["description"] = "binds/drop_weapon/desc",
    ["category"] = "weapon",
    ["command"] = "drop",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["hold_breath"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/hold_breath",
    ["description"] = "binds/hold_breath/desc",
    ["category"] = "weapon",
    ["command"] = "+hmcd_holdbreath",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["toggle_laser"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/toggle_laser",
    ["description"] = "binds/toggle_laser/desc",
    ["category"] = "weapon",
    ["command"] = "hmcd_togglelaser",
    ["should_override"] = false,
    ["default_override"] = false
  },

  // ragdoll
  ["fake"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/fake",
    ["description"] = "binds/fake/desc",
    ["category"] = "movement",
    ["command"] = "fake",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["fake_grab_left"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/fake_grab_left",
    ["description"] = "binds/fake_grab_left/desc",
    ["category"] = "ragdoll",
    ["command"] = "+speed",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["fake_grab_right"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/fake_grab_right",
    ["description"] = "binds/fake_grab_right/desc",
    ["category"] = "ragdoll",
    ["command"] = "+walk",
    ["should_override"] = false,
    ["default_override"] = false
  },

  // stances
  ["posture_regular"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_regular",
    ["description"] = "binds/posture_regular/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {0},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_hipfire"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_hipfire",
    ["description"] = "binds/posture_hipfire/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {1},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_leftshoulder"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_leftshoulder",
    ["description"] = "binds/posture_leftshoulder/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {2},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_highready"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_highready",
    ["description"] = "binds/posture_highready/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {3},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_lowready"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_lowready",
    ["description"] = "binds/posture_lowready/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {4},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_pointshooting"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_pointshooting",
    ["description"] = "binds/posture_pointshooting/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {5},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_cover"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_cover",
    ["description"] = "binds/posture_cover/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {6},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_gangsta"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_gangsta",
    ["description"] = "binds/posture_gangsta/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {7},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_onehanded"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_onehanded",
    ["description"] = "binds/posture_onehanded/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {8},
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["posture_somalian"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/posture_somalian",
    ["description"] = "binds/posture_somalian/desc",
    ["category"] = "posture",
    ["command"] = "hg_change_posture",
    ["args"] = {9},
    ["should_override"] = false,
    ["default_override"] = false
  },

  // misc
  ["open_radial"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/open_radial",
    ["description"] = "binds/open_radial/desc",
    ["category"] = "misc",
    ["command"] = "+radialmenu",
    ["should_override"] = false,
    ["default_override"] = false
  },

  // admin
  ["open_admin"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/open_admin",
    ["description"] = "binds/open_admin/desc",
    ["category"] = "admin",
    ["command"] = "adminmenu",
    ["should_override"] = false,
    ["default_override"] = false
  },
  ["open_admin_config"] = {
    ["key"] = KEY_NONE,
    ["default"] = KEY_NONE,
    ["label"] = "binds/open_admin_config",
    ["description"] = "binds/open_admin_config/desc",
    ["category"] = "admin",
    ["command"] = "adminmenu_modeconfig",
    ["should_override"] = false,
    ["default_override"] = false
  }
}
