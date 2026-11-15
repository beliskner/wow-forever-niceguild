local addonName, ns = ...

-- Default message templates and configuration schema
local function NormalizeTabs(tabs, legacyText, defaultText)
    if type(tabs) ~= "table" then
        tabs = {}
    end

    local useLegacyText = type(legacyText) == "string"
        and (type(tabs[1]) ~= "table" or type(tabs[1].text) ~= "string")

    for i = 1, 10 do
        local tab = tabs[i]
        if type(tab) ~= "table" then
            tab = {}
            tabs[i] = tab
        end

        if type(tab.enabled) ~= "boolean" then
            tab.enabled = (i == 1)
        end

        if type(tab.text) ~= "string" then
            tab.text = (i == 1) and defaultText or ""
        end
    end

    if useLegacyText then
        tabs[1].text = legacyText
        tabs[1].enabled = legacyText ~= ""
    end

    return tabs
end

function ns.InitializeSavedVariables()
    if type(NiceGuildDB) ~= "table" then
        NiceGuildDB = {}
    end

    if type(NiceGuildDB.enableCongrats) ~= "boolean" then NiceGuildDB.enableCongrats = true end
    if type(NiceGuildDB.enableWelcome) ~= "boolean" then NiceGuildDB.enableWelcome = true end
    if type(NiceGuildDB.useShortName) ~= "boolean" then NiceGuildDB.useShortName = true end

    NiceGuildDB.congratsTabs = NormalizeTabs(
        NiceGuildDB.congratsTabs,
        NiceGuildDB.congratsText,
        "{star} Grats {{name}}! {star}"
    )
    NiceGuildDB.welcomeTabs = NormalizeTabs(
        NiceGuildDB.welcomeTabs,
        NiceGuildDB.welcomeText,
        "{triangle} Welcome to the guild, {{name}}!"
    )
    NiceGuildDB.congratsText = nil
    NiceGuildDB.welcomeText = nil

    ns.db = NiceGuildDB
end

-- Uniform 1/N random selection from enabled, non-whitespace tabs within 255 char limit
function ns.PickRandomEnabledTab(kind, memberName, memberClass, memberLevel)
    if not ns.db then return nil end
    local tabs = (kind == "level") and ns.db.congratsTabs or ns.db.welcomeTabs
    if not tabs then return nil end

    local eligible = {}
    for i = 1, 10 do
        local tab = tabs[i]
        if tab and tab.enabled and tab.text then
            local trimmed = tab.text:gsub("^%s+", ""):gsub("%s+$", "")
            if trimmed ~= "" then
                local sampleName = memberName or "Adventurer"
                local sampleFormatted = ns.FormatTemplate(trimmed, sampleName, memberClass, memberLevel)
                if sampleFormatted and string.len(sampleFormatted) <= 255 then
                    table.insert(eligible, trimmed)
                end
            end
        end
    end

    if #eligible == 0 then
        return nil
    end

    local idx = math.random(1, #eligible)
    return eligible[idx]
end
