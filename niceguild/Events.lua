local addonName, ns = ...

local eventFrame = CreateFrame("Frame")
local rosterSnapshot = nil
local seenMemberGuids = nil
local guidByName = {}
local nameByGuid = {}
local rosterTicker = nil

local function CleanRosterValue(value)
    if value == nil or (type(ns.IsSecret) == "function" and ns.IsSecret(value)) then
        return nil
    end
    return value
end

function ns.RequestGuildRoster()
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        pcall(C_GuildInfo.GuildRoster)
    end
end

function ns.StartRosterMonitoring()
    ns.RequestGuildRoster()
    if not rosterTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
        rosterTicker = C_Timer.NewTicker(30, ns.RequestGuildRoster)
    end
end

function ns.ScanGuildRoster()
    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then
        return
    end

    local rows = {}
    local current = {}
    local total = tonumber((GetNumGuildMembers())) or 0
    if total <= 0 then
        return
    end

    for index = 1, total do
        local values = { GetGuildRosterInfo(index) }
        if type(values[1]) == "table" then
            values = values[1]
        end

        local name = CleanRosterValue(values[1])
        local levelValue = CleanRosterValue(values[4])
        local class = CleanRosterValue(values[5])
        local guid = CleanRosterValue(values[17])
        local level = tonumber(levelValue)
        if type(name) == "string" and name ~= "" and level then
            rows[#rows + 1] = {
                name = name,
                nameKey = name:lower(),
                class = type(class) == "string" and class or "",
                level = level,
                guid = type(guid) == "string" and guid ~= "" and guid or nil,
            }
        end
    end

    -- Refresh explicit GUID/name relationships before resolving rows whose GUID
    -- is temporarily unavailable. This makes rename handling independent of
    -- roster order and prevents stale names from impersonating another member.
    for _, row in ipairs(rows) do
        if row.guid then
            local previousNameKey = nameByGuid[row.guid]
            if previousNameKey and previousNameKey ~= row.nameKey
                and guidByName[previousNameKey] == row.guid then
                guidByName[previousNameKey] = nil
            end
            guidByName[row.nameKey] = row.guid
            nameByGuid[row.guid] = row.nameKey
        end
    end

    local validGuidCount = 0
    for _, row in ipairs(rows) do
        local stableGuid = row.guid or guidByName[row.nameKey]
        if stableGuid then
            if not current[stableGuid] then
                validGuidCount = validGuidCount + 1
            end
            current[stableGuid] = {
                name = row.name,
                class = row.class,
                level = row.level,
                guid = stableGuid,
            }
        end
    end

    -- Do not establish a partial login baseline. Otherwise the next complete
    -- roster response would misclassify existing offline members as live joins.
    if not rosterSnapshot then
        if validGuidCount < total then
            return
        end
        seenMemberGuids = {}
        for _, member in pairs(current) do
            seenMemberGuids[member.guid] = true
        end
        rosterSnapshot = current
        return
    end

    if rosterSnapshot then
        for key, member in pairs(current) do
            local previous = rosterSnapshot[key]
            if previous then
                if ns.db and ns.db.enableCongrats and member.level > previous.level then
                    ns.TriggerGuildGreeting("level", member.name, false, nil, member.class, member.level)
                elseif member.level < previous.level then
                    -- Keep a session high-water mark so stale roster data cannot
                    -- make the same level look new again on a later refresh.
                    member.level = previous.level
                end
            end

            if member.guid and not seenMemberGuids[member.guid] then
                -- Mark first even when welcomes are disabled, so enabling the
                -- section later cannot replay an old join from this session.
                seenMemberGuids[member.guid] = true
                if ns.db and ns.db.enableWelcome then
                    ns.TriggerGuildGreeting("welcome", member.name, false, nil, member.class, member.level)
                end
            end
        end

        -- A transiently missing roster entry must not erase its high-water mark.
        for key, previous in pairs(rosterSnapshot) do
            if not current[key] then
                current[key] = previous
            end
        end
    end

    rosterSnapshot = current
end

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
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        local ok, err = pcall(ns.InitializeSavedVariables)
        if not ok then
            print("[Nice Guild] DB Init error: " .. tostring(err))
        end
        pcall(ns.RegisterSettingsPanel)
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ns.StartRosterMonitoring()
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
        ns.ScanGuildRoster()
        if type(ns.RefreshConfigUI) == "function" then
            ns.RefreshConfigUI()
        end
    end
end)
