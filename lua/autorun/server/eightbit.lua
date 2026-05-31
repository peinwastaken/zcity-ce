if util.IsBinaryModuleInstalled("eightbit") then
	require("eightbit")

	if eightbit.SetDamp1 then
		eightbit.SetDamp1(0.85)
	end

	if eightbit.SetProotCutoff then
		eightbit.SetProotCutoff(0.7)
	end

	if eightbit.SetProotGain then
		eightbit.SetProotGain(0.7)
	end
else
	MsgC(Color(255, 0, 0), "Eightbit module is not found.\n")
end
