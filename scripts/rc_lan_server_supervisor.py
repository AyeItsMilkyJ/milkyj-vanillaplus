#!/usr/bin/env python3
"""Own a disposable LAN-test server process and stop it through its console."""

from __future__ import annotations

import argparse
import json
import subprocess
import time
from datetime import datetime
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server-root", type=Path, required=True)
    parser.add_argument("--java", required=True)
    parser.add_argument("--stop-file", type=Path, required=True)
    parser.add_argument("--process-info", type=Path, required=True)
    parser.add_argument("--stdout", type=Path, required=True)
    parser.add_argument("--stderr", type=Path, required=True)
    args = parser.parse_args()
    root = args.server_root.resolve()
    for path in (args.stop_file, args.process_info, args.stdout, args.stderr):
        path.parent.mkdir(parents=True, exist_ok=True)
    args.stop_file.unlink(missing_ok=True)
    command = [
        args.java,
        "@user_jvm_args.txt",
        "@libraries/net/minecraftforge/forge/1.20.1-47.4.10/win_args.txt",
        "nogui",
    ]
    with args.stdout.open("w", encoding="utf-8") as stdout, args.stderr.open("w", encoding="utf-8") as stderr:
        process = subprocess.Popen(command, cwd=root, stdin=subprocess.PIPE, stdout=stdout, stderr=stderr, text=True)
        args.process_info.write_text(json.dumps({
            "pid": process.pid,
            "startedAt": datetime.now().astimezone().isoformat(),
            "serverRoot": str(root),
        }, indent=2) + "\n", encoding="utf-8")
        stop_requested = False
        while process.poll() is None:
            if args.stop_file.exists() and not stop_requested:
                stop_requested = True
                assert process.stdin is not None
                process.stdin.write("stop\n")
                process.stdin.flush()
            time.sleep(0.5)
        return process.returncode or 0


if __name__ == "__main__":
    raise SystemExit(main())
