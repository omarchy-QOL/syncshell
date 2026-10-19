"""Disposable Syncthing API with recorded mutations and explicit failure injection."""
import http.server
import json
import threading
import time
from urllib.parse import parse_qs, unquote, urlsplit


def device_id(letter):
    return '-'.join([letter * 7] * 8)


class FakeSyncthing:
    def __init__(self, work):
        self.work = work
        self.key = 'isolated-fixture-api-key'
        self.local, self.peer, self.pending, self.new, self.dismiss = map(device_id, 'ABCDE')
        self.data = work / 'data'
        self.data.mkdir()
        (self.data / 'nested').mkdir()
        self.sentinel = self.data / 'keep.txt'
        self.sentinel.write_text('user files survive forgetting\n')
        (work / 'offered').mkdir()
        self.assets = work / 'gui'
        self.assets.mkdir()
        (self.assets / 'another-adapter').mkdir()
        self.folders = {'folder': {'id': 'folder', 'label': 'Fixture', 'path': str(self.data),
                                  'paused': False, 'devices': [{'deviceID': self.local}]}}
        self.devices = {self.local: {'deviceID': self.local, 'name': 'Local'},
                        self.peer: {'deviceID': self.peer, 'name': 'Peer', 'paused': False}}
        self.pending_devices = {self.pending: {'name': 'Pending', 'address': 'tcp://pending'},
                                self.dismiss: {'name': 'Dismiss me', 'address': 'tcp://dismiss'}}
        self.pending_folders = {'offered': {'offeredBy': {
            self.peer: {'label': 'Offered folder', 'receiveEncrypted': False}}},
            'dismiss-offer': {'offeredBy': {
                self.peer: {'label': 'Same offer', 'receiveEncrypted': False},
                self.pending: {'label': 'Same offer', 'receiveEncrypted': False}}}}
        self.theme = 'default'
        self.errors = True
        self.profile_failures = 1
        self.mutations = []
        self.lock = threading.RLock()
        fixture = self

        class API(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, value, status=200):
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                try:
                    self.wfile.write(json.dumps(value).encode())
                except BrokenPipeError:
                    pass

            def handle_request(self):
                url = urlsplit(self.path)
                path, query = url.path, parse_qs(url.query)
                if path == '/rest/noauth/health':
                    return self.reply({'status': 'OK'})
                if self.headers.get('X-API-Key') != fixture.key:
                    return self.reply({}, 403)
                if path == '/rest/events':
                    time.sleep(.05)
                    return self.reply([])
                with fixture.lock:
                    if self.command == 'GET':
                        responses = {
                            '/rest/system/status': {'myID': fixture.local, 'tilde': str(work)},
                            '/rest/system/version': {'version': 'v2.1.3'},
                            '/rest/config/devices': list(fixture.devices.values()),
                            '/rest/config/folders': list(fixture.folders.values()),
                            '/rest/config/defaults/folder': {'type': 'sendreceive', 'rescanIntervalS': 3600},
                            '/rest/config/defaults/device': {'addresses': ['dynamic'], 'compression': 'metadata'},
                            '/rest/system/connections': {'connections': {key: {'connected': True, 'address': 'tcp://fixture'}
                                                                        for key in fixture.devices}},
                            '/rest/db/status': {'state': 'idle', 'globalFiles': 1, 'globalBytes': 35,
                                                'pullErrors': 1 if fixture.errors and query.get('folder') == ['folder'] else 0},
                            '/rest/db/completion': {'remoteState': 'valid'},
                            '/rest/folder/errors': {'errors': [{'path': 'keep.txt', 'error': 'Retry fixture'}]
                                                   if fixture.errors and query.get('folder') == ['folder'] else []},
                            '/rest/cluster/pending/folders': fixture.pending_folders,
                            '/rest/cluster/pending/devices': fixture.pending_devices,
                            '/rest/system/discovery': {fixture.new: {'addresses': ['tcp://nearby']}},
                            '/rest/config/gui': {'theme': fixture.theme},
                            '/rest/svc/random/string': {'random': 'generated1'},
                            '/rest/system/paths': {'guiAssets': str(fixture.assets), 'baseDir-userHome': str(work)},
                        }
                        if path.startswith('/rest/config/folders/'):
                            return self.reply(fixture.folders.get(unquote(path.rsplit('/', 1)[1]), {}))
                        if path.startswith('/rest/config/devices/'):
                            return self.reply(fixture.devices.get(unquote(path.rsplit('/', 1)[1]), {}))
                        if path in responses:
                            return self.reply(responses[path])
                        return self.reply({}, 404)
                    raw = self.rfile.read(int(self.headers.get('Content-Length', '0')))
                    data = json.loads(raw) if raw else {}
                    fixture.mutations.append({'method': self.command, 'path': path, 'query': query, 'data': data})
                    if self.command == 'PATCH':
                        if path == '/rest/config/gui':
                            if fixture.profile_failures and data['theme'].endswith('-modern'):
                                fixture.profile_failures -= 1
                                return self.reply({'error': 'Injected profile failure'}, 500)
                            fixture.theme = data['theme']
                        elif path.startswith('/rest/config/folders/'):
                            fixture.folders[unquote(path.rsplit('/', 1)[1])].update(data)
                        elif path.startswith('/rest/config/devices/'):
                            fixture.devices[unquote(path.rsplit('/', 1)[1])].update(data)
                        else:
                            return self.reply({}, 404)
                    elif self.command == 'POST':
                        if path == '/rest/db/scan':
                            fixture.errors = False
                        elif path == '/rest/config/folders':
                            fixture.folders[data['id']] = data
                            offer = fixture.pending_folders.get(data['id'])
                            if offer:
                                for member in data['devices']:
                                    offer['offeredBy'].pop(member['deviceID'], None)
                                if not offer['offeredBy']:
                                    fixture.pending_folders.pop(data['id'])
                        elif path == '/rest/config/devices':
                            fixture.devices[data['deviceID']] = data
                            fixture.pending_devices.pop(data['deviceID'], None)
                        else:
                            return self.reply({}, 404)
                    elif self.command == 'DELETE':
                        if path.startswith('/rest/config/folders/'):
                            fixture.folders.pop(unquote(path.rsplit('/', 1)[1]))
                        elif path.startswith('/rest/config/devices/'):
                            fixture.devices.pop(unquote(path.rsplit('/', 1)[1]))
                        elif path == '/rest/cluster/pending/devices':
                            fixture.pending_devices.pop(query['device'][0])
                        elif path == '/rest/cluster/pending/folders':
                            offer = fixture.pending_folders[query['folder'][0]]
                            offer['offeredBy'].pop(query['device'][0])
                            if not offer['offeredBy']:
                                fixture.pending_folders.pop(query['folder'][0])
                        else:
                            return self.reply({}, 404)
                    self.reply({})
            do_GET = handle_request
            do_PATCH = handle_request
            do_POST = handle_request
            do_DELETE = handle_request

        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), API)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.config = work / 'config.xml'
        self.config.write_text(f'<configuration><gui><address>127.0.0.1:{self.server.server_port}</address>'
                               f'<apikey>{self.key}</apikey></gui></configuration>')
        self.config.chmod(0o600)

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
