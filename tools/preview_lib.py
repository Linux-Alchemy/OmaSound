"""Owned fixture staging; never installs packages or starts a shell."""
from __future__ import annotations

import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import time
import uuid

PLUGIN_ID = "linux-alchemy.omasound-dev"
FILES = (
    "manifest.json", "BarWidget.qml", "Panel.qml", "Service.qml",
    "ui/Action.qml", "ui/Label.qml", "ui/SideControls.qml", "models/Fixture.js",
    "ui/ProfileEditor.qml", "models/ProfileModel.js", "models/EffectiveState.js",
    "models/EditSession.js", "models/FakeEngine.js", "models/ProfileController.js",
    "LICENSE", "THIRD_PARTY_NOTICES.md",
)
MAX_FILE = 2 * 1024 * 1024


class PreviewError(RuntimeError):
    pass


def read_regular(path: Path) -> bytes:
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_FILE:
            raise PreviewError(f"Not a bounded regular file: {path}")
        with os.fdopen(fd, "rb", closefd=False) as stream:
            value = stream.read(MAX_FILE + 1)
        if len(value) > MAX_FILE:
            raise PreviewError(f"Oversized file: {path}")
        return value
    finally:
        os.close(fd)


def publish(path: Path, data: bytes) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".omasound-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def tree_hashes(folder: Path) -> dict[str, str]:
    if folder.is_symlink() or not folder.is_dir():
        raise PreviewError(f"Not an owned directory: {folder}")
    result = {}
    for path in sorted(folder.rglob("*")):
        if path.is_symlink():
            raise PreviewError(f"Symlink in staging: {path}")
        if path.is_dir():
            continue
        result[str(path.relative_to(folder))] = digest(read_regular(path))
    return result


def contains_id(value: object) -> bool:
    if isinstance(value, dict):
        return value.get("id") == PLUGIN_ID or any(contains_id(v) for v in value.values())
    if isinstance(value, list):
        return PLUGIN_ID in value or any(contains_id(v) for v in value)
    return value == PLUGIN_ID


def without_preview(config: dict) -> dict:
    value = json.loads(json.dumps(config))
    layout = value.get("bar", {}).get("layout", {})
    for section, entries in layout.items():
        if isinstance(entries, list):
            layout[section] = [e for e in entries if e != PLUGIN_ID and not (isinstance(e, dict) and e.get("id") == PLUGIN_ID)]
    if isinstance(value.get("plugins"), list):
        value["plugins"] = [e for e in value["plugins"] if e != PLUGIN_ID and not (isinstance(e, dict) and e.get("id") == PLUGIN_ID)]
    return value


def shell_call(method: str, *args: str) -> str:
    # Known installed IPC CLI; argv only. A file-backed capture bounds memory;
    # timeout and RLIMIT_FSIZE bound the trusted client's output and lifetime.
    import resource

    def limits():
        resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_FILE, MAX_FILE))

    with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
        proc = subprocess.Popen(["omarchy-shell", "shell", method, *args], stdout=out, stderr=err,
                                start_new_session=True, preexec_fn=limits)
        try:
            code = proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            import signal
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
            raise PreviewError(f"Shell IPC timed out: {method}") from None
        out.seek(0)
        err.seek(0)
        data = out.read(MAX_FILE + 1)
        error = err.read(MAX_FILE + 1)
        if code or len(data) >= MAX_FILE or len(error) >= MAX_FILE:
            raise PreviewError(f"Shell IPC failed: {method}: {error[:1000].decode(errors='replace').strip()}")
        return data.decode().strip()


class Preview:
    def __init__(self, repo: Path, config_home: Path, call=shell_call):
        self.repo = repo.resolve()
        self.config = config_home / "omarchy" / "shell.json"
        self.plugins = config_home / "omarchy" / "plugins"
        self.stage = self.plugins / PLUGIN_ID
        self.local = self.repo / "local" / "preview"
        self.record = self.local / "ownership.json"
        self.call = call

    def read_config(self) -> dict:
        value = json.loads(read_regular(self.config))
        # Refuse unusual/partial shapes rather than letting the host normalize
        # unrelated settings as a side effect of enabling the preview.
        layout = value.get("bar", {}).get("layout", {})
        if not isinstance(value.get("plugins"), list) or not all(isinstance(layout.get(s), list) for s in ("left", "centerBegin", "center", "centerEnd", "right", "tray")):
            raise PreviewError("Preview requires an existing complete bar layout and plugins list; no configuration normalization was attempted")
        return value

    def locked(self):
        self.local.mkdir(parents=True, exist_ok=True, mode=0o700)
        fd = os.open(self.local / "lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        lock = os.fdopen(fd, "w")
        fcntl.flock(lock, fcntl.LOCK_EX)
        return lock

    def load_record(self) -> dict:
        record = json.loads(read_regular(self.record))
        if record.get("stage") != str(self.stage) or record.get("repo") != str(self.repo) or record.get("version") != 1:
            raise PreviewError("Ownership record does not match this checkout and staging path")
        actual = tree_hashes(self.stage)
        if actual != record.get("hashes"):
            raise PreviewError("Owned preview files changed; refusing to overwrite or remove them. Preserve/reconcile the changes first")
        return record

    def wait_status(self, visible: bool, runtime: str | None = None) -> dict:
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            answer = self.call("call", PLUGIN_ID, "status", "")
            try:
                status = json.loads(answer)
            except (ValueError, TypeError):
                status = {}
            source_matches = runtime is None or status.get("sourceUrl", "").endswith("/" + runtime + "/Panel.qml")
            if source_matches and status.get("mode") == "fixture" and status.get("ready") is True and status.get("visible") is visible:
                return status
            time.sleep(0.1)
        raise PreviewError("Fixture did not acknowledge loaded/visible state; inspect the shell log, then run tools/preview --stop")

    def start(self) -> dict:
        if self.call("ping") != "ok":
            raise PreviewError("Existing Omarchy shell did not answer")
        before = self.read_config()
        changed = not self.record.exists()
        if self.record.exists():
            record = self.load_record()
            for name in FILES:
                if digest(read_regular(self.repo / name)) != record.get("sourceHashes", {}).get(name):
                    raise PreviewError("Checkout changed since staging; stop the existing preview before starting the new version")
        else:
            if self.stage.exists() or self.stage.is_symlink() or contains_id(before):
                raise PreviewError("Development ID or staging directory is already in use; refusing to take ownership")
            content = {name: read_regular(self.repo / name) for name in FILES}
            manifest = json.loads(content["manifest.json"])
            if manifest.get("id") != PLUGIN_ID:
                raise PreviewError("Unexpected development manifest ID")
            source_hashes = {name: digest(data) for name, data in content.items()}
            runtime = "runtime_" + digest(json.dumps(source_hashes, sort_keys=True).encode())
            manifest["entryPoints"] = {key: runtime + "/" + value for key, value in manifest["entryPoints"].items()}
            self.plugins.mkdir(parents=True, exist_ok=True)
            temporary = Path(tempfile.mkdtemp(prefix=".omasound-stage-", dir=self.plugins))
            try:
                for name, data in content.items():
                    if name == "manifest.json":
                        target = temporary / name
                        data = (json.dumps(manifest, indent=2) + "\n").encode()
                    else:
                        target = temporary / runtime / name if name.endswith((".qml", ".js")) else temporary / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(data)
                (temporary / ".omasound-owner").write_text(str(uuid.uuid4()) + "\n")
                hashes = tree_hashes(temporary)
                # Record before publication, so a crash after rename is recoverable.
                record = {"version": 1, "repo": str(self.repo), "stage": str(self.stage), "hashes": hashes,
                          "sourceHashes": source_hashes, "runtime": runtime}
                publish(self.record, (json.dumps(record, indent=2) + "\n").encode())
                os.rename(temporary, self.stage)
            finally:
                if temporary.exists():
                    shutil.rmtree(temporary)
        if changed:
            self.call("rescanPlugins")
        deadline = time.monotonic() + 8
        while True:
            catalog = json.loads(self.call("listPlugins"))
            if isinstance(catalog, list) and any(p.get("id") == PLUGIN_ID for p in catalog if isinstance(p, dict)):
                break
            if time.monotonic() >= deadline:
                raise PreviewError("Host did not register staged preview; run tools/preview --stop")
            time.sleep(0.1)
        # Do not enable twice: the host may add an extra plugins[] record when
        # an already-enabled combined bar-widget/panel plugin is enabled again.
        if not contains_id(self.read_config()):
            if self.call("enablePlugin", PLUGIN_ID, '{"section":"right"}') != "ok":
                raise PreviewError("Host refused preview enable; owned staging retained for --stop")
        if self.call("summon", PLUGIN_ID, "{}") != "ok":
            raise PreviewError("Host refused fixture open; run tools/preview --stop")
        status = self.wait_status(True, record["runtime"])
        if without_preview(self.read_config()) != without_preview(before):
            raise PreviewError("Configuration changed concurrently or unexpectedly; owned preview retained for inspection/stop")
        return {"ok": True, "changed": changed, "message": "Fixture window loaded; no live audio access", "status": status}

    def stop(self) -> dict:
        if not self.record.exists():
            if self.stage.exists() or self.stage.is_symlink():
                raise PreviewError("Unowned staging exists; refusing removal")
            return {"ok": True, "changed": False, "message": "No owned preview to stop"}
        if not self.stage.exists() and not self.stage.is_symlink():
            # Recovery from interrupted initial publication or completed removal.
            record = json.loads(read_regular(self.record))
            if record.get("stage") != str(self.stage) or record.get("repo") != str(self.repo) or contains_id(self.read_config()):
                raise PreviewError("Missing staging has conflicting ownership/configuration")
            self.record.unlink()
            return {"ok": True, "changed": True, "message": "Cleared interrupted preview ownership record"}
        self.load_record()
        before = self.read_config()
        self.call("hide", PLUGIN_ID)
        if contains_id(before):
            if self.call("setPluginEnabled", PLUGIN_ID, "false") != "ok":
                raise PreviewError("Host refused disable; preview files retained")
        after = self.read_config()
        if contains_id(after):
            raise PreviewError("Preview still referenced by configuration; refusing removal")
        if without_preview(before) != after:
            raise PreviewError("Unrelated configuration changed during stop; files retained for inspection/retry")
        self.call("rescanPlugins")
        # The panel must be unloaded, not merely invisible, before files go away.
        deadline = time.monotonic() + 8
        while self.call("call", PLUGIN_ID, "status", "") != "unknown":
            if time.monotonic() >= deadline:
                raise PreviewError("Host has not unloaded preview; files retained")
            time.sleep(0.1)
        self.load_record()
        shutil.rmtree(self.stage)
        self.call("rescanPlugins")
        self.record.unlink()
        return {"ok": True, "changed": True, "message": "Owned preview unloaded and removed; unrelated settings preserved"}
