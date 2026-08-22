"""Disposable stdin-controlled TCP server used by server-tool test harnesses."""

from __future__ import annotations

import argparse
import socket
import sys
import time
from pathlib import Path


def append_log(path: Path, line: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(line + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server-root", required=True)
    parser.add_argument("--port", required=True, type=int)
    args = parser.parse_args()
    root = Path(args.server_root).resolve()
    if args.port == 25565 or "server-infrastructure-test" not in str(root).lower():
        raise SystemExit("refusing non-disposable root or production port")

    count_path = root / "server-management" / "fake-launch-count.txt"
    count_path.parent.mkdir(parents=True, exist_ok=True)
    count = int(count_path.read_text(encoding="ascii")) + 1 if count_path.exists() else 1
    count_path.write_text(str(count), encoding="ascii")
    if (root / "fail-always.flag").exists() or ((root / "fail-first.flag").exists() and count == 1):
        return 37

    latest = root / "logs" / "latest.log"
    append_log(latest, f"[Server thread/INFO] [minecraft/DedicatedServer]: Done (0.123s)! Test launch {count}")
    print(f"[Fake Minecraft] Done (0.123s)! Test launch {count}", flush=True)
    print(f"[Fake Minecraft stderr] Java console stream test launch {count}", file=sys.stderr, flush=True)
    command_log = root / "server-management" / "fake-commands.log"
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", args.port))
    listener.listen(4)
    listener.settimeout(0.2)
    try:
        if (root / "self-stop-clean.flag").exists():
            # Simulates Minecraft's Swing-window close handler: the server owns
            # the shutdown rather than receiving `stop` from the supervisor.
            time.sleep(3)
            append_log(latest, "[Server thread/INFO] [minecraft/MinecraftServer]: Stopping server")
            append_log(latest, "[Server thread/INFO] [minecraft/MinecraftServer]: Saving players")
            append_log(latest, "[Server thread/INFO] [minecraft/MinecraftServer]: Saving worlds")
            append_log(latest, "[Server thread/INFO] [minecraft/MinecraftServer]: ThreadedAnvilChunkStorage: All dimensions are saved")
            return 0
        for line in sys.stdin:
            command = line.strip()
            append_log(command_log, command)
            print(f"[Fake Minecraft command] {command}", flush=True)
            if command.lower() != "stop":
                continue
            append_log(latest, "[Server thread/INFO] [minecraft/MinecraftServer]: Saving players")
            append_log(latest, "[Server thread/INFO] [minecraft/MinecraftServer]: Saving worlds")
            append_log(latest, "[Server thread/INFO] [minecraft/ThreadedAnvilChunkStorage]: All dimensions are saved")
            listener.close()
            if (root / "linger-on-stop.flag").exists():
                time.sleep(120)
            return 0
        if (root / "linger-on-stdin-eof.flag").exists():
            # Abrupt-supervisor regression mode: keep the disposable listener
            # alive after its inherited stdin pipe closes so management can
            # prove that an orphan is reported but never force-killed.
            append_log(latest, "[Server thread/WARN] [test]: Supervisor stdin closed; disposable orphan mode remains active")
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline:
                try:
                    connection, _ = listener.accept()
                    connection.close()
                except socket.timeout:
                    pass
    finally:
        try:
            listener.close()
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
