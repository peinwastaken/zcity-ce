local convar = GetConVar("developer")

function IsDeveloper()
  return convar:GetBool()
end

function DevPrint(value)
  if !IsDeveloper() then return end

  if type(value) == "table" then
    PrintTable(value)
  elseif type(value) == "string" then
    print(value)
  end
end