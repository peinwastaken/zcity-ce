-- Values
local maps = {}
local votes = {}
local winmap = ""

local VoteCD = 0

-- RTV CL Functions
local BlurBackground = zc.DrawBlur
local uiColors = zc.colors.ui

function zc.RTVMenu()
    system.FlashWindow()

    local RTVMenu = vgui.Create("ZB_RTVMenu")
    RTVMenu:SetSize(ScrW() / 2.0, ScrH() / 1.05)
    RTVMenu:Center()
    RTVMenu:SetTitle("")
    RTVMenu:SetBackgroundBlur(true)
    RTVMenu:ShowCloseButton(false)
    RTVMenu:SetDraggable(false)
    RTVMenu:MakePopup()
    RTVMenu:SetKeyboardInputEnabled(false)

    local MAPSPanel = vgui.Create("DPanel", RTVMenu)
    MAPSPanel:Dock(FILL)
    MAPSPanel:DockMargin(5, ScrH() * 0.04, 5, ScrH() * 0.01)
    function MAPSPanel.Paint() end

    for _, v in ipairs(maps) do
        local MapButton = vgui.Create("ZB_RTVButton", MAPSPanel)
        MapButton:Dock(TOP)
        MapButton:DockMargin(0, 5, 0, 0)
        MapButton:SetSize(0, ScrH() * 0.06)

        if v == "random" then
            MapButton:SetText("Random Map")
            MapButton.Map = "random"
            MapButton.MapIcon = Material("icon64/random.png")
            if MapButton.MapIcon:IsError() then
                MapButton.MapIcon = Material("icon64/tool.png")
            end
        else
            local txt = v
            txt = string.Explode("_", txt)
            table.remove(txt, 1)
            txt[1] = string.upper(string.Left(txt[1], 1)) .. string.sub(txt[1], 2)
            MapButton:SetText(table.concat(txt, " "))
            MapButton.Map = v
            MapButton.MapIcon = Material("maps/thumb/" .. MapButton.Map .. ".png")
            if MapButton.MapIcon:IsError() then
                MapButton.MapIcon = Material("icon64/tool.png")
            end
        end

        function MapButton:Think()
            self.Votes = votes[self.Map] or 0
            if self.Map ~= "random" and self.Map == winmap then
                self.Win = true
            else
                self.Win = false
            end
        end

        function MapButton:DoClick()
            if VoteCD > CurTime() then return end
            net.Start("ZC_RockTheVoteVote")
                net.WriteString(self.Map)
            net.SendToServer()
            VoteCD = CurTime() + 1
        end
    end

    local button = vgui.Create("DButton", RTVMenu)
    button:SetPos(ScrW() / 2.0 - ScreenScale(25), ScreenScale(5))
    button:SetSize(ScreenScale(20), ScreenScale(10))
    button:SetText("")

    function button:Paint(w, h)
        BlurBackground(self)

        surface.SetDrawColor(uiColors.frameOutline)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)

        local x, y = w / 2, h / 2
        local txt = "Exit"
        surface.SetFont("HomigradFont")
        surface.SetTextColor(uiColors.white)
        local tw, th = surface.GetTextSize(txt)
        surface.SetTextPos(x - tw / 2, y - th / 2)
        surface.DrawText(txt)
    end

    function button:DoClick()
        if IsValid(RTVMenu) then
            RTVMenu:Remove()
        end
    end
end

function zc.StartRTV()
    maps = net.ReadTable()
    time = net.ReadFloat()
    zc.RTVMenu()
    rtvStarted = true
end

net.Receive("ZC_RTVMenu", function()
    zc.RTVMenu()
end)

function zc.RTVregVote()
    votes = net.ReadTable()
end

function zc.EndRTV()
    winmap = net.ReadString()
    rtvEnded = true
end

-- NETWORKING

net.Receive("ZC_RockTheVoteStart", zc.StartRTV)
net.Receive("ZC_RockTheVoteVoteRegister", zc.RTVregVote)
net.Receive("ZC_RockTheVoteEnd", zc.EndRTV)
