#!/usr/bin/env python3
"""Expose only the freshness of the local monitoring run."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import os
import time

STAMP = Path(os.environ["XDG_RUNTIME_DIR"]) / "bazzite-monitoring/last-run"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/healthz":
            self.send_error(404)
            return
        try:
            age = time.time() - int(STAMP.read_text().strip())
            healthy = 0 <= age < 720
        except (OSError, ValueError):
            healthy = False
        body = b"ok\n" if healthy else b"stale\n"
        self.send_response(200 if healthy else 503)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


HTTPServer(("127.0.0.1", 8297), Handler).serve_forever()
