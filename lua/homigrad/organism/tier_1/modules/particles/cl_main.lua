local delay = 0
local math_min = math.min
local CurTime, _ = CurTime, FrameTime
bloodparticles_hook = bloodparticles_hook or {}
local bloodparticles_hook = bloodparticles_hook

local zc_blood_fps = ConVarExists("zc_blood_fps") and GetConVar("zc_blood_fps") or CreateClientConVar("zc_blood_fps", 24, true, nil, "fps to draw blood", 12, 165)

hook.Add("PreDrawEffects", "bloodpartciels", function()
	local time = CurTime()
	local fps = 1 / zc_blood_fps:GetInt()-- / game.GetTimeScale()
	if not bloodparticles_hook then return end
	local animpos = math_min((delay - time) / fps, 1)
	if not bloodparticles_hook[1] then return end

	bloodparticles_hook[1](animpos, fps)
	bloodparticles_hook[3](animpos, fps)

	if delay < time then
		delay = time + fps

		bloodparticles_hook[2](fps)
		bloodparticles_hook[4](fps)
	end
end)

hook.Add("PostCleanupMap","remove_decals",function()
	table.Empty(hg.bloodparticles1)
	table.Empty(hg.bloodparticles2)
end)