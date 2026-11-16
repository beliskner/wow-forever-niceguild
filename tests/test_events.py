import unittest

from lua_test_harness import load_addon_file, make_runtime


class EventFlowTests(unittest.TestCase):
    def make_namespace(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            ns.VERSION = "test"
            ns.db = { enableCongrats = true, enableWelcome = true }
            ns.randomPickCalls = 0
            ns.pickArgs = nil
            ns.formatArgs = nil
            ns.printed = nil
            function ns.PickRandomEnabledTab(kind, memberName, memberClass, memberLevel)
                ns.randomPickCalls = ns.randomPickCalls + 1
                ns.pickArgs = { kind, memberName, memberClass, memberLevel }
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
            function ns.IsSelf(value) return SELF_NAME ~= nil and value == SELF_NAME end
            function ns.Print(message) ns.printed = message end
            function ns.RegisterSettingsPanel() end
            function ns.InitializeSavedVariables() end
            C_Timer = {
                After = function(delay, callback) callback() end,
                NewTicker = function(seconds, callback)
                    TEST_TICKER = { seconds = seconds, callback = callback }
                    return TEST_TICKER
                end,
            }
            C_GuildInfo = {
                GuildRoster = function()
                    GUILD_ROSTER_REQUESTS = (GUILD_ROSTER_REQUESTS or 0) + 1
                end,
            }
            GUILD_MEMBERS = {}
            function GetNumGuildMembers() return #GUILD_MEMBERS end
            function GetGuildRosterInfo(index)
                local member = GUILD_MEMBERS[index]
                if not member then return nil end
                return member.name, nil, nil, member.level, member.class,
                    nil, nil, nil, member.online, nil, nil, nil, nil, nil, nil, nil, member.guid
            end
            C_ChatInfo = {
                SendChatMessage = function(message, channel)
                    SEND_ARGS = { message, channel }
                end,
            }
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

    def test_first_roster_update_builds_a_silent_baseline(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )

        event_frame.scripts.OnEvent(
            event_frame,
            "GUILD_ROSTER_UPDATE",
            True,
        )

        self.assertEqual(ns.randomPickCalls, 0)
        self.assertIsNone(ns.formatArgs)

    def test_roster_level_increase_triggers_with_real_member_metadata_once(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute("GUILD_MEMBERS[1].level = 43")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 1)
        self.assertEqual(ns.formatArgs[2], "Alice Amber")
        self.assertEqual(ns.formatArgs[3], "Mage")
        self.assertEqual(ns.formatArgs[4], 43)

        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 1)

    def test_new_members_and_level_decreases_do_not_trigger_congratulations(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute("GUILD_MEMBERS[1].level = 40")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 0)
        self.assertIsNone(ns.formatArgs)

        lua.execute(
            'GUILD_MEMBERS[2] = { name = "Bob Birch", level = 22, class = "Druid", guid = "Player-2" }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 1)
        self.assertEqual(ns.pickArgs[1], "welcome")

    def test_returning_to_a_previous_high_after_a_decrease_does_not_trigger_twice(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute("GUILD_MEMBERS[1].level = 43")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 1)

        lua.execute("GUILD_MEMBERS[1].level = 42")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        lua.execute("GUILD_MEMBERS[1].level = 43")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 1)

    def test_temporary_guid_loss_keeps_the_same_level_high_water_identity(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute("GUILD_MEMBERS[1].guid = nil; GUILD_MEMBERS[1].level = 43")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 1)
        self.assertEqual(ns.pickArgs[1], "level")
        self.assertEqual(ns.pickArgs[4], 43)

        lua.execute("GUILD_MEMBERS[1].level = 44")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 2)
        self.assertEqual(ns.pickArgs[4], 44)

        lua.execute('GUILD_MEMBERS[1].guid = "Player-1"')
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 2)

    def test_renaming_a_guid_removes_the_old_name_alias(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute('GUILD_MEMBERS[1].name = "Carol Copper"; GUILD_MEMBERS[1].level = 42')
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 1)
        self.assertEqual(ns.pickArgs[1], "level")
        self.assertEqual(ns.pickArgs[2], "Carol Copper")

        lua.execute(
            r'''
            GUILD_MEMBERS[2] = {
                name = "Alice Amber", level = 60, class = "Warrior", guid = nil,
            }
            '''
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 1)
        self.assertEqual(ns.pickArgs[2], "Carol Copper")

    def test_member_added_after_the_baseline_is_welcomed_once_with_roster_metadata(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute(
            'GUILD_MEMBERS[2] = { name = "Bob Birch", level = 22, class = "Druid", guid = "Player-2" }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 1)
        self.assertEqual(ns.pickArgs[1], "welcome")
        self.assertEqual(ns.pickArgs[2], "Bob Birch")
        self.assertEqual(ns.pickArgs[3], "Druid")
        self.assertEqual(ns.pickArgs[4], 22)
        self.assertEqual(lua.globals().SEND_ARGS[1], "Random template")
        self.assertEqual(lua.globals().SEND_ARGS[2], "GUILD")

        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        self.assertEqual(ns.randomPickCalls, 1)

    def test_existing_offline_member_coming_online_is_not_welcomed(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            r'''
            GUILD_MEMBERS = {
                { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1", online = true },
                { name = "Bob Birch", level = 22, class = "Druid", guid = "Player-2", online = false },
            }
            '''
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute("GUILD_MEMBERS[2].online = true")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 0)
        self.assertIsNone(lua.globals().SEND_ARGS)

    def test_new_guid_matching_the_player_is_consumed_without_a_welcome(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            r'''
            SELF_NAME = "Player Person"
            GUILD_MEMBERS = {
                { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" },
            }
            '''
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute(
            'GUILD_MEMBERS[2] = { name = "Player Person", level = 22, class = "Druid", guid = "Player-self" }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 0)
        self.assertIsNone(lua.globals().SEND_ARGS)

    def test_temporarily_missing_member_is_not_welcomed_when_they_reappear(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            r'''
            GUILD_MEMBERS = {
                { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" },
                { name = "Bob Birch", level = 22, class = "Druid", guid = "Player-2" },
            }
            '''
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute("table.remove(GUILD_MEMBERS, 2)")
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        lua.execute(
            'GUILD_MEMBERS[2] = { name = "Bob Birch", level = 22, class = "Druid", guid = "Player-2" }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 0)

    def test_join_seen_while_welcomes_are_disabled_is_not_sent_later(self):
        lua, ns, event_frame = self.make_namespace()
        lua.execute(
            'GUILD_MEMBERS = { { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" } }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        ns.db.enableWelcome = False

        lua.execute(
            'GUILD_MEMBERS[2] = { name = "Bob Birch", level = 22, class = "Druid", guid = "Player-2" }'
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)
        ns.db.enableWelcome = True
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 0)

    def test_empty_initial_cache_does_not_turn_the_first_real_roster_into_joins(self):
        lua, ns, event_frame = self.make_namespace()
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        lua.execute(
            r'''
            GUILD_MEMBERS = {
                { name = "Alice Amber", level = 41, class = "Mage", guid = "Player-1" },
                { name = "Bob Birch", level = 22, class = "Druid", guid = "Player-2" },
            }
            '''
        )
        event_frame.scripts.OnEvent(event_frame, "GUILD_ROSTER_UPDATE", True)

        self.assertEqual(ns.randomPickCalls, 0)

    def test_login_starts_a_30_second_roster_refresh_ticker(self):
        lua, _, event_frame = self.make_namespace()

        event_frame.scripts.OnEvent(event_frame, "PLAYER_LOGIN")

        self.assertEqual(lua.globals().TEST_TICKER.seconds, 30)
        self.assertEqual(lua.globals().GUILD_ROSTER_REQUESTS, 1)
        lua.globals().TEST_TICKER.callback()
        self.assertEqual(lua.globals().GUILD_ROSTER_REQUESTS, 2)

    def test_system_chat_level_text_is_no_longer_a_level_trigger(self):
        _, ns, event_frame = self.make_namespace()

        event_frame.scripts.OnEvent(
            event_frame,
            "CHAT_MSG_SYSTEM",
            "Alice has reached level 42",
        )

        self.assertEqual(ns.randomPickCalls, 0)
        self.assertIsNone(ns.formatArgs)

    def test_system_chat_join_text_is_no_longer_a_welcome_trigger(self):
        _, ns, event_frame = self.make_namespace()

        event_frame.scripts.OnEvent(
            event_frame,
            "CHAT_MSG_SYSTEM",
            "Bob Birch has joined the guild",
        )

        self.assertEqual(ns.randomPickCalls, 0)
        self.assertIsNone(ns.formatArgs)

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
