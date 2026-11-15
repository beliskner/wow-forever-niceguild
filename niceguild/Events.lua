local addonName, ns = ...

local eventFrame = CreateFrame("Frame")

function ns.SendGuildMessage(msg)
    if not msg or msg == "" then return end
    local safeMsg = ns.NormalizeRaidSymbolsForChat(msg)
    if string.len(safeMsg) > 255 then
        ns.Print("Error: Message exceeds 255 characters limit.")
        return
    end

    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        C_ChatInfo.SendChatMessage(safeMsg, "GUILD")
    elseif SendChatMessage then
        SendChatMessage(safeMsg, "GUILD")
    end
end

function ns.TriggerGuildGreeting(kind, memberName, isLocalTest)
    local template = ns.PickRandomEnabledTab(kind)
    if not template or template == "" then
        if isLocalTest then
            ns.Print("No enabled tabs configured for testing in this section.")
        end
        return
    end

    local finalMsg = ns.FormatTemplate(template, memberName, "Adventurer", "80")
    if string.len(finalMsg) > 255 then
        ns.Print("Error: Generated test message exceeds 255 character limit.")
        return
    end

    if isLocalTest then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[Test Preview (Guild)]|r " .. finalMsg)
        else
            ns.Print("[Test Preview] " .. finalMsg)
        end
    else
        ns.SendGuildMessage(finalMsg)
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        local ok, err = pcall(ns.InitializeSavedVariables)
        if not ok then
            print("[Nice Guild] DB Init error: " .. tostring(err))
        end
        pcall(ns.RegisterSettingsPanel)
    elseif event == "PLAYER_LOGIN" then
        ns.Print("Loaded v1.4.0. Type /niceguild to configure or /niceguild help for commands.")
    elseif event == "CHAT_MSG_SYSTEM" and arg1 then
        if not ns.db then return end
        if ns.IsSecret(arg1) then return end

        if ns.db.enableCongrats then
            local playerName = arg1:match("^(.-) has achieved level") or arg1:match("^(.-) has reached level")
            if playerName then
                C_Timer.After(0.5, function()
                    ns.TriggerGuildGreeting("level", playerName, false)
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
