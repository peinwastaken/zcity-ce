/*
BindInfo
{
  "bind_id" = {
    "keycode": int,
    "default": int
    "label": string,
    "description": string,
  }
}
*/

binds = {}

zb.binds = binds or {}

function binds.SaveBinds(bindInfo)

end

function binds.LoadBinds()

end

function binds.UpdateBind(id, keycode)
  SaveBinds()
end

function binds.RemoveBind(id)
  SaveBinds()
end

