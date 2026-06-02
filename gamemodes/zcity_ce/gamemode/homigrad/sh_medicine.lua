zc.medicine = zc.medicine or {}

function zc.medicine.HasBandageTarget(org)
	return #org.wounds > 0
		or org.lleg == 1
		or org.rleg == 1
		or org.skull >= 0.6
		or org.chest == 1
		or org.rarm == 1
		or org.larm == 1
end
