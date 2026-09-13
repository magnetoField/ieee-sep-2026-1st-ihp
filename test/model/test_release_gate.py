import tempfile
from pathlib import Path
import unittest
from scripts.release_check import REQUIRED, check_statuses, check_xml


class ReleaseGateTests(unittest.TestCase):
    def test_exact_status_not_prefix(self):
        text = "\n".join(f"{name}=PASS" for name in REQUIRED)
        text += "\nPRODUCTION_PERSISTENCE=NOT_IMPLEMENTED\n"
        check_statuses(text)
        with self.assertRaises(ValueError):
            check_statuses(text.replace("TT_PRECHECK=PASS", "TT_PRECHECK=PASS_BUT_BLOCKED"))
        with self.assertRaises(ValueError):
            check_statuses(text + "TT_PRECHECK=PASS\n")

    def test_xml_rejects_empty_failure_and_skipped(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "results.xml"
            for content in ("<testsuite/>", "<testsuite><testcase><failure/></testcase></testsuite>",
                            "<testsuite><testcase><skipped/></testcase></testsuite>"):
                path.write_text(content)
                with self.assertRaises(ValueError):
                    check_xml(path, 1)
            path.write_text("<testsuite><testcase/></testsuite>")
            check_xml(path, 1)


if __name__ == "__main__":
    unittest.main()
