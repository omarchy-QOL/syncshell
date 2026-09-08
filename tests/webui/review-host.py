"""Run the existing conflict review handler against a marked port fixture."""
import argparse
import http.client
import importlib.util
from pathlib import Path
from urllib.parse import urlsplit
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('handler', type=Path)
parser.add_argument('runtime', type=Path)
parser.add_argument('--port', type=int, required=True)
parser.add_argument('--api-port', type=int, required=True)
args = parser.parse_args()
if not (args.runtime / '.syncshell-port-fixture').is_file():
    raise SystemExit('Unmarked test runtime')
spec = importlib.util.spec_from_file_location('existing_review', args.handler)
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)
review.ROOT = args.runtime
review.FILES = args.runtime / 'files'
review.PORT = args.port
review.ORIGIN = f'http://127.0.0.1:{args.port}'
review.FOLDER = 'port-verification'
review.API_PORT = args.api_port
config = ET.parse(args.runtime / 'home/config.xml')
if config.findtext('gui/address') != f'127.0.0.1:{args.api_port}':
    raise SystemExit('GUI port does not match the marked runtime')
if Path(config.findtext("folder[@id='port-verification']/path", '')).resolve() != review.FILES.resolve():
    raise SystemExit('Folder path does not match the marked runtime')
review.API_KEY = config.findtext('gui/apikey')
(args.runtime / 'evidence').mkdir(exist_ok=True)

class PortReview(review.Review):
    def proxy(self):
        if not self.valid_host():
            return self.send(403, {'error': 'Wrong host'})
        if self.command != 'GET' and self.headers.get('Origin') != review.ORIGIN:
            return self.send(403, {'error': 'Wrong origin'})
        conn = http.client.HTTPConnection('127.0.0.1', args.api_port, timeout=90)
        try:
            headers = {key: value for key, value in self.headers.items()
                       if key.lower() not in ('host', 'connection', 'content-length', 'accept-encoding')}
            headers['Host'] = f'127.0.0.1:{args.api_port}'
            headers['Accept-Encoding'] = 'identity'
            for name in ('Origin', 'Referer'):
                if headers.get(name, '').startswith(review.ORIGIN):
                    headers[name] = f'http://127.0.0.1:{args.api_port}' + headers[name][len(review.ORIGIN):]
            size = int(self.headers.get('Content-Length', '0'))
            body = self.rfile.read(size) if size else None
            conn.request(self.command, self.path, body=body, headers=headers)
            response = conn.getresponse()
            data = response.read()
            kind = response.getheader('Content-Type', 'application/octet-stream')
            if urlsplit(self.path).path in ('/', '/index.html') and response.status == 200:
                data = data.replace(b'</head>',
                    (f'<meta name="review-token" content="{review.TOKEN}">'
                     '<script src="/review/host-actions.js"></script></head>').encode())
            cookies = [value for key, value in response.getheaders() if key.lower() == 'set-cookie']
            return self.send(response.status, data, kind, cookies)
        except OSError:
            return self.send(502, {'error': 'Test Syncthing instance unavailable'})
        finally:
            conn.close()

    def do_GET(self):
        if urlsplit(self.path).path == '/review/host-actions.js':
            if not self.valid_host():
                return self.send(403, {'error': 'Wrong host'})
            return self.send(200, Path(__file__).with_name('review-host-actions.js').read_bytes(), 'text/javascript')
        if self.path.startswith('/review/'):
            return super().do_GET()
        return self.proxy()

    def do_POST(self):
        if self.path.startswith('/review/'):
            return super().do_POST()
        return self.proxy()

    do_PUT = proxy
    do_PATCH = proxy
    do_DELETE = proxy

review.ThreadingHTTPServer(('127.0.0.1', args.port), PortReview).serve_forever()
