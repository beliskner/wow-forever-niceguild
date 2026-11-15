local addonName, ns = ...

local configFrame = nil

local function VersionLabel()
    local ok, version = pcall(function()
        if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
            return C_AddOns.GetAddOnMetadata(addonName, "Version")
        end
        return ns.VERSION
    end)
    if ok and version and version ~= "" then
        return " v" .. tostring(version)
    end
    return ""
end

function ns.SaveInputsFromUI()
    if not configFrame or not ns.db then return end
    ns.db.enableCongrats = configFrame.congratsCheck:GetChecked() and true or false
    ns.db.enableWelcome = configFrame.welcomeCheck:GetChecked() and true or false
    if configFrame.congratsSection then configFrame.congratsSection:RefreshTabContent() end
    if configFrame.welcomeSection then configFrame.welcomeSection:RefreshTabContent() end
end

function ns.RefreshConfigUI()
    if not configFrame or not ns.db then return end
    configFrame.congratsCheck:SetChecked(ns.db.enableCongrats == true)
    configFrame.welcomeCheck:SetChecked(ns.db.enableWelcome == true)

    if configFrame.congratsSection then
        configFrame.congratsSection:UpdateTabVisuals()
        configFrame.congratsSection:UpdatePreview()
    end
    if configFrame.welcomeSection then
        configFrame.welcomeSection:UpdateTabVisuals()
        configFrame.welcomeSection:UpdatePreview()
    end

    if configFrame.tokenPreviewStrings then
        local info = ns.GetSelfInfo()
        for _, entry in ipairs(configFrame.tokenPreviewStrings) do
            local sample = ns.FormatTemplate(entry.tag, info.name, info.class, info.level) or ""
            entry.fontString:SetText("|cffffffff" .. sample .. "|r |cff888888(" .. entry.weight .. ")|r")
        end
    end
end

local function InsertTagIntoActiveBox(tag)
    if not configFrame or not tag then return end
    local target = ns.activeEditBox
    if not target or not target:IsShown() then
        target = configFrame.congratsSection and configFrame.congratsSection.editBox
    end
    if not target then return end
    target:SetFocus()
    target:Insert(tag)
    ns.RefreshConfigUI()
end

-- Section header: the title IS the enable checkbox, so the row explains itself.
local function BuildSectionHeader(parent, titleText, onToggle)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", 8, -4)
    check.Text:SetFontObject("GameFontNormal")
    check.Text:SetText(titleText)
    check.Text:SetJustifyH("LEFT")
    check:SetScript("OnClick", function(self)
        onToggle(self:GetChecked() and true or false)
    end)
    parent.titleCheck = check
    return check
end

local function BuildConfigFrame()
    if configFrame then
        return configFrame
    end

    local f = CreateFrame("Frame", "NiceGuildConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(580, 650)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
    f:Hide()

    if ns.db and type(ns.db.windowPoint) == "table" then
        local p = ns.db.windowPoint
        f:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or "CENTER", p.x or 0, p.y or 0)
    else
        f:SetPoint("CENTER")
    end

    f:SetScript("OnDragStart", function(self)
        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            return
        end
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        if ns.db then
            ns.db.windowPoint = {
                point = point,
                relativePoint = relativePoint,
                x = x,
                y = y,
            }
        end
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Nice Guild" .. VersionLabel())

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetText("Pick a template tab, then use Section 3 to insert tokens or raid icons into the active message box.")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function()
        ns.HideConfig()
    end)

    ---------------------------------------------------------------------------
    -- SECTION 1: Level-Up Congratulations
    ---------------------------------------------------------------------------
    local sec1 = ns.CreateSectionPanel(f, 180)
    sec1:SetPoint("TOPLEFT", 14, -48)
    sec1:SetPoint("TOPRIGHT", -14, -48)

    local congratsCheck = BuildSectionHeader(sec1, "1. Level-Up Congratulations (check to enable)", function(enabled)
        if ns.db then
            ns.db.enableCongrats = enabled
        end
        ns.RefreshConfigUI()
    end)
    f.congratsCheck = congratsCheck
    sec1.masterCheck = congratsCheck

    f.congratsSection = ns.BuildTabSection(sec1, "level")
    f.congratsSection.masterCheck = congratsCheck
    f.congratsSection.panel = sec1

    ---------------------------------------------------------------------------
    -- SECTION 2: New Member Welcome
    ---------------------------------------------------------------------------
    local sec2 = ns.CreateSectionPanel(f, 180)
    sec2:SetPoint("TOPLEFT", sec1, "BOTTOMLEFT", 0, -8)
    sec2:SetPoint("TOPRIGHT", sec1, "BOTTOMRIGHT", 0, -8)

    local welcomeCheck = BuildSectionHeader(sec2, "2. New Member Welcome (check to enable)", function(enabled)
        if ns.db then
            ns.db.enableWelcome = enabled
        end
        ns.RefreshConfigUI()
    end)
    f.welcomeCheck = welcomeCheck
    sec2.masterCheck = welcomeCheck

    f.welcomeSection = ns.BuildTabSection(sec2, "welcome")
    f.welcomeSection.masterCheck = welcomeCheck
    f.welcomeSection.panel = sec2

    ---------------------------------------------------------------------------
    -- SECTION 3: Utilities, Formatting Tokens & Raid Symbols
    ---------------------------------------------------------------------------
    local sec3 = ns.CreateSectionPanel(f, 180)
    sec3:SetPoint("TOPLEFT", sec2, "BOTTOMLEFT", 0, -8)
    sec3:SetPoint("TOPRIGHT", sec2, "BOTTOMRIGHT", 0, -8)

    local sec3Title = sec3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sec3Title:SetPoint("TOPLEFT", 10, -8)
    sec3Title:SetText("3. Utilities, Formatting Tokens & Raid Symbols")

    local raidLabel = sec3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidLabel:SetPoint("TOPLEFT", 10, -30)
    raidLabel:SetText("Insert Raid Symbol:")

    local prevRaidBtn = nil
    for _, info in ipairs(ns.RAID_SYMBOLS or {}) do
        local btn = CreateFrame("Button", nil, sec3, "BackdropTemplate")
        btn:SetSize(24, 24)
        if not prevRaidBtn then
            btn:SetPoint("LEFT", raidLabel, "RIGHT", 8, 0)
        else
            btn:SetPoint("LEFT", prevRaidBtn, "RIGHT", 4, 0)
        end

        btn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        btn:SetBackdropColor(0.13, 0.13, 0.16, 0.95)
        btn:SetBackdropBorderColor(0.45, 0.45, 0.50, 1)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetSize(16, 16)
        tex:SetPoint("CENTER")
        tex:SetTexture(ns.GetRaidIconTexturePath(info.index))

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(info.label, 1, 0.82, 0)
            GameTooltip:AddLine("Click to insert " .. info.tag .. " (or " .. info.rt .. ")", 1, 1, 1)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.45, 0.45, 0.50, 1)
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            InsertTagIntoActiveBox(info.tag)
        end)

        prevRaidBtn = btn
    end

    local tokensHeader = sec3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tokensHeader:SetPoint("TOPLEFT", 10, -62)
    tokensHeader:SetText("Insert Formatting Token (previewed with your character; potential cost in parentheses):")

    f.tokenPreviewStrings = {}

    for idx, tok in ipairs(ns.FORMAT_TOKENS or {}) do
        local isRightCol = (idx >= 5)
        local rowIndex = isRightCol and (idx - 5) or (idx - 1)
        local colX = isRightCol and 274 or 10
        local rowY = -76 - (rowIndex * 22)

        local tokBtn = CreateFrame("Button", nil, sec3, "BackdropTemplate")
        tokBtn:SetSize(76, 20)
        tokBtn:SetPoint("TOPLEFT", colX, rowY)
        tokBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        tokBtn:SetBackdropColor(0.14, 0.14, 0.18, 0.95)
        tokBtn:SetBackdropBorderColor(0.50, 0.46, 0.30, 1)

        local btnText = tokBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetPoint("CENTER")
        btnText:SetText("|cffffd100" .. tok.tag .. "|r")

        tokBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tok.tag, 1, 0.82, 0)
            GameTooltip:AddLine(tok.desc, 1, 1, 1, true)
            GameTooltip:AddLine("Potential character count: " .. tok.weight, 0.7, 0.9, 0.7)
            GameTooltip:AddLine("Click to insert into the active message box.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)

        tokBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.50, 0.46, 0.30, 1)
            GameTooltip:Hide()
        end)

        tokBtn:SetScript("OnClick", function()
            InsertTagIntoActiveBox(tok.tag)
        end)

        local previewFS = sec3:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        previewFS:SetPoint("LEFT", tokBtn, "RIGHT", 6, 0)
        previewFS:SetWidth(166)
        previewFS:SetJustifyH("LEFT")
        previewFS:SetWordWrap(false)

        table.insert(f.tokenPreviewStrings, {
            tag = tok.tag,
            weight = tok.weight,
            fontString = previewFS,
        })
    end

    local legend = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("BOTTOMLEFT", 16, 16)
    legend:SetText("|cff888888Tab colours: green = on, orange = on but empty, grey = off.|r")

    ---------------------------------------------------------------------------
    -- Bottom Action Buttons
    ---------------------------------------------------------------------------
    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(110, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        ns.SaveInputsFromUI()
        ns.Print("Settings saved.")
    end)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 24)
    resetBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        NiceGuildDB = nil
        ns.InitializeSavedVariables()
        if configFrame then
            configFrame.congratsSection:SelectTab(1)
            configFrame.welcomeSection:SelectTab(1)
        end
        ns.RefreshConfigUI()
        ns.Print("Defaults restored (auto-messages disabled).")
    end)

    table.insert(UISpecialFrames, "NiceGuildConfigFrame")
    ns.activeEditBox = f.congratsSection.editBox
    configFrame = f
    ns.RefreshConfigUI()
    return f
end

function ns.ShowConfig()
    if not ns.db and type(ns.InitializeSavedVariables) == "function" then
        ns.InitializeSavedVariables()
    end
    ns.RunOutOfCombat(function()
        local f = BuildConfigFrame()
        ns.RefreshConfigUI()
        f:Show()
    end)
end

function ns.HideConfig()
    if not configFrame then
        return
    end
    ns.RunOutOfCombat(function()
        if configFrame then
            configFrame:Hide()
        end
    end)
end

function ns.ToggleConfig()
    local f = BuildConfigFrame()
    if f:IsShown() then
        ns.HideConfig()
    else
        ns.ShowConfig()
    end
end

function ns.RegisterSettingsPanel()
    if not Settings or type(Settings.RegisterVerticalLayoutCategory) ~= "function" then
        return
    end
    local category, layout = Settings.RegisterVerticalLayoutCategory("Nice Guild")
    if type(CreateSettingsButtonInitializer) == "function" and layout and type(layout.AddInitializer) == "function" then
        local initializer = CreateSettingsButtonInitializer(
            "Configure Nice Guild",
            "Open Window",
            function()
                ns.ShowConfig()
            end,
            "Opens the Nice Guild level-up and welcome message editor.",
            true
        )
        layout:AddInitializer(initializer)
    end
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

function NiceGuild_OnCompartmentClick(addonNameArg, buttonName)
    ns.ToggleConfig()
end
