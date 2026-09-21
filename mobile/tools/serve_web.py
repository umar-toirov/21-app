"""Serve the built Flutter web app (build/web) on 127.0.0.1:5210 with path-URL support.

Usage (from mobile/):
    flutter build web --release --dart-define-from-file=env.json
    python tools/serve_web.py            # then open http://127.0.0.1:5210

Works in a normal browser and in VS Code's Simple Browser (unlike `flutter run`'s
dev server, which needs its debug connection). Unknown paths fall back to
index.html so /auth/callback and page refreshes work.
"""

import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 5210


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):
        path = self.translate_path(self.path.split("?", 1)[0])
        if not os.path.exists(path) or os.path.isdir(path) and not os.path.exists(
            os.path.join(path, "index.html")
        ):
            self.path = "/index.html"
        return super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


if __name__ == "__main__":
    print(f"Serving {os.path.normpath(ROOT)} on http://127.0.0.1:{PORT}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
