local convar = GetConVar("developer")

function IsDeveloper()
  return convar:GetBool()
end