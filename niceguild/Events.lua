local addonName, ns = ...

local eventFrame = CreateFrame("Frame")

function ns.SendGuildMessage(msg)
    if msg == nil or ns.IsSecret(msg) then return end
    if type(msg) ~= "string" then msg = tostring(msg) end
    if msg == "" then return end
    local safeMsg = ns.NormalizeRaidSymbolsForChat(msg)
    if string.len(safeMsg) > 255 then
        ns.Print("Error: Message exceeds 255 characters limit.")
        return
    end

    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        local ok, err = pcall(C_ChatInfo.SendChatMessage, safeMsg, "GUILD")
        if not ok then
            ns.Print("Error: Could not send guild message: " .. tostring(err))
        end
    else
        ns.Print("Error: Guild chat API is unavailable.")
    end
end

function ns.TriggerGuildGreeting(kind, memberName, isLocalTest, templateOverride, memberClass, memberLevel)
    if not isLocalTest and type(ns.IsSelf) == "function" and ns.IsSelf(memberName) then
        return
    end

    local template
    if templateOverride ~= nil then
        template = templateOverride:gsub("^%s+", ""):gsub("%s+$", "")
    else
        template = ns.PickRandomEnabledTab(kind, memberName, memberClass, memberLevel)
    end
    if not template or template == "" then
        if isLocalTest then
            ns.Print("The selected tab is empty.")
        end
        return
    end

    local finalMsg = ns.FormatTemplate(template, memberName, memberClass, memberLevel)
    if string.len(finalMsg) > 255 then
        ns.Print("Error: Generated message exceeds 255 character limit.")
        return
    end

    if isLocalTest then
        -- Chat shows Blizzard symbols for {star}..{skull}, but a FontString preview
        -- needs the texture markup, so render the test line instead of showing raw tags.
        local display = finalMsg
        if type(ns.RenderRaidSymbolsForPreview) == "function" then
            display = ns.RenderRaidSymbolsForPreview(finalMsg, 14)
        end
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Test Preview (Guild)]|r " .. display)
        else
            ns.Print("[Test Preview] " .. display)
        end
    else
        ns.SendGuildMessage(finalMsg)
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        local ok, err = pcall(ns.InitializeSavedVariables)
        if not ok then
            print("[Nice Guild] DB Init error: " .. tostring(err))
        end
        pcall(ns.RegisterSettingsPanel)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if type(ns.RequestGuildRoster) == "function" then
            ns.RequestGuildRoster()
        end
        if type(ns.ResolveSelfNameFromRoster) == "function" then
            ns.ResolveSelfNameFromRoster()
        end
        if event == "PLAYER_LOGIN" then
            ns.Print("Loaded v" .. ns.VERSION .. ". Type /niceguild to configure or /niceguild help for commands.")
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        if type(ns.ResolveSelfNameFromRoster) == "function" then
            ns.ResolveSelfNameFromRoster()
        end
        if type(ns.RefreshConfigUI) == "function" then
            ns.RefreshConfigUI()
        end
    elseif event == "CHAT_MSG_SYSTEM" and arg1 then
        if not ns.db then return end
        if ns.IsSecret(arg1) then return end

        if ns.db.enableCongrats then
            local playerName, playerLevel = arg1:match("^(.-) has achieved level (%d+)")
            if not playerName then
                playerName, playerLevel = arg1:match("^(.-) has reached level (%d+)")
            end
            if not playerName then
                playerName = arg1:match("^(.-) has achieved level") or arg1:match("^(.-) has reached level")
            end
            if playerName then
                C_Timer.After(0.5, function()
                    ns.TriggerGuildGreeting("level", playerName, false, nil, nil, playerLevel)
                end)
            end
        end

        if ns.db.enableWelcome then
            local joinedName = arg1:match("^(.-) has joined the guild")
            if joinedName then
                C_Timer.After(0.5, function()
                    ns.TriggerGuildGreeting("welcome", joinedName, false)
                end)
            end
        end
    end
end)
