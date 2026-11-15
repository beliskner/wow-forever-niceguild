import unittest

from lua_test_harness import load_addon_file, make_runtime


SELF_ENV = r'''
NiceGuildDB = {}
C_GuildInfo = { GuildRoster = function() GUILD_ROSTER_REQUESTED = true end }
function issecretvalue(value) return false end
function UnitName(unit) return "Hotdog" end
function UnitGUID(unit) return "Player-1" end
function UnitFullName(unit) return "Hotdog", "" end
function UnitNameUnmodified(unit) return "Hotdog", "Harold" end
function UnitClass(unit) return "Mage", "MAGE" end
function UnitLevel(unit) return 60 end
ROSTER = {}
function GetNumGuildMembers() return #ROSTER end
function GetGuildRosterInfo(index) return unpack(ROSTER[index] or {}) end
function IsInGuild() return true end
function set_roster_entry(index, name, level, memberClass, guid)
    ROSTER[index] = {
        name, "", 0, level, memberClass, "", "", "", 1, 0,
        "", "", "", "", "", "", guid,
    }
end
'''


class SelfIdentityTests(unittest.TestCase):
    def make_namespace(self):
        lua = make_runtime()
        ns = lua.table()
        lua.globals().ns = ns
        lua.execute(SELF_ENV)
        load_addon_file(lua, "Config.lua", ns)
        load_addon_file(lua, "Tokens.lua", ns)
        ns.InitializeSavedVariables()
        return lua, ns

    def set_roster(self, lua, entries):
        lua.execute("ROSTER = {}")
        for index, entry in enumerate(entries, start=1):
            name, level, member_class, guid = entry
            lua.globals().set_roster_entry(index, name, level, member_class, guid)

    def test_full_name_falls_back_to_primary_until_the_roster_resolves_it(self):
        lua, ns = self.make_namespace()

        self.assertEqual(ns.GetSelfFullName(), "Hotdog Harold")

    def test_the_surname_comes_from_the_second_return_value(self):
        lua, ns = self.make_namespace()

        name, source = ns.GetUnitFullName("player")
        self.assertEqual(name, "Hotdog Harold")
        self.assertEqual(source, "UnitNameUnmodified")
        ns.GetSelfFullName()
        self.assertEqual(ns.selfNameSource, "UnitNameUnmodified")

    def test_a_stale_primary_only_cache_does_not_beat_the_live_unit_name(self):
        lua, ns = self.make_namespace()
        ns.db.selfNameCache["Player-1"] = "Hotdog Harold"
        lua.execute('function UnitNameUnmodified(unit) return "Hotdog", "Harold" end')

        self.assertEqual(ns.GetSelfFullName(), "Hotdog Harold")

    def test_the_candidate_with_the_most_name_parts_wins(self):
        lua, ns = self.make_namespace()
        lua.execute(
            r'''
            function UnitNameUnmodified(unit) return "Hotdog", "" end
            function UnitFullName(unit) return "Hotdog", "Harold" end
            '''
        )

        name, source = ns.GetUnitFullName("player")
        self.assertEqual(name, "Hotdog Harold")
        self.assertEqual(source, "UnitFullName")

    def test_a_name_that_already_has_two_parts_is_not_doubled(self):
        lua, ns = self.make_namespace()
        lua.execute('function UnitNameUnmodified(unit) return "Hotdog Harold", "Harold" end')

        name, _ = ns.GetUnitFullName("player")
        self.assertEqual(name, "Hotdog Harold")

    def test_roster_resolution_matches_the_player_guid_and_caches_the_full_name(self):
        lua, ns = self.make_namespace()
        self.set_roster(lua, [
            ("Comrade Pep", 60, "Warrior", "Player-999"),
            ("Hotdog Harold", 60, "Mage", "Player-1"),
        ])

        resolved = ns.ResolveSelfNameFromRoster()

        self.assertTrue(resolved)
        self.assertEqual(ns.GetSelfFullName(), "Hotdog Harold")
        self.assertEqual(ns.db.selfNameCache["Player-1"], "Hotdog Harold")
        self.assertEqual(ns.selfNameSource, "GuildRoster(GUID)")

    def test_cached_full_name_is_used_before_the_first_roster_update(self):
        lua, ns = self.make_namespace()
        lua.execute(
            r'''
            function UnitNameUnmodified(unit) return "Hotdog", "" end
            function UnitFullName(unit) return "Hotdog", "" end
            function UnitName(unit) return "Hotdog" end
            '''
        )
        ns.db.selfNameCache["Player-1"] = "Hotdog Harold"

        self.assertEqual(ns.GetSelfFullName(), "Hotdog Harold")
        self.assertEqual(ns.selfNameSource, "SavedCache")

    def test_roster_fallback_matches_primary_name_with_class_and_level(self):
        lua, ns = self.make_namespace()
        self.set_roster(lua, [
            ("Hotdog Harold", 60, "Mage", "Player-unknown"),
        ])
        lua.execute(
            r'''
            function UnitNameUnmodified(unit) return "Hotdog", "" end
            function UnitFullName(unit) return "Hotdog", "" end
            function UnitName(unit) return "Hotdog" end
            '''
        )

        resolved = ns.ResolveSelfNameFromRoster()

        self.assertTrue(resolved)
        self.assertEqual(ns.GetSelfFullName(), "Hotdog Harold")
        self.assertEqual(ns.selfNameSource, "GuildRoster(Name+Class+Lvl)")

    def test_roster_fallback_rejects_a_name_match_with_the_wrong_class(self):
        lua, ns = self.make_namespace()
        self.set_roster(lua, [
            ("Hotdog Harold", 60, "Warrior", "Player-unknown"),
        ])

        self.assertFalse(ns.ResolveSelfNameFromRoster())
        self.assertEqual(ns.GetSelfFullName(), "Hotdog Harold")
        self.assertEqual(ns.selfNameSource, "UnitNameUnmodified")

    def test_is_self_recognises_both_the_full_and_primary_name(self):
        lua, ns = self.make_namespace()
        self.set_roster(lua, [
            ("Hotdog Harold", 60, "Mage", "Player-1"),
        ])
        ns.ResolveSelfNameFromRoster()

        self.assertTrue(ns.IsSelf("Hotdog Harold"))
        self.assertTrue(ns.IsSelf("hotdog"))
        self.assertFalse(ns.IsSelf("Comrade Pep"))

    def test_self_info_carries_the_full_name_class_and_level(self):
        lua, ns = self.make_namespace()
        self.set_roster(lua, [
            ("Hotdog Harold", 60, "Mage", "Player-1"),
        ])
        ns.ResolveSelfNameFromRoster()

        info = ns.GetSelfInfo()

        self.assertEqual(info.name, "Hotdog Harold")
        self.assertEqual(getattr(info, "class"), "Mage")
        self.assertEqual(info.level, 60)


if __name__ == "__main__":
    unittest.main()
