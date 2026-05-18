local convar = CreateConVar("zc_developer", 0, FCVAR_SERVER_CAN_EXECUTE, "Enables zcity developer mode (admin only)", 0, 1)

local dev = {}

zb.dev = dev or {}

function dev.IsDeveloper()
  return convar:GetBool()
end

function dev.DevPrint(value)
  if !dev.IsDeveloper() then return end

  if type(value) == "table" then
    PrintTable(value)
  elseif type(value) == "string" then
    print(value)
  end
end