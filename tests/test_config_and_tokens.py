import unittest

from lua_test_harness import load_addon_file, make_runtime


class SavedVariableTests(unittest.TestCase):
    def load_config(self, setup):
        lua = make_runtime()
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(setup)
        load_addon_file(lua, "Config.lua", ns)
        return lua, ns

    def test_legacy_single_templates_are_migrated(self):
        lua, ns = self.load_config(
            r'''
            NiceGuildDB = {
                enableCongrats = false,
                enableWelcome = true,
                congratsText = "Legacy grats {{name}}",
                welcomeText = "Legacy welcome {{name}}",
            }
            '''
        )

        ns.InitializeSavedVariables()

        self.assertEqual(ns.db.congratsTabs[1].text, "Legacy grats {{name}}")
        self.assertEqual(ns.db.welcomeTabs[1].text, "Legacy welcome {{name}}")
        self.assertFalse(ns.db.congratsTabs[1].enabled)
        self.assertTrue(ns.db.welcomeTabs[1].enabled)
        self.assertIsNone(ns.db.congratsText)
        self.assertIsNone(ns.db.welcomeText)

    def test_legacy_templates_are_not_resurrected_after_the_user_clears_them(self):
        lua, ns = self.load_config(
            r'''
            NiceGuildDB = {
                congratsText = "Legacy",
                congratsTabs = { [1] = { enabled = false, text = "" } },
            }
            '''
        )

        ns.InitializeSavedVariables()

        self.assertEqual(ns.db.congratsTabs[1].text, "")
        self.assertFalse(ns.db.congratsTabs[1].enabled)

    def test_empty_legacy_template_stays_empty_and_disabled(self):
        lua, ns = self.load_config('NiceGuildDB = { congratsText = "" }')

        ns.InitializeSavedVariables()

        self.assertEqual(ns.db.congratsTabs[1].text, "")
        self.assertFalse(ns.db.congratsTabs[1].enabled)

    def test_fresh_install_starts_with_both_sections_and_all_tabs_disabled(self):
        lua, ns = self.load_config("NiceGuildDB = nil")

        ns.InitializeSavedVariables()

        self.assertFalse(ns.db.enableCongrats)
        self.assertFalse(ns.db.enableWelcome)
        for index in range(1, 31):
            self.assertFalse(ns.db.congratsTabs[index].enabled)
            self.assertFalse(ns.db.welcomeTabs[index].enabled)
        self.assertIn("{{name}}", ns.db.congratsTabs[1].text)
        self.assertIn("{{name}}", ns.db.welcomeTabs[1].text)

    def test_obsolete_realm_suffix_setting_is_removed_and_name_cache_is_created(self):
        lua, ns = self.load_config('NiceGuildDB = { useShortName = true }')

        ns.InitializeSavedVariables()

        self.assertIsNone(ns.db.useShortName)
        self.assertEqual(lua.eval("type")(ns.db.selfNameCache), "table")

    def test_partial_or_malformed_tab_data_is_repaired(self):
        lua, ns = self.load_config(
            r'''
            NiceGuildDB = {
                congratsTabs = { [1] = { enabled = "yes", text = 42 } },
                welcomeTabs = {},
            }
            '''
        )

        ns.InitializeSavedVariables()

        for index in range(1, 31):
            congrats = ns.db.congratsTabs[index]
            welcome = ns.db.welcomeTabs[index]
            self.assertEqual(lua.eval("type")(congrats), "table")
            self.assertEqual(lua.eval("type")(welcome), "table")
            self.assertEqual(lua.eval("type")(congrats.enabled), "boolean")
            self.assertEqual(lua.eval("type")(welcome.enabled), "boolean")
            self.assertEqual(lua.eval("type")(congrats.text), "string")
            self.assertEqual(lua.eval("type")(welcome.text), "string")

    def test_non_table_saved_variable_root_is_reinitialized(self):
        lua, ns = self.load_config('NiceGuildDB = "corrupt"')

        ns.InitializeSavedVariables()

        self.assertEqual(lua.eval("type")(ns.db), "table")
        self.assertEqual(len(ns.db.congratsTabs), 30)
        self.assertEqual(len(ns.db.welcomeTabs), 30)

    def test_random_selection_validates_length_with_the_real_member_name(self):
        lua, ns = self.load_config("NiceGuildDB = {}")
        lua.execute(
            r'''
            function ns.FormatTemplate(template, memberName)
                return (template:gsub("{{name}}", memberName))
            end
            '''
        )
        ns.InitializeSavedVariables()
        ns.db.congratsTabs[1].text = "{{name}}" * 20
        long_name = "Longcharacter-VeryLongRealm"

        selected = ns.PickRandomEnabledTab("level", long_name)

        self.assertIsNone(selected)

    def test_random_selection_is_uniform_over_enabled_non_whitespace_tabs(self):
        lua, ns = self.load_config("NiceGuildDB = {}")
        lua.execute(
            r'''
            function ns.FormatTemplate(template) return template end
            randomLower = nil
            randomUpper = nil
            math.random = function(lower, upper)
                randomLower = lower
                randomUpper = upper
                return upper
            end
            '''
        )
        ns.InitializeSavedVariables()
        for index in range(1, 31):
            ns.db.congratsTabs[index].enabled = False
            ns.db.congratsTabs[index].text = ""
        ns.db.congratsTabs[2].enabled = True
        ns.db.congratsTabs[2].text = "Second"
        ns.db.congratsTabs[4].enabled = True
        ns.db.congratsTabs[4].text = "   \n\t  "
        ns.db.congratsTabs[7].enabled = True
        ns.db.congratsTabs[7].text = "Seventh"
        ns.db.congratsTabs[9].enabled = True
        ns.db.congratsTabs[9].text = "Ninth"

        selected = ns.PickRandomEnabledTab("level", "Tester")

        self.assertEqual(selected, "Ninth")
        self.assertEqual(lua.globals().randomLower, 1)
        self.assertEqual(lua.globals().randomUpper, 3)


class FormatTemplateTests(unittest.TestCase):
    def setUp(self):
        self.lua = make_runtime()
        self.ns = self.lua.table()
        self.lua.globals().ns = self.ns
        self.lua.execute("function issecretvalue(value) return false end")
        load_addon_file(self.lua, "Tokens.lua", self.ns)

    def test_two_part_names_keep_the_secondary_name_and_any_hyphen(self):
        self.assertEqual(
            self.ns.FormatTemplate("{{Name}} of {{Class}} ({{lvl}})", "Windfury Wim", "Mage", 60),
            "Windfury Wim of Mage (60)",
        )
        self.assertEqual(self.ns.FormatTemplate("{{Name}}", "Windfury-Wim"), "Windfury-Wim")

    def test_raid_symbols_are_normalised_for_chat_and_rendered_for_previews(self):
        formatted = self.ns.FormatTemplate("{{rt1}} hi {{Name}}", "Windfury Wim")

        self.assertIn("{star}", formatted)
        rendered = self.ns.RenderRaidSymbolsForPreview(formatted, 14)
        self.assertIn("UI-RaidTargetingIcon_1", rendered)
        self.assertNotIn("{star}", rendered)


class RaidSymbolTests(unittest.TestCase):
    def setUp(self):
        self.lua = make_runtime()
        self.ns = self.lua.table()
        self.lua.globals().ns = self.ns
        self.ns.db = self.lua.table()
        self.lua.execute("function issecretvalue(value) return false end")
        load_addon_file(self.lua, "Tokens.lua", self.ns)

    def test_rt_aliases_map_to_matching_named_raid_markers(self):
        expected = {
            1: "{star}",
            2: "{circle}",
            3: "{diamond}",
            4: "{triangle}",
            5: "{moon}",
            6: "{square}",
            7: "{cross}",
            8: "{skull}",
        }

        for index, tag in expected.items():
            with self.subTest(index=index):
                self.assertEqual(self.ns.NormalizeRaidSymbolsForChat(f"{{rt{index}}}"), tag)
                self.assertEqual(self.ns.RAID_SYMBOLS[index].tag, tag)

    def test_preview_uses_the_matching_texture_index(self):
        preview = self.ns.RenderRaidSymbolsForPreview("{diamond} {triangle} {moon} {square} {cross}", 14)

        for index in range(3, 8):
            self.assertIn(f"UI-RaidTargetingIcon_{index}", preview)


if __name__ == "__main__":
    unittest.main()
