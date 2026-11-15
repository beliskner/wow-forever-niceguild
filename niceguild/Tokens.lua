local addonName, ns = ...

ns.RAID_SYMBOLS = {
    { index = 1, tag = "{star}", rt = "{rt1}", label = "Star" },
    { index = 2, tag = "{circle}", rt = "{rt2}", label = "Circle" },
    { index = 3, tag = "{diamond}", rt = "{rt3}", label = "Diamond" },
    { index = 4, tag = "{triangle}", rt = "{rt4}", label = "Triangle" },
    { index = 5, tag = "{moon}", rt = "{rt5}", label = "Moon" },
    { index = 6, tag = "{square}", rt = "{rt6}", label = "Square" },
    { index = 7, tag = "{cross}", rt = "{rt7}", label = "Cross" },
    { index = 8, tag = "{skull}", rt = "{rt8}", label = "Skull" },
}

-- Formatting tokens with worst-case character weights used by the chat-limit preview
ns.FORMAT_TOKENS = {
    { tag = "{{name}}", weight = 25, desc = "Member name in lowercase" },
    { tag = "{{Name}}", weight = 25, desc = "Member name, first letters capitalized" },
    { tag = "{{NAME}}", weight = 25, desc = "Member name in UPPERCASE" },
    { tag = "{{class}}", weight = 7, desc = "Class in lowercase" },
    { tag = "{{Class}}", weight = 7, desc = "Class capitalized" },
    { tag = "{{CLASS}}", weight = 7, desc = "Class in UPPERCASE" },
    { tag = "{{lvl}}", weight = 2, desc = "Member level" },
}

function ns.GetPotentialLength(text)
    if type(text) ~= "string" then return 0 end
    local simulated = text:gsub("{{[Nn][Aa][Mm][Ee]}}", string.rep("N", 25))
    simulated = simulated:gsub("{{[Cc][Ll][Aa][Ss][Ss]}}", string.rep("C", 7))
    simulated = simulated:gsub("{{[Ll][Vv][Ll]}}", string.rep("L", 2))
    return #simulated
end

function ns.GetRaidIconTexturePath(index)
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. tostring(index)
end

function ns.NormalizeRaidSymbolsForChat(text)
    if not text then return "" end
    local map = { ["{rt1}"] = "{star}", ["{rt2}"] = "{circle}", ["{rt3}"] = "{diamond}", ["{rt4}"] = "{triangle}", ["{rt5}"] = "{moon}", ["{rt6}"] = "{square}", ["{rt7}"] = "{cross}", ["{rt8}"] = "{skull}", ["{coin}"] = "{diamond}" }
    for rt, tag in pairs(map) do
        text = text:gsub(rt, tag)
    end
    text = text:gsub("%{(%a+)%}", function(inner)
        local lower = inner:lower()
        for _, info in ipairs(ns.RAID_SYMBOLS) do
            if info.tag == "{" .. lower .. "}" then
                return info.tag
            end
        end
        return "{" .. inner .. "}"
    end)
    text = text:gsub("%{%{([%w_]+)%}%}", "{%1}")
    return text
end

function ns.FormatTemplate(template, memberName, memberClass, memberLevel)
    if not template then return "" end
    local formatted = template

    -- WoW: Forever names are "Primary Secondary"; never strip part of a name here.
    memberName = memberName or "Adventurer"
    memberClass = memberClass or ""
    memberLevel = memberLevel or ""

    local nameUpper = memberName:upper()
    local nameLower = memberName:lower()
    local classUpper = memberClass:upper()
    local classLower = memberClass:lower()
    local lvlStr = tostring(memberLevel)

    formatted = formatted:gsub("{{NAME}}", nameUpper)
    formatted = formatted:gsub("{{Name}}", memberName)
    formatted = formatted:gsub("{{name}}", nameLower)

    formatted = formatted:gsub("{{CLASS}}", classUpper)
    formatted = formatted:gsub("{{Class}}", memberClass)
    formatted = formatted:gsub("{{class}}", classLower)

    formatted = formatted:gsub("{{lvl}}", lvlStr)
    formatted = formatted:gsub("{{LVL}}", lvlStr)

    formatted = ns.NormalizeRaidSymbolsForChat(formatted)
    return formatted
end

function ns.RenderRaidSymbolsForPreview(text, iconSize)
    iconSize = iconSize or 14
    local tagMap = {
        ["{star}"] = 1, ["{circle}"] = 2, ["{diamond}"] = 3, ["{triangle}"] = 4,
        ["{moon}"] = 5, ["{square}"] = 6, ["{cross}"] = 7, ["{skull}"] = 8
    }
    for tag, idx in pairs(tagMap) do
        local texPath = ns.GetRaidIconTexturePath(idx)
        local markup = string.format("|T%s:%d:%d:0:0|t", texPath, iconSize, iconSize)
        text = text:gsub(tag:gsub("([%(%[%]%.%*%+%-%?%^%$%%])", "%%%1"), markup)
    end
    return text
end

function ns.GetSafePlayerName()
    return ns.GetSelfFullName()
end

--------------------------------------------------------------------------------
-- Self identity: WoW: Forever returns only the primary name from UnitName(),
-- so the full "Primary Secondary" name is resolved from the guild roster and
-- cached per character in SavedVariables.
--------------------------------------------------------------------------------

local function CleanName(value)
    if value == nil then
        return nil
    end
    local secret = false
    if type(ns.IsSecret) == "function" then
        secret = ns.IsSecret(value)
    elseif type(issecretvalue) == "function" then
        secret = issecretvalue(value)
    end
    if secret or type(value) ~= "string" then
        return nil
    end
    local trimmed = value:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil
    end
    return trimmed
end

function ns.GetSelfPrimaryName()
    if type(UnitName) ~= "function" then
        return nil
    end
    return CleanName(UnitName("player"))
end

local function SelfCacheKey()
    if type(UnitGUID) == "function" then
        local guid = CleanName(UnitGUID("player"))
        if guid then
            return guid
        end
    end
    local primary = ns.GetSelfPrimaryName()
    if primary then
        return "name:" .. primary:lower()
    end
    return nil
end

function ns.SetSelfFullName(fullName, source)
    local clean = CleanName(fullName)
    if not clean then
        return false
    end
    ns.selfFullName = clean
    ns.selfNameSource = source or "GuildRoster"

    if ns.db then
        if type(ns.db.selfNameCache) ~= "table" then
            ns.db.selfNameCache = {}
        end
        local key = SelfCacheKey()
        if key then
            ns.db.selfNameCache[key] = clean
        end
    end
    return true
end

function ns.GetSelfFullName()
    if type(ns.selfFullName) == "string" and ns.selfFullName ~= "" then
        return ns.selfFullName
    end

    local primary = ns.GetSelfPrimaryName()

    -- 1. Per-character cache, so previews are correct before the roster arrives.
    if ns.db and type(ns.db.selfNameCache) == "table" then
        local key = SelfCacheKey()
        local cached = key and CleanName(ns.db.selfNameCache[key]) or nil
        if cached then
            if not primary or cached:lower():sub(1, #primary) == primary:lower() then
                ns.selfFullName = cached
                ns.selfNameSource = "SavedCache"
                return cached
            end
        end
    end

    -- 2. UnitFullName may already carry both parts on some builds.
    if type(UnitFullName) == "function" then
        local full = CleanName((UnitFullName("player")))
        if full and full:find(" ") then
            ns.selfFullName = full
            ns.selfNameSource = "UnitFullName"
            return full
        end
    end

    -- 3. Primary name only until GUILD_ROSTER_UPDATE resolves the full name.
    ns.selfNameSource = "UnitName"
    return primary or "Adventurer"
end

function ns.GetSelfInfo()
    local class = type(UnitClass) == "function" and CleanName((UnitClass("player"))) or nil
    local level = type(UnitLevel) == "function" and UnitLevel("player") or nil
    if level ~= nil and type(ns.IsSecret) == "function" and ns.IsSecret(level) then
        level = nil
    end
    return {
        name = ns.GetSelfFullName(),
        class = class or "",
        level = level or "",
    }
end

function ns.IsSelf(rawName)
    local target = CleanName(rawName)
    if not target then
        return false
    end
    local targetLower = target:lower()

    local fullSelf = ns.GetSelfFullName()
    if fullSelf and targetLower == fullSelf:lower() then
        return true
    end

    local primarySelf = ns.GetSelfPrimaryName()
    if primarySelf and targetLower == primarySelf:lower() then
        return true
    end

    return false
end

-- Resolves "Primary Secondary" by matching the player GUID against the roster,
-- with a guarded primary-name + class + level fallback.
function ns.ResolveSelfNameFromRoster()
    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then
        return false
    end

    local total = tonumber((GetNumGuildMembers())) or 0
    if total <= 0 then
        return false
    end

    local selfGuid = type(UnitGUID) == "function" and CleanName((UnitGUID("player"))) or nil
    local primary = ns.GetSelfPrimaryName()
    local primaryLower = primary and primary:lower() or nil
    local selfClass = type(UnitClass) == "function" and CleanName((UnitClass("player"))) or nil
    local selfLevel = type(UnitLevel) == "function" and UnitLevel("player") or nil
    if selfLevel ~= nil and type(ns.IsSecret) == "function" and ns.IsSecret(selfLevel) then
        selfLevel = nil
    end

    for index = 1, total do
        local values = { GetGuildRosterInfo(index) }
        if type(values[1]) == "table" then
            values = values[1]
        end

        local clean = CleanName(values[1])
        local rosterLevel = values[4]
        local rosterClass = values[5]
        local rosterGuid = values[17]

        if clean then
            local matchesGuid = selfGuid ~= nil and rosterGuid ~= nil and rosterGuid == selfGuid
            local matchesFallback = false
            if not matchesGuid and primaryLower then
                local rosterLower = clean:lower()
                local nameMatches = rosterLower == primaryLower
                    or rosterLower:sub(1, #primaryLower + 1) == primaryLower .. " "
                local classMatches = (not selfClass) or selfClass == "" or rosterClass == selfClass
                local levelMatches = (not selfLevel) or rosterLevel == selfLevel
                matchesFallback = nameMatches and classMatches and levelMatches
            end

            if matchesGuid or matchesFallback then
                return ns.SetSelfFullName(clean, matchesGuid and "GuildRoster(GUID)" or "GuildRoster(Name+Class+Lvl)")
            end
        end
    end

    return false
end
