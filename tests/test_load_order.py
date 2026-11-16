import unittest

from lua_test_harness import ROOT, load_addon_file, make_runtime


class AddonLoadOrderTests(unittest.TestCase):
    def test_toc_load_order_initializes_and_opens_the_addon(self):
        lua = make_runtime(with_ui=True)
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(
            r'''
            NiceGuildDB = nil
            SlashCmdList = {}
            DEFAULT_CHAT_FRAME = { AddMessage = function(...) end }
            C_Timer = { After = function(delay, callback) callback() end }
            C_ChatInfo = { SendChatMessage = function(...) end }
            function issecretvalue(value) return false end
            function UnitName(unit) return "Tester" end
            function GetBuildInfo() return "", "", "", 16001 end
            '''
        )

        toc_entries = []
        for raw_line in (ROOT / "niceguild" / "niceguild.toc").read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if line and not line.startswith("##"):
                toc_entries.append(line)

        for entry in toc_entries:
            load_addon_file(lua, entry, ns)

        for index in range(1, len(lua.globals().CREATED_FRAMES) + 1):
            frame = lua.globals().CREATED_FRAMES[index]
            on_event = frame.scripts.OnEvent
            if on_event is not None:
                on_event(frame, "ADDON_LOADED", "niceguild")

        self.assertIsNotNone(ns.db)
        self.assertEqual(ns.VERSION, "1.8.0")
        self.assertEqual(len(ns.db.congratsTabs), 10)
        ns.ToggleConfig()
        config_frame = lua.globals().FindFrameByName("NiceGuildConfigFrame")
        self.assertTrue(config_frame.IsShown(config_frame))


if __name__ == "__main__":
    unittest.main()
