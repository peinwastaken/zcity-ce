local maleAnims = "models/get_up_anims/getup_m.mdl"
local femaleAnims = "models/get_up_anims/getup_m.mdl"
local neturalAnims = "models/get_up_anims/getup_m.mdl"

wOS.DynaBase:RegisterSource({
    Name = "Z-City: CE | Getting up animations",
    Type = WOS_DYNABASE.EXTENSION,

    -- model paths per gender:
    Shared = neturalAnims,      -- default or neutral model
    Female = femaleAnims,    -- female-specific model (optional)
    Male   = maleAnims,     -- optional if you have a male version
})

hook.Add("PreLoadAnimations", "wOS.DynaBase.MountGettingUpAnims", function(gender)
    if gender == WOS_DYNABASE.SHARED then
        IncludeModel(neturalAnims)
    elseif gender == WOS_DYNABASE.FEMALE then
        IncludeModel(femaleAnims)
    elseif gender == WOS_DYNABASE.MALE then
        IncludeModel(maleAnims)
    end
end)
