local addonName, ns = ...

local EDITOR_BORDER = { 0.45, 0.45, 0.52, 1 }

function ns.CreateSectionPanel(parent, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetHeight(height)
    panel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.09, 0.09, 0.12, 0.78)
    panel:SetBackdropBorderColor(0.32, 0.32, 0.38, 0.95)
    return panel
end

function ns.CreateMultilineMacroBox(parent, width, height)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(width, height)
    container:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    container:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    container:SetBackdropBorderColor(unpack(EDITOR_BORDER))

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 6)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(width - 32)
    editBox:SetMaxLetters(500)
    editBox:SetTextInsets(2, 2, 2, 2)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", function()
        container:SetBackdropBorderColor(0.95, 0.78, 0.25, 1)
    end)
    editBox:SetScript("OnEditFocusLost", function()
        container:SetBackdropBorderColor(unpack(EDITOR_BORDER))
    end)
    editBox:SetScript("OnCursorChanged", function(self, _, y, _, cursorHeight)
        local offset = -y
        local viewHeight = scrollFrame:GetHeight()
        local currentScroll = scrollFrame:GetVerticalScroll()
        if offset < currentScroll then
            scrollFrame:SetVerticalScroll(offset)
        elseif (offset + cursorHeight) > (currentScroll + viewHeight) then
            scrollFrame:SetVerticalScroll(offset + cursorHeight - viewHeight)
        end
    end)

    scrollFrame:SetScrollChild(editBox)
    container:EnableMouse(true)
    container:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    container.editBox = editBox
    container.scrollFrame = scrollFrame
    return container, editBox
end

function ns.CreateContainedPreviewBox(parent, width, height)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(width, height)
    container:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    container:SetBackdropColor(0.11, 0.14, 0.19, 0.85)
    container:SetBackdropBorderColor(0.30, 0.48, 0.68, 0.95)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 8, -7)
    text:SetPoint("BOTTOMRIGHT", -8, 7)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetNonSpaceWrap(true)

    container.text = text
    return container, text
end

-- Kept for compatibility with focused tests and external callers.
function ns.CreateStyledEditBox(parent, width, height)
    local _, editBox = ns.CreateMultilineMacroBox(parent, width, height)
    return editBox
end
