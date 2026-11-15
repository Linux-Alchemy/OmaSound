"""Exercise preview ownership and cleanup with a disposable fake host."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from preview_lib import FILES, PLUGIN_ID, Preview, PreviewError, read_regular


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.repo = root / "repo"
        for name in FILES:
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps({"id": PLUGIN_ID}) if name == "manifest.json" else "fixture\n")
        self.config_home = root / "config"
        self.preview = Preview(self.repo, self.config_home, self.call)
        self.preview.config.parent.mkdir(parents=True)
        self.config = {"bar": {"layout": {s: [] for s in ("left", "centerBegin", "center", "centerEnd", "right", "tray")}}, "plugins": [], "unrelated": {"keep": True}}
        self.config["bar"]["layout"]["right"].append({"id": "omarchy.audio"})
        self.write_config()
        self.calls = []
        self.visible = False
        self.enabled = False
        self.fail_enable = False

    def write_config(self):
        self.preview.config.write_text(json.dumps(self.config))

    def call(self, method, *args):
        self.calls.append((method, args))
        if method == "ping":
            return "ok"
        if method == "listPlugins":
            return json.dumps([{"id": PLUGIN_ID}])
        if method == "enablePlugin":
            if self.fail_enable:
                return "failed"
            self.config["bar"]["layout"]["right"].append({"id": PLUGIN_ID})
            self.write_config()
            self.enabled = True
            return "ok"
        if method == "setPluginEnabled":
            self.config["bar"]["layout"]["right"] = [e for e in self.config["bar"]["layout"]["right"] if e["id"] != PLUGIN_ID]
            self.write_config()
            self.enabled = False
            return "ok"
        if method == "summon":
            self.visible = True
            return "ok"
        if method == "hide":
            self.visible = False
        if method == "call":
            return json.dumps({"mode": "fixture", "ready": True, "visible": self.visible, "instance": "one"}) if self.enabled else "unknown"
        return ""

    def start(self):
        with self.preview.locked():
            return self.preview.start()

    def stop(self):
        with self.preview.locked():
            return self.preview.stop()

    def test_round_trip_and_repeated_start_stop(self):
        before = json.loads(json.dumps(self.config))
        self.assertTrue(self.start()["changed"])
        self.assertFalse(self.start()["changed"])
        self.assertEqual(sum(method == "enablePlugin" for method, _ in self.calls), 1)
        self.assertEqual(set(p.name for p in self.preview.stage.iterdir()) & {"local", "PLAN.md", ".git", "tests"}, set())
        self.assertTrue(self.stop()["changed"])
        self.assertEqual(self.config, before)
        self.assertFalse(self.preview.stage.exists())
        self.assertFalse(self.stop()["changed"])

    def test_cleanup_preserves_concurrent_unrelated_settings(self):
        self.start()
        self.config["unrelated"]["new"] = "keep this"
        self.config["bar"]["layout"]["left"].append({"id": "other.widget"})
        self.write_config()
        self.stop()
        self.assertEqual(self.config["unrelated"]["new"], "keep this")
        self.assertEqual(self.config["bar"]["layout"]["left"], [{"id": "other.widget"}])

    def test_refuses_unowned_directory_and_existing_id(self):
        self.preview.stage.mkdir(parents=True)
        (self.preview.stage / "user-file").write_text("keep")
        with self.assertRaises(PreviewError):
            self.start()
        with self.assertRaises(PreviewError):
            self.stop()
        self.assertEqual((self.preview.stage / "user-file").read_text(), "keep")

    def test_refuses_existing_id_without_staging(self):
        self.config["plugins"].append({"id": PLUGIN_ID})
        self.write_config()
        with self.assertRaises(PreviewError):
            self.start()
        self.assertFalse(self.preview.stage.exists())

    def test_modified_stage_survives_stop(self):
        self.start()
        target = self.preview.stage / "Panel.qml"
        target.write_text("user edit")
        with self.assertRaises(PreviewError):
            self.stop()
        self.assertEqual(target.read_text(), "user edit")
        self.assertTrue(self.enabled)

    def test_symlink_in_stage_is_not_followed(self):
        self.start()
        target = self.preview.stage / "Panel.qml"
        target.unlink()
        target.symlink_to(self.repo / "Panel.qml")
        with self.assertRaises(PreviewError):
            self.stop()
        self.assertTrue(target.is_symlink())

    def test_checkout_changes_require_stop_before_restage(self):
        self.start()
        (self.repo / "Panel.qml").write_text("new version")
        with self.assertRaises(PreviewError):
            self.start()
        self.stop()
        self.start()
        self.assertEqual((self.preview.stage / "Panel.qml").read_text(), "new version")

    def test_enable_failure_is_recoverable(self):
        self.fail_enable = True
        with self.assertRaises(PreviewError):
            self.start()
        self.assertTrue(self.preview.record.exists())
        self.stop()
        self.assertFalse(self.preview.stage.exists())

    def test_wrong_record_never_removes_stage(self):
        self.start()
        record = json.loads(self.preview.record.read_text())
        record["stage"] = "/tmp/not-owned"
        self.preview.record.write_text(json.dumps(record))
        with self.assertRaises(PreviewError):
            self.stop()
        self.assertTrue(self.preview.stage.exists())

    def test_waits_for_asynchronous_registration(self):
        original = self.preview.call
        polls = []

        def delayed(method, *args):
            if method == "listPlugins":
                polls.append(method)
                if len(polls) == 1:
                    return "[]"
            return original(method, *args)

        self.preview.call = delayed
        self.start()
        self.assertEqual(len(polls), 2)
        self.stop()

    def test_recovers_interrupted_publication_record(self):
        self.start()
        self.stop()
        self.preview.record.write_text(json.dumps({"version": 1, "stage": str(self.preview.stage), "repo": str(self.repo)}))
        self.assertTrue(self.stop()["changed"])
        self.assertFalse(self.preview.record.exists())

    def test_bounded_reads_reject_fifo_and_symlink(self):
        import os
        fifo = self.repo / "fifo"
        os.mkfifo(fifo)
        with self.assertRaises(PreviewError):
            read_regular(fifo)
        link = self.repo / "link"
        link.symlink_to(self.repo / "Panel.qml")
        with self.assertRaises(OSError):
            read_regular(link)


if __name__ == "__main__":
    unittest.main()
