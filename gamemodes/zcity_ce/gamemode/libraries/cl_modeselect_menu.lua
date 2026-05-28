if CLIENT then
    local uiColors = zc.colors.ui
    local isMenuOpen = nil
    zb.availableModes = zb.availableModes or {}

    zb.RoundList = zb.RoundList or {}
    zb.nextround = zb.nextround or nil
    local queuePanelInstance = nil
    local selectedModes = {}

    net.Receive("ZC_ModesInfoSend", function()
        zb.availableModes = net.ReadTable()
    end)

    net.Receive("ZC_RoundListSend", function()
        zb.RoundList = net.ReadTable()
        zb.nextround = net.ReadString()
        table.insert(zb.RoundList, 1, zb.nextround)
        zb.nextround = nil
        if IsValid(queuePanelInstance) then
            queuePanelInstance:QueueUpdate()
        end
    end)

    net.Receive("ZC_RoundListChangeNotice", function()
        local playerName = net.ReadString()

        chat.AddText(uiColors.menuChatName, playerName, uiColors.white, zb.locale.GetLocalized("admin/modes/queue_modified"))

        net.Start("ZC_RoundListRequest")
        net.SendToServer()
    end)

    local function StyleElement(element, bgColor)
        bgColor = bgColor or uiColors.menuBackground

        element.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, bgColor)

            if self:IsHovered() and self.Selectable then
                draw.RoundedBox(6, 1, 1, w-2, h-2, uiColors.menuHoverOverlay)
                surface.SetDrawColor(uiColors.blackMediumOverlay)
                surface.DrawOutlinedRect(1, 1, w-2, h-2, 1)
            end

            if self.Selected then
                surface.SetDrawColor(uiColors.successOutline)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
        end
    end

    local function CreateModeItem(parent, mode, queue, index)
        local modePanel = vgui.Create("DPanel", parent)
        modePanel:SetTall(40)
        modePanel:Dock(TOP)
        modePanel:DockMargin(5, 2, 5, 2)
        modePanel.Mode = mode
        modePanel.Index = index
        modePanel.Selectable = true
        modePanel.Selected = selectedModes[mode.key] or false

        StyleElement(modePanel, uiColors.menuItemBackground)

        local title = vgui.Create("DLabel", modePanel)
        title:SetFont("DermaDefaultBold")
        title:SetText(mode.name)
        title:SetTextColor(uiColors.white)
        title:Dock(LEFT)
        title:DockMargin(10, 0, 0, 0)
        title:SizeToContents()

        if queue then
            local posLabel = vgui.Create("DLabel", modePanel)
            posLabel:SetFont("DermaDefault")
            posLabel:SetText("#" .. index)
            posLabel:SetTextColor(uiColors.mutedText)
            posLabel:Dock(LEFT)
            posLabel:DockMargin(5, 0, 0, 0)
            posLabel:SizeToContents()

            local upBtn = vgui.Create("DButton", modePanel)
            upBtn:SetSize(24, 24)
            upBtn:Dock(RIGHT)
            upBtn:DockMargin(2, 8, 5, 8)
            upBtn:SetText("▲")
            upBtn.DoClick = function()
                if index > 1 then
                    local item = table.remove(zb.RoundList, index)
                    table.insert(zb.RoundList, index - 1, item)
                    queue:QueueUpdate()

                    /*net.Start("ZC_RoundListUpdate")
                        net.WriteTable(zb.RoundList)
                        net.WriteBool(false)
                    net.SendToServer()*/
                end
            end

            local downBtn = vgui.Create("DButton", modePanel)
            downBtn:SetSize(24, 24)
            downBtn:Dock(RIGHT)
            downBtn:DockMargin(2, 8, 2, 8)
            downBtn:SetText("▼")
            downBtn.DoClick = function()
                if index < #zb.RoundList then
                    local item = table.remove(zb.RoundList, index)
                    table.insert(zb.RoundList, index + 1, item)
                    queue:QueueUpdate()

                    /*net.Start("ZC_RoundListUpdate")
                        net.WriteTable(zb.RoundList)
                        net.WriteBool(false)
                    net.SendToServer()*/
                end
            end

            local removeBtn = vgui.Create("DButton", modePanel)
            removeBtn:SetSize(24, 24)
            removeBtn:Dock(RIGHT)
            removeBtn:DockMargin(2, 8, 2, 8)
            removeBtn:SetText("✕")
            removeBtn.DoClick = function()
                table.remove(zb.RoundList, index)
                queue:QueueUpdate()

                /*net.Start("ZC_RoundListUpdate")
                    net.WriteTable(zb.RoundList)
                    net.WriteBool(false)
                net.SendToServer()*/
            end
        else

            modePanel.OnMousePressed = function()
                modePanel.Selected = not modePanel.Selected
                selectedModes[mode.key] = modePanel.Selected

                if modePanel.Selected then
                    surface.PlaySound("buttons/button9.wav")
                else
                    surface.PlaySound("buttons/button17.wav")
                end
            end
        end

        return modePanel
    end

    local function CreateQueuePanel(frame)
        local queuePanel = vgui.Create("DPanel", frame)
        queuePanel:SetSize(frame:GetWide() / 2 - 10, frame:GetTall())
        queuePanel:Dock(RIGHT)
        queuePanel:DockMargin(5, 5, 5, 5)
        StyleElement(queuePanel, uiColors.menuPanelBackground)

        queuePanelInstance = queuePanel

        local titleLabel = vgui.Create("DLabel", queuePanel)
        titleLabel:SetText(zb.locale.GetLocalized("admin/modes/queue"))
        titleLabel:SetFont("DermaLarge")
        titleLabel:SetTextColor(uiColors.titleText)
        titleLabel:Dock(TOP)
        titleLabel:DockMargin(0, 5, 0, 5)
        titleLabel:SetContentAlignment(5)

        local queueScroll = vgui.Create("DScrollPanel", queuePanel)
        queueScroll:Dock(FILL)
        queueScroll:DockMargin(5, 5, 5, 5)

        local saveBtn = vgui.Create("DButton", queuePanel)
        saveBtn:SetText(zb.locale.GetLocalized("admin/modes/apply_queue"))
        saveBtn:Dock(BOTTOM)
        saveBtn:DockMargin(5, 5, 5, 5)
        saveBtn:SetTall(30)
        saveBtn.DoClick = function()
            //if #zb.RoundList > 0 then
                local tbl = table.Copy(zb.RoundList)
                //table.insert(tbl, 1, zb.nextround)
                net.Start("ZC_RoundListUpdate")
                    net.WriteTable(tbl)
                net.SendToServer()

                chat.AddText(uiColors.successBright, zb.locale.GetLocalized("admin/modes/queue_set"))
            //else
                //chat.AddText(uiColors.errorBright, "Game mode queue is empty!")
            //end
        end

        local clearBtn = vgui.Create("DButton", queuePanel)
        clearBtn:SetText(zb.locale.GetLocalized("admin/modes/clear_queue"))
        clearBtn:Dock(BOTTOM)
        clearBtn:DockMargin(5, 5, 5, 5)
        clearBtn:SetTall(30)
        clearBtn.DoClick = function()
            zb.RoundList = {}
            queuePanel:QueueUpdate()

            /*net.Start("ZC_RoundListUpdate")
                net.WriteTable({})
                net.WriteBool(false)
            net.SendToServer()*/

            chat.AddText(uiColors.warningOrange, zb.locale.GetLocalized("admin/modes/queue_cleared"))
        end

        function queuePanel:QueueUpdate()
            queueScroll:Clear()

            if zb.nextround and zb.nextround ~= "" then
                local nextRoundLabel = vgui.Create("DLabel", queueScroll)
                nextRoundLabel:SetText(zb.locale.GetLocalized("admin/modes/next_mode", zb.nextround))
                nextRoundLabel:SetFont("DermaDefaultBold")
                nextRoundLabel:SetTextColor(uiColors.successText)
                nextRoundLabel:Dock(TOP)
                nextRoundLabel:DockMargin(5, 0, 0, 10)
                nextRoundLabel:SizeToContents()
            end

            for idx, modeKey in ipairs(zb.RoundList) do
                local mode = nil

                for _, availableMode in ipairs(zb.availableModes) do
                    if availableMode.key == modeKey then
                        mode = availableMode
                        break
                    end
                end

                if not mode then
                    mode = {key = modeKey, name = modeKey}
                end

                CreateModeItem(queueScroll, mode, queuePanel, idx)
            end
        end

        queuePanel:QueueUpdate()
        return queuePanel
    end

    local function OpenModeSelection(command)
        local frame = vgui.Create("ZFrame")
        frame:SetSize(700, 500)
        frame:Center()
        frame:SetTitle(zb.locale.GetLocalized("admin/modes/manager"))
        frame:MakePopup()

        selectedModes = {}

        local queuePanel = CreateQueuePanel(frame)

        local leftPanel = vgui.Create("DPanel", frame)
        leftPanel:SetSize(frame:GetWide() / 2 - 10, frame:GetTall())
        leftPanel:Dock(LEFT)
        leftPanel:DockMargin(5, 5, 5, 5)
        StyleElement(leftPanel, uiColors.menuPanelBackground)

        local titleLabel = vgui.Create("DLabel", leftPanel)
        titleLabel:SetText(zb.locale.GetLocalized("admin/modes/available"))
        titleLabel:SetFont("DermaLarge")
        titleLabel:SetTextColor(uiColors.titleText)
        titleLabel:Dock(TOP)
        titleLabel:DockMargin(0, 5, 0, 5)
        titleLabel:SetContentAlignment(5)

        local searchBar = vgui.Create("DTextEntry", leftPanel)
        searchBar:SetPlaceholderText(zb.locale.GetLocalized("admin/modes/search"))
        searchBar:Dock(TOP)
        searchBar:DockMargin(5, 5, 5, 5)
        searchBar:SetTall(25)

        local dscroll = vgui.Create("DScrollPanel", leftPanel)
        dscroll:Dock(FILL)
        dscroll:DockMargin(5, 5, 5, 5)

        local modeItems = {}

        local function UpdateSearch(filter)
            filter = filter:lower()

            for _, item in ipairs(modeItems) do
                local visible = filter == "" or string.find(item.Mode.name:lower(), filter)
                item:SetVisible(visible)
            end

            dscroll:InvalidateLayout()
        end

        searchBar.OnChange = function(self)
            UpdateSearch(self:GetValue())
        end

        local allowedModes = {
            ["tdm"] = true,
            ["cstrike"] = true,
            ["hmcd"] = true,
            ["hl2dm"] = true,
            ["riot"] = true,
            ["gwars"] = true,
            ["criresp"] = true,
        }

        for i, mode in SortedPairsByMemberValue(zb.availableModes,"canlaunch",true) do
            if !LocalPlayer():IsSuperAdmin() and !allowedModes[mode.key] then continue end

            local modeBtn = CreateModeItem(dscroll, mode)
            table.insert(modeItems, modeBtn)

            modeBtn:SetCursor("hand")
            modeBtn:SetTooltip(zb.locale.GetLocalized("admin/modes/select_tooltip"))

            local inQueue = false
            for _, queuedModeKey in ipairs(zb.RoundList) do
                if queuedModeKey == mode.key then
                    inQueue = true
                    break
                end
            end

            local indicator = vgui.Create("DPanel", modeBtn)
            indicator:SetSize(16, 7)
            indicator:SetPos(8, 4)
            indicator.IndiColor = uiColors.blackTransparent
            indicator.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, indicator.IndiColor)
            end

            if mode.canlaunch == 1 then
                indicator.IndiColor = uiColors.successBright
                indicator:SetTooltip(zb.locale.GetLocalized("admin/modes/can_launch"))
            end

            if inQueue then
                indicator.IndiColor = uiColors.warningOrange
                indicator:SetTooltip(zb.locale.GetLocalized("admin/modes/already_in_queue"))
            end

            if mode.canlaunch == 0 then
                indicator.IndiColor = uiColors.errorBright
                indicator:SetTooltip(zb.locale.GetLocalized("admin/modes/cant_launch"))
            end

            if command == "setmode" or command == "setforcemode" then
                local selectBtn = vgui.Create("DButton", modeBtn)
                selectBtn:SetSize(80, 26)
                selectBtn:Dock(RIGHT)
                selectBtn:DockMargin(5, 7, 5, 7)
                selectBtn:SetText(zb.locale.GetLocalized("common/select"))
                selectBtn.DoClick = function()
                    net.Start("ZC_AdminSetGameMode")
                    net.WriteString(command)
                    net.WriteString(mode.key)
                    net.WriteBool(false)
                    net.SendToServer()
                    frame:Close()
                end
            end
        end


        local batchPanel = vgui.Create("DPanel", leftPanel)
        batchPanel:Dock(BOTTOM)
        batchPanel:DockMargin(5, 5, 5, 5)
        batchPanel:SetTall(160)
        StyleElement(batchPanel, uiColors.menuBatchBackground)

        local batchTitle = vgui.Create("DLabel", batchPanel)
        batchTitle:SetText(zb.locale.GetLocalized("admin/modes/batch_operations"))
        batchTitle:SetFont("DermaDefaultBold")
        batchTitle:SetTextColor(uiColors.white)
        batchTitle:Dock(TOP)
        batchTitle:DockMargin(0, 5, 0, 5)
        batchTitle:SetContentAlignment(5)

        local addToQueueBtn = vgui.Create("DButton", batchPanel)
        addToQueueBtn:SetText(zb.locale.GetLocalized("admin/modes/add_selected_beginning"))
        addToQueueBtn:Dock(TOP)
        addToQueueBtn:DockMargin(5, 0, 5, 5)
        addToQueueBtn:SetTall(26)
        addToQueueBtn.DoClick = function()
            local selectedCount = 0

            local selectedKeys = {}
            for key, selected in pairs(selectedModes) do
                if selected then
                    table.insert(selectedKeys, 1, key)
                    selectedCount = selectedCount + 1
                end
            end

            for i = 1, #selectedKeys do
                table.insert(zb.RoundList, 1, selectedKeys[i])
            end

            if selectedCount > 0 then
                queuePanel:QueueUpdate()

                /*net.Start("ZC_RoundListUpdate")
                    net.WriteTable(zb.RoundList)
                    net.WriteBool(false)
                net.SendToServer()*/

                chat.AddText(uiColors.successBright, zb.locale.GetLocalized("admin/modes/added_beginning", selectedCount))
            else
                chat.AddText(uiColors.errorBright, zb.locale.GetLocalized("admin/modes/none_selected"))
            end
        end

        local addToEndBtn = vgui.Create("DButton", batchPanel)
        addToEndBtn:SetText(zb.locale.GetLocalized("admin/modes/add_selected_end"))
        addToEndBtn:Dock(TOP)
        addToEndBtn:DockMargin(5, 0, 5, 0)
        addToEndBtn:SetTall(26)
        addToEndBtn.DoClick = function()
            local selectedCount = 0

            for key, selected in pairs(selectedModes) do
                if selected then
                    table.insert(zb.RoundList, key)
                    selectedCount = selectedCount + 1
                end
            end

            if selectedCount > 0 then
                queuePanel:QueueUpdate()

                /*net.Start("ZC_RoundListUpdate")
                    net.WriteTable(zb.RoundList)
                    net.WriteBool(false)
                net.SendToServer()*/

                chat.AddText(uiColors.successBright, zb.locale.GetLocalized("admin/modes/added_end", selectedCount))
            else
                chat.AddText(uiColors.errorBright, zb.locale.GetLocalized("admin/modes/none_selected"))
            end
        end

        local clearSelectBtn = vgui.Create("DButton", batchPanel)
        clearSelectBtn:SetText(zb.locale.GetLocalized("admin/modes/clear_selected"))
        clearSelectBtn:Dock(TOP)
        clearSelectBtn:DockMargin(5, 5, 5, 5)
        clearSelectBtn:SetTall(26)
        clearSelectBtn.DoClick = function()
            local selectedCount = 0

            local selectedKeys = {}
            for key, selected in pairs(selectedModes) do
                if selected then
                    table.insert(selectedKeys, 1, key)
                    selectedCount = selectedCount + 1
                end
            end

            for i = 1, #selectedKeys do
                table.insert(zb.RoundList, 1, selectedKeys[i])
            end

            if selectedCount > 0 then
                selectedModes = {}
                for _, item in ipairs(modeItems) do
                    item.Selected = false
                end

                chat.AddText(uiColors.successBright, zb.locale.GetLocalized("admin/modes/selected_cleared"))
            else
                chat.AddText(uiColors.errorBright, zb.locale.GetLocalized("admin/modes/none_selected"))
            end
        end

        local refreshBtn = vgui.Create("DButton", leftPanel)
        refreshBtn:SetText(zb.locale.GetLocalized("admin/modes/refresh_data"))
        refreshBtn:Dock(BOTTOM)
        refreshBtn:DockMargin(5, 5, 5, 5)
        refreshBtn:SetTall(30)
        refreshBtn.DoClick = function()
            net.Start("ZC_RoundListRequest")
            net.SendToServer()
        end

        batchPanel:InvalidateLayout(true)
        batchPanel:SizeToChildren(false, true)

        timer.Create("QueueAutoRefresh", 5, 0, function()
            if IsValid(frame) then
                //net.Start("ZC_RoundListRequest")
                //net.SendToServer()
            else
                timer.Remove("QueueAutoRefresh")
            end
        end)

        frame.OnClose = function()
            timer.Remove("QueueAutoRefresh")
            queuePanelInstance = nil
        end

        net.Start("ZC_RoundListRequest")
        net.SendToServer()
    end

    local function OpenAdminMenu()
        if IsValid(isMenuOpen) then return end
        if !LocalPlayer():IsAdmin() then return end

        isMenuOpen = vgui.Create("ZFrame")
        local frame = isMenuOpen
        frame:SetSize(300, 210)
        frame:Center()
        frame:SetTitle(zb.locale.GetLocalized("admin/panel"))
        frame:MakePopup()

        local setModeBtn = vgui.Create("DButton", frame)
        setModeBtn:SetText(zb.locale.GetLocalized("admin/set_next_mode"))
        setModeBtn:Dock(TOP)
        setModeBtn:DockMargin(5, 10, 5, 2)
        setModeBtn:SetSize(300, 40)
        StyleElement(setModeBtn)
        setModeBtn.DoClick = function()
            OpenModeSelection("setmode")
        end

        local setForceModeBtn = vgui.Create("DButton", frame)
        setForceModeBtn:SetText(zb.locale.GetLocalized("admin/set_auto_next_mode"))
        setForceModeBtn:Dock(TOP)
        setForceModeBtn:DockMargin(5, 2, 5, 2)
        setForceModeBtn:SetSize(300, 40)
        StyleElement(setForceModeBtn)
        setForceModeBtn.DoClick = function()
            OpenModeSelection("setforcemode")
        end

        local queueModeBtn = vgui.Create("DButton", frame)
        queueModeBtn:SetText(zb.locale.GetLocalized("admin/manage_mode_queue"))
        queueModeBtn:Dock(TOP)
        queueModeBtn:DockMargin(5, 2, 5, 2)
        queueModeBtn:SetSize(300, 40)
        StyleElement(queueModeBtn)
        queueModeBtn.DoClick = function()
            OpenModeSelection("queue")
        end

        local endRoundBtn = vgui.Create("DButton", frame)
        endRoundBtn:SetText(zb.locale.GetLocalized("admin/end_round"))
        endRoundBtn:Dock(TOP)
        endRoundBtn:DockMargin(5, 2, 5, 2)
        endRoundBtn:SetSize(300, 40)
        StyleElement(endRoundBtn)
        endRoundBtn.DoClick = function()
			net.Start("ZC_AdminEndRound")
			net.SendToServer()
			frame:Close()
        end

        frame.OnClose = function()
            isMenuOpen = false
        end
        frame:InvalidateLayout(true)
        frame:SizeToChildren(false, true)
    end

    hook.Add("InitPostEntity", "ZC_RequestModeData", function()
        if LocalPlayer():IsAdmin() then
            timer.Simple(2, function()
                net.Start("ZC_RoundListRequest")
                net.SendToServer()
            end)
        end
    end)

    concommand.Add("adminmenu", function()
        OpenAdminMenu()
    end, nil, "Opens admin menu", nil)
end
