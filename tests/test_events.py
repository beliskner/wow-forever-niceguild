import unittest

from lua_test_harness import load_addon_file, make_runtime


class EventFlowTests(unittest.TestCase):
    def make_namespace(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            ns.db = { enableCongrats = true, enableWelcome = true }
            ns.randomPickCalls = 0
            ns.formatArgs = nil
            ns.printed = nil
            function ns.PickRandomEnabledTab(kind, memberName, memberClass, memberLevel)
                ns.randomPickCalls = ns.randomPickCalls + 1
                return "Random template"
            end
            function ns.FormatTemplate(template, memberName, memberClass, memberLevel)
                ns.formatArgs = { template, memberName, memberClass, memberLevel }
                return template
            end
            function ns.NormalizeRaidSymbolsForChat(message) return message end
            function ns.RenderRaidSymbolsForPreview(text)
                return (text:gsub("{star}", "|TICON|t"))
            end
            function ns.IsSecret(value) return false end
            function ns.Print(message) ns.printed = message end
            function ns.RegisterSettingsPanel() end
            function ns.InitializeSavedVariables() end
            C_Timer = { After = function(delay, callback) callback() end }
            C_ChatInfo = { SendChatMessage = function(...) end }
            DEFAULT_CHAT_FRAME = {
                AddMessage = function(self, message) self.lastMessage = message end,
            }
            '''
        )
        load_addon_file(lua, "Events.lua", ns)
        event_frame = lua.globals().CREATED_FRAMES[len(lua.globals().CREATED_FRAMES)]
        return lua, ns, event_frame

    def test_local_test_can_render_the_selected_template_without_random_pick(self):
        lua, ns, _ = self.make_namespace()

        ns.TriggerGuildGreeting("level", "Tester", True, "Selected template")

        self.assertEqual(ns.randomPickCalls, 0)
        self.assertEqual(ns.formatArgs[1], "Selected template")
        self.assertIn("Selected template", lua.globals().DEFAULT_CHAT_FRAME.lastMessage)

    def test_local_test_preview_renders_raid_symbols_instead_of_raw_tags(self):
        lua, ns, _ = self.make_namespace()
        lua.execute('function ns.FormatTemplate() return "{star} nice one" end')

        ns.TriggerGuildGreeting("level", "Windfury Wim", True, "{star} nice one")

        message = lua.globals().DEFAULT_CHAT_FRAME.lastMessage
        self.assertIn("|TICON|t", message)
        self.assertNotIn("{star}", message)

    def test_disabled_section_skips_random_selection_and_sending(self):
        lua, ns, event_frame = self.make_namespace()
        ns.db.enableCongrats = False
        lua.execute(
            r'''
            ns.sendCalls = 0
            function ns.SendGuildMessage(message) ns.sendCalls = ns.sendCalls + 1 end
            '''
        )

        event_frame.scripts.OnEvent(
            event_frame,
            "CHAT_MSG_SYSTEM",
            "Alice has reached level 42",
        )

        self.assertEqual(ns.randomPickCalls, 0)
        self.assertEqual(ns.sendCalls, 0)
        self.assertIsNone(ns.formatArgs)

    def test_level_event_passes_captured_level_without_fake_class(self):
        _, ns, event_frame = self.make_namespace()

        event_frame.scripts.OnEvent(
            event_frame,
            "CHAT_MSG_SYSTEM",
            "Alice has reached level 42",
        )

        self.assertEqual(ns.formatArgs[2], "Alice")
        self.assertIsNone(ns.formatArgs[3])
        self.assertEqual(ns.formatArgs[4], "42")

    def test_live_length_failure_does_not_claim_it_was_only_a_test(self):
        _, ns, _ = self.make_namespace()
        ns.FormatTemplate = lambda *args: "x" * 256

        ns.TriggerGuildGreeting("level", "Tester", False, "Selected template")

        self.assertEqual(ns.printed, "Error: Generated message exceeds 255 character limit.")

    def test_secret_message_is_rejected_before_string_operations(self):
        _, ns, _ = self.make_namespace()
        ns.IsSecret = lambda value: True

        ns.SendGuildMessage({"secret": True})

        self.assertIsNone(ns.printed)

    def test_chat_api_error_is_reported_without_escaping_the_event_handler(self):
        lua, ns, _ = self.make_namespace()
        lua.execute(
            r'''
            C_ChatInfo.SendChatMessage = function()
                error("chat locked")
            end
            '''
        )

        ns.SendGuildMessage("hello")

        self.assertIn("Could not send guild message", ns.printed)


if __name__ == "__main__":
    unittest.main()
