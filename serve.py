#!/usr/bin/env python3

# kill app on port 8000
#fuser -k -n tcp 8000
#fuser -k 8000/tcp
#./serve.py

import http.server
import socketserver
import subprocess
import os
import sys
import time
import traceback
import tempfile
import threading

from pathlib import Path
from urllib.parse import urlparse, parse_qs, urlencode


def get_path_or_none(path):
    if not path.exists():
        return None
    c = path.read_text('utf8').strip()
    if not c:
        return None
    p = Path(c)
    if not p.exists() or p.is_file():
        return None
    return p


PORT = 8000

CWD_PATH = Path(os.path.realpath(__file__)).parent.absolute()
os.chdir(CWD_PATH)

SCRIPT_CONF_PATH = CWD_PATH / 'script_conf'
DATA_PATH = get_path_or_none(SCRIPT_CONF_PATH / 'data-path.txt')


START_CMD = CWD_PATH / "start.sh"
ALLOWED = [START_CMD, CWD_PATH / "stop.sh"]

for i in (CWD_PATH / "cec").iterdir():
    if i.suffix == ".sh":
        ALLOWED.append(i)

for i in (CWD_PATH / "script_customize").iterdir():
    if i.suffix == ".sh":
        ALLOWED.append(i)


# Creating links

STEM_TO_HREF_AND_TEXT = {a.stem : (f'/script/{a.stem}', a.stem) for a in ALLOWED}
STEM_TO_HREF_AND_TEXT['set-port'] = '/set-port/', 'set-port/{you have to add the port here}'


LINKS_HTML = "\n".join(f'<li><a href="{href}">{text}</a></li>' for (href, text) in STEM_TO_HREF_AND_TEXT.values())
LINKS_HTML = f'<ul>{LINKS_HTML}</ul>'


TIME_OPENED_QUERY_NAME = 'time_opened'

TMP_SCRIPT_OUTPUT_FILE = tempfile.NamedTemporaryFile('w+', encoding='utf8')
TMP_SCRIPT_OUTPUT_PATH = Path(TMP_SCRIPT_OUTPUT_FILE.name)


ENDED_MARKER = '<!-- we are finished with this script -->'


def has_bash_shebang(file_path):
    with open(file_path, 'r') as file:
        first_line = file.readline().strip()  # Read the first line and strip whitespace
        if first_line == '#!/bin/bash':
            return True
        else:
            return False

def p(c):
    return f'<p>{c}</p>'

def copy_file_stepwise(src, dst, chunk_size=64*1024):
    while True:
        # read up to chunk_size bytes
        chunk = src.read(chunk_size)
        if not chunk:
            break
        dst.write(chunk)

def forward_stdout_to_file(process, target_file):
    target_file.truncate(0)
    for line in process.stdout:
        target_file.write(line)
        target_file.flush()
    target_file.write(ENDED_MARKER)
    target_file.flush()



class MyRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs, directory=DATA_PATH)

    def _set_header(self, resp_code, is_html=False):
        self.send_response(resp_code)
        self.send_header("Content-type", "text/html" if is_html else "text/plain")
        self.end_headers()

    def _write_utf8(self, text):
        self.wfile.write(str(text).encode("utf8"))

    def _write_html_ok(self, text, subtitle, head=""):
        self._set_header(200, is_html=True)
        self._write_utf8(self.get_html(text, subtitle, head))

    def _write_html_error(self, text, subtitle):
        self._set_header(400, is_html=True)
        self._write_utf8(self.get_html(text, subtitle))

    def _write_file(self, mime_type, path=None, binary=False):
        if path is None:
            path = self.path

        if isinstance(path, str):
            path = CWD_PATH / path.removeprefix("/")

        if not path.exists():
            return False

        self.send_response(200)
        self.send_header("Content-type", mime_type)
        self.end_headers()

        if binary:
            with path.open('rb') as file:
                copy_file_stepwise(file, self.wfile)
        else:
            with path.open('r', encoding='utf8') as file:
                self.wfile.write(file.read().encode('utf8'))
        return True

    def _update_path_and_query(self):
        pu = urlparse(self.path)
        self.path = pu.path
        self.query = parse_qs(pu.query)

    def _redirect_to(self, relative_url):
       self.send_response(301)
       self.send_header('Location', relative_url)
       self.end_headers()

    def _is_too_old(self):
        time_opened = self.query[TIME_OPENED_QUERY_NAME][0]

        if not time_opened.isdigit():
            raise ValueError(f"Should have been a digit but wasn't: {time_opened}")

        if (time.time_ns() - int(time_opened)) > (10 * 10**9):
            # more than 10 seconds passed
            return True
        return False


    def do_GET(self):
        self._update_path_and_query()

        try:
            if self.handle_get() is True:
                return
        except Exception as e:
            print(traceback.format_exc())
            self._write_html_error(p(e.args[0] if e.args else ""), type(e).__name__)
            return

        self._set_header(404)
        self._write_utf8('Not Found\n')

    def _has_query_param(self, param):
        return param in self.query and self.query[param]

    def add_query_str_with_open_time(self):
        self.query[TIME_OPENED_QUERY_NAME] = time.time_ns()

    def handle_get(self):
        if self.path == '/':
            self._write_html_ok(LINKS_HTML, "Home")
            return True
        elif (self.path == '/media' or self.path.startswith('/media/')):
            # we do the above, so /media_test would not be handled by this
            if DATA_PATH is None:
                raise ValueError("data-path.txt does not exist or is empty - run setup.sh")

            self.path = self.path.removeprefix('/media')
            super().do_GET()
            return True
        elif self.path == '/script_log':
            c = TMP_SCRIPT_OUTPUT_PATH.read_text(encoding='utf8')

            self._write_html_ok(
                '<pre>' + c + '</pre>',
                subtitle='Script Output',
                head='' if ENDED_MARKER in c else '<meta http-equiv="Refresh" content="1">'
            )
            return True
        elif self.path == '/style.css':
            return self._write_file('text/css')
        elif self.path == '/favicon.ico':
            return self._write_file('image/x-icon')
        elif self.path.startswith("/set-port/"):
            port = self.path.removeprefix("/set-port/").strip()
            if port == "":
                raise ValueError("You need to add an actual port number after the last slash in the URL.")
            else:
                (SCRIPT_CONF_PATH / "torrenting-port.txt").write_text(port + "\n", "utf8")
                self._write_html_ok(
                    'The updated port will come into effect once you <a href="/script/start">restart</a>.',
                    'Port Updated'
                )
            return True
        elif not self._has_query_param(TIME_OPENED_QUERY_NAME):
            self.add_query_str_with_open_time()
            self._redirect_to(self.path + '?' + urlencode(self.query))
            return True
        elif self._is_too_old():
            raise ValueError('This was opened a while ago. To avoid accidentally triggering something, go <a href="/">back to Home</a> and click again.')

        for a in ALLOWED:
            if self.path.removeprefix("/script/") == a.stem:
                self.handle_command(a)
                return True

    def handle_command(self, command):
        """Execute a command and send the output as a response."""
        process = subprocess.Popen(command, stdout=subprocess.PIPE, text=True, encoding='utf8', bufsize=1)

        t = threading.Thread(target=forward_stdout_to_file, args=(process, TMP_SCRIPT_OUTPUT_FILE), daemon=True)
        t.start()

        self._redirect_to('/script_log')

    def get_html(self, content, subtitle="", head=""):
        st = " - " + subtitle if subtitle else ""

        return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Arr-On-Deck Manager{st}</title>
    <link rel="stylesheet" href="/style.css">
    {head}
</head>
<body>
    <main class="center">
        <section class="card">
            <h1>Arr-On-Deck Manager{st}</h1>
{content}
        </section>
    </main>
</body>
</html>
        """

if __name__ == '__main__':
    print(f'Scripts available: {ALLOWED}')
    time.sleep(2)
    subprocess.Popen(START_CMD)

    for i in range(3):
        with socketserver.TCPServer(("", PORT), MyRequestHandler) as httpd:
            print(f"Serving on port {PORT}")
            try:
                httpd.serve_forever()
            finally:
                httpd.shutdown()
                httpd.server_close() # Close also the socket.
                TMP_SCRIPT_OUTPUT_FILE.close()
                sys.exit(0)
        time.sleep(3)
