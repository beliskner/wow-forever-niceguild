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

    if ns.db and ns.db.useShortName and memberName then
        memberName = memberName:match("^(.-)%-") or memberName
    end

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
    local name = UnitName("player")
    if ns.IsSecret(name) then return "Adventurer" end
    return name
end
