#!/usr/bin/env python3
"""Disposable loopback-only Discord webhook recorder for server-tool tests."""

from __future__ import annotations

import argparse
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--responses", default="200", help="Comma-separated HTTP status sequence; the last status repeats.")
    args = parser.parse_args()
    response_statuses = [int(value.strip()) for value in args.responses.split(",") if value.strip()]
    if not response_statuses or any(value < 100 or value > 599 for value in response_statuses):
        raise ValueError("--responses must contain HTTP status codes")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_lock = threading.Lock()
    request_count = 0

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self) -> None:  # noqa: N802
            nonlocal request_count
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length)
            try:
                body = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                self.send_error(400)
                return
            record = json.dumps({"path": self.path, "body": body}, ensure_ascii=False)
            with write_lock:
                request_index = request_count
                request_count += 1
                with args.output.open("a", encoding="utf-8", newline="\n") as stream:
                    stream.write(record + "\n")
            status = response_statuses[min(request_index, len(response_statuses) - 1)]
            response = b'{"id":"disposable-test-message"}' if 200 <= status < 300 else b'{"message":"disposable failure"}'
            self.send_response(status)
            if status == 429:
                self.send_header("Retry-After", "0.1")
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)

        def log_message(self, _format: str, *_args: object) -> None:
            return

    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
