local allowedchars = {
	"ah",
	"AH",
	"ghh",
	"GH",
	"AHHH",
}

local audible_pain = {
	"AH FUCK! THAT FUCKING HURTS!",
	"I CAN'T TAKE THIS ANYMORE!",
    "Jesus Christ, make it STOP!",
    "Why won't IT STOP!?",
    "I need to pass out - right fucking now.",
    "Why did I have to be the one to endure this...",
    "I'd do anything for this to stop...",
    "I can't bear this torture any longer.",
    "I don't care anymore, just STOP the PAIN!",
    "I can't focus on anything except for this pain.",
    "Every second is excruciating.",
    "Just fucking kill me...",
    "Just one moment without this pain...",
	"I need some god-damn painkillers.",
}

local sharp_pain = {
	"AAAHH!!",
	"AAAH!",
	"AAaaAH!",
	"AAaaAH!! SHIT!",
	"AAaaAAAGH FUCK!",
	"AAaaAH!",
	"AAaAaaH!",
	"AAAAAaaH!",
	"AAaaAHHHH!",
	"AAaAA!",
	"AAAAAa!",
	"AAAaaAa!",
	"AAAaaGHHH!!",
	"AAAaaAAHH!!",
}

hg.sharp_pain = sharp_pain

local random_phrase = {
	"*yawn*",
	"Everything seems too quiet...",
	"Just another day...",
	"What if this quiet lasts forever?",
	"Man, I'm bored.",
}

local fear_hurt_ironic = {
	"I bet there's a lesson in this... if I survive.",
	"If only my dad could see me now...",
	"Well, this is a stupid way to go.",
	"At least my life wasn't boring.",
	"Note to self: Never do this again.",
	"This isn't the worst day to die.",
}

local fear_phrases = {
	"It's not that bad... right?",
	"I don't want to die like this.",
	"Is this really how it ends?",
	"This isn't good.",
	"Is this really how it ends?",
	"I don't want to die like this.",
	"I wish I had a way out.",
	"I regret so many things.",
	"This can't be it.",
	"I can't believe this is happening to me.",
	"I should've taken this more seriously.",
	"What if I don't make it..?",
	"This is worse than I thought.",
	"This is so unfair.",
	"I can't give up yet.",
	"I never thought it would be like this.",
	"I should've listened to my instincts.",
	"Breathe. Just breathe.",
	"Cold hands. Steady hands.",
}

local is_aimed_at_phrases = {
    "Oh God. This is it.",
    "Don't. move.",
    "Is this really how I die?",
    "I should've run. Why didn't I run?",
    "Please don't pull the trigger. Please.",
    "I can see their finger on the trigger.",
    "I don't want to die. Not like this.",
    "If I beg, will it make it worse?",
    "This can't be real. This can't be real.",
    "Someone help me. Please. Someone.",
    "I don't want to die in a place like this.",
    "I don't want my last thought to be fear.",
    "I don't want to die.",
}

local near_death_poetic = {
	"Trying to stand... but I just can't...",
	"Breathing's just performative at this point...",
	"Can't tell if my eyes are open or not anymore...",
	"Last thing I'll taste is my own blood.",
	"My eyes can't focus any more.",
	"Can't remember how to keep myself upright.",
	"Everything echoes inside my skull.",
	"An eternity passes with each blink.",
	"Fingers won't close around anything.",
	"Lungs refuse to be full.",
	"Regrets are pointless now.",
}


local broken_limb = {
	"FUCK. IT'S DEFINITELY BROKEN!",
	"I CAN FEEL THE SHARDS OF BONE MOVING!",
	"IT'S FUCKING BROKEN. I THINK...",
	"It hurts just thinking about it. Definitely broken.",
	"I don't think it should bend here.",
	"Oh fuck. It's snapped.",
	"I don't see anything wrong, but I feel like I broke something.",
}

local dislocated_limb = {
	"Yeah, that shouldn't be bending like that.",
	"I have to get this bone back in.",
	"No... I have to move it back in place.",
	"Something popped out. I need to take a look at it.",
	"One of my limbs is fucked up.",
}

local hungry_a_bit = {
    "Hmm, I'm hungry...",
    "Some food would be great.",
    "I'm hungry...",
    "I should eat something.",
}

local very_hungry = {
    "My stomach... Ugh.",
    "If I don't eat, I'll feel even worse.",
    "My stomach... fuck... I feel sick",
}

local after_unconscious = {
	"Jesus, how long was I out for?",
	"Everything's blurry...",
	"Fuck, that's not good.",
    "What happened? It hurts...",
	"Where am I? Why does it hurt...",
	"I thought I was going to die...",
	"My head... What happened?",
	"Did I almost die a second ago?",
	"It felt like I died.",
	"Oh fuck... my head is aching...",
	"Man, it's going to be a pain to get up again.",
	"I don't recognize this place at all.",
	"I don't want to experience this ever again.",
}

local slight_braindamage_phraselist = {
	"I don't understand...",
	"It doesn't make sense...",
	"Where am I?",
	"Huh? What is this..?",
	"I don't know what is happening...",
	"Hello?",
	"Ughhh, ohhhh...      huh...",
	"What... is happening?",
}

local braindamage_phraselist = {
	"Bbbee.. wheea mgh?!",
	"Bmmeee... mehk...",
	"Mm--hhhh. Mmm?",
	"Ghmgh whhh...",
	"Ahgg...mg?",
	"Hgghh... D-Dmmh.",
	"Lmmmphf, mp-hf!",
	"Heeelllhhpphp...",
	"Nghh... Gmh?",
	"Ggg... Bgh..",
	"Bhrhraihin.",
}

local cold_phraselist = {
	"It's getting very cold..",
	"Too cold for me.",
	"God damn, it's fucking freezing.",
	"Way too fucking cold out here..",
	"Need something to warm myself up...",
	"I feel pretty cold...",
	"I can't feel my fingers, it's too cold."
}

local freezing_phraselist = {
	"I.. ca.. can't feel m-my b-body..",
	"I can't.. f-feel my legs...",
	"I'm f-fuck-king fre-ezing..",
	"M-My face is num-mb..",
	"C-cold..",
	"I.. can't feel a-ny-t-thing..",
}

local numb_phraselist = {
	"It's not.. cold anymore..",
	"Why... does it feel warm..?",
	"I think I'm okay... I think...",
	"Finally, some warmth...",
	"I'm warm again...",
	"I was just freezing... Where did this heat come from..?",
}

local hot_phraselist = {
	"I'm so sweaty, need to cool off.",
	"This heat is killing me..",
	"I'm drenched with sweat.",
	"I should really cool down...",
	"It's a bit too hot.",
	"I'm too warm right now.",
	"Why is it so hot in here?",
}

local heatstroke_phraselist = {
	"My head feels like it's going to explode.",
	"Please... water...",
	"I feel dizzy.",
	"So this is a migraine...",
	"My head is aching..",
}

local heatvomit_phraselist = {
	"That heat.. I'm gonna vomit-",
	"Ugh... I'm about to puke-",
	"Fuck.. Ugh.. I don't feel-"
}

if not ConVarExists("hg_showthoughts") then
	CreateClientConVar("hg_showthoughts", "1", true, true, "Toggle thoughts of your character", 0, 1)
end

function string.Random(length)
	local length = tonumber(length)

    if length < 1 then return end

    local result = {}

    for i = 1, length do
        result[i] = allowedchars[math.random(#allowedchars)]
    end

    return table.concat(result)
end

function hg.nothing_happening(ply)
	if not IsValid(ply) then return end

	return ply.organism and ply.organism.fear < -0.6
end

function hg.fearful(ply)
	if not IsValid(ply) then return end

	return ply.organism and ply.organism.fear > 0.5
end

function hg.likely_to_phrase(ply)
	local org = ply.organism

	local pain = org.pain
	local brain = org.brain
	local blood = org.blood
	local fear = org.fear
	local temperature = org.temperature
	local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone - CurTime()) < -3)

	return (broken_dislocated) and 5
		or (pain > 65) and 5
		or (temperature < 31 and 0.5)
		or (temperature > 38 and 0.5)
		or (blood < 3000 and 0.3)
		--or (fear > 0.5 and 0.7)
		or (brain > 0.1 and brain * 5)
		or (fear < -0.5 and 0.05)
		or -0.1
end

function IsAimedAt(ply)
    return ply.aimed_at or 0
end

local function get_status_message(ply)
	if not IsValid(ply) then
		if CLIENT then
			ply = lply
		else
			return
		end
	end

	local nomessage = hook.Run("HG_CanThoughts", ply) --ply.PlayerClassName == "Gordon" || ply.PlayerClassName == "Combine"
	if nomessage ~= nil and nomessage == false then return "" end

    if ply:GetInfoNum("hg_showthoughts", 1) == 0 then return "" end

	local org = ply.organism

	if not org or not org.brain then return "" end

	local pain = org.pain
	local brain = org.brain
	local temperature = org.temperature
	local blood = org.blood
	local hungry = org.hungry
	local broken_dislocated = org.just_damaged_bone and ((org.just_damaged_bone + 3 - CurTime()) < -3)

	if broken_dislocated and org.just_damaged_bone then
		org.just_damaged_bone = nil
	end

	local broken_notify = (org.rarm == 1) or (org.larm == 1) or (org.rleg == 1) or (org.lleg == 1)
	local dislocated_notify = (org.rarm == 0.5) or (org.larm == 0.5) or (org.rleg == 0.5) or (org.lleg == 0.5)
	local after_unconscious_notify = org.after_otrub

	if not isnumber(pain) then return "" end

	local str = ""

	local most_wanted_phraselist

	if temperature < 35 then
		most_wanted_phraselist = temperature > 31 and cold_phraselist or (temperature < 28 and numb_phraselist or freezing_phraselist)
	elseif temperature > 38 then
		most_wanted_phraselist = temperature < 40 and hot_phraselist or heatstroke_phraselist
	end

	if not most_wanted_phraselist and hungry and hungry > 25 and math.random(3) == 1 then
		most_wanted_phraselist = hungry > 45 and very_hungry or hungry_a_bit
	end

	if (blood < 3100) or (pain > 75) or (broken_dislocated) or (broken_notify) or (dislocated_notify) then
		if pain > 75 and (broken_dislocated) then
			most_wanted_phraselist = math.random(2) == 1 and audible_pain or (broken_notify and broken_limb or dislocated_limb)
		elseif pain > 75 then
			most_wanted_phraselist = audible_pain
		elseif broken_dislocated then
			most_wanted_phraselist = (broken_notify and broken_limb or dislocated_limb)
		end

		if pain > 100 then
			most_wanted_phraselist = sharp_pain
		end

		if not most_wanted_phraselist then
			if (broken_dislocated_notify) and (blood < 3100) then
				most_wanted_phraselist = blood < 2900 and (near_death_poetic) or (math.random(2) == 1 and (broken_notify and broken_limb or dislocated_limb) or near_death_poetic)
			--elseif(broken_dislocated_notify)then
				--most_wanted_phraselist = (broken_notify and broken_limb or dislocated_limb)
			elseif(blood < 3100)then
				most_wanted_phraselist = near_death_poetic
			end
		end
	elseif after_unconscious_notify then
		most_wanted_phraselist = after_unconscious
	elseif hg.nothing_happening(ply) then
		most_wanted_phraselist = random_phrase

		if hungry and hungry > 25 and math.random(5) == 1 then
			most_wanted_phraselist = hungry > 45 and very_hungry or hungry_a_bit
		end
	elseif hg.fearful(ply) then
		most_wanted_phraselist = ((IsAimedAt(ply) > 0.9) and is_aimed_at_phrases or (math.random(10) == 1 and fear_hurt_ironic or fear_phrases))
	end

	if brain > 0.1 then
		most_wanted_phraselist = brain < 0.2 and slight_braindamage_phraselist or braindamage_phraselist
	end

	if most_wanted_phraselist then
		str = most_wanted_phraselist[math.random(#most_wanted_phraselist)]

		return str
	else
		return ""
	end
end

local allowedlist_types = {
	heatvomit = heatvomit_phraselist,
}

function hg.get_phraselist(ply, type)
	if not IsValid(ply) then
		if CLIENT then
			ply = lply
		else
			return
		end
	end

	local nomessage = ply.PlayerClassName == "Gordon" || ply.PlayerClassName == "Combine"

	if nomessage then return "" end
    if ply:GetInfoNum("hg_showthoughts", 1) == 0 then return "" end

	local org = ply.organism
	if not org or not org.brain then return "" end

	if not isstring(type) or not allowedlist_types[type] then return "" end

	local needed_list = allowedlist_types[type]

	local str = needed_list[math.random(#needed_list)]
	return str
end

function hg.get_status_message(ply)
	local txt = get_status_message(ply)

	return txt
end
