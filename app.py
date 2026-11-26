import os
from http.server import BaseHTTPRequestHandler, HTTPServer
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        message = os.getenv('APP_MESSAGE', 'AI App works!')
        os.makedirs('/app/logs', exist_ok=True)
        with open('/app/logs/access.log', 'a') as log:
            log.write(self.path + '\n')
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.end_headers()
        self.wfile.write(message.encode())
HTTPServer(('0.0.0.0', int(os.getenv('APP_PORT', '8000'))), Handler).serve_forever()
