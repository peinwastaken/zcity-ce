--[[
    TO-DO
    - Add a nice popup when a track starts.
--]]
zc = zc or {}
zc.DynamicMusicV2 = zc.DynamicMusicV2 or {}
zc.DynamicMusicV2.Player = zc.DynamicMusicV2.Player or {}


--[[
    ["example track"] = {
        ["SelectPreset"] = function(ply)
            local intens = 0
            local org = ply.organism
            if org.adrenaline > 0.2 then
                intens = intens + 1
            end

            -- and so on...
        end,

        ["Presets"] = {
            [1] = {"Name for layers1"}
            [2] = {
                ["Name for layers2"] = {volume = 1},
                ["Name for layers4"] = {volume = 1}
            }

            -- I think it is clear...
        },

        ["Layers"] = {
            ["Name for layers1"] = ".wav .mp3 path to any file the game can digest",
            ["Name for layers2"] = ".wav .mp3 path to any file the game can digest",
            ["Name for layers3"] = ".wav .mp3 path to any file the game can digest",
            ["Name for layers4"] = ".wav .mp3 path to any file the game can digest",
            ["Name for layers5"] = ".wav .mp3 path to any file the game can digest",
        }
    }
--]]

DYNAMIC_MUSIC_PAUSE = 0
DYNAMIC_MUSIC_STOP = -1
DYNAMIC_MUSIC_PLAY = 1

zc.DynamicMusicV2.Player.CurrentTrack = "None"
zc.DynamicMusicV2.Player.State = zc.DynamicMusicV2.Player.State or DYNAMIC_MUSIC_STOP


zc.DynamicMusicV2.Player.Layers = zc.DynamicMusicV2.Player.Layers or {}
local layers = zc.DynamicMusicV2.Player.Layers
local function SetupMusicFile(name, path, callback)
    sound.PlayFile("sound/" .. path, "noplay noblock", function(Channel, Err, ErrStr)
        --print(Channel, Err, ErrStr)
        if IsValid( Channel ) then
            Channel:EnableLooping( true )
            layers[#layers + 1] = {name, Channel}
            callback()
        end
    end)
end

local function GetTrack()
    return zc.DynamicMusicV2.Trakcs and zc.DynamicMusicV2.Trakcs[ zc.DynamicMusicV2.Player.CurrentTrack ]
end

zc.DynamicMusicV2.Player.GetTrack = GetTrack

function zc.DynamicMusicV2.Player.SetupLayers()
    if !IsValid(lply) then return end
    local Track = GetTrack()

    if !Track then return end

    zc.DynamicMusicV2.Player.Stop(true)
    local amount = table.Count(Track.Layers)
    for k,v in pairs(Track.Layers) do
        SetupMusicFile(k, v, function()
            amount = amount - 1
            --print(amount)
            if amount <= 0 then zc.DynamicMusicV2.Player.Play() end
        end)
    end

    zc.DynamicMusicV2.Player.State = DYNAMIC_MUSIC_PAUSE
end

function zc.DynamicMusicV2.Player.Stop(overide)
    if !IsValid(lply) then return end

    for _,v in ipairs(layers) do
        if !IsValid(v[2]) then continue end
        v[2]:Stop()
    end
    table.Empty(layers)

    if !overide then
        zc.DynamicMusicV2.Player.CurrentTrack = "None"
        zc.DynamicMusicV2.Player.State = DYNAMIC_MUSIC_STOP
    end
end

local function LayerFadeOut(channel)
    if !IsValid(channel) then return end
    local l_volume = LerpFT(0.02, channel:GetVolume(), 0)
    channel:SetVolume(l_volume)
end

local function LayerFade(channel, volume)
    if !IsValid(channel) then return end
    local l_volume = LerpFT(0.02, channel:GetVolume(), volume or 1)
    channel:SetVolume(l_volume)
end

function zc.DynamicMusicV2.Player.Play()
    for i = 1, #layers do
        local layer = layers[i]
        layer[2]:SetVolume( 0 )
        layer[2]:SetTime( 0, true )
        layer[2]:Play()
    end

    zc.DynamicMusicV2.Player.State = DYNAMIC_MUSIC_PLAY
end

function zc.DynamicMusicV2.Player.Start( strTrackName )
    zc.DynamicMusicV2.Player.CurrentTrack = strTrackName or zc.DynamicMusicV2.Player.CurrentTrack
    zc.DynamicMusicV2.Player.SetupLayers()
end

--zc.DynamicMusicV2.Player.Start( "overdose" )
--zc.DynamicMusicV2.Player.Start( "final_heartbeat" )

function zc.DynamicMusicV2.Player.Think()
    if !IsValid(lply) then return end

    if zc.DynamicMusicV2.Player.State != DYNAMIC_MUSIC_PLAY then
        for i = 1, #layers do
            local layer = layers[i]
            LayerFadeOut(layer[2])
        end
    return end

    local Track = GetTrack()

    if !Track then return end

    local Preset = Track["Presets"][Track.SelectPreset(lply)]
    for i = 1, #layers do

        local layer = layers[i]
        local PresetLayer = Preset and Preset[layer[1]] or false
        if PresetLayer then
            LayerFade(layer[2],PresetLayer.volume)
        else
            LayerFadeOut(layer[2])
        end
    end
end

hook.Add("Think", "ZC_DynamicMusicV2", zc.DynamicMusicV2.Player.Think)
