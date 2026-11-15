from pathlib import Path

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


WOW_UI_STUBS = r'''
CREATED_FONT_STRINGS = {}
CREATED_FRAMES = {}
UISpecialFrames = {}
Settings = nil

local function new_font_string()
    local fs = { text = nil, color = nil }
    function fs:SetPoint(...) end
    function fs:SetText(value) self.text = value end
    function fs:SetTextColor(...) self.color = {...} end
    table.insert(CREATED_FONT_STRINGS, fs)
    return fs
end

local frame_methods = {}
function frame_methods:SetSize(...) end
function frame_methods:SetPoint(...) end
function frame_methods:SetFrameStrata(...) end
function frame_methods:SetMovable(...) end
function frame_methods:EnableMouse(...) end
function frame_methods:RegisterForDrag(...) end
function frame_methods:SetClampedToScreen(...) end
function frame_methods:SetBackdrop(...) end
function frame_methods:SetBackdropColor(...) end
function frame_methods:SetBackdropBorderColor(...) end
function frame_methods:SetAutoFocus(...) end
function frame_methods:SetFontObject(...) end
function frame_methods:SetTextInsets(...) end
function frame_methods:SetMaxLetters(...) end
function frame_methods:RegisterEvent(...) end
function frame_methods:StartMoving(...) self.moving = true end
function frame_methods:StopMovingOrSizing(...) self.moving = false end
function frame_methods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function frame_methods:SetScript(event, callback) self.scripts[event] = callback end
function frame_methods:CreateFontString(...) return new_font_string() end
function frame_methods:CreateTexture(...)
    local texture = {}
    function texture:SetSize(...) end
    function texture:SetPoint(...) end
    function texture:SetTexture(...) end
    return texture
end
function frame_methods:SetText(value)
    self.textValue = value
    if self.Text then self.Text:SetText(value) end
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function frame_methods:GetText() return self.textValue or "" end
function frame_methods:Insert(value)
    self.textValue = (self.textValue or "") .. value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
end
function frame_methods:SimulateUserText(value)
    self.textValue = value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
end
function frame_methods:HasFocus() return self.hasFocus == true end
function frame_methods:SetFocus() self.hasFocus = true end
function frame_methods:ClearFocus() self.hasFocus = false end
function frame_methods:SetChecked(value) self.checked = not not value end
function frame_methods:GetChecked() return self.checked end
function frame_methods:Disable() self.enabled = false end
function frame_methods:Enable() self.enabled = true end
function frame_methods:Hide() self.shown = false end
function frame_methods:Show() self.shown = true end
function frame_methods:IsShown() return self.shown == true end

function NewFrame(frame_type, template)
    local frame = {
        frameType = frame_type,
        template = template,
        scripts = {},
        enabled = true,
        shown = false,
        textValue = "",
    }
    setmetatable(frame, { __index = frame_methods })
    if template == "UIPanelButtonTemplate" or template == "UICheckButtonTemplate" then
        frame.Text = new_font_string()
    end
    table.insert(CREATED_FRAMES, frame)
    return frame
end

function CreateFrame(frame_type, name, parent, template)
    local frame = NewFrame(frame_type, template)
    frame.name = name
    return frame
end

UIParent = NewFrame("Frame", nil)

function InCombatLockdown() return false end

function HasFontStringText(expected)
    for _, fs in ipairs(CREATED_FONT_STRINGS) do
        if fs.text == expected then return true end
    end
    return false
end

function FindFrameByName(name)
    for _, frame in ipairs(CREATED_FRAMES) do
        if frame.name == name then return frame end
    end
    return nil
end
'''


def make_runtime(with_ui=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    if with_ui:
        lua.execute(WOW_UI_STUBS)
    return lua


def load_addon_file(lua, relative_path, namespace):
    source = (ROOT / "niceguild" / relative_path).read_text(encoding="utf-8")
    return lua.execute(source, "niceguild", namespace)
