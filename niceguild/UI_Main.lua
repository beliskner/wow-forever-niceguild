local addonName, ns = ...

local configFrame = nil

local function BuildConfigFrame()
    if configFrame then
        return configFrame
    end

    local f = CreateFrame("Frame", "NiceGuildConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(450, 470)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile = "Interface\DialogFrame\UI-DialogBox-Background",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.96)

    if ns.db and type(ns.db.windowPoint) == "table" then
        local p = ns.db.windowPoint
        f:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or "CENTER", p.x or 0, p.y or 0)
    else
        f:SetPoint("CENTER")
    end

    f:SetScript("OnDragStart", function(self)
        ns.RunOutOfCombat(function()
            self:StartMoving()
        end)
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        if ns.db then
            ns.db.windowPoint = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)

    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Nice Guild v1.4.0")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Use {{name}} for member and {star}..{skull} or {rt1}..{rt8} for raid icons.")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function()
        ns.HideConfig()
    end)

    local levelSection = ns.BuildTabSection(f, "level", -52)
    f.levelSection = levelSection

    local welcomeSection = ns.BuildTabSection(f, "welcome", -152)
    f.welcomeSection = welcomeSection

    local iconLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -252)
    iconLabel:SetText("Insert Raid Symbol:")

    local prevBtn = nil
    for _, info in ipairs(ns.RAID_SYMBOLS) do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(24, 24)
        if not prevBtn then
            btn:SetPoint("LEFT", iconLabel, "RIGHT", 8, 0)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end
        btn:SetBackdrop({
            bgFile = "Interface\ChatFrame\ChatFrameBackground",
            edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        btn:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetSize(16, 16)
        tex:SetPoint("CENTER")
        tex:SetTexture(ns.GetRaidIconTexturePath(info.index))

        btn:SetScript("OnClick", function()
            local target = ns.activeEditBox or f.levelSection.editBox
            if target then
                target:SetFocus()
                target:Insert(info.tag)
            end
        end)
        prevBtn = btn
    end

    local shortNameCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    shortNameCheck:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", -6, -10)
    shortNameCheck.Text:SetText("Strip -Realm suffix from {{name}}")
    shortNameCheck:SetScript("OnClick", function(self)
        if ns.db then
            ns.db.useShortName = self:GetChecked() and true or false
            ns.RefreshConfigUI()
        end
    end)
    f.shortNameCheck = shortNameCheck

    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(110, 26)
    saveBtn:SetPoint("BOTTOMRIGHT", -18, 16)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        ns.SaveInputsFromUI()
        ns.Print("Settings saved.")
    end)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 26)
    resetBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        if NiceGuildDB then
            NiceGuildDB = nil
            ns.InitializeSavedVariables()
            f.levelSection:SelectTab(1)
            f.welcomeSection:SelectTab(1)
            ns.RefreshConfigUI()
            ns.Print("Defaults restored.")
        end
    end)

    table.insert(UISpecialFrames, "NiceGuildConfigFrame")
    configFrame = f
    return f
end

function ns.RefreshConfigUI()
    if not configFrame or not ns.db then return end
    configFrame.shortNameCheck:SetChecked(ns.db.useShortName)

    if configFrame.levelSection then
        configFrame.levelSection:RefreshTabContent()
        local sampleName = ns.GetSafePlayerName() or "Thrall"
        local curText = configFrame.levelSection.editBox:GetText() or ""
        local formatted = ns.FormatTemplate(curText, sampleName)
        local preview = ns.RenderRaidSymbolsForPreview(formatted, 14)
        configFrame.levelSection.previewLabel:SetText("Preview: " .. preview)
    end

    if configFrame.welcomeSection then
        configFrame.welcomeSection:RefreshTabContent()
        local sampleName = ns.GetSafePlayerName() or "Thrall"
        local curText = configFrame.welcomeSection.editBox:GetText() or ""
        local formatted = ns.FormatTemplate(curText, sampleName)
        local preview = ns.RenderRaidSymbolsForPreview(formatted, 14)
        configFrame.welcomeSection.previewLabel:SetText("Preview: " + preview)
    end
end

function ns.SaveInputsFromUI()
    if not configFrame or not ns.db then return end
    ns.db.useShortName = configFrame.shortNameCheck:GetChecked() and true or false
end

function ns.ShowConfig()
    ns.RunOutOfCombat(function()
        local f = BuildConfigFrame()
        ns.RefreshConfigUI()
        f:Show()
    end)
end

function ns.HideConfig()
    if not configFrame then return end
    ns.RunOutOfCombat(function()
        if configFrame then configFrame:Hide() end
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
    if not Settings or type(Settings.RegisterVerticalLayoutCategory) ~= "function" then return end
    local category, layout = Settings.RegisterVerticalLayoutCategory("Nice Guild")
    if type(CreateSettingsButtonInitializer) == "function" and layout and type(layout.AddInitializer) == "function" then
        local initializer = CreateSettingsButtonInitializer(
            "Configure Nice Guild", "Open Window",
            function() ns.ShowConfig() end,
            "Opens the Nice Guild level-up and welcome message editor.", true
        )
        layout:AddInitializer(initializer)
    end
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

function NiceGuild_OnCompartmentClick(addonNameArg, buttonName)
    ns.ToggleConfig()
end
