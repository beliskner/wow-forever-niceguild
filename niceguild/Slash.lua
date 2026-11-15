local addonName, ns = ...

SLASH_NICEGUILD1 = "/niceguild"
SLASH_NICEGUILD2 = "/ng"

SlashCmdList["NICEGUILD"] = function(msg)
    if not msg then msg = "" end
    msg = msg:trim and msg:trim() or msg:match("^%s*(.-)%s*$")

    local cmd, sub, val = msg:match("^(%S+)%s*(%S*)%s*(.*)$")
    if not cmd or cmd == "" then
        ns.ToggleConfig()
        return
    end

    cmd = cmd:lower()
    if cmd == "config" or cmd == "options" then
        ns.ToggleConfig()
    elseif cmd == "help" then
        ns.Print("Commands:")
        ns.Print("  /niceguild - Open configuration window")
        ns.Print("  /niceguild test <level|welcome> - Test preview message locally")
        ns.Print("  /niceguild icons - Show raid symbol reference")
        ns.Print("  /niceguild status - Check addon status and interface version")
    elseif cmd == "icons" then
        ns.Print("Raid Symbols & Tags:")
        for _, info in ipairs(ns.RAID_SYMBOLS) do
            local tex = ns.GetRaidIconTexturePath(info.index)
            ns.Print(string.format("  |T%s:14:14:0:0|t %s or %s (%s)", tex, info.tag, info.rt, info.label))
        end
    elseif cmd == "status" then
        local _, _, _, tocVersion = GetBuildInfo()
        ns.Print("Status: Active | Version: 1.4.0 | Interface TOC: " .. tostring(tocVersion))
    elseif cmd == "test" then
        local kind = sub:lower()
        if kind == "level" or kind == "congrats" then
            local sample = ns.GetSafePlayerName() or "Thrall"
            ns.TriggerGuildGreeting("level", sample, true)
        elseif kind == "welcome" then
            local sample = ns.GetSafePlayerName() or "Thrall"
            ns.TriggerGuildGreeting("welcome", sample, true)
        else
            ns.Print("Usage: /niceguild test level or /niceguild test welcome")
        end
    else
        ns.ToggleConfig()
    end
end
