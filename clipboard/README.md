# Paste images into Claude Code over SSH

Claude Code on a headless Linux box can't read your Mac's clipboard, so Ctrl+V with a screenshot does nothing. These three files fix that, for images only.

```text
Mac                                         Linux box
image-server.py  ◀── SSH RemoteForward ──  xclip (shim in ~/.local/bin)
127.0.0.1:18339/png                         127.0.0.1:18339  ◀── Claude Code, Ctrl+V
```

| File | Where it runs | What it does |
|---|---|---|
| `image-server.py` | macOS, from launchd | Serves the clipboard image as PNG at `127.0.0.1:18339/png`. 404 when there's no image. Never sends text |
| `clipboard-image.plist` | macOS | The launchd agent. `install.sh` copies it to `~/Library/LaunchAgents/` with your label from `install.conf` |
| `xclip` | Linux | A shim that answers Claude Code's two `xclip` calls from the forwarded port, and passes anything else to the real `xclip` |

## Turn it on

1. Run `install.sh` on the Mac and on the Linux box.
2. Add the forward to the box's entry in `ssh/config`:

   ```sshconfig
   Host my-server
     RemoteForward 127.0.0.1:18339 127.0.0.1:18339
   ```

3. SSH in again, copy an image on the Mac, and press Ctrl+V in Claude Code.

Check the server with `launchctl print gui/$(id -u)/local.clipboard-image`. Errors go to `/tmp/clipboard-image.log`. To turn it off, set `CLIPBOARD_LABEL=""` in `install.conf`.
