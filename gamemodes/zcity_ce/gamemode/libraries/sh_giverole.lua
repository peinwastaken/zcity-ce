if SERVER then
    util.AddNetworkString("ZC_GiveRole")

    function zb.GiveRole(ply, name, color)
        hook.Run( "ZC_BeforeRoleAssigned", ply, name )
        net.Start("ZC_GiveRole")
            net.WriteTable({
                name = name or "WHO ARE YOU?",
                color = color or color_white
            })
        net.Send(ply)
    end
else
    net.Receive("ZC_GiveRole",function()
        LocalPlayer().role = net.ReadTable() or false
    end)    
end