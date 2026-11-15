local addonName, ns = ...

ns.addonName = addonName
ns.VERSION = "1.5.0"

-- Secure Print helper
function ns.Print(...)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffcc[Nice Guild]|r " .. tostring(...))
    end
end

-- Secret value guard for WoW: Forever modern API security
function ns.IsSecret(val)
    if type(issecretvalue) == "function" then
        return issecretvalue(val)
    end
    return false
end

-- Combat lockdown queue helper
local pendingCombatCalls = {}
function ns.RunOutOfCombat(callback)
    if type(callback) ~= "function" then return end
    if not InCombatLockdown() then
        pcall(callback)
    else
        table.insert(pendingCombatCalls, callback)
    end
end

local combatEventFrame = CreateFrame("Frame")
combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEventFrame:SetScript("OnEvent", function()
    while #pendingCombatCalls > 0 do
        local cb = table.remove(pendingCombatCalls, 1)
        pcall(cb)
    end
end)
