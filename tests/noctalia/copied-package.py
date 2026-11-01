#!/usr/bin/env python3
"""Exercise a copied binary and recovery command against an isolated fake API."""
import http.server
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.parse

with tempfile.TemporaryDirectory(prefix="syncshell-noctalia-copy-") as temporary:
    root = pathlib.Path(temporary)
    package = root / "package with ' quote"
    shutil.copytree(pathlib.Path(sys.argv[1]).resolve(), package)
    data = root / "data"
    data.mkdir(mode=0o700)
    assets = root / "gui"
    assets.mkdir()
    config = root / "config.xml"
    theme = "syncshell-noctalia-modern"
    own = assets / theme
    own.mkdir()
    (own / ".syncshell-profile.json").write_text('{"owner":"noctalia"}')
    other = assets / "another-adapter"
    other.mkdir()

    class API(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            path = urllib.parse.urlsplit(self.path).path
            assert path == "/rest/noauth/health" or self.headers["X-API-Key"] == "fixture-key"
            responses = {
                "/rest/noauth/health": {"status": "OK"},
                "/rest/system/status": {"myID": "LOCAL"},
                "/rest/system/version": {"version": "v2.1.3"},
                "/rest/config/devices": [], "/rest/config/folders": [],
                "/rest/system/connections": {"connections": {}},
                "/rest/cluster/pending/folders": {}, "/rest/cluster/pending/devices": {},
                "/rest/system/discovery": {}, "/rest/config/gui": {"theme": theme},
                "/rest/system/paths": {"config": str(config), "guiAssets": str(assets)},
            }
            self.send_response(200 if path in responses else 404)
            self.end_headers()
            self.wfile.write(json.dumps(responses.get(path, {})).encode())

        def do_PATCH(self):
            global theme
            assert self.path == "/rest/config/gui"
            theme = json.loads(self.rfile.read(int(self.headers["Content-Length"])))['theme']
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{}')

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), API)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    config.write_text(f'<configuration><gui><address>http://127.0.0.1:{server.server_port}</address>'
                      '<apikey>fixture-key</apikey></gui></configuration>')
    config.chmod(0o600)
    binary = package / "bin/syncshell-core"
    args = ["--config", str(config), "--web-profile-authorized", "--web-profile-owner", "noctalia",
            "--web-profile-bundle", str(package / "webui")]
    subprocess.run([str(binary), "native-browse", str(root)], check=True, stdout=subprocess.DEVNULL, cwd=root)
    subprocess.run([str(binary), "native-save-cleanup", str(data), *args], check=True, cwd=root)
    cleanup = data / "syncshell-noctalia-cleanup/cleanup.sh"
    assert cleanup.stat().st_mode & 0o777 == 0o700
    assert "fixture-key" not in cleanup.read_text()
    shutil.rmtree(package)
    try:
        for _ in range(2):
            result = subprocess.run([str(cleanup)], check=True, capture_output=True, text=True, cwd=root, timeout=15)
            assert json.loads(result.stdout)["ok"]
        assert theme == "default" and not own.exists() and other.is_dir()
    finally:
        server.shutdown()
        server.server_close()
print("Copied package and post-deletion idempotent cleanup checks passed")
