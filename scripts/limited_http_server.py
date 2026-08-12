import argparse
import functools
import http.server
import socketserver
import threading


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, _format, *args):
        pass


class LimitedThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    request_queue_size = 1024

    def __init__(self, *args, max_workers=32, **kwargs):
        self._worker_slots = threading.BoundedSemaphore(max_workers)
        super().__init__(*args, **kwargs)

    def process_request(self, request, client_address):
        self._worker_slots.acquire()
        try:
            super().process_request(request, client_address)
        except Exception:
            self._worker_slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self._worker_slots.release()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--directory", required=True)
    parser.add_argument("--workers", type=int, default=32)
    args = parser.parse_args()
    handler = functools.partial(QuietHandler, directory=args.directory)
    server = LimitedThreadingHTTPServer(
        (args.bind, args.port), handler, max_workers=args.workers
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
