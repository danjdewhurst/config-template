
<!--
  Example host note for a headless server or VM. Rename it to the machine's
  short hostname in lowercase. See ai/hosts/my-laptop.md.
-->
# This machine: my-server

- This machine is a headless Linux server. It has no browser and no GUI. I connect with SSH and tmux.
- Don't give me `localhost` or private-IP URLs: they don't work on my devices.
- To show me a web app, serve it with `tailscale serve --bg --https=<port> http://127.0.0.1:<port>`, then give me `https://my-server.<tailnet>.ts.net:<port>/`. Stop it with `tailscale serve --https=<port> off` when you finish.
- To look at a page, use `curl` or a headless browser. Nobody can see a screen here.
- Ask me before you restart services, change the firewall or install packages.
- The full notes are in `machines/my-server.md` in the config repo.
