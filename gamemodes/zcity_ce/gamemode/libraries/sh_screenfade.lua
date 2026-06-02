if CLIENT then
    local fade = 0

    net.Receive("ZC_ScreenFade", function()
        faded = true
        fade = 0

        timer.Simple(6, function()
           hook.Add("RenderScreenspaceEffects", "ZC_ScreenFade", function()
                surface.SetDrawColor(0, 0, 0, 255 * fade)
                surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
                fade = Lerp(FrameTime() * 10, fade, 2)
           end)

           timer.Simple(2, function()
                zc.RemoveFade()
           end)
        end)
    end)

    function zc.RemoveFade()
        hook.Remove("RenderScreenspaceEffects", "ZC_ScreenFade")
    end
end
