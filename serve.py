#!/usr/bin/env python3

# kill app on port 8000
#fuser -k 8000/tcp
#./serve.py

import http.server
import socketserver
import subprocess
import os
import sys
from pathlib import Path
import time


cwd = Path(os.path.realpath(__file__)).parent.absolute()
os.chdir(cwd)


PORT = 8000


def has_bash_shebang(file_path):
    with open(file_path, 'r') as file:
        first_line = file.readline().strip()  # Read the first line and strip whitespace
        if first_line == '#!/bin/bash':
            return True
        else:
            return False


START_CMD = cwd / "start.sh"
ALLOWED = [START_CMD, cwd / "stop.sh"]

for i in (cwd / "cec").iterdir():
    if i.suffix == ".sh":
        ALLOWED.append(i)

for i in (cwd / "script_customize").iterdir():
    if i.suffix == ".sh":
        ALLOWED.append(i)

print(f'Scripts available: {ALLOWED}')

time.sleep(2)

subprocess.Popen(START_CMD)

class MyRequestHandler(http.server.SimpleHTTPRequestHandler):
    # TODO: use <meta http-equiv="refresh" content="0; url=http://example.com/" /> to direct to /log
    # TODO: make it harder to accidentally trigger /start by including an UTC timestamp
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(self.get_home_page().encode())
            return
        elif self.path.startswith("/set-port/"):
            port = self.path.removeprefix("/set-port/").strip()
            if port != "":
                (cwd / "script_conf/torrenting-port.txt").write_text(port + "\n")

        for a in ALLOWED:
            if self.path.removeprefix("/script/") == a.stem:
                try:
                    self.handle_command(a)
                except Exception as e:
                    print(e)
                return

        self.send_response(404)
        self.end_headers()
        self.wfile.write(b'Not Found\n')

    def handle_command(self, command):
        """Execute a command and send the output as a response."""
        try:
            self.send_response(200)
            self.send_header("Content-type", "text/plain") #"application/octet-stream")
            self.end_headers()

            if not has_bash_shebang(command):
                print(f'{command} must start with a line like this: #!/bin/bash')

            process = subprocess.Popen(command, stdout=subprocess.PIPE)
            if command.stem == "start":
                # takes too long and then causes problems
                return
            for c in iter(lambda: process.stdout.read(1), b""):
                self.wfile.write(c)
        except Exception as e:
            print(e)
            self.wfile.write(bytes(str(e), "utf8"))
            self.send_response(400)

    def get_home_page(self):
        """Return the HTML for the home page with links to start and stop."""
        links = "\n".join(f'<p><a href="/script/{a.stem}">{a.stem}</a></p>' for a in ALLOWED)
        links += '\n<p></p><p><a href="/set-port/">set-port/{you have to add the port here}</a></p>'
        return f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Arr-On-Deck Manager</title>
        </head>
        <body>
            <h1>Arr-On-Deck Manager</h1>
            {links}
        </body>
        </html>
        """

for i in range(3):
    with socketserver.TCPServer(("", PORT), MyRequestHandler) as httpd:
        print(f"Serving on port {PORT}")
        try:
            httpd.serve_forever()
        finally:
            httpd.shutdown()
            httpd.server_close() # Close also the socket.
            sys.exit(0)
    time.sleep(3)
