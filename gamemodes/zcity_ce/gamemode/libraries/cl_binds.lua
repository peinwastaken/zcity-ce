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

zb.binds.categories = {
  { ["id"] = "movement", ["label"] = "Movement" },
  { ["id"] = "admin", ["label"] = "Admin" }
}

zb.binds.allbinds = {
  ["fake"] = {
    ["key"] = KEY_T,
    ["default"] = nil,
    ["label"] = "Toggle ragdoll",
    ["description"] = "Pretty self-explanatory. Press once to enter and press again to leave ragdoll.",
    ["category"] = "movement",
    ["command"] = "fake"
  },
  ["open_admin"] = {
    ["key"] = KEY_F6,
    ["default"] = KEY_F6,
    ["label"] = "Open admin menu",
    ["description"] = "for admin abusers",
    ["category"] = "admin",
    ["command"] = "adminmenu"
  }
}

local function CreateBindSave()
  local bindSave = {}

  for k,v in pairs(zb.binds.allbinds) do
    bindSave[k] = v.key
  end

  return bindSave
end

function binds.SaveDefaultBinds()
  local dir = file.CreateDir("zcity-ce")

  file.Write("zcity-ce/settings/binds.json", util.TableToJSON(CreateBindSave(), true))
end

function binds.SaveBinds()
  file.Write("zcity-ce/settings/binds.json", util.TableToJSON(CreateBindSave(), true))

  DevPrint("Saved binds")
  DevPrint(binds.allbinds)
end

function binds.LoadBinds()
  local bindsExists = file.Exists("zcity-ce/settings/binds.json", "DATA")
  if !bindsExists then
    DevPrint("binds file not found, creating default")
    binds.SaveDefaultBinds()
  end
 
  local data = file.Read("zcity-ce/settings/binds.json", "DATA")
  local bindConfig = util.JSONToTable(data)

  local loaded = 0
  for k,v in pairs(bindConfig) do
    local bind = binds.allbinds[k]

    if bind then
      bind.key = v
      loaded = loaded + 1
    end
  end

  DevPrint(string.format("Loaded %s binds", loaded))
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
    if IsDeveloper() then
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
  for k,v in pairs(binds.allbinds) do
    if keycode == v.key then
      return v
    end
  end

  return nil
end

hook.Add("PlayerBindPress", "zcity.binds.press", function(ply, bind, pressed, number)
  local zcBind = binds.FindFirstBind(number)
  if zcBind and pressed then
    if IsDeveloper() then
      print(string.format("found bind %s", zcBind.label))
    end

    RunConsoleCommand(zcBind.command)

    return true
  end
end)

zb.binds.LoadBinds()
