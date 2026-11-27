import os
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = self.path.split('?', 1)[0]
        message = os.getenv('APP_MESSAGE', 'AI App works after GitHub Actions!')
        log_dir = os.getenv('APP_LOG_DIR', '/app/logs')
        os.makedirs(log_dir, exist_ok=True)
        with open(os.path.join(log_dir, 'access.log'), 'a') as log:
            log.write(self.path + '\n')
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.end_headers()
        if route == '/health':
            self.wfile.write(b'OK')
            return
        self.wfile.write(message.encode())


def create_server():
    return HTTPServer(('0.0.0.0', int(os.getenv('APP_PORT', '8000'))), Handler)


if __name__ == '__main__':
    create_server().serve_forever()
