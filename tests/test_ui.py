import unittest

from lua_test_harness import load_addon_file, make_runtime


class TabSectionTests(unittest.TestCase):
    def make_namespace(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            ns.db = { congratsTabs = {}, welcomeTabs = {} }
            for i = 1, 10 do
                ns.db.congratsTabs[i] = { enabled = i == 1, text = i == 1 and " Hello " or "" }
                ns.db.welcomeTabs[i] = { enabled = i == 1, text = i == 1 and " Welcome " or "" }
            end
            ns.MAX_CHAT_CHARACTERS = 255
            ns.refreshCalls = 0
            function ns.RefreshConfigUI() ns.refreshCalls = ns.refreshCalls + 1 end
            function ns.GetSafePlayerName() return "Tester" end
            function ns.GetPotentialLength(text) return string.len(text or "") end
            function ns.FormatTemplate(text, name) return text end
            function ns.RenderRaidSymbolsForPreview(text, size) return text end
            ns.triggerArgs = nil
            function ns.TriggerGuildGreeting(...) ns.triggerArgs = {...} end
            function ns.SaveInputsFromUI() end
            function ns.CreateStyledEditBox(parent, width, height)
                return NewFrame("EditBox", "BackdropTemplate")
            end
            '''
        )
        load_addon_file(lua, "UI_Tabs.lua", ns)
        return lua, ns

    def test_tab_visuals_color_the_template_button_text_region(self):
        lua, ns = self.make_namespace()

        section = ns.BuildTabSection(lua.globals().UIParent, "level", -52)

        self.assertAlmostEqual(section.tabs[1].Text.color[1], 0.2)
        self.assertAlmostEqual(section.tabs[1].Text.color[2], 1.0)
        self.assertAlmostEqual(section.tabs[2].Text.color[1], 0.5)

    def test_programmatic_text_refresh_does_not_write_back_or_recurse(self):
        lua, ns = self.make_namespace()

        section = ns.BuildTabSection(lua.globals().UIParent, "level", -52)

        self.assertEqual(ns.refreshCalls, 0)
        section.editBox.SimulateUserText(section.editBox, "Changed by user")
        self.assertEqual(ns.db.congratsTabs[1].text, "Changed by user")
        self.assertEqual(ns.refreshCalls, 1)

    def test_switching_tabs_while_focused_loads_the_new_tab_before_editing(self):
        lua, ns = self.make_namespace()
        ns.db.congratsTabs[2].text = "Second tab"
        section = ns.BuildTabSection(lua.globals().UIParent, "level", -52)
        section.editBox.SetFocus(section.editBox)

        section.SelectTab(section, 2)
        self.assertEqual(section.editBox.GetText(section.editBox), "Second tab")
        section.editBox.SimulateUserText(section.editBox, "Edited second tab")

        self.assertEqual(ns.db.congratsTabs[1].text, " Hello ")
        self.assertEqual(ns.db.congratsTabs[2].text, "Edited second tab")

    def test_switching_tabs_refreshes_the_preview(self):
        lua, ns = self.make_namespace()
        section = ns.BuildTabSection(lua.globals().UIParent, "level", -52)
        refreshes_before_click = ns.refreshCalls

        section.SelectTab(section, 2)

        self.assertEqual(ns.refreshCalls, refreshes_before_click + 1)

    def test_test_button_uses_the_active_tab_instead_of_random_selection(self):
        lua, ns = self.make_namespace()
        section = ns.BuildTabSection(lua.globals().UIParent, "level", -52)

        section.testBtn.scripts.OnClick()

        self.assertEqual(ns.triggerArgs[1], "level")
        self.assertTrue(ns.triggerArgs[3])
        self.assertEqual(ns.triggerArgs[4], " Hello ")


MAIN_FRAME_SETUP = r'''
NiceGuildDB = {}
ns.VERSION = "1.4.1"
ns.db = { enableCongrats = false, enableWelcome = false }
ns.RAID_SYMBOLS = {}
ns.FORMAT_TOKENS = { { tag = "{{Name}}", weight = 25, desc = "test token" } }
ns.MAX_CHAT_CHARACTERS = 255
function ns.RunOutOfCombat(callback) callback() end
function ns.Print(...) end
function ns.GetSafePlayerName() return "Tester" end
function ns.GetSelfInfo() return { name = "Tester", class = "Mage", level = 60 } end
function ns.FormatTemplate(text, name) return text end
function ns.RenderRaidSymbolsForPreview(text, size) return text end
function ns.GetPotentialLength(text) return string.len(text or "") end
function ns.CreateSectionPanel(parent, height)
    local panel = NewFrame("Frame", nil)
    panel.height = height
    return panel
end
function ns.BuildTabSection(parent, kind)
    local section = NewFrame("Frame", nil)
    section.kind = kind
    section.editBox = NewFrame("EditBox", nil)
    section.editBox.textValue = kind
    section.previewText = parent:CreateFontString()
    section.previewLabel = section.previewText
    section.countText = parent:CreateFontString()
    section.warnText = parent:CreateFontString()
    function section:SelectTab(...) end
    function section:RefreshTabContent(...) end
    function section:UpdateTabVisuals(...) end
    function section:UpdatePreview(...) end
    return section
end
'''


class WidgetIntegrationTests(unittest.TestCase):
    def make_section(self, kind="level"):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            ns.db = { congratsTabs = {}, welcomeTabs = {} }
            for i = 1, 10 do
                ns.db.congratsTabs[i] = { enabled = false, text = "" }
                ns.db.welcomeTabs[i] = { enabled = false, text = "" }
            end
            ns.db.congratsTabs[3] = { enabled = true, text = "Third" }
            ns.MAX_CHAT_CHARACTERS = 255
            ns.refreshCalls = 0
            function ns.RefreshConfigUI() ns.refreshCalls = ns.refreshCalls + 1 end
            function ns.GetSafePlayerName() return "Tester" end
            function ns.GetPotentialLength(text) return string.len(text or "") end
            function ns.FormatTemplate(text, name) return text end
            function ns.RenderRaidSymbolsForPreview(text, size) return text end
            function ns.TriggerGuildGreeting(...) end
            function ns.SaveInputsFromUI() end
            '''
        )
        load_addon_file(lua, "UI_Widgets.lua", ns)
        load_addon_file(lua, "UI_Tabs.lua", ns)
        return lua, ns, ns.BuildTabSection(lua.globals().UIParent, kind)

    def test_real_widgets_build_ten_tab_buttons_with_the_first_selected(self):
        lua, ns, section = self.make_section()

        self.assertEqual(len(section.tabs), 10)
        self.assertEqual(section.activeTab, 1)
        self.assertFalse(section.tabs[1].enabled)
        self.assertTrue(section.tabs[3].enabled)

    def test_focusing_the_editor_keeps_the_widget_highlight_and_tracks_the_active_box(self):
        lua, ns, section = self.make_section()

        section.editBox.scripts["OnEditFocusGained"](section.editBox)

        same_box = lua.eval("function(a, b) return a == b end")(section.editBox, ns.activeEditBox)
        self.assertTrue(same_box)
        self.assertAlmostEqual(section.editorContainer.borderColor[1], 0.95)

    def test_selecting_an_enabled_tab_loads_its_message_into_the_editor(self):
        lua, ns, section = self.make_section()

        section.SelectTab(section, 3)

        self.assertEqual(section.activeTab, 3)
        self.assertEqual(section.editBox.GetText(section.editBox), "Third")
        self.assertTrue(section.tabToggle.checked)

    def test_preview_expands_class_and_level_with_the_self_identity(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            ns.db = { congratsTabs = {}, welcomeTabs = {} }
            for i = 1, 10 do
                ns.db.congratsTabs[i] = { enabled = false, text = "" }
                ns.db.welcomeTabs[i] = { enabled = false, text = "" }
            end
            ns.db.congratsTabs[2] = { enabled = true, text = "{{Name}} the {{Class}} hit {{lvl}}" }
            ns.MAX_CHAT_CHARACTERS = 255
            ns.GetSafePlayerName = nil
            function ns.GetSelfInfo() return { name = "Windfury Wim", class = "Mage", level = 60 } end
            function ns.GetPotentialLength(text) return string.len(text or "") end
            function ns.FormatTemplate(template, name, class, level)
                return (template:gsub("{{Name}}", name):gsub("{{Class}}", class):gsub("{{lvl}}", tostring(level)))
            end
            function ns.RenderRaidSymbolsForPreview(text, size) return text end
            function ns.RefreshConfigUI() end
            function ns.TriggerGuildGreeting(...) end
            function ns.SaveInputsFromUI() end
            '''
        )
        load_addon_file(lua, "UI_Widgets.lua", ns)
        load_addon_file(lua, "UI_Tabs.lua", ns)

        section = ns.BuildTabSection(lua.globals().UIParent, "level")
        section.SelectTab(section, 2)

        self.assertEqual(section.previewText.text, "Windfury Wim the Mage hit 60")

    def test_test_tab_passes_class_and_level_to_the_sender(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            ns.db = { congratsTabs = {}, welcomeTabs = {} }
            for i = 1, 10 do
                ns.db.congratsTabs[i] = { enabled = false, text = "" }
                ns.db.welcomeTabs[i] = { enabled = false, text = "" }
            end
            ns.db.congratsTabs[1] = { enabled = true, text = "one" }
            ns.MAX_CHAT_CHARACTERS = 255
            function ns.GetSelfInfo() return { name = "Windfury Wim", class = "Mage", level = 60 } end
            function ns.GetPotentialLength(text) return string.len(text or "") end
            function ns.FormatTemplate(text) return text end
            function ns.RenderRaidSymbolsForPreview(text, size) return text end
            function ns.RefreshConfigUI() end
            function ns.SaveInputsFromUI() end
            ns.triggerArgs = nil
            function ns.TriggerGuildGreeting(...) ns.triggerArgs = {...} end
            '''
        )
        load_addon_file(lua, "UI_Widgets.lua", ns)
        load_addon_file(lua, "UI_Tabs.lua", ns)

        section = ns.BuildTabSection(lua.globals().UIParent, "level")
        section.testBtn.scripts.OnClick()

        self.assertEqual(ns.triggerArgs[1], "level")
        self.assertEqual(ns.triggerArgs[2], "Windfury Wim")
        self.assertEqual(ns.triggerArgs[5], "Mage")
        self.assertEqual(ns.triggerArgs[6], 60)


class MainWindowTests(unittest.TestCase):
    def test_main_window_restores_the_three_section_design(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(MAIN_FRAME_SETUP)
        load_addon_file(lua, "UI_Main.lua", ns)

        ns.ToggleConfig()
        frame = lua.globals().FindFrameByName("NiceGuildConfigFrame")

        self.assertEqual(frame.width, 580)
        self.assertEqual(frame.height, 650)
        self.assertTrue(lua.globals().HasFontStringText("1. Level-Up Congratulations"))
        self.assertTrue(lua.globals().HasFontStringText("2. New Member Welcome"))
        self.assertTrue(lua.globals().HasFontStringText("3. Utilities, Formatting Tokens & Raid Symbols"))

    def test_master_toggles_live_inside_their_own_sections_and_start_off(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(MAIN_FRAME_SETUP)
        load_addon_file(lua, "UI_Main.lua", ns)

        ns.ToggleConfig()
        frame = lua.globals().FindFrameByName("NiceGuildConfigFrame")
        same = lua.eval("function(a, b) return a == b end")

        self.assertTrue(same(frame.congratsSection.masterCheck, frame.congratsCheck))
        self.assertTrue(same(frame.welcomeSection.masterCheck, frame.welcomeCheck))
        self.assertFalse(frame.congratsSection.masterCheck.checked)
        self.assertFalse(frame.welcomeSection.masterCheck.checked)

    def test_refresh_renders_formatting_token_previews(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(MAIN_FRAME_SETUP)
        lua.execute(
            r'''
            function ns.FormatTemplate(text, name)
                return "value-of-" .. text
            end
            '''
        )
        load_addon_file(lua, "UI_Main.lua", ns)

        ns.ToggleConfig()

        self.assertTrue(lua.globals().HasFontStringText("|cffffffffvalue-of-{{Name}}|r |cff888888(25)|r"))

    def test_drag_started_during_combat_is_not_replayed_after_combat(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(MAIN_FRAME_SETUP)
        lua.execute(
            r'''
            combat = false
            pending = {}
            function InCombatLockdown() return combat end
            function ns.RunOutOfCombat(callback)
                if combat then table.insert(pending, callback) else callback() end
            end
            '''
        )
        load_addon_file(lua, "UI_Main.lua", ns)
        ns.ToggleConfig()
        frame = lua.globals().FindFrameByName("NiceGuildConfigFrame")

        lua.globals().combat = True
        frame.scripts.OnDragStart(frame)
        frame.scripts.OnDragStop(frame)
        lua.globals().combat = False
        lua.execute("for _, callback in ipairs(pending) do callback() end")

        self.assertFalse(frame.moving)


if __name__ == "__main__":
    unittest.main()
