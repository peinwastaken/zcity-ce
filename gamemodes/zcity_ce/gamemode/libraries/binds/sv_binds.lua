util.AddNetworkString("ZC_BindState")

zb.binds = zb.binds or {}

local bindPressedWindow = 0.15

local function IsValidBindId(id)
  return isstring(id) and #id > 0 and #id <= 64 and string.match(id, "^[%w_]+$") ~= nil
end

local function GetBindStates(ply)
  ply.ZCBindStates = ply.ZCBindStates or {}

  return ply.ZCBindStates
end

net.Receive("ZC_BindState", function(len, ply)
  local id = net.ReadString()
  local down = net.ReadBool()

  if !IsValid(ply) or !IsValidBindId(id) then return end

  local bindStates = GetBindStates(ply)
  local bindState = bindStates[id] or {}

  bindState.down = down
  bindState.changed = CurTime()

  if down then
    bindState.pressed = CurTime()
  else
    bindState.released = CurTime()
  end

  bindStates[id] = bindState

  hook.Run("ZC_BindStateChanged", ply, id, down)
end)

function zb.binds.IsDown(ply, id)
  if !IsValid(ply) or !IsValidBindId(id) then return false end

  local bindState = ply.ZCBindStates and ply.ZCBindStates[id]

  return bindState and bindState.down == true or false
end

function zb.binds.WasPressed(ply, id, window)
  if !IsValid(ply) or !IsValidBindId(id) then return false end

  local bindState = ply.ZCBindStates and ply.ZCBindStates[id]
  if !bindState or !bindState.pressed then return false end

  return bindState.pressed >= CurTime() - (window or bindPressedWindow)
end

function zb.binds.WasReleased(ply, id, window)
  if !IsValid(ply) or !IsValidBindId(id) then return false end

  local bindState = ply.ZCBindStates and ply.ZCBindStates[id]
  if !bindState or !bindState.released then return false end

  return bindState.released >= CurTime() - (window or bindPressedWindow)
end

local PLAYER = FindMetaTable("Player")

function PLAYER:ZCBindDown(id)
  return zb.binds.IsDown(self, id)
end

function PLAYER:ZCBindPressed(id, window)
  return zb.binds.WasPressed(self, id, window)
end

function PLAYER:ZCBindReleased(id, window)
  return zb.binds.WasReleased(self, id, window)
end

hook.Add("PlayerDisconnected", "ZC_ClearBindStates", function(ply)
  ply.ZCBindStates = nil
end)
