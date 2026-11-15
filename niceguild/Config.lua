local addonName, ns = ...

-- Default message templates and configuration schema
function ns.InitializeSavedVariables()
    if not NiceGuildDB then
        NiceGuildDB = {}
    end

    if NiceGuildDB.enableCongrats == nil then NiceGuildDB.enableCongrats = true end
    if NiceGuildDB.enableWelcome == nil then NiceGuildDB.enableWelcome = true end
    if NiceGuildDB.useShortName == nil then NiceGuildDB.useShortName = true end

    -- Initialize 10 independent tabs per section (disabled by default except Tab 1)
    if type(NiceGuildDB.congratsTabs) ~= "table" then
        NiceGuildDB.congratsTabs = {}
        for i = 1, 10 do
            NiceGuildDB.congratsTabs[i] = {
                enabled = (i == 1),
                text = (i == 1) and "{star} Grats {{name}}! {star}" or ""
            }
        end
    end

    if type(NiceGuildDB.welcomeTabs) ~= "table" then
        NiceGuildDB.welcomeTabs = {}
        for i = 1, 10 do
            NiceGuildDB.welcomeTabs[i] = {
                enabled = (i == 1),
                text = (i == 1) and "{triangle} Welcome to the guild, {{name}}!" or ""
            }
        end
    end

    -- Backward compatibility for old single strings
    if NiceGuildDB.congratsText and NiceGuildDB.congratsTabs[1].text == "" then
        NiceGuildDB.congratsTabs[1].text = NiceGuildDB.congratsText
        NiceGuildDB.congratsTabs[1].enabled = true
    end
    if NiceGuildDB.welcomeText and NiceGuildDB.welcomeTabs[1].text == "" then
        NiceGuildDB.welcomeTabs[1].text = NiceGuildDB.welcomeText
        NiceGuildDB.welcomeTabs[1].enabled = true
    end

    ns.db = NiceGuildDB
end

-- Uniform 1/N random selection from enabled, non-whitespace tabs within 255 char limit
function ns.PickRandomEnabledTab(kind)
    if not ns.db then return nil end
    local tabs = (kind == "level") and ns.db.congratsTabs or ns.db.welcomeTabs
    if not tabs then return nil end

    local eligible = {}
    for i = 1, 10 do
        local tab = tabs[i]
        if tab and tab.enabled and tab.text then
            local trimmed = tab.text:gsub("^%s+", ""):gsub("%s+$", "")
            if trimmed ~= "" then
                local sampleName = "Adventurer"
                local sampleFormatted = ns.FormatTemplate(trimmed, sampleName)
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
