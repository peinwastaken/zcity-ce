local PANEL = {}
local curent_panel
local uiColors = zc.colors.ui
local red_select = uiColors.mainMenuSelect

DISCORD_URL = "https://discord.gg/475EmEdTgH"

local Selects = {
    {Title = "menu/disconnect", Func = function(luaMenu) RunConsoleCommand("disconnect") end},
    {Title = "menu/mainmenu", Func = function(luaMenu) gui.ActivateGameUI() luaMenu:Close() end},
    {Title = "menu/discord", Func = function(luaMenu) luaMenu:Close() gui.OpenURL(DISCORD_URL)  end},
    {Title = "menu/traitor_role",
    GamemodeOnly = true,
    CreatedFunc = function(self, parent, luaMenu)
        local btn = vgui.Create( "DLabel", self )
        btn:SetText( zb.locale.GetLocalized("menu/traitor_role/soe") )
        btn:SetMouseInputEnabled( true )
        btn:SizeToContents()
        btn:SetFont( "ZCity_Small" )
        btn:SetTall( ScreenScale( 15 ) )
        btn:Dock(BOTTOM)
        btn:DockMargin(ScreenScale(20),ScreenScale(10),0,0)
        btn:SetTextColor(uiColors.white)
        btn:InvalidateParent()
        btn.RColor = Color(uiColors.mainMenuTextTransparent:Unpack())
        btn.WColor = Color(uiColors.mainMenuText:Unpack())
        btn.x = btn:GetX()

        function btn:DoClick()
            luaMenu:Close()
            hg.SelectPlayerRole(nil, "soe")
        end

        local selfa = self
        function btn:Think()
            self.HoverLerp = selfa.HoverLerp
            self.HoverLerp2 = LerpFT(0.2, self.HoverLerp2 or 0, self:IsHovered() and 1 or 0)

            self:SetTextColor(self.RColor:Lerp(self.WColor:Lerp(red_select, self.HoverLerp2), self.HoverLerp))
            self:SetX(self.x + ScreenScaleH(40) + self.HoverLerp * ScreenScaleH(50))
        end

        local btn = vgui.Create( "DLabel", btn )
        btn:SetText( zb.locale.GetLocalized("menu/traitor_role/std") )
        btn:SetMouseInputEnabled( true )
        btn:SizeToContents()
        btn:SetFont( "ZCity_Small" )
        btn:SetTall( ScreenScale( 15 ) )
        btn:Dock(BOTTOM)
        btn:DockMargin(0,ScreenScale(2),0,0)
        btn:SetTextColor(uiColors.white)
        btn:InvalidateParent()
        btn.RColor = Color(uiColors.mainMenuTextTransparent:Unpack())
        btn.WColor = Color(uiColors.mainMenuText:Unpack())
        btn.x = btn:GetX()

        function btn:DoClick()
            luaMenu:Close()
            hg.SelectPlayerRole(nil, "standard")
        end

        function btn:Think()
            self.HoverLerp = selfa.HoverLerp
            self.HoverLerp2 = LerpFT(0.2, self.HoverLerp2 or 0, self:IsHovered() and 1 or 0)

            self:SetTextColor(self.RColor:Lerp(self.WColor:Lerp(red_select, self.HoverLerp2), self.HoverLerp))
            self:SetX(self.x + ScreenScaleH(35))
        end
    end,
    Func = function(luaMenu)

    end,
    },
    {Title = "menu/achievements", Func = function(luaMenu,pp)
        hg.DrawAchievmentsMenu(pp)
    end},
    {Title = "menu/settings", Func = function(luaMenu,pp)
        hg.DrawSettings(pp)
    end},
    {Title = "menu/binds", Func = function(luamenu, pp)
        hg.DrawBinds(pp)
    end},
    {Title = "menu/appearance", Func = function(luaMenu,pp) hg.CreateApperanceMenu(pp) end},
    {Title = "menu/return", Func = function(luaMenu) luaMenu:Close() end},
}

local splasheh = {
    "menu/splash/we_love_homigrad",
    "menu/splash/now_without_furries",
    "menu/splash/welcome",
    "menu/splash/steam_happy"
}

--print(string.upper('I wish you good health, Jason Statham'))
surface.CreateFont("ZC_MM_Title", {
    font = "Bahnschrift",
    size = ScreenScale(40),
    weight = 800,
    antialias = true
})
-- local Title = markup.Parse("error")


function PANEL:GetRandomText()
    return zb.locale.GetLocalized(splasheh[math.random(#splasheh)])
end

function PANEL:GetMapName()
    return game.GetMap()
end

local clr_gray = uiColors.mainMenuFooterText
local clr_verygray = uiColors.mainMenuBackground
local function FormatAuthors(authors)
    return istable(authors) and table.concat(authors, ", ") or tostring(authors or "")
end

function PANEL:Init()
    self:SetAlpha(0)
    self:SetSize(ScrW(), ScrH())
    self:Center()
    self:SetTitle("")
    self:SetDraggable(false)
    self:SetBorder(false)
    self:SetColorBG(clr_verygray)
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    curent_panel = nil
    local mapName = self:GetMapName()
    local randomText = self:GetRandomText()

    timer.Simple(0, function()
        if self.First then
            self:First()
        end
    end)

    self.lDock = vgui.Create("DPanel", self)
    local lDock = self.lDock
    lDock:Dock(LEFT)
    lDock:SetSize(ScrW() / 2, ScrH())
    lDock:DockMargin(ScreenScale(10), ScreenScaleH(90), ScreenScale(10), ScreenScaleH(90))
    lDock.Paint = function() end

    local logoPanel = vgui.Create("DPanel", lDock)
    logoPanel:SetWide(512)
    logoPanel:SetTall(128)
    logoPanel:DockMargin(0, 0, 0, 0)
    logoPanel:Dock(TOP)
    logoPanel.Paint = function(self, w, h)
        local layerData = hg.menuDrawLayers
        if !layerData then return end

        local baseMat = hg.menuBaseLogos[layerData.base]
        local logoW, logoH = baseMat:Width(), baseMat:Height()

        surface.SetMaterial(baseMat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, logoW, logoH)

        local layers = layerData.layers
        for _, id in ipairs(hg.menuLayerOrder) do
            local layer = table.HasValue(layers, id)
            if !layer then continue end

            surface.SetMaterial(hg.menuLogoLayers[id])
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(0, 0, logoW, logoH)
        end
    end

    local textLabel = vgui.Create("DLabel", lDock)
    textLabel:SetFont("ZCity_Tiny")
    textLabel:SetTextColor(clr_gray)
    textLabel:SetText(zb.locale.GetLocalized("menu/playing_on", randomText, mapName))
    textLabel:SizeToContentsY(5)
    textLabel:DockMargin(0, ScreenScale(3), 0, ScreenScale(5))
    textLabel:Dock(TOP)

    self.Buttons = {}
    for _, v in ipairs(Selects) do
        if v.GamemodeOnly and engine.ActiveGamemode() != "zcity" then continue end
        self:AddSelect(lDock, v.Title, v)
    end

    local bottomDock = vgui.Create("DPanel", self)
    bottomDock:SetPos(ScreenScale(1), ScrH() - ScrH()/6.7)
    bottomDock:SetSize(ScreenScale(230), ScreenScaleH(60))
    bottomDock.Paint = function(this, w, h) end
    self.panelparrent = vgui.Create("DPanel", self)
    self.panelparrent:SetPos(bottomDock:GetWide()+bottomDock:GetX(), 0)
    self.panelparrent:SetSize(ScrW() - bottomDock:GetWide()*1, ScrH())
    self.panelparrent.Paint = function(this, w, h) end

    local git = vgui.Create("DLabel", bottomDock)
    git:Dock(BOTTOM)
    git:DockMargin(ScreenScale(10), 0, 0, 0)
    git:SetFont("ZCity_Tiny")
    git:SetTextColor(clr_gray)
    git:SetText("GitHub: github.com/" .. hg.GitHub_ReposOwner .. "/" .. hg.GitHub_ReposName)
    git:SetContentAlignment(4)
    git:SetMouseInputEnabled(true)
    git:SizeToContents()

    function git:DoClick()
        gui.OpenURL("https://github.com/" .. hg.GitHub_ReposOwner .. "/" .. hg.GitHub_ReposName)
    end

    local version = vgui.Create("DLabel", bottomDock)
    version:Dock(BOTTOM)
    version:DockMargin(ScreenScale(10), 0, 0, 0)
    version:SetFont("ZCity_Tiny")
    version:SetTextColor(clr_gray)
    version:SetText(zb.locale.GetLocalized("menu/version", hg.Version))
    version:SetContentAlignment(4)
    version:SizeToContents()

    local ceTeam = vgui.Create("DLabel", bottomDock)
    ceTeam:Dock(BOTTOM)
    ceTeam:DockMargin(ScreenScale(10), 0, 0, 0)
    ceTeam:SetFont("ZCity_Tiny")
    ceTeam:SetTextColor(clr_gray)
    ceTeam:SetText(zb.locale.GetLocalized("menu/authors_ce", FormatAuthors(hg.Authors_CE)))
    ceTeam:SetContentAlignment(4)
    ceTeam:SizeToContents()

    local zteam = vgui.Create("DLabel", bottomDock)
    zteam:Dock(BOTTOM)
    zteam:DockMargin(ScreenScale(10), 0, 0, 0)
    zteam:SetFont("ZCity_Tiny")
    zteam:SetTextColor(clr_gray)
    zteam:SetText(zb.locale.GetLocalized("menu/authors", FormatAuthors(hg.Authors)))
    zteam:SetContentAlignment(4)
    zteam:SizeToContents()
end

function PANEL:First( ply )
    self:AlphaTo( 255, 0.1, 0, nil )
end

local gradient_d = surface.GetTextureID("vgui/gradient-d")
surface.GetTextureID("vgui/gradient-u")
local gradient_l = surface.GetTextureID("vgui/gradient-l")

local clr_1 = uiColors.mainMenuGradient
function PANEL:Paint(w,h)
    draw.RoundedBox( 0, 0, 0, w, h, self.ColorBG )
    hg.DrawBlur(self, 5)
    surface.SetDrawColor( self.ColorBG )
    surface.SetTexture( gradient_l )
    surface.DrawTexturedRect(0,0,w,h)
    surface.SetDrawColor( clr_1 )
    surface.SetTexture( gradient_d )
    surface.DrawTexturedRect(0,0,w,h)
end

function PANEL:AddSelect( pParent, strTitle, tbl )
    local localizedTitle = zb.locale.GetLocalized(strTitle)
    local id = #self.Buttons + 1
    self.Buttons[id] = vgui.Create( "DLabel", pParent )
    local btn = self.Buttons[id]
    btn:SetText( localizedTitle )
    btn:SetMouseInputEnabled( true )
    btn:SizeToContents()
    btn:SetFont( "ZCity_Small" )
    btn:SetTall( ScreenScale( 15 ) )
    btn:Dock(TOP)
    btn:DockMargin(0, ScreenScale(1.5), 0, 0)
    btn.Func = tbl.Func
    btn.HoveredFunc = tbl.HoveredFunc
    local luaMenu = self
    if tbl.CreatedFunc then tbl.CreatedFunc(btn, self, luaMenu) end
    btn.RColor = Color(uiColors.mainMenuText:Unpack())
    function btn:DoClick()
        -- ,kz needs optimization, but there is an error(cache luaMenu.panelparrent instead of calling it every time)
        if curent_panel == string.lower(strTitle) then
			for _ = 1, 3 do
				surface.PlaySound("shitty/tap_release.wav")
			end
            luaMenu.panelparrent:AlphaTo(0,0.2,0,function()
                luaMenu.panelparrent:Remove()
                luaMenu.panelparrent = nil
                luaMenu.panelparrent = vgui.Create("DPanel", luaMenu)

                luaMenu.panelparrent:SetPos(some_coordinates_x, 0)
                luaMenu.panelparrent:SetSize(some_size_x, some_size_y)
                luaMenu.panelparrent.Paint = function(this, w, h) end
                --btn.Func(luaMenu,luaMenu.panelparrent)
                curent_panel = nil
            end)
            return
        end
        some_size_x = luaMenu.panelparrent:GetWide()
        some_size_y = luaMenu.panelparrent:GetTall()
        some_coordinates_x = luaMenu.panelparrent:GetX()
        luaMenu.panelparrent:AlphaTo(0,0.2,0,function()
            luaMenu.panelparrent:Remove()
            luaMenu.panelparrent = nil
            luaMenu.panelparrent = vgui.Create("DPanel", luaMenu)

            luaMenu.panelparrent:SetPos(some_coordinates_x, 0)
            luaMenu.panelparrent:SetSize(some_size_x, some_size_y)
            luaMenu.panelparrent.Paint = function(this, w, h) end
            btn.Func(luaMenu,luaMenu.panelparrent)
            curent_panel = string.lower(strTitle)
        end)
		for _ = 1, 3 do
			surface.PlaySound("shitty/tap_depress.wav")
		end
    end

    function btn:Think()
        self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, (self:IsHovered() or (IsValid(self:GetChild(0)) and self:GetChild(0):IsHovered()) or (IsValid(self:GetChild(0)) and IsValid(self:GetChild(0):GetChild(0)) and self:GetChild(0):GetChild(0):IsHovered())) and 1 or 0)

        local v = self.HoverLerp
        self:SetTextColor(self.RColor:Lerp(red_select, v))

        local targetText = (self:IsHovered()) and string.upper(localizedTitle) or localizedTitle
        local crw = self:GetText()

        if (crw ~= targetText) or (curent_panel == string.lower(strTitle)) then
            local ntxt = ""
            local will_text = (curent_panel == string.lower(strTitle) and strTitle ~= "menu/traitor_role") and "[ "..string.upper(localizedTitle).." ]" or localizedTitle
            for i = 1, #will_text do
                local char = will_text:sub(i, i)
                if i <= math.ceil(#will_text * v) then
                    ntxt = ntxt .. string.upper(char)
                else
                    ntxt = ntxt .. char
                end
            end
			if self:GetText() ~= ntxt then
				surface.PlaySound("shitty/tap-resonant.wav")
			end
            self:SetText(ntxt)
        end
        self:SizeToContents()
    end
end

function PANEL:Close()
    self:AlphaTo( 0, 0.1, 0, function() self:Remove() end)
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
end

vgui.Register( "ZMainMenu", PANEL, "ZFrame")

hook.Add("OnPauseMenuShow","ZC_OpenMainMenu",function()
    local run = hook.Run("ZC_OnShowPause")
    if run != nil then
        return run
    end

    if MainMenu and IsValid(MainMenu) then
        MainMenu:Close()
        MainMenu = nil
        return false
    end

    MainMenu = vgui.Create("ZMainMenu")
    MainMenu:MakePopup()
    return false
end)
