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
            ns.refreshCalls = 0
            function ns.RefreshConfigUI() ns.refreshCalls = ns.refreshCalls + 1 end
            function ns.GetSafePlayerName() return "Tester" end
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


class MainWindowTests(unittest.TestCase):
    def test_welcome_preview_uses_string_concatenation(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            NiceGuildDB = {}
            ns.VERSION = "1.4.1"
            ns.db = { useShortName = true }
            ns.RAID_SYMBOLS = {}
            function ns.RunOutOfCombat(callback) callback() end
            function ns.Print(...) end
            function ns.GetSafePlayerName() return "Tester" end
            function ns.FormatTemplate(text, name) return text end
            function ns.RenderRaidSymbolsForPreview(text, size) return "rendered" end
            function ns.BuildTabSection(parent, kind, offset)
                local section = NewFrame("Frame", nil)
                section.editBox = NewFrame("EditBox", nil)
                section.editBox.textValue = kind
                section.previewLabel = parent:CreateFontString()
                function section:SelectTab(...) end
                function section:RefreshTabContent(...) end
                return section
            end
            '''
        )
        load_addon_file(lua, "UI_Main.lua", ns)

        ns.ToggleConfig()

        self.assertTrue(lua.globals().HasFontStringText("Preview: rendered"))

    def test_drag_started_during_combat_is_not_replayed_after_combat(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            NiceGuildDB = {}
            ns.VERSION = "1.4.1"
            combat = false
            pending = {}
            function InCombatLockdown() return combat end
            ns.db = { useShortName = true }
            ns.RAID_SYMBOLS = {}
            function ns.RunOutOfCombat(callback)
                if combat then table.insert(pending, callback) else callback() end
            end
            function ns.Print(...) end
            function ns.GetSafePlayerName() return "Tester" end
            function ns.FormatTemplate(text, name) return text end
            function ns.RenderRaidSymbolsForPreview(text, size) return text end
            function ns.BuildTabSection(parent, kind, offset)
                local section = NewFrame("Frame", nil)
                section.editBox = NewFrame("EditBox", nil)
                section.previewLabel = parent:CreateFontString()
                function section:SelectTab(...) end
                function section:RefreshTabContent(...) end
                return section
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
