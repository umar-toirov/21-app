"""Same-origin reverse proxy for local Flutter web + FastAPI.

Serves the app and the API on one origin (default :8090) so the browser never
makes a cross-port request:
  /v1/*  -> http://127.0.0.1:8001/v1/*
  /*     -> http://127.0.0.1:8091/*   (flutter web-server)

Also provides SPA fallback so OAuth redirects like /auth/callback load the app.

Usage (after backend + flutter web-server are running):
  python mobile/tools/same_origin_proxy.py
Then open http://127.0.0.1:8090
"""

from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

FLUTTER = "http://127.0.0.1:8091"
API = "http://127.0.0.1:8001"
HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "content-encoding",
    "content-length",
}

_ASSET_SUFFIXES = (
    ".js",
    ".css",
    ".map",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".svg",
    ".ico",
    ".woff",
    ".woff2",
    ".ttf",
    ".json",
    ".wasm",
)


def _looks_like_asset(path: str) -> bool:
    clean = urlsplit(path).path.lower()
    return any(clean.endswith(s) for s in _ASSET_SUFFIXES) or clean.startswith(
        ("/packages/", "/assets/", "/canvaskit/", "/icons/")
    )


class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        print(f"[proxy] {self.address_string()} - {fmt % args}")

    def _target(self, path: str | None = None) -> str:
        path = path or self.path
        if path.startswith("/v1"):
            return API + path
        return FLUTTER + path

    def _forward(self, url: str, body: bytes | None, headers: dict[str, str]) -> tuple[int, dict[str, str], bytes]:
        req = Request(url, data=body, headers=headers, method=self.command)
        with urlopen(req, timeout=60) as resp:
            data = resp.read()
            out_headers = {k: v for k, v in resp.headers.items() if k.lower() not in HOP_BY_HOP}
            return resp.status, out_headers, data

    def _proxy(self) -> None:
        length = int(self.headers.get("Content-Length", "0") or 0)
        body = self.rfile.read(length) if length > 0 else None
        headers = {
            k: v
            for k, v in self.headers.items()
            if k.lower() not in HOP_BY_HOP and k.lower() != "host"
        }
        try:
            status, out_headers, data = self._forward(self._target(), body, headers)
        except HTTPError as e:
            data = e.read()
            status = e.code
            out_headers = {}
            # SPA fallback: OAuth returns to /auth/callback — serve the Flutter app shell.
            if (
                self.command in ("GET", "HEAD")
                and status == 404
                and not self.path.startswith("/v1")
                and not _looks_like_asset(self.path)
            ):
                try:
                    status, out_headers, data = self._forward(self._target("/"), None, headers)
                except Exception as fallback_err:
                    msg = f"Upstream unavailable: {fallback_err}".encode()
                    self.send_response(502)
                    self.send_header("Content-Type", "text/plain")
                    self.send_header("Content-Length", str(len(msg)))
                    self.end_headers()
                    self.wfile.write(msg)
                    return
        except URLError as e:
            msg = f"Upstream unavailable: {e}".encode()
            self.send_response(502)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            return

        self.send_response(status)
        for k, v in out_headers.items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def do_GET(self) -> None:
        self._proxy()

    def do_POST(self) -> None:
        self._proxy()

    def do_PUT(self) -> None:
        self._proxy()

    def do_PATCH(self) -> None:
        self._proxy()

    def do_DELETE(self) -> None:
        self._proxy()

    def do_OPTIONS(self) -> None:
        self._proxy()

    def do_HEAD(self) -> None:
        self._proxy()


def main() -> None:
    global FLUTTER, API
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8090)
    parser.add_argument("--flutter-port", type=int, default=8091)
    parser.add_argument("--api-port", type=int, default=8001)
    # 0.0.0.0 lets a phone on the same Wi-Fi open the app.
    parser.add_argument("--host", default="0.0.0.0")
    args = parser.parse_args()
    FLUTTER = f"http://127.0.0.1:{args.flutter_port}"
    API = f"http://127.0.0.1:{args.api_port}"
    server = ThreadingHTTPServer((args.host, args.port), ProxyHandler)
    print(f"Same-origin proxy listening on {args.host}:{args.port}")
    print(f"  /v1 -> {API}")
    print(f"  /*  -> {FLUTTER}")
    server.serve_forever()


if __name__ == "__main__":
    main()
