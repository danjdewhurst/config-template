#!/usr/bin/env python3
"""Serve the Mac clipboard image as PNG on 127.0.0.1, for the xclip shim.

An SSH session to a Linux box forwards the box's 127.0.0.1:18339 here
(RemoteForward in ssh/config), so Ctrl+V in Claude Code on the box pastes what
was copied on the Mac. Images only: text never leaves the Mac this way. Runs
from launchd with the system python3, see clipboard-image.plist.
"""

import os
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 18339


def clipboard_png():
    """The clipboard as PNG bytes, or None when it holds no image."""
    fd, path = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    try:
        # The same AppleScript Claude Code uses on macOS. It also converts
        # TIFF (an image copied from most apps) to PNG.
        script = [
            "set png_data to (the clipboard as «class PNGf»)",
            'set fp to open for access POSIX file "%s" with write permission' % path,
            "write png_data to fp",
            "close access fp",
        ]
        args = ["/usr/bin/osascript"]
        for line in script:
            args += ["-e", line]
        done = subprocess.run(args, capture_output=True, timeout=5)
        if done.returncode != 0:
            return None
        with open(path, "rb") as f:
            data = f.read()
        return data or None
    except subprocess.TimeoutExpired:
        return None
    finally:
        os.unlink(path)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/png":
            self.send_error(404)
            return
        data = clipboard_png()
        if data is None:
            self.send_error(404, "no image on the clipboard")
            return
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
