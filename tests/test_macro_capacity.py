"""Regression coverage for 30-slot pools, equal odds, and the three-row editor."""
import unittest

from lua_test_harness import load_addon_file, make_runtime


class MacroCapacityTests(unittest.TestCase):
    def make_config(self, with_ui=False):
        lua = make_runtime(with_ui=with_ui)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute("NiceGuildDB = {}; function ns.FormatTemplate(text) return text end")
        load_addon_file(lua, "Config.lua", ns)
        return lua, ns

    def test_existing_ten_slots_survive_expansion_and_reload(self):
        lua, ns = self.make_config()
        lua.execute('''
            for _, kind in ipairs({"congratsTabs", "welcomeTabs"}) do
                NiceGuildDB[kind] = {}
                for i = 1, 10 do
                    NiceGuildDB[kind][i] = {text = "Saved " .. i, enabled = i % 2 == 0}
                end
            end
        ''')
        ns.InitializeSavedVariables()
        for pool in (ns.db.congratsTabs, ns.db.welcomeTabs):
            self.assertEqual(len(pool), 30)
            for index in range(1, 11):
                self.assertEqual(pool[index].text, f"Saved {index}")
                self.assertEqual(pool[index].enabled, index % 2 == 0)
            for index in range(11, 31):
                self.assertEqual(pool[index].text, "")
                self.assertFalse(pool[index].enabled)
            pool[30].text = "Last macro"
            pool[30].enabled = True
        ns.InitializeSavedVariables()
        for pool in (ns.db.congratsTabs, ns.db.welcomeTabs):
            self.assertEqual(pool[30].text, "Last macro")
            self.assertTrue(pool[30].enabled)

    def test_every_random_outcome_selects_one_distinct_macro_in_both_pools(self):
        lua, ns = self.make_config()
        # Build the requested fixture independently of normalization so a stale
        # selector limit fails as an assertion, not a missing-table error.
        lua.execute('''
            ns.db = {congratsTabs = {}, welcomeTabs = {}}
            for i = 1, 30 do
                ns.db.congratsTabs[i] = {text = "Grats " .. i, enabled = true}
                ns.db.welcomeTabs[i] = {text = "Welcome " .. i, enabled = true}
            end
            draw = 1
            function math.random(lower, upper)
                randomLower, randomUpper = lower, upper
                return draw
            end
        ''')
        for kind, prefix in (("level", "Grats"), ("welcome", "Welcome")):
            for draw in range(1, 31):
                lua.globals().draw = draw
                self.assertEqual(ns.PickRandomEnabledTab(kind, "Tester"), f"{prefix} {draw}")
                self.assertEqual((lua.globals().randomLower, lua.globals().randomUpper), (1, 30))

    def test_high_slots_use_only_eligible_macros_for_the_denominator(self):
        lua, ns = self.make_config()
        lua.execute('''
            ns.db = {congratsTabs = {}, welcomeTabs = {}}
            for _, pool in ipairs({ns.db.congratsTabs, ns.db.welcomeTabs}) do
                for i = 1, 30 do pool[i] = {text = "", enabled = false} end
                pool[11] = {text = "Eleventh", enabled = true}
                pool[21] = {text = "Twenty-first", enabled = true}
                pool[27] = {text = "Disabled", enabled = false}
                pool[28] = {text = "  \\n\\t ", enabled = true}
                pool[29] = {text = string.rep("x", 256), enabled = true}
                pool[30] = {text = "Thirtieth", enabled = true}
            end
            draw = 1
            function math.random(lower, upper)
                assert(lower == 1 and upper == 3, "expected three eligible macros")
                return draw
            end
        ''')
        for kind in ("level", "welcome"):
            for draw, expected in enumerate(("Eleventh", "Twenty-first", "Thirtieth"), 1):
                lua.globals().draw = draw
                self.assertEqual(ns.PickRandomEnabledTab(kind, "Tester"), expected)

    def test_both_editors_have_three_rows_of_ten_and_editable_last_slot(self):
        lua, ns = self.make_config(with_ui=True)
        ns.InitializeSavedVariables()
        lua.execute('''
            function ns.GetSafePlayerName() return "Tester" end
            function ns.RefreshConfigUI() end
            function ns.SaveInputsFromUI() end
            function ns.TriggerGuildGreeting(...) ns.triggerArgs = {...} end
        ''')
        load_addon_file(lua, "UI_Widgets.lua", ns)
        load_addon_file(lua, "UI_Tabs.lua", ns)
        for kind, pool in (("level", ns.db.congratsTabs), ("welcome", ns.db.welcomeTabs)):
            section = ns.BuildTabSection(lua.globals().UIParent, kind)
            self.assertEqual(len(section.tabs), 30)
            for row, first in enumerate((1, 11, 21)):
                button = section.tabs[first]
                self.assertEqual(button.point[1], "TOPLEFT")
                self.assertEqual(button.point[2], 0)
                self.assertEqual(button.point[3], (0, -22, -44)[row])
                for index in range(first, first + 10):
                    self.assertEqual(section.tabs[index].GetText(section.tabs[index]), str(index))
                    self.assertEqual((section.tabs[index].width, section.tabs[index].height), (29, 20))
            self.assertEqual(section.editorContainer.point[3], -84)
            section.tabs[30].scripts.OnClick()
            self.assertEqual(section.activeTab, 30)
            section.editBox.SimulateUserText(section.editBox, "Last slot edited")
            section.tabToggle.SetChecked(section.tabToggle, True)
            section.tabToggle.scripts.OnClick(section.tabToggle)
            self.assertEqual(pool[30].text, "Last slot edited")
            self.assertTrue(pool[30].enabled)
            section.testBtn.scripts.OnClick()
            self.assertEqual(ns.triggerArgs[4], "Last slot edited")
            section.SelectTab(section, 1)
            section.SelectTab(section, 30)
            self.assertEqual(section.editBox.GetText(section.editBox), "Last slot edited")
            self.assertEqual(section.previewText.text, "Last slot edited")


if __name__ == "__main__":
    unittest.main()
