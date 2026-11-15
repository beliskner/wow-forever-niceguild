local addonName, ns = ...

function ns.CreateStyledEditBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetTextInsets(8, 8, 4, 4)
    box:SetMaxLetters(200)
    box:SetBackdrop({
        bgFile = "Interface\ChatFrame\ChatFrameBackground",
        edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
    box:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return box
end
