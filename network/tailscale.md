# Tailscale

<!-- An example network note. Fill it in from `tailscale status`. -->

| | |
|---|---|
| Tailnet | (your tailnet's owner) |
| MagicDNS suffix | `<tailnet>.ts.net` |
| Exit nodes | None |
| Subnet routes | None |

## Devices

| Device | OS | MagicDNS name | Notes |
|---|---|---|---|
| my-laptop | macOS | my-laptop.<tailnet>.ts.net | Main machine. See `machines/my-laptop.md` |
| my-phone | iOS | my-phone.<tailnet>.ts.net | |
| my-server | Linux | my-server.<tailnet>.ts.net | See `machines/my-server.md` |

## Refresh

```sh
tailscale status
```

_Last updated: YYYY-MM-DD_
