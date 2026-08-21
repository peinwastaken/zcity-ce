// do not get rid of this under any circumstance
local MODE = MODE

MODE.Intro = {
    Title = "Event"
}

function MODE:GetPlayerIntroData(ply)
    local eventer = self.EventersList and self.EventersList[ply:SteamID()]
    return {
        Title = "Z-City | " .. GetGlobalString("ZB_EventName", "Event"),
        Role = eventer and "Eventer" or GetGlobalString("ZB_EventRole", "Player"),
        Objective = GetGlobalString("ZB_EventObjective", ""),
        Color = eventer and Color(50, 200, 50) or Color(0, 120, 190)
    }
end
