/*
BindInfo
{
  "bind_id" = {
    "key": int,
    "default": int
    "label": string,
    "description": string,
  }
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

function binds.SaveBinds()

end

function binds.LoadBinds()
  
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

  SaveBinds()
end

function binds.RemoveBind(id)
  SaveBinds()
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
