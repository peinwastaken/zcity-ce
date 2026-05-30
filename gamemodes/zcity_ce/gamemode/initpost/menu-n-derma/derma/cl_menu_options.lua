hg.settings = hg.settings or {}
hg.settings.tbl = hg.settings.tbl or {}
local uiColors = zc.colors.ui
local dropButton = Material("icon16/bullet_arrow_down.png")
local dropButton_open = Material("icon16/bullet_arrow_up.png")
local checkmark = Material("icon16/check_on_gray.png")

function hg.settings:AddOpt( strCategory, strConVar, strTitle, bDecimals, bString, category, desc )
    self.tbl[strCategory] = self.tbl[strCategory] or {}
    self.tbl[strCategory][strConVar] = { strCategory, strConVar, strTitle, bDecimals or false, bString or false, category, desc }
end

CreateClientConVar("zc_firstperson_death", "0", true, false, "Toggle first-person death camera view", 0, 1)
local zc_font = CreateClientConVar("zc_font", "Bahnschrift", true, false, "change every text font to selected because ui customization is cool")
CreateClientConVar("zc_attachment_draw_distance", 0, true, nil, "distance to draw attachments", 0, 4096)

xbars = 17
ybars = 30

gradient_l = Material("vgui/gradient-l")

local blur = Material("pp/blurscreen")
local sw, sh = ScrW(), ScrH()

local font = function() -- zc_coolvetica:GetBool() and "Coolvetica" or "Bahnschrift"
    local usefont = "Bahnschrift"

    if zc_font:GetString() != "" then
        usefont = zc_font:GetString()
    end

    return usefont
end

surface.CreateFont("ZCity_setiings_tiny", {
	font = font(),
	size = ScreenScale(7),
	weight = 100
})

surface.CreateFont("ZCity_setiings_fine", {
	font = font(),
	size = ScreenScale(10),
	weight = 100
})

surface.CreateFont("ZCity_setiings_category", {
	font = font(),
	size = ScreenScale(15),
	weight = 100
})


hg.settings:AddOpt("settings/category/gameplay","zc_old_notificate", "settings/gameplay/old_notifications")
hg.settings:AddOpt("settings/category/gameplay","zc_cheats", "settings/gameplay/enable_cheats")
hg.settings:AddOpt("settings/category/gameplay","zc_showthoughts", "settings/gameplay/show_thoughts")
hg.settings:AddOpt("settings/category/gameplay","zc_hints", "settings/gameplay/show_hints")
hg.settings:AddOpt("settings/category/gameplay","zc_gary", "settings/gameplay/hg_gary")
hg.settings:AddOpt("settings/category/gameplay","zc_deathfadeout", "settings/gameplay/death_fade_out")
--zc_gary
--zc_deathfadeout
if not game.IsDedicated() and LocalPlayer():IsAdmin() then
    hg.settings:AddOpt("menu/settings/serversettings", "zc_always_ragdoll_aim", "menu/settings/aim_in_ragdoll", nil, nil, "bool", "menu/settings/aim_in_ragdoll/desc")
	hg.settings:AddOpt("menu/settings/serversettings", "zc_toughnpcs", "settings/server/tough_npcs")
	hg.settings:AddOpt("menu/settings/serversettings", "zc_thirdperson", "settings/server/thirdperson")
    hg.settings:AddOpt("menu/settings/serversettings", "zc_legacycam", "settings/server/legacy_camera")
    hg.settings:AddOpt("menu/settings/serversettings", "zc_ragdollcombat", "settings/server/ragdoll_combat")
    hg.settings:AddOpt("menu/settings/serversettings", "zc_movement_stamina_debuff", "settings/server/movement_stamina_debuff")
    hg.settings:AddOpt("menu/settings/serversettings", "zc_appearance_access_for_all", "settings/server/appearance_full_access", nil, nil, "bool")
	hg.settings:AddOpt("menu/settings/serversettings", "zc_healanims", "settings/server/heal_food_animations")
	hg.settings:AddOpt("menu/settings/serversettings", "zc_aimtoshoot", "settings/server/aim_to_shoot")
	hg.settings:AddOpt("menu/settings/serversettings", "zc_slings", "settings/server/sling_system")
    hg.settings:AddOpt("menu/settings/serversettings", "zc_homicide_traitoramount", "settings/server/homicide_traitor_amount", nil, nil, "int")
end
--zc_appearance_access_for_all
--zc_legacycam
--zc_toughnpcs

hg.settings:AddOpt("settings/category/debug","zc_show_hitposmuzzle", "settings/debug/show_weapon_hitpos")
hg.settings:AddOpt("settings/category/debug","zc_setzoompos", "settings/debug/edit_weapon_zoompos")
hg.settings:AddOpt("settings/category/debug","zc_show_hitbox", "settings/debug/show_hitboxes")

hg.settings:AddOpt("settings/category/optimization","zc_potatopc", "settings/optimization/potato_pc")
hg.settings:AddOpt("settings/category/optimization","zc_anims_draw_distance", "settings/optimization/animations_draw_distance", true, nil, "int")
hg.settings:AddOpt("settings/category/optimization","zc_anim_fps", "settings/optimization/animations_fps", nil, nil, "int")
hg.settings:AddOpt("settings/category/optimization","zc_attachment_draw_distance", "settings/optimization/attachment_draw_distance", true, nil, "int")
hg.settings:AddOpt("settings/category/optimization","zc_maxsmoketrails", "settings/optimization/maximum_smoke_trails", nil, nil, "int")
hg.settings:AddOpt("settings/category/optimization","zc_tpik_distance", "settings/optimization/tpik_render_distance", true, nil, "int")

hg.settings:AddOpt("settings/category/blood","zc_blood_draw_distance", "settings/blood/draw_distance")
hg.settings:AddOpt("settings/category/blood","zc_blood_fps", "settings/blood/fps")
hg.settings:AddOpt("settings/category/blood","zc_blood_sprites", "settings/blood/sprites")
hg.settings:AddOpt("settings/category/blood","zc_old_blood", "settings/blood/old_blood")

hg.settings:AddOpt("settings/category/ui", "zc_font", "settings/ui/change_custom_font", false, true)
hg.settings:AddOpt("settings/category/ui", "zc_language", "settings/ui/change_language", false, true)

hg.settings:AddOpt("settings/category/weapons","zc_weaponshotblur_enable", "settings/weapons/shooting_blur")
hg.settings:AddOpt("settings/category/weapons","zc_dynamic_mags", "settings/weapons/dynamic_ammo_inspect")
hg.settings:AddOpt("settings/category/weapons","zc_zoomsensitivity", "settings/weapons/scope_sensitivity")
hg.settings:AddOpt("settings/category/weapons","zc_highpitchgunfire", "settings/weapons/high_pitch_gunfire")

hg.settings:AddOpt("settings/category/view","zc_firstperson_death", "settings/view/first_person_death")
hg.settings:AddOpt("settings/category/view","zc_fov", "settings/view/field_of_view")
hg.settings:AddOpt("settings/category/view","zc_newspectate", "settings/view/smooth_spectator_camera")
hg.settings:AddOpt("settings/category/view","zc_cshs_fake", "settings/view/cshs_ragdoll_camera")
hg.settings:AddOpt("settings/category/view","zc_gun_cam", "settings/view/gun_camera_admin")
hg.settings:AddOpt("settings/category/view","zc_nofovzoom", "settings/view/fov_zoom")
hg.settings:AddOpt("settings/category/view","zc_realismcam", "settings/view/realism_camera")
hg.settings:AddOpt("settings/category/view","zc_gopro", "settings/view/gopro_camera")
hg.settings:AddOpt("settings/category/view","zc_newfakecam", "settings/view/new_fake_camera")
hg.settings:AddOpt("settings/category/view","zc_leancam_mul", "settings/view/lean_camera_mul", true, nil, "int")
hg.settings:AddOpt("settings/category/view","zc_gun_cam", "settings/view/gun_camera_wip_admin")
--zc_hints
--zc_leancam_mul
  --zc_newfakecam
hg.settings:AddOpt("settings/category/sound","zc_dmusic", "settings/sound/dynamic_music")
hg.settings:AddOpt("settings/category/sound","zc_quietshots", "settings/sound/quiet_shots")


function hg.CreateCategory(ctgName, ParentPanel, yPos)
    local pppanel = vgui.Create('DPanel', ParentPanel)
    local label = zb.locale.GetLocalized(ctgName)
    pppanel:SetSize(ParentPanel:GetWide(), 64)
    pppanel:SetPos(ParentPanel:GetWide() / 2 -pppanel:GetWide() / 2, yPos)
    --pppanel:SetText(ctgName)
    pppanel.Paint = function(self,w,h)
        surface.SetDrawColor(uiColors.settingsCategoryBackground)
        surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(uiColors.settingsCategoryAccent)
		surface.DrawRect(0, h-5, w, 5)

        draw.SimpleText(label, 'ZCity_setiings_category', w / 2, h / 2, color3, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    return pppanel
end

function hg.GetConVarType(convar)
    local stringv = convar:GetString()
    local floatVal = convar:GetFloat()
    local intVal = convar:GetInt()
    local boolVal = convar:GetBool()

    if (stringv == '0' and not boolVal) or (stringv == '1' and boolVal) then
        return 'bool'
    end

    if tonumber(stringv) and math.floor(stringv) == floatVal then
        if intVal == floatVal then
            return "int"
        end
    end

    return "string"
end

local function SetConVarValue(convar, value)
    if not convar then
        return
    end

    local name = convar.GetName and convar:GetName()
    if not name or name == "" then
        return
    end

    if isbool(value) then
        RunConsoleCommand(name, value and "1" or "0")
        return
    end

    RunConsoleCommand(name, tostring(value))
end

local clr_1 = uiColors.settingsTextPrimary
local clr_2 = uiColors.settingsTextSecondary
local clr_3 = uiColors.settingsToggleTrack
local clr_4 = uiColors.settingsToggleShadow
local clr_5 = uiColors.settingsToggleInner
local clr_6 = uiColors.settingsToggleGloss
local clr_7 = uiColors.settingsValueText
local clr_8 = uiColors.settingsTextHighlight
function hg.CreateButton(buttonData, convarName, ParentPanel, yPos)
    local convar = GetConVar(convarName)

    if not convar then
        print(string.format("convar %s not found, skipping creating settings option", convarName))
        return
    end

    // seriously this is stupid
    local label = buttonData[3]
    local desc = buttonData[7] or convar:GetHelpText()
    local localizedLabel = zb.locale.GetLocalized(label)
    local localizedDesc = zb.locale.GetLocalized(desc)

    local pppanel = vgui.Create('DPanel', ParentPanel)
    pppanel:SetSize(ParentPanel:GetWide()/1.05, 64)

    surface.SetFont('ZCity_setiings_fine')
    local _, height2 = surface.GetTextSize(buttonData[3])

    convarType = buttonData[6] or hg.GetConVarType(convar)
    pppanel.Paint = function(self,w,h)
        surface.SetDrawColor(uiColors.settingsRowBackgroundStrong)
        surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(uiColors.settingsRowDivider)
		surface.DrawRect(0, h-3, w, 3)

        draw.SimpleText(localizedLabel, 'ZCity_setiings_fine', 30, h / 2 -height2/2.5, clr_1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(localizedDesc, 'ZCity_setiings_tiny', 30, h / 2+height2/2, clr_2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    // TODO: TEMPORARY!!! replace with a REAL key value dropdown system!!!
    if convarName == "zc_language" then
        local comboBox = vgui.Create("DComboBox", pppanel)
        comboBox:SetSize(pppanel:GetWide()/8, pppanel:GetTall()/2)
        comboBox:SetPos(pppanel:GetWide()-pppanel:GetWide()/8-20, pppanel:GetTall()/2-comboBox:GetTall()/2)
        comboBox:SetFont('ZCity_Tiny')
        comboBox.Paint = function(self, w, h)
            surface.SetDrawColor(uiColors.settingsInputBackground)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(uiColors.settingsInputOutline)
            surface.DrawOutlinedRect(0, 0, w, h)

            self:DrawTextEntryText(uiColors.white, clr_8, uiColors.white)
        end
        comboBox.DropButton.Paint = function(self, w, h)
            surface.SetMaterial(comboBox:IsMenuOpen() and dropButton_open or dropButton)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(0, 0, w, h)
        end

        local options = zb.locale.GetLocaleNativeNames()
        if not options["en"] then
            options["en"] = "English"
        end
        
        for id, nativeLabel in pairs(options) do
            comboBox:AddChoice(nativeLabel, id)
        end

        local value = convar:GetString()
        comboBox:SetValue(options[value] or options["en"] or value or "en")

        comboBox.OnSelect = function(self, index, value, data)
            RunConsoleCommand(convarName, data)
        end
    elseif convarType == 'bool' then
        local toggle = vgui.Create('DButton', pppanel)
        toggle:SetSize(pppanel:GetWide() / 18, pppanel:GetTall() / 2)

        toggle:SetPos(pppanel:GetWide() - toggle:GetWide()*1.4 - pppanel:GetWide() / 20, pppanel:GetTall() / 2 - toggle:GetTall() / 2)
        toggle:SetText('')

        local animProgress = convar:GetBool() and 1 or 0
        local targetProgress = animProgress

        function toggle:Paint(w, h)
            if animProgress ~= targetProgress then
                animProgress = Lerp(FrameTime() * 8, animProgress, targetProgress)
            end

            local bgColor = Color(
                Lerp(animProgress, uiColors.settingsToggleOffKnob.r, uiColors.settingsToggleOnKnob.r),
                Lerp(animProgress, uiColors.settingsToggleOffKnob.g, uiColors.settingsToggleOnKnob.g),
                Lerp(animProgress, uiColors.settingsToggleOffKnob.b, uiColors.settingsToggleOnKnob.b)
            )

            local shadowColor = Color(
                uiColors.black.r,
                uiColors.black.g,
                uiColors.black.b,
                Lerp(animProgress, uiColors.blackMediumOverlay.a, uiColors.settingsToggleShadowLight.a)
            )
            surface.SetDrawColor(clr_3)
            draw.RoundedBox(0, 0, 0, w, h, clr_3)

            surface.SetDrawColor(clr_5)
            draw.RoundedBox(0, 2, 2, w - 4, h - 4, clr_4)

            local slsize = h - 12
            local slPos = Lerp(animProgress, 6, w - slsize - 6)
            surface.SetDrawColor(bgColor)
            draw.RoundedBox(0, slPos, 6, slsize, slsize, bgColor)
            surface.SetDrawColor(shadowColor)
            surface.DrawRect(slPos, slsize+4, slsize, 3)

            surface.SetDrawColor(clr_6)
        end

        function toggle:DoClick()
            if convar then
                local newValue = not convar:GetBool()
                SetConVarValue(convar, newValue)

                surface.PlaySound('glide/headlights_on.wav')
                targetProgress = newValue and 1 or 0
            end
        end
    elseif convarType == 'int' then
        local slider = vgui.Create('DNumSlider', pppanel)
        slider:SetSize(280, 30)
        slider:SetPos(pppanel:GetWide() - 300, pppanel:GetTall() / 2 - 15)
        slider:SetText('')

        local min = convar:GetMin() or 0
        local max = convar:GetMax() or 100
        local decimals = buttonData[4] and 2 or 0

        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(decimals)
        slider:SetValue(decimals > 0 and convar:GetFloat() or convar:GetInt())

        function slider:OnValueChanged(val)
            if convar then
                SetConVarValue(convar, decimals > 0 and math.Round(val, decimals) or math.Round(val))
            end
        end

        local valueLabel = vgui.Create('DLabel', pppanel)
        valueLabel:SetPos(pppanel:GetWide() - 350, pppanel:GetTall() / 2 - 8)
        valueLabel:SetSize(50, 20)
        valueLabel:SetText(convar:GetInt())
        valueLabel:SetTextColor(clr_7)
        valueLabel:SetFont('ZCity_setiings_tiny')

        slider.Think = function()
            if convar then
                valueLabel:SetText(convar:GetInt())
            end
        end
    elseif convarType == 'string' then
        local textEntry = vgui.Create('DTextEntry', pppanel)
        textEntry:SetSize(pppanel:GetWide()/8, pppanel:GetTall()/2)
        textEntry:SetPos(pppanel:GetWide()-pppanel:GetWide()/8-20, pppanel:GetTall()/2-textEntry:GetTall()/2)
        textEntry:SetText(convar:GetString())
        textEntry:SetUpdateOnType(true)
        textEntry:SetFont('ZCity_Tiny')

        textEntry.Paint = function(self, w, h)
            surface.SetDrawColor(uiColors.settingsInputBackground)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(uiColors.settingsInputOutline)
            surface.DrawOutlinedRect(0, 0, w, h)

            self:DrawTextEntryText(uiColors.white, clr_8, uiColors.white)
        end

        function textEntry:OnValueChange(val)
            if convar then
                SetConVarValue(convar, val)
            end
        end
    end

    return pppanel
end

function hg.DrawSettings(ParentPanel)
    local sidePanel = hg.CreateSidePanel(ParentPanel)

    // create category panels
    local categoryPanels = {}
    for categoryName, categoryTable in pairs(hg.settings.tbl) do
        local categoryPanel = vgui.Create("DPanel", sidePanel)
        categoryPanel:SetWide(sidePanel:GetWide())
        categoryPanel.Paint = function() end

        local categoryHeading = hg.CreateCategory(categoryName, categoryPanel, offset)
        categoryHeading:Dock(TOP)

        categoryPanels[categoryName] = categoryPanel

        // load settings
        for convarName, settingData in pairs(categoryTable) do
            local option = hg.CreateButton(settingData, convarName, sidePanel, yOffset)
            if !option then continue end

            option:Dock(TOP)
            option:DockMargin(15, 0, 15, 5)
        end
    end

    // fix layout
    for _, categoryPanel in pairs(categoryPanels) do
        categoryPanel:InvalidateLayout(true)
        categoryPanel:SizeToChildren(false, true)
        categoryPanel:DockMargin(0, 0, 0, 5)
        categoryPanel:Dock(TOP)
    end
end

function hg.CreateBindRow(bindId, bindData, ParentPanel, yPos)
    local pppanel = vgui.Create('DPanel', ParentPanel)
    pppanel:SetSize(ParentPanel:GetWide()/1.05, 64)

    surface.SetFont('ZCity_setiings_fine')
    local _, height2 = surface.GetTextSize(bindData.label)

    pppanel.Paint = function(self,w,h)
        surface.SetDrawColor(uiColors.settingsRowBackgroundStrong)
        surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(uiColors.settingsRowDivider)
		surface.DrawRect(0, h-3, w, 3)

        local label = zb.locale.GetLocalized(bindData.label)
        local desc = zb.locale.GetLocalized(bindData.description)

        draw.SimpleText(label, 'ZCity_setiings_fine', 30, h / 2 -height2/2.5, clr_1, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(desc, 'ZCity_setiings_tiny', 30, h / 2+height2/2, clr_2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local binder = vgui.Create('DBinder', pppanel)
    binder:SetSize(pppanel:GetWide()/8, pppanel:GetTall()/2)
    binder:SetPos(pppanel:GetWide()-pppanel:GetWide()/8-20, pppanel:GetTall()/2-binder:GetTall()/2)
    binder:SetValue(bindData.key)
    binder:SetFont('ZCity_Tiny')

    binder.Paint = function(self, w, h)
        surface.SetDrawColor(uiColors.settingsInputBackground)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(uiColors.settingsInputOutline)
        surface.DrawOutlinedRect(0, 0, w, h)

        self:DrawTextEntryText(uiColors.white, clr_8, uiColors.white)
    end

    binder.OnChange = function(self, num)
        zb.dev.DevPrint(string.format("New bind for %s -> %s (key: %s)", bindId, num, input.GetKeyName(num or KEY_NONE) or "NONE"))
        zb.binds.UpdateBind(bindId, num)
    end

    local override = vgui.Create("DCheckBox", pppanel)
    override:SetSize(pppanel:GetTall()/2, pppanel:GetTall()/2)
    override:SetPos(pppanel:GetWide()-pppanel:GetWide()/8-64, pppanel:GetTall()/2-override:GetTall()/2)
    override:SetChecked(bindData.should_override)
    override:SetTooltip(zb.locale.GetLocalized("binds/override/tooltip"))
    override.Paint = function(self, w, h)
        local checked = self:GetChecked()

        surface.SetDrawColor(uiColors.settingsInputBackground)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(uiColors.settingsInputOutline)
        surface.DrawOutlinedRect(0, 0, w, h)

        if checked then
            local scale = 2
            local size = h / scale
            surface.SetMaterial(checkmark)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(size/scale, size/scale, size, size)
        end
    end
    override.OnChange = function(self, new)
        zb.binds.UpdateBindOverride(bindId, new)
        surface.PlaySound('glide/headlights_on.wav')
    end
    override.OnMousePressed = function(self, mouseCode)
        local default = bindData.default_override
        if mouseCode == MOUSE_MIDDLE and bindData.should_override != default then
            local default = bindData.default_override
            
            self:SetChecked(default)
            surface.PlaySound('glide/headlights_on.wav')

            zb.binds.UpdateBindOverride(bindId, default)
            return
        end

        self.BaseClass.OnMousePressed(self, mouseCode)
    end

    local overrideLabel = vgui.Create("DLabel", pppanel)
    overrideLabel:SetPos(pppanel:GetWide()-pppanel:GetWide()/8-130, pppanel:GetTall()/2-overrideLabel:GetTall()/2)
    overrideLabel:SetText(zb.locale.GetLocalized("binds/override"))
    overrideLabel:SetFont("ZCity_setiings_tiny")
    overrideLabel:SetTextColor(clr_2)

    return pppanel
end

function hg.DrawBinds(ParentPanel)
    local sidePanel = hg.CreateSidePanel(ParentPanel)

    // create category panels
    local categoryPanels = {}
    for _, category in ipairs(zb.binds.categories) do
        local categoryPanel = vgui.Create("DPanel", sidePanel)
        categoryPanel:SetWide(sidePanel:GetWide())
        categoryPanel.Paint = function() end

        local categoryHeading = hg.CreateCategory(category.label, categoryPanel, offset)
        categoryHeading:Dock(TOP)

        categoryPanels[category.id] = categoryPanel
    end

    // load binds
    for id, bindInfo in pairs(zb.binds.allbinds) do
        local categoryPanel = categoryPanels[bindInfo.category]
        if !categoryPanel then continue end

        local bindRow = hg.CreateBindRow(
            id,
            bindInfo,
            categoryPanel,
            optionOffset)
        bindRow:Dock(TOP)
        bindRow:DockMargin(15, 5, 15, 0)
    end

    // fix layout
    for _, categoryPanel in pairs(categoryPanels) do
        categoryPanel:InvalidateLayout(true)
        categoryPanel:SizeToChildren(false, true)
        categoryPanel:DockMargin(0, 0, 0, 5)
        categoryPanel:Dock(TOP)
    end
end

function hg.CreateSidePanel(ParentPanel)
    // generic ui panel shit
    ParentPanel:SetAlpha(0)
    ParentPanel.Paint = function(self,w,h)
        surface.SetDrawColor(uiColors.settingsSideBackground)
        surface.DrawRect(0, 0, w, h)

        surface.SetDrawColor(uiColors.settingsSideGrid)

        for i = 1, (ybars + 1) do
            surface.DrawRect((sw / ybars) * i - (CurTime() * 30 % (sw / ybars)), 0, ScreenScale(1), sh)
        end

        for i = 1, (xbars + 1) do
            surface.DrawRect(0, (sh / xbars) * (i - 1) + (CurTime() * 30 % (sh / xbars)), sw, ScreenScale(1))
        end

        local border_size = ScreenScale(2)

        surface.SetDrawColor(uiColors.black)
        surface.SetMaterial(gradient_l)
        surface.DrawTexturedRect(0, 0, border_size, sh)
		surface.SetMaterial(blur)
        surface.SetDrawColor(uiColors.settingsSideOverlay)
        surface.DrawRect(0, 0, w, h)
    end
    hg.DrawBlur(ParentPanel, 5)
    ParentPanel:AlphaTo(255,0.15,0)
    local pppanel3 = vgui.Create('DScrollPanel', ParentPanel)
    pppanel3:SetSize(ParentPanel:GetWide(), ParentPanel:GetTall())
    pppanel3:SetPos(0,0)
    local scrollBar = pppanel3:GetVBar()
    scrollBar:SetWide(0)
    scrollBar:SetEnabled(false)
    local scrollCanvas = pppanel3:GetCanvas()
    scrollCanvas:DockPadding(15, 15, 15, 15)

    return pppanel3
end
