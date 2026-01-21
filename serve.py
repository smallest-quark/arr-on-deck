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
import re
import json

from pathlib import Path
from urllib.parse import urlparse, parse_qs, urlencode


# when False, only run, when container not running yet
ALWAYS_RUN_START_WHEN_THIS_STARTS = False
PORT = 8000

# Marker pattern templates (use format to insert the identifier name)
_OPEN_TEMPLATE = r'<!--\s*\${name}\s*-->'
_CLOSE_TEMPLATE = r'<!--\s*/\${name}\s*-->'

def _open_pat(name: str) -> str:
    return _OPEN_TEMPLATE.format(name=re.escape(name))

def _close_pat(name: str) -> str:
    return _CLOSE_TEMPLATE.format(name=re.escape(name))


def get_block(text: str, name: str) -> str:
    pattern = re.compile(_open_pat(name) + r'(.*?)' + _close_pat(name), re.DOTALL)
    m = pattern.search(text)
    if not m:
        raise ValueError(f"{name} not found")
    return m.group(1)


def remove_block(text: str, name: str) -> str:
    pattern = re.compile("(" + _open_pat(name) + r'.*?' + _close_pat(name) + ")", re.DOTALL)
    return pattern.sub('', text)


def replace_block(text: str, name: str, new_inner: str) -> str:
    open_pat = r'(' + _open_pat(name) + r')'
    inner_pat = r'(.*?)'
    close_pat = r'(' + _close_pat(name) + r')'
    pattern = re.compile(open_pat + inner_pat + close_pat, re.DOTALL)

    def _sub(m: re.Match) -> str:
        return f"{new_inner}"

    new_text, count = pattern.subn(_sub, text, count=1)
    if count == 0:
        raise ValueError(f"{name} not found")
    return new_text


def get_path_or_none(path):
    if not path.exists():
        return None
    c = path.read_text(encoding='utf8').strip()
    if not c:
        return None

    # do not check if exists here, as path might be only available later
    return Path(c)

CWD_PATH = Path(os.path.realpath(__file__)).parent.absolute()
os.chdir(CWD_PATH)

SCRIPT_CONF_PATH = CWD_PATH / 'script_conf'
TORRENT_PORT_PATH = SCRIPT_CONF_PATH / "torrenting-port.txt"
DATA_PATH = get_path_or_none(SCRIPT_CONF_PATH / 'data-path.txt')


START_CMD = CWD_PATH / "start.sh"
STOP_CMD = CWD_PATH / "stop.sh"
ALLOWED = [START_CMD, STOP_CMD]

for i in (CWD_PATH / "cec").iterdir():
    if i.suffix == ".sh":
        ALLOWED.append(i)

for i in (CWD_PATH / "script_customize").iterdir():
    if i.suffix == ".sh":
        ALLOWED.append(i)


# Creating links

STEM_TO_HREF_AND_TEXT = {a.stem : (f'/script/{a.stem}', a.stem) for a in ALLOWED if a is not START_CMD and a is not STOP_CMD}

MAIN_HTML = (CWD_PATH / 'serve' / 'main.html').read_text(encoding='utf8')


TIME_OPENED_QUERY_NAME = 'time_opened'

TMP_SCRIPT_OUTPUT_FILE = tempfile.NamedTemporaryFile('w+', encoding='utf8')
TMP_SCRIPT_OUTPUT_PATH = Path(TMP_SCRIPT_OUTPUT_FILE.name)

FILES_TO_MIME_BINARY = {
    "style.css": ("text/css", False),
    "web-app-manifest-512x512.png": ("image/png", True),
    "web-app-manifest-192x192.png": ("image/png", True),
    "site.webmanifest": ("application/manifest+json", False),
    "favicon-96x96.png": ("image/png", True),
    "favicon.svg": ("image/svg+xml", False),
    "favicon.ico": ("image/vnd.microsoft.icon", True),
    "apple-touch-icon.png": ("image/png", True),
    "material-symbols-selection.woff2": ("font/woff2", True),
}


ENDED_MARKER = '<!-- we are finished with this script -->'


def is_podman_pod_running(pod_name: str) -> bool:
    """
    Checks if a Podman pod with the given name or ID is currently running.

    Args:
        pod_name: The name or ID of the pod to check.

    Returns:
        True if the pod is running, False otherwise.
    """
    try:
        # Run the podman pod inspect command and capture the JSON output
        # The --format is used to specifically get the State, which is more reliable
        # than parsing the general output.
        result = subprocess.run(
            ['podman', 'pod', 'inspect', '--format', '{{.State}}', pod_name],
            capture_output=True,
            text=True,
            check=True
        )
        # The output state is a single string if the command succeeds
        state = result.stdout.strip().lower()
        # The state is "running" if the pod is active
        return state == "running"

    except subprocess.CalledProcessError as e:
        # If the pod does not exist, or another error occurs, the command
        # will return a non-zero exit code.
        # We can also use 'podman pod exists' to check for existence first,
        # but inspect works for both existence and status.
        print(f"Error checking pod status: {e.stderr.strip()}")
        return False
    except FileNotFoundError:
        print("Error: 'podman' command not found. Ensure Podman is installed and in your PATH.")
        return False


def has_bash_shebang(file_path):
    with open(file_path, 'r') as file:
        first_line = file.readline().strip()  # Read the first line and strip whitespace
        if first_line == '#!/bin/bash':
            return True
        else:
            return False


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

    def _set_header(self, resp_code):
        self.send_response(resp_code)
        self.send_header("Content-type", "text/html")
        self.end_headers()

    def _write_utf8(self, text):
        self.wfile.write(str(text).encode("utf8"))

    def _write_html_ok(self, subtitle, log="", head=""):
        self._set_header(200)
        self._write_utf8(self.get_html(log=log, subtitle=subtitle, head=head))

    def _write_html_error(self, log, subtitle):
        self._set_header(500)
        self._write_utf8(self.get_html(log=log, subtitle=subtitle))

    def _write_file(self, mime_type, path=None, binary=False):
        if path is None:
            path = self.path

        if isinstance(path, str):
            path = CWD_PATH / 'serve' / path.removeprefix("/")

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
            self._write_html_error(log=e.args[0] if e.args else "", subtitle=type(e).__name__)
            return

        self._set_header(404)
        self._write_utf8('Not Found\n')

    def _has_query_param(self, param):
        return param in self.query and self.query[param]

    def add_query_str_with_open_time(self):
        self.query[TIME_OPENED_QUERY_NAME] = time.time_ns()

    def handle_get(self):
        if self.path == '/':
            self._write_html_ok(subtitle="Home")
            return True
        elif (self.path == '/media' or self.path.startswith('/media/')):
            # we do the above, so /media_test would not be handled by this
            if DATA_PATH is None or not DATA_PATH.exists():
                raise ValueError("data-path.txt does not exist or is empty - run setup.sh")

            self.path = self.path.removeprefix('/media')
            super().do_GET()
            return True
        elif self.path == '/script_log':
            c = " " + TMP_SCRIPT_OUTPUT_PATH.read_text(encoding='utf8')
            self._write_html_ok(
                log=c,
                subtitle='Script Output',
                head='' if ENDED_MARKER in c else '<meta http-equiv="Refresh" content="1">'
            )
            return True
        elif self.path.removeprefix('/') in FILES_TO_MIME_BINARY:
            mime_type, binary = FILES_TO_MIME_BINARY[self.path.removeprefix('/')]
            return self._write_file(mime_type, binary=binary)
        elif self.path.startswith("/set-port/"):
            port = self.path.removeprefix("/set-port/").strip()
            if port == "" or not port.isdigit():
                raise ValueError("You need to add an actual port number after the last slash in the URL.")
            else:
                TORRENT_PORT_PATH.write_text(port + "\n", "utf8")
                self._write_html_ok(
                    log='The updated port will come into effect once you <a href="/script/start">restart</a>.',
                    subtitle='Port Updated'
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
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,  # Merges stderr into the stdout pipe
            text=True,
            encoding='utf8',
            bufsize=1
        )

        t = threading.Thread(target=forward_stdout_to_file, args=(process, TMP_SCRIPT_OUTPUT_FILE), daemon=True)
        t.start()

        self._redirect_to('/script_log')

    def get_html(self, log="", subtitle="", head=""):
        if not subtitle:
            subtitle = "Arr-On-Deck Manager"

        # can't use format, because open braces appear in JavaScript
        html = MAIN_HTML.replace("{subtitle}", " - " + subtitle).replace('{meta}', head)

        if log:
            return remove_block(html, 'DEFAULT').replace('{log}', log.strip())
        else:
            port = TORRENT_PORT_PATH.read_text(encoding='utf8') if TORRENT_PORT_PATH.exists() else ''
            html = remove_block(html, 'LOG').replace('{port}', port)
            link_template = get_block(html, 'LINK')

            links = []
            for href, text in STEM_TO_HREF_AND_TEXT.values():
                text = '<span class="material-symbols-outlined">skull</span>' + text if 'unmount' in href else text
                classes = ' btn-danger' if 'unmount' in href else ''
                links.append(link_template.format(href=href, text=text, classes=classes))

            # replace with actual
            return replace_block(html, 'LINK', "\n".join(links))

if __name__ == '__main__':
    print(f'Scripts available: {ALLOWED}')
    time.sleep(2)

    if ALWAYS_RUN_START_WHEN_THIS_STARTS or not is_podman_pod_running('arrPod'):
        subprocess.Popen(START_CMD)

    for i in range(3):
        socketserver.TCPServer.allow_reuse_address = True
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
