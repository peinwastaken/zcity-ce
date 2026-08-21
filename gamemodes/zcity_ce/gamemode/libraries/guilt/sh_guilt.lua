zc = zc or {}
zc.MaximumHarm = 10
zc.MaxKarma = 120

local guiltEnabled = CreateConVar("zc_guilt_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Enables the guilt and karma system", 0, 1)

function zc.IsGuiltEnabled()
    return guiltEnabled:GetBool()
end

function zc.GetEffectiveKarma(ply)
    if not zc.IsGuiltEnabled() then return 100 end
    return IsValid(ply) and (ply.Karma or 100) or 100
end
