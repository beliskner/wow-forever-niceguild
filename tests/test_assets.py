import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BLP_PATH = ROOT / "niceguild" / "logo_32x32.blp"
TOC_PATH = ROOT / "niceguild" / "niceguild.toc"


class AddonLogoTests(unittest.TestCase):
    def test_logo_is_valid_uncompressed_bgra_blp2(self):
        data = BLP_PATH.read_bytes()
        magic, version = struct.unpack_from("<4sI", data, 0)
        color_encoding, alpha_depth, alpha_encoding, has_mips = struct.unpack_from("<4B", data, 8)
        width, height = struct.unpack_from("<II", data, 12)
        mip_offset = struct.unpack_from("<I", data, 20)[0]
        mip_size = struct.unpack_from("<I", data, 84)[0]

        self.assertEqual(magic, b"BLP2")
        self.assertEqual(version, 1)
        self.assertEqual(color_encoding, 3, "raw BGRA pixels require BLP2 encoding 3")
        self.assertEqual(alpha_depth, 8)
        self.assertEqual(alpha_encoding, 8)
        self.assertEqual(has_mips, 0)
        self.assertEqual((width, height), (32, 32))
        self.assertEqual(mip_offset, 148 + (256 * 4))
        self.assertEqual(mip_size, width * height * 4)
        self.assertEqual(data[148:mip_offset], bytes(256 * 4))
        self.assertEqual(len(data), mip_offset + mip_size)

    def test_toc_icon_path_matches_the_packaged_asset(self):
        toc = TOC_PATH.read_text(encoding="utf-8")

        self.assertIn(r"## IconTexture: Interface\AddOns\niceguild\logo_32x32", toc)
        self.assertTrue(BLP_PATH.is_file())


if __name__ == "__main__":
    unittest.main()
