-- Starter, so we do not suffer in sandbox.
ZBox = ZBox or {}
ZBox.Plugins = ZBox.Plugins or {}

function ZBox.StartAll()
    for _,plugin in pairs(ZBox.Plugins) do
        for name, hok in pairs(plugin.Hooks) do
            --print(name,plugin.Name .. "_" .. name)
            hook.Add(name, "ZC_ZBox" .. plugin.Name .. name, hok )
        end
    end
    timer.Simple(1,function()
        hook.Run("ZC_StartZBox")
    end)
end
ZBox.Maps = {
    ["rp_truenorth_v1a"] = true,
}
-- hook.Add("InitPostEntity","ZC_InitZBOX",function()
    -- if engine.ActiveGamemode() == "sandbox" and ZBox.Maps[game.GetMap()] then
        -- ZBox.StartAll()
    -- end
-- end)


function ZBox.DisableAll()
    for _,plugin in pairs(ZBox.Plugins) do
        for name, _ in pairs(plugin.Hooks) do
            hook.Remove(name, "ZC_ZBox" .. plugin.Name .. name )
        end
    end
    timer.Simple(1,function()
        hook.Run("ZC_DisableZBox")
    end)
end
