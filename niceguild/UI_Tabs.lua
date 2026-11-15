local addonName, ns = ...

local TAB_COUNT = 10
local BOX_WIDTH = 258
local BOX_HEIGHT = 60

local function GetTabs(sectionKind)
    if not ns.db then return nil end
    return (sectionKind == "level") and ns.db.congratsTabs or ns.db.welcomeTabs
end

local function Trim(text)
    if type(text) ~= "string" then return "" end
    return text:match("^%s*(.-)%s*$") or ""
end

local function GetSelfInfo()
    if type(ns.GetSelfInfo) == "function" then
        return ns.GetSelfInfo()
    end
    local name = (type(ns.GetSafePlayerName) == "function" and ns.GetSafePlayerName()) or "Adventurer"
    return { name = name, class = "", level = "" }
end

local function CreateEditor(parent)
    if type(ns.CreateMultilineMacroBox) == "function" then
        return ns.CreateMultilineMacroBox(parent, BOX_WIDTH, BOX_HEIGHT)
    end
    local editBox = ns.CreateStyledEditBox(parent, BOX_WIDTH, BOX_HEIGHT)
    return editBox, editBox
end

local function CreatePreview(parent)
    if type(ns.CreateContainedPreviewBox) == "function" then
        return ns.CreateContainedPreviewBox(parent, BOX_WIDTH, BOX_HEIGHT)
    end
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(BOX_WIDTH, BOX_HEIGHT)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    return container, text
end

function ns.BuildTabSection(parent, sectionKind)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 10, -30)
    container:SetPoint("BOTTOMRIGHT", -10, 8)

    container.tabs = {}
    container.activeTab = 1

    local prevTabBtn = nil
    for i = 1, TAB_COUNT do
        local btn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
        btn:SetSize(29, 20)
        if not prevTabBtn then
            btn:SetPoint("TOPLEFT", 0, 0)
        else
            btn:SetPoint("LEFT", prevTabBtn, "RIGHT", 2, 0)
        end
        btn:SetText(tostring(i))
        btn:SetScript("OnClick", function()
            container:SelectTab(i)
        end)

        container.tabs[i] = btn
        prevTabBtn = btn
    end

    local tabToggle = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    tabToggle:SetSize(24, 24)
    tabToggle:SetPoint("LEFT", prevTabBtn, "RIGHT", 8, 0)
    tabToggle.Text:SetText("Enable Tab")
    tabToggle:SetScript("OnClick", function(self)
        local tabs = GetTabs(sectionKind)
        local tab = tabs and tabs[container.activeTab]
        if tab then
            tab.enabled = self:GetChecked() and true or false
            container:UpdateTabVisuals()
            container:UpdatePreview()
            if type(ns.RefreshConfigUI) == "function" then
                ns.RefreshConfigUI()
            end
        end
    end)
    container.tabToggle = tabToggle

    local testBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    testBtn:SetSize(70, 20)
    testBtn:SetPoint("TOPRIGHT", 0, 0)
    testBtn:SetText("Test Tab")
    testBtn:SetScript("OnClick", function()
        ns.SaveInputsFromUI()
        local tabs = GetTabs(sectionKind)
        local tabData = tabs and tabs[container.activeTab]
        local info = GetSelfInfo()
        ns.TriggerGuildGreeting(sectionKind, info.name, true, tabData and tabData.text or "", info.class, info.level)
    end)
    container.testBtn = testBtn

    local editLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editLabel:SetPoint("TOPLEFT", 0, -26)
    editLabel:SetText("|cffccccccMessage Template (4-line macro editor):|r")

    local previewLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewLabel:SetPoint("TOPLEFT", BOX_WIDTH + 14, -26)
    previewLabel:SetText("|cff7fb3e6Live Preview (read-only):|r")

    local editorContainer, editBox = CreateEditor(container)
    editorContainer:SetPoint("TOPLEFT", 0, -40)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local tabs = GetTabs(sectionKind)
        local tab = tabs and tabs[container.activeTab]
        if tab then
            tab.text = self:GetText() or ""
            container:UpdateTabVisuals()
            container:UpdatePreview()
            if type(ns.RefreshConfigUI) == "function" then
                ns.RefreshConfigUI()
            end
        end
    end)
    local previousFocusHandler = type(editBox.GetScript) == "function" and editBox:GetScript("OnEditFocusGained") or nil
    editBox:SetScript("OnEditFocusGained", function(self)
        if previousFocusHandler then previousFocusHandler(self) end
        ns.activeEditBox = self
    end)
    container.editorContainer = editorContainer
    container.editBox = editBox

    local previewBox, previewText = CreatePreview(container)
    previewBox:SetPoint("LEFT", editorContainer, "RIGHT", 14, 0)
    container.previewBox = previewBox
    container.previewText = previewText
    container.previewLabel = previewText

    local countText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", editorContainer, "BOTTOMLEFT", 2, -5)
    container.countText = countText

    local warnText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warnText:SetPoint("TOPLEFT", countText, "BOTTOMLEFT", 0, -2)
    container.warnText = warnText

    function container:UpdatePreview()
        local rawTemplate = self.editBox:GetText() or ""
        local potential = type(ns.GetPotentialLength) == "function" and ns.GetPotentialLength(rawTemplate) or #rawTemplate
        local maxChars = ns.MAX_CHAT_CHARACTERS or 255
        if potential > maxChars then
            self.countText:SetText("|cffff4444Potential characters: " .. potential .. " / " .. maxChars .. "|r")
            self.warnText:SetText("|cffff4444Warning: exceeds the chat limit and will not be selected.|r")
        else
            self.countText:SetText("|cff9fd49fPotential characters: " .. potential .. " / " .. maxChars .. "|r")
            self.warnText:SetText("|cff888888Whitespace-only tabs are ignored even when enabled.|r")
        end

        local info = GetSelfInfo()
        local formatted = type(ns.FormatTemplate) == "function"
            and ns.FormatTemplate(rawTemplate, info.name, info.class, info.level)
            or rawTemplate
        if formatted and Trim(formatted) ~= "" then
            local rendered = type(ns.RenderRaidSymbolsForPreview) == "function"
                and ns.RenderRaidSymbolsForPreview(formatted, 14)
                or formatted
            self.previewText:SetText(rendered)
        else
            self.previewText:SetText("|cff777777(empty message)|r")
        end
    end

    function container:SelectTab(idx)
        if type(idx) ~= "number" or idx < 1 or idx > TAB_COUNT then return end
        if self.editBox:HasFocus() then
            self.editBox:ClearFocus()
        end
        self.activeTab = idx
        for i = 1, TAB_COUNT do
            if i == idx then
                self.tabs[i]:Disable()
            else
                self.tabs[i]:Enable()
            end
        end
        self:RefreshTabContent()
        if self.initialized and type(ns.RefreshConfigUI) == "function" then
            ns.RefreshConfigUI()
        end
    end

    function container:RefreshTabContent()
        local tabs = GetTabs(sectionKind)
        local tabData = tabs and tabs[self.activeTab]
        if not tabData then return end
        self.tabToggle:SetChecked(tabData.enabled == true)
        if not self.editBox:HasFocus() then
            self.editBox:SetText(tabData.text or "")
        end
        self:UpdateTabVisuals()
        self:UpdatePreview()
    end

    function container:UpdateTabVisuals()
        local tabs = GetTabs(sectionKind)
        if not tabs then return end
        for i = 1, TAB_COUNT do
            local tab = tabs[i]
            local btn = self.tabs[i]
            if tab and tab.enabled then
                if Trim(tab.text) == "" then
                    btn.Text:SetTextColor(1, 0.6, 0)
                else
                    btn.Text:SetTextColor(0.2, 1, 0.2)
                end
            else
                btn.Text:SetTextColor(0.5, 0.5, 0.5)
            end
        end
    end

    container:SelectTab(1)
    container.initialized = true
    return container
end
