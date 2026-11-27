import threading
from http.server import HTTPServer
from urllib.request import urlopen

from app import Handler


def test_index(monkeypatch, tmp_path):
    monkeypatch.delenv('APP_MESSAGE', raising=False)
    monkeypatch.setenv('APP_LOG_DIR', str(tmp_path))
    server = HTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with urlopen(f'http://127.0.0.1:{server.server_port}/') as response:
            assert response.status == 200
            assert response.headers['Content-Type'] == 'text/plain; charset=utf-8'
            assert response.read() == b'AI App works after GitHub Actions!'
        assert (tmp_path / 'access.log').read_text() == '/\n'
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
