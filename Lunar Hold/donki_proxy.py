#!/usr/bin/env python3
"""IPv4 bridge to NASA CCMC DONKI.

GameMaker's HTTP client can stall on the IPv6 route to ccmc.gsfc.nasa.gov.
This proxy answers on 127.0.0.1:8771 and fetches with curl -4.
Paths: /FLR  /CME  /SEP
"""

import json
import subprocess
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 8771
KINDS = {"FLR", "CME", "SEP"}


def donki_url(kind: str) -> str:
    end = date.today()
    start = end - timedelta(days=59)
    url = (
        "https://ccmc.gsfc.nasa.gov/DONKI-API/get/"
        + kind
        + "?startDate="
        + start.isoformat()
        + "&endDate="
        + end.isoformat()
    )
    if kind == "CME":
        url += "&mostAccurateOnly=true"
    return url


def fetch(kind: str) -> bytes:
    url = donki_url(kind)
    return subprocess.check_output(
        ["curl", "-4", "-fsS", "--max-time", "40", url],
        stderr=subprocess.STDOUT,
    )


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        kind = self.path.strip("/").split("?")[0].upper()
        if kind not in KINDS:
            body = b'{"error":"use /FLR /CME or /SEP"}'
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        try:
            body = fetch(kind)
            json.loads(body)
        except Exception as exc:
            msg = json.dumps({"error": str(exc)[:300]}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("donki-proxy", self.address_string(), fmt % args)


if __name__ == "__main__":
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"DONKI IPv4 proxy on http://{HOST}:{PORT}")
    httpd.serve_forever()
