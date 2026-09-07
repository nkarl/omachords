"""Run the real adapter inside an isolated, headless Quickshell instance."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="omachords-engine-test-") as temporary:
    directory = Path(temporary)
    shutil.copy(repo / "EngineAdapter.qml", directory / "EngineAdapter.qml")
    shutil.copy(repo / "tests/engineadapter.qml", directory / "shell.qml")
    shutil.copytree(repo / "tests/fixtures", directory / "fixtures")
    environment = dict(
        os.environ,
        QT_QPA_PLATFORM="offscreen",
        QT_QPA_PLATFORMTHEME="",
        QT_QUICK_CONTROLS_STYLE="Basic",
        XDG_RUNTIME_DIR=temporary,
        XDG_CACHE_HOME=temporary,
    )
    environment.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(
        ["quickshell", "--no-color", "-p", str(directory / "shell.qml")],
        env=environment,
        capture_output=True,
        text=True,
        timeout=45,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    reports = re.findall(r"ENGINE_ADAPTER_RESULT (\{[^\n]+\})", output)
    if result.returncode != 0 or len(reports) != 1:
        raise SystemExit("EngineAdapter tests did not complete successfully")
    report = json.loads(reports[0])
    if report["failed"] or report["skipped"] or report["passed"] < 8:
        raise SystemExit(f"EngineAdapter tests failed: {report}")
