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
        out = open(os.path.join(ROOT, name), "wb")
        got = 0
        if "chunked" in self.headers.get("Transfer-Encoding", "").lower():
            # OpenWrt uclient-fetch --post-file chunked gonderir
            while True:
                size = int(self.rfile.readline().split(b";")[0].strip() or b"0", 16)
                if size == 0:
                    self.rfile.readline()
                    break
                out.write(self.rfile.read(size)); got += size
                self.rfile.readline()
        else:
            remaining = int(self.headers.get("Content-Length", 0))
            while remaining > 0:
                chunk = self.rfile.read(min(65536, remaining))
                if not chunk:
                    break
                out.write(chunk); got += len(chunk); remaining -= len(chunk)
        out.close()
        print(f"alindi: {name} ({got} bayt)")
        self.send_response(201); self.end_headers()

    do_POST = do_PUT  # OpenWrt: uclient-fetch --post-file


if __name__ == "__main__":
    print(f"Dinleniyor: 0.0.0.0:8000  klasor: {ROOT}")
    HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
