#!/usr/bin/env python3
"""Router'dan gelen dosyalari (curl -T) kabul eden basit HTTP sunucu.
Kullanim: dump.sh ile ayni klasorde  ->  python put_server.py
Dosyalar bu script'in bulundugu klasore kaydedilir. Port: 8000
"""
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(ROOT)


class Handler(SimpleHTTPRequestHandler):
    def do_PUT(self):
        name = os.path.basename(self.path.split("?")[0])
        if not name:
            self.send_response(400); self.end_headers(); return
        length = int(self.headers.get("Content-Length", 0))
        remaining = length
        with open(os.path.join(ROOT, name), "wb") as f:
            while remaining > 0:
                chunk = self.rfile.read(min(65536, remaining))
                if not chunk:
                    break
                f.write(chunk)
                remaining -= len(chunk)
        print(f"alindi: {name} ({length - remaining} bayt)")
        self.send_response(201); self.end_headers()


if __name__ == "__main__":
    print(f"Dinleniyor: 0.0.0.0:8000  klasor: {ROOT}")
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
