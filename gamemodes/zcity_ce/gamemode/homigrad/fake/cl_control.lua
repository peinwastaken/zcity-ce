local controlUseCvar = CreateConVar("zc_always_ragdoll_aim", 0, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables permanent +use in fake ragdoll mode", 0, 1)

local function ToggleForcedFakeAim(ply)
	if not controlUseCvar:GetBool() then return end
	if not IsValid(ply) then return end

	if ply.forcefakeaim == false then
		ply.forcefakeaim = controlUseCvar:GetBool()
	else
		ply.forcefakeaim = false
	end
end

hook.Add("ZC_BindStateChanged", "ZC_ToggleForcedFakeAim", function(id, down)
	if id ~= "fake_aim_toggle" or not down then return end

	ToggleForcedFakeAim(LocalPlayer())
end)
