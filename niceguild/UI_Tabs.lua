local addonName, ns = ...

function ns.BuildTabSection(parent, sectionKind, yOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(410, 85)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)

    container.tabs = {}
    container.activeTab = 1

    local titleText = (sectionKind == "level") and "Auto-Congratulate Level-Up Templates (Tabs 1-10)" or "Auto-Welcome New Member Templates (Tabs 1-10)"
    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(titleText)

    local prevTabBtn = nil
    for i = 1, 10 do
        local btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
        btn:SetSize(34, 22)
        if not prevTabBtn then
            btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
        else
            btn:SetPoint("LEFT", prevTabBtn, "RIGHT", 3, 0)
        end
        btn:SetText(tostring(i))
        
        btn:SetScript("OnClick", function()
            container:SelectTab(i)
        end)

        container.tabs[i] = btn
        prevTabBtn = btn
    end

    local tabToggle = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    tabToggle:SetPoint("TOPLEFT", container.tabs[1], "BOTTOMLEFT", -4, -6)
    tabToggle.Text:SetText("Enable Tab")
    tabToggle:SetScript("OnClick", function(self)
        local active = container.activeTab
        if ns.db then
            local tabs = (sectionKind == "level") and ns.db.congratsTabs or ns.db.welcomeTabs
            if tabs and tabs[active] then
                tabs[active].enabled = self:GetChecked() and true or false
                container:UpdateTabVisuals()
                ns.RefreshConfigUI()
            end
        end
    end)
    container.tabToggle = tabToggle

    local editBox = ns.CreateStyledEditBox(container, 305, 26)
    editBox:SetPoint("TOPLEFT", tabToggle, "BOTTOMLEFT", 4, -4)
    editBox:SetScript("OnTextChanged", function(self)
        local active = container.activeTab
        if ns.db then
            local tabs = (sectionKind == "level") and ns.db.congratsTabs or ns.db.welcomeTabs
            if tabs and tabs[active] then
                tabs[active].text = self:GetText() or ""
                container:UpdateTabVisuals()
                ns.RefreshConfigUI()
            end
        end
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        ns.activeEditBox = self
    end)
    container.editBox = editBox

    local testBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    testBtn:SetSize(70, 24)
    testBtn:SetPoint("LEFT", editBox, "RIGHT", 6, 0)
    testBtn:SetText("Test Tab")
    testBtn:SetScript("OnClick", function()
        ns.SaveInputsFromUI()
        local sampleName = ns.GetSafePlayerName() or "Adventurer"
        ns.TriggerGuildGreeting(sectionKind, sampleName, true)
    end)
    container.testBtn = testBtn

    local previewLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLabel:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 2, -4)
    previewLabel:SetTextColor(0.7, 0.85, 0.7)
    container.previewLabel = previewLabel

    function container:SelectTab(idx)
        self.activeTab = idx
        for i = 1, 10 do
            local b = self.tabs[i]
            if i == idx then
                b:Disable()
            else
                b:Enable()
            end
        end
        self:RefreshTabContent()
    end

    function container:RefreshTabContent()
        if not ns.db then return end
        local tabs = (sectionKind == "level") and ns.db.congratsTabs or ns.db.welcomeTabs
        local tabData = tabs and tabs[self.activeTab]
        if tabData then
            self.tabToggle:SetChecked(tabData.enabled)
            if not self.editBox:HasFocus() then
                self.editBox:SetText(tabData.text or "")
            end
        end
        self:UpdateTabVisuals()
    end

    function container:UpdateTabVisuals()
        if not ns.db then return end
        local tabs = (sectionKind == "level") and ns.db.congratsTabs or ns.db.welcomeTabs
        for i = 1, 10 do
            local t = tabs[i]
            local btn = self.tabs[i]
            if t and t.enabled then
                local trimmed = (t.text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if trimmed == "" then
                    btn.text:SetTextColor(1, 0.6, 0)
                else
                    btn.text:SetTextColor(0.2, 1, 0.2)
                end
            else
                btn.text:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end

    container:SelectTab(1)
    return container
end
